codeunit 50106 "PaperTide GL Account Predictor"
{
    Access = Internal;

    var
        SetupNotConfiguredErr: Label 'Auto Coding is not configured. Please configure Coding API Base URL, Key, and Model in PaperTide AI Setup.';
        HttpRequestFailedErr: Label 'Coding API request failed with status code: %1\Error: %2';
        InvalidResponseErr: Label 'Invalid response from coding AI: %1';
        AutoCodingResultLbl: Label 'Auto Coding: %1 of %2 lines classified (%3 High, %4 Medium, %5 Low). %6';

    procedure PredictGLAccounts(EntryNo: Integer)
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        ImportDocLine: Record "PaperTide Import Doc. Line";
        AISetup: Record "PaperTide AI Setup";
        RequestBody: Text;
        ResponseText: Text;
        ResponseJson: JsonArray;
        ResultSummary: Text;
    begin
        if not AISetup.Get() then
            exit;

        if not AISetup."Enable Auto Coding" then
            exit;

        if not ImportDocHeader.Get(EntryNo) then
            exit;

        ImportDocLine.SetRange("Entry No.", EntryNo);
        if ImportDocLine.IsEmpty() then
            exit;

        // Build request and call API
        RequestBody := BuildRequestBody(AISetup, ImportDocHeader, ImportDocLine);
        if not CallCodingAPI(AISetup, RequestBody, ResponseText) then begin
            SetAutoCodingStatus(ImportDocHeader, 'Auto Coding: API call failed');
            exit;
        end;

        // Parse response
        if not ParseResponse(ResponseText, ResponseJson) then begin
            SetAutoCodingStatus(ImportDocHeader, 'Auto Coding: Failed to parse AI response');
            exit;
        end;

        // Apply predictions to import document lines
        ResultSummary := ApplyPredictions(EntryNo, ResponseJson);
        SetAutoCodingStatus(ImportDocHeader, ResultSummary);
    end;

    [TryFunction]
    procedure TryPredictGLAccounts(EntryNo: Integer)
    begin
        PredictGLAccounts(EntryNo);
    end;

    procedure TestCodingConnection(): Boolean
    var
        AISetup: Record "PaperTide AI Setup";
        HttpClient: HttpClient;
        HttpRequest: HttpRequestMessage;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        ContentHeaders: HttpHeaders;
        HttpContent: HttpContent;
        RequestBody: Text;
    begin
        if not AISetup.Get() then
            exit(false);

        if (AISetup."Coding API Base URL" = '') or (not AISetup.HasCodingAPIKey()) then
            exit(false);

        RequestBody := '{' +
            '"model": "' + AISetup."Coding Model Name" + '",' +
            '"messages": [{' +
                '"role": "user",' +
                '"content": "test"' +
            '}],' +
            '"max_tokens": 5' +
        '}';

        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        HttpClient.Timeout(AISetup."Coding Request Timeout (ms)");

        HttpRequest.Method := 'POST';
        HttpRequest.SetRequestUri(AISetup."Coding API Base URL" + '/chat/completions');
        HttpRequest.Content(HttpContent);
        HttpRequest.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AISetup.GetCodingAPIKey()));

        exit(HttpClient.Send(HttpRequest, HttpResponse) and HttpResponse.IsSuccessStatusCode());
    end;

    local procedure BuildRequestBody(
        AISetup: Record "PaperTide AI Setup";
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        var ImportDocLine: Record "PaperTide Import Doc. Line"): Text
    var
        JsonObj: JsonObject;
        MessagesArr: JsonArray;
        SystemMsg: JsonObject;
        UserMsg: JsonObject;
        SystemPromptText: Text;
        UserMessageText: Text;
        ChartContext: Text;
        ItemContext: Text;
        DimensionContext: Text;
    begin
        // Build system prompt with chart of accounts
        SystemPromptText := AISetup.GetCodingSystemPrompt();

        // Build user message with lines, history, and chart
        UserMessageText := BuildUserMessage(AISetup, ImportDocHeader, ImportDocLine);

        // Chart of accounts context
        ChartContext := AISetup.GetChartOfAccountsContext();
        if ChartContext = '' then
            ChartContext := AISetup.BuildChartOfAccountsContextV2();

        if ChartContext <> '' then
            UserMessageText += '\n\nChart of Accounts (Type: G/L Account):\n' + ChartContext;

        // Item context
        ItemContext := BuildItemContext(AISetup);
        if ItemContext <> '' then
            UserMessageText += '\n\nItems (Type: Item):\n' + ItemContext;

        // Dimension values context
        DimensionContext := BuildDimensionContext();
        if DimensionContext <> '' then
            UserMessageText += '\n\n' + DimensionContext;

        // System message
        SystemMsg.Add('role', 'system');
        SystemMsg.Add('content', SystemPromptText);
        MessagesArr.Add(SystemMsg);

        // User message
        UserMsg.Add('role', 'user');
        UserMsg.Add('content', UserMessageText);
        MessagesArr.Add(UserMsg);

        // Build request
        JsonObj.Add('model', AISetup."Coding Model Name");
        JsonObj.Add('messages', MessagesArr);
        JsonObj.Add('max_tokens', AISetup."Coding Max Tokens");
        JsonObj.Add('temperature', AISetup."Coding Temperature");

        JsonObj.WriteTo(UserMessageText);
        exit(UserMessageText);
    end;

    local procedure BuildItemContext(AISetup: Record "PaperTide AI Setup"): Text
    var
        Item: Record Item;
        Context: Text;
        LineCount: Integer;
        MaxItems: Integer;
    begin
        Context := '';
        LineCount := 0;
        MaxItems := AISetup."Chart Context Max Accounts";
        if MaxItems <= 0 then
            MaxItems := 200;

        Item.SetRange(Blocked, false);
        if Item.FindSet() then begin
            repeat
                if Context <> '' then
                    Context += '\n';
                Context += '- ' + Item."No." + ': ' + Item.Description;
                if Item."Item Category Code" <> '' then
                    Context += ' (Category: ' + Item."Item Category Code" + ')';
                LineCount += 1;

                if LineCount >= MaxItems then
                    break;
            until Item.Next() = 0;
        end;

        exit(Context);
    end;

    local procedure BuildDimensionContext(): Text
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        Context: Text;
        DimCount: Integer;
        ValueCount: Integer;
    begin
        if not GeneralLedgerSetup.Get() then
            exit('');

        Context := 'Available Dimensions for line classification:';

        // Global Dimension 1
        if GeneralLedgerSetup."Global Dimension 1 Code" <> '' then begin
            if Dimension.Get(GeneralLedgerSetup."Global Dimension 1 Code") then begin
                Context += '\n\nDimension 1: ' + Dimension.Code + ' (' + Dimension.Name + ')';
                Context += '\nValues:';
                DimensionValue.SetRange("Dimension Code", Dimension.Code);
                DimensionValue.SetRange("Dimension Value Type", DimensionValue."Dimension Value Type"::Standard);
                DimensionValue.SetRange(Blocked, false);
                ValueCount := 0;
                if DimensionValue.FindSet() then
                    repeat
                        Context += '\n- ' + DimensionValue.Code + ': ' + DimensionValue.Name;
                        ValueCount += 1;
                        if ValueCount >= 100 then
                            break;
                    until DimensionValue.Next() = 0;
                DimCount += 1;
            end;
        end;

        // Global Dimension 2
        if GeneralLedgerSetup."Global Dimension 2 Code" <> '' then begin
            if Dimension.Get(GeneralLedgerSetup."Global Dimension 2 Code") then begin
                Context += '\n\nDimension 2: ' + Dimension.Code + ' (' + Dimension.Name + ')';
                Context += '\nValues:';
                DimensionValue.SetRange("Dimension Code", Dimension.Code);
                DimensionValue.SetRange("Dimension Value Type", DimensionValue."Dimension Value Type"::Standard);
                DimensionValue.SetRange(Blocked, false);
                ValueCount := 0;
                if DimensionValue.FindSet() then
                    repeat
                        Context += '\n- ' + DimensionValue.Code + ': ' + DimensionValue.Name;
                        ValueCount += 1;
                        if ValueCount >= 100 then
                            break;
                    until DimensionValue.Next() = 0;
                DimCount += 1;
            end;
        end;

        if DimCount = 0 then
            exit('');

        exit(Context);
    end;

    local procedure BuildUserMessage(
        AISetup: Record "PaperTide AI Setup";
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        var ImportDocLine: Record "PaperTide Import Doc. Line"): Text
    var
        Vendor: Record Vendor;
        VendorName: Text;
        Message: Text;
        LineIndex: Integer;
    begin
        // Vendor context
        if ImportDocHeader."Vendor No." <> '' then begin
            if Vendor.Get(ImportDocHeader."Vendor No.") then
                VendorName := Vendor.Name
            else
                VendorName := ImportDocHeader."Vendor Name";
            Message := 'Vendor: ' + VendorName + ' (' + ImportDocHeader."Vendor No." + ')';
        end else
            Message := 'Vendor: ' + ImportDocHeader."Vendor Name" + ' (unknown)';

        // Invoice lines
        Message += '\n\nInvoice Lines to classify:';
        LineIndex := 1;
        ImportDocLine.SetRange("Entry No.", ImportDocHeader."Entry No.");
        if ImportDocLine.FindSet() then
            repeat
                Message += '\n' + Format(LineIndex) + '. [Line ' + Format(ImportDocLine."Line No.") + '] "' +
                    ImportDocLine.Description + '"';
                if ImportDocLine.Quantity <> 0 then
                    Message += ' - Qty: ' + Format(ImportDocLine.Quantity);
                if ImportDocLine."Line Amount" <> 0 then
                    Message += ', Amount: ' + Format(ImportDocLine."Line Amount", 0, '<Precision,2:2><Standard Format,1>');
                LineIndex += 1;
            until ImportDocLine.Next() = 0;

        // Posting history
        if (ImportDocHeader."Vendor No." <> '') and (AISetup."Coding History Invoices" > 0) then begin
            Message += BuildPostingHistoryContext(ImportDocHeader."Vendor No.", AISetup."Coding History Invoices", AISetup."Coding History Days");
        end;

        exit(Message);
    end;

    local procedure BuildPostingHistoryContext(VendorNo: Code[20]; MaxInvoices: Integer; MaxDays: Integer): Text
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        DimSetEntry: Record "Dimension Set Entry";
        GLAccount: Record "G/L Account";
        Context: Text;
        DimText: Text;
        AccountName: Text;
        InvoiceCount: Integer;
        LineCount: Integer;
    begin
        Context := '';
        InvoiceCount := 0;
        LineCount := 0;

        PurchInvHeader.SetRange("Buy-from Vendor No.", VendorNo);
        if MaxDays > 0 then
            PurchInvHeader.SetFilter("Posting Date", '>=%1', CalcDate('<-' + Format(MaxDays) + 'D>', Today()));
        PurchInvHeader.SetCurrentKey("Posting Date");
        // Sort descending to get most recent first
        PurchInvHeader.Ascending(false);

        if not PurchInvHeader.FindSet() then
            exit('');

        repeat
            PurchInvLine.SetRange("Document No.", PurchInvHeader."No.");
            PurchInvLine.SetFilter(Type, '<>%1', PurchInvLine.Type::" ");
            if PurchInvLine.FindSet() then
                repeat
                    // Get GL account name
                    AccountName := '';
                    if (PurchInvLine.Type = PurchInvLine.Type::"G/L Account") and (PurchInvLine."No." <> '') then
                        if GLAccount.Get(PurchInvLine."No.") then
                            AccountName := GLAccount.Name;

                    // Build dimension text
                    DimText := '';
                    if PurchInvLine."Dimension Set ID" <> 0 then begin
                        DimSetEntry.SetRange("Dimension Set ID", PurchInvLine."Dimension Set ID");
                        if DimSetEntry.FindSet() then
                            repeat
                                if DimText <> '' then
                                    DimText += ', ';
                                DimText += DimSetEntry."Dimension Code" + '=' + DimSetEntry."Dimension Value Code";
                            until DimSetEntry.Next() = 0;
                    end;

                    Context += '\n- "' + PurchInvLine.Description + '" → Account: ' + PurchInvLine."No.";
                    if AccountName <> '' then
                        Context += ' (' + AccountName + ')';
                    Context += ', Type: ' + Format(PurchInvLine.Type);
                    if PurchInvLine."No." <> '' then
                        if PurchInvLine.Type = PurchInvLine.Type::Item then
                            Context += ' (' + PurchInvLine."No." + ')';
                    if DimText <> '' then
                        Context += ', Dimensions: [' + DimText + ']';

                    LineCount += 1;
                until PurchInvLine.Next() = 0;

            InvoiceCount += 1;
        until (PurchInvHeader.Next() = 0) or (InvoiceCount >= MaxInvoices);

        if Context = '' then
            exit('');

        exit('\n\nPosting History (last ' + Format(InvoiceCount) + ' invoices from this vendor):' + Context);
    end;

    local procedure CallCodingAPI(
        AISetup: Record "PaperTide AI Setup";
        RequestBody: Text;
        var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpRequest: HttpRequestMessage;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        ContentHeaders: HttpHeaders;
    begin
        ValidateSetup(AISetup);

        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        HttpClient.Timeout(AISetup."Coding Request Timeout (ms)");

        HttpRequest.Method := 'POST';
        HttpRequest.SetRequestUri(AISetup."Coding API Base URL" + '/chat/completions');
        HttpRequest.Content(HttpContent);
        HttpRequest.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AISetup.GetCodingAPIKey()));

        if not HttpClient.Send(HttpRequest, HttpResponse) then
            exit(false);

        if not HttpResponse.IsSuccessStatusCode() then begin
            HttpResponse.Content().ReadAs(ResponseText);
            Error(HttpRequestFailedErr, HttpResponse.HttpStatusCode(), ResponseText);
        end;

        HttpResponse.Content().ReadAs(ResponseText);
        exit(true);
    end;

    local procedure ValidateSetup(AISetup: Record "PaperTide AI Setup")
    begin
        if AISetup."Coding API Base URL" = '' then
            Error(SetupNotConfiguredErr);
        if not AISetup.HasCodingAPIKey() then
            Error(SetupNotConfiguredErr);
        if AISetup."Coding Model Name" = '' then
            Error(SetupNotConfiguredErr);
    end;

    local procedure ParseResponse(ResponseText: Text; var PredictionsArr: JsonArray): Boolean
    var
        ResponseJson: JsonObject;
        ChoicesArr: JsonArray;
        ChoiceObj: JsonObject;
        MessageObj: JsonObject;
        ContentToken: JsonToken;
        ContentText: Text;
    begin
        if not ResponseJson.ReadFrom(ResponseText) then
            exit(false);

        if not ResponseJson.Get('choices', ContentToken) then
            exit(false);

        ChoicesArr := ContentToken.AsArray();
        if ChoicesArr.Count() = 0 then
            exit(false);

        ChoicesArr.Get(0, ContentToken);
        ChoiceObj := ContentToken.AsObject();

        if not ChoiceObj.Get('message', ContentToken) then
            exit(false);

        MessageObj := ContentToken.AsObject();

        if not MessageObj.Get('content', ContentToken) then
            exit(false);

        ContentText := ContentToken.AsValue().AsText();
        ContentText := CleanJsonResponse(ContentText);

        if not PredictionsArr.ReadFrom(ContentText) then
            exit(false);

        exit(true);
    end;

    local procedure CleanJsonResponse(ResponseText: Text) CleanText: Text
    begin
        CleanText := ResponseText;

        if CopyStr(CleanText, 1, 7).ToLower() = '```json' then
            CleanText := CleanText.Substring(8)
        else if CleanText.StartsWith('```') then
            CleanText := CleanText.Substring(4);
        if CleanText.EndsWith('```') then
            CleanText := CleanText.Substring(1, StrLen(CleanText) - 3);

        CleanText := CleanText.Trim();
    end;

    local procedure ApplyPredictions(EntryNo: Integer; PredictionsArr: JsonArray): Text
    var
        ImportDocLine: Record "PaperTide Import Doc. Line";
        PredictionToken: JsonToken;
        PredictionObj: JsonObject;
        LineNo: Integer;
        AccountNo: Code[20];
        LineType: Text;
        Confidence: Text[10];
        Reason: Text[250];
        i: Integer;
        TotalLines: Integer;
        ClassifiedCount: Integer;
        HighCount: Integer;
        MediumCount: Integer;
        LowCount: Integer;
        ExtraInfo: Text;
        MatchedByIndex: Boolean;
        LineNumbers: List of [Integer];
    begin
        // Collect line numbers in order for index-based fallback matching
        ImportDocLine.SetRange("Entry No.", EntryNo);
        if ImportDocLine.FindSet() then
            repeat
                LineNumbers.Add(ImportDocLine."Line No.");
                TotalLines += 1;
            until ImportDocLine.Next() = 0;

        for i := 0 to PredictionsArr.Count() - 1 do begin
            PredictionsArr.Get(i, PredictionToken);
            PredictionObj := PredictionToken.AsObject();

            LineNo := GetJsonIntValue(PredictionObj, 'LineNo');
            AccountNo := CopyStr(GetJsonTextValue(PredictionObj, 'No'), 1, 20);
            // Fallback: check old field name GLAccountNo for backward compatibility
            if AccountNo = '' then
                AccountNo := CopyStr(GetJsonTextValue(PredictionObj, 'GLAccountNo'), 1, 20);
            LineType := GetJsonTextValue(PredictionObj, 'Type');
            Confidence := CopyStr(GetJsonTextValue(PredictionObj, 'Confidence'), 1, 10);
            Reason := CopyStr(GetJsonTextValue(PredictionObj, 'Reason'), 1, 250);

            // Try exact LineNo match first
            MatchedByIndex := false;
            if not ImportDocLine.Get(EntryNo, LineNo) then begin
                // Fallback: match by array index (AI returned wrong LineNo)
                if (i + 1) <= LineNumbers.Count() then begin
                    LineNumbers.Get(i + 1, LineNo);
                    if ImportDocLine.Get(EntryNo, LineNo) then begin
                        MatchedByIndex := true;
                    end else
                        // Could not match at all, skip
                        AccountNo := '';  // Force skip
                end;
            end;

            if ImportDocLine."Entry No." = EntryNo then begin
                // Determine and set line type
                if UpperCase(LineType) = 'ITEM' then
                    ImportDocLine.Type := ImportDocLine.Type::Item
                else
                    ImportDocLine.Type := ImportDocLine.Type::"G/L Account";

                // Validate account/item before applying
                if (AccountNo <> '') and ValidateLineNo(ImportDocLine.Type, AccountNo) then begin
                    ImportDocLine."No." := AccountNo;
                    ClassifiedCount += 1;

                    case UpperCase(Confidence) of
                        'HIGH':
                            HighCount += 1;
                        'MEDIUM':
                            MediumCount += 1;
                        else
                            LowCount += 1;
                    end;
                end;

                // Apply dimension suggestions
                ApplyDimensionSuggestions(ImportDocLine, PredictionObj);

                ImportDocLine."GL Suggestion Confidence" := Confidence;
                if MatchedByIndex then
                    Reason := CopyStr('[Matched by index] ' + Reason, 1, 250);
                ImportDocLine."GL Suggestion Reason" := Reason;
                ImportDocLine.Modify();
            end;
        end;

        ExtraInfo := '';
        if PredictionsArr.Count() <> TotalLines then
            ExtraInfo := StrSubstNo('AI returned %1 predictions for %2 lines.', PredictionsArr.Count(), TotalLines);

        exit(StrSubstNo(AutoCodingResultLbl, ClassifiedCount, TotalLines, HighCount, MediumCount, LowCount, ExtraInfo));
    end;

    local procedure ValidateLineNo(LineType: Enum "Purchase Line Type"; AccountNo: Code[20]): Boolean
    var
        GLAccount: Record "G/L Account";
        Item: Record Item;
    begin
        case LineType of
            LineType::"G/L Account":
                begin
                    if not GLAccount.Get(AccountNo) then
                        exit(false);
                    if GLAccount."Account Type" <> GLAccount."Account Type"::Posting then
                        exit(false);
                    if GLAccount.Blocked then
                        exit(false);
                    exit(true);
                end;
            LineType::Item:
                begin
                    if not Item.Get(AccountNo) then
                        exit(false);
                    if Item.Blocked then
                        exit(false);
                    exit(true);
                end;
            else
                exit(false);
        end;
    end;

    local procedure ApplyDimensionSuggestions(var ImportDocLine: Record "PaperTide Import Doc. Line"; PredictionObj: JsonObject)
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        DimensionValue: Record "Dimension Value";
        DimensionsToken: JsonToken;
        DimensionsArr: JsonArray;
        DimToken: JsonToken;
        DimObj: JsonObject;
        DimCode: Code[20];
        DimValueCode: Code[20];
        DimSuggestionText: Text;
        j: Integer;
    begin
        if not PredictionObj.Get('Dimensions', DimensionsToken) then
            exit;

        if not DimensionsToken.IsArray() then
            exit;

        DimensionsArr := DimensionsToken.AsArray();
        if DimensionsArr.Count() = 0 then
            exit;

        if not GeneralLedgerSetup.Get() then
            exit;

        for j := 0 to DimensionsArr.Count() - 1 do begin
            DimensionsArr.Get(j, DimToken);
            DimObj := DimToken.AsObject();

            DimCode := CopyStr(GetJsonTextValue(DimObj, 'Code'), 1, 20);
            DimValueCode := CopyStr(GetJsonTextValue(DimObj, 'Value'), 1, 20);

            if (DimCode = '') or (DimValueCode = '') then
                // Skip empty suggestions
            else begin
                // Validate dimension value exists and is not blocked
                if DimensionValue.Get(DimCode, DimValueCode) and (not DimensionValue.Blocked) then begin
                    // Map to shortcut dimension fields
                    if DimCode = GeneralLedgerSetup."Global Dimension 1 Code" then
                        ImportDocLine."Shortcut Dimension 1 Code" := DimValueCode
                    else if DimCode = GeneralLedgerSetup."Global Dimension 2 Code" then
                        ImportDocLine."Shortcut Dimension 2 Code" := DimValueCode;
                end;

                // Always store in suggestion text for visibility
                if DimSuggestionText <> '' then
                    DimSuggestionText += ', ';
                DimSuggestionText += DimCode + '=' + DimValueCode;
            end;
        end;

        if DimSuggestionText <> '' then
            ImportDocLine."Dimension Suggestion" := CopyStr(DimSuggestionText, 1, 250);
    end;

    local procedure SetAutoCodingStatus(var ImportDocHeader: Record "PaperTide Import Doc. Header"; StatusText: Text)
    begin
        ImportDocHeader."Auto Coding Status" := CopyStr(StatusText, 1, 250);
        ImportDocHeader.Modify();
    end;

    local procedure GetJsonTextValue(JsonObj: JsonObject; FieldName: Text): Text
    var
        JsonToken: JsonToken;
    begin
        if not JsonObj.Get(FieldName, JsonToken) then
            exit('');
        if JsonToken.AsValue().IsNull() then
            exit('');
        exit(JsonToken.AsValue().AsText());
    end;

    local procedure GetJsonIntValue(JsonObj: JsonObject; FieldName: Text): Integer
    var
        JsonToken: JsonToken;
        ValueText: Text;
        Result: Integer;
    begin
        if not JsonObj.Get(FieldName, JsonToken) then
            exit(0);
        if JsonToken.AsValue().IsNull() then
            exit(0);
        ValueText := JsonToken.AsValue().AsText();
        if Evaluate(Result, ValueText) then
            exit(Result);
        exit(0);
    end;
}
