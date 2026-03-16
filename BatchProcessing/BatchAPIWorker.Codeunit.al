codeunit 50103 "PaperTide Batch API Worker"
{
    Access = Internal;

    var
        ProcessingErr: Label 'Error processing document %1: %2';
        LastErrorMsg: Text;

    procedure ProcessDocument(EntryNo: Integer)
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        AISetup: Record "PaperTide AI Setup";
        InvoiceExtraction: Codeunit "PaperTide Invoice Extraction";
        GLAccountPredictor: Codeunit "PaperTide GL Account Predictor";
        ExtractedData: JsonObject;
        MediaId: Guid;
    begin
        if not ImportDocHeader.Get(EntryNo) then
            exit;

        // Ensure we have the media
        if IsNullGuid(ImportDocHeader."Media ID") then begin
            MarkAsError(ImportDocHeader, 'No image data found');
            exit;
        end;

        // Step 0: Convert PDF to image if needed (deferred from upload for better UX)
        if ImportDocHeader."Is PDF" then begin
            SetProcessingStage(ImportDocHeader, 'PDF Conversion');
            if not ConvertPdfToImageBackground(ImportDocHeader) then begin
                MarkAsError(ImportDocHeader, 'PDF conversion failed: ' + GetLastErrorText());
                exit;
            end;
        end;

        // Get the media GUID
        MediaId := ImportDocHeader."Media ID";

        // Step 1: Visual Extraction from image
        SetProcessingStage(ImportDocHeader, 'Visual Extraction');
        Clear(LastErrorMsg);
        if not ExtractFromImageWithErrorHandling(MediaId, ExtractedData) then begin
            MarkAsError(ImportDocHeader, LastErrorMsg);
            exit;
        end;

        // Step 2: Parse and save extracted data
        SetProcessingStage(ImportDocHeader, 'Parsing Data');
        if not TryParseAndSave(InvoiceExtraction, ExtractedData, ImportDocHeader) then begin
            MarkAsError(ImportDocHeader, 'Parsing failed: ' + GetLastErrorText());
            exit;
        end;

        // Step 3: Auto Coding (if enabled)
        if AISetup.Get() and AISetup."Enable Auto Coding" then begin
            SetProcessingStage(ImportDocHeader, 'Auto Coding');
            if not GLAccountPredictor.TryPredictGLAccounts(ImportDocHeader."Entry No.") then begin
                ImportDocHeader.Find();
                if ImportDocHeader."Auto Coding Status" = '' then begin
                    ImportDocHeader."Auto Coding Status" := CopyStr('Auto Coding failed: ' + GetLastErrorText(), 1, 250);
                    ImportDocHeader.Modify();
                end;
            end;
        end;

        // Mark as ready for review
        ImportDocHeader.Status := ImportDocHeader.Status::Ready;
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Completed;
        ImportDocHeader."Processing Started At" := 0DT;
        ImportDocHeader."Processing Stage" := '';
        ImportDocHeader.Modify();

        // Try to process next pending document
        ProcessNextIfAvailable();
    end;

    [TryFunction]
    local procedure ExtractFromImageWithErrorHandling(MediaId: Guid; var ExtractedData: JsonObject)
    var
        AIVisionAPI: Codeunit "PaperTide AI Vision API";
    begin
        if not AIVisionAPI.ExtractFromImage(MediaId, ExtractedData) then
            Error('Failed to extract data from image');
    end;

    [TryFunction]
    local procedure TryParseAndSave(
        var InvoiceExtraction: Codeunit "PaperTide Invoice Extraction";
        ExtractedData: JsonObject;
        var ImportDocHeader: Record "PaperTide Import Doc. Header")
    begin
        InvoiceExtraction.ParseAndSaveToImportDoc(ExtractedData, ImportDocHeader);
    end;

    [TryFunction]
    local procedure ConvertPdfToImageBackground(var ImportDocHeader: Record "PaperTide Import Doc. Header")
    var
        PDFConverter: Codeunit "PaperTide PDF Converter";
        ImageTempBlob: Codeunit "Temp Blob";
        PdfInStream: InStream;
        ImageInStream: InStream;
        ImageOutStream: OutStream;
        MediaInStream: InStream;
    begin
        ImportDocHeader.CalcFields("Original PDF Blob");
        if not ImportDocHeader."Original PDF Blob".HasValue() then
            Error('No original PDF data found for document %1', ImportDocHeader."Entry No.");

        ImportDocHeader."Original PDF Blob".CreateInStream(PdfInStream);
        PDFConverter.ConvertPdfToImage(PdfInStream, ImageTempBlob);

        // Store converted image in Image Blob
        ImageTempBlob.CreateInStream(ImageInStream);
        ImportDocHeader."Image Blob".CreateOutStream(ImageOutStream);
        CopyStream(ImageOutStream, ImageInStream);
        ImportDocHeader.Modify();

        // Import as media for preview display
        ImportDocHeader.CalcFields("Image Blob");
        ImportDocHeader."Image Blob".CreateInStream(MediaInStream);
        ImportDocHeader."Invoice Image".ImportStream(MediaInStream, ImportDocHeader."File Name", 'image/png');
        ImportDocHeader.Modify();
    end;

    local procedure MarkAsError(var ImportDocHeader: Record "PaperTide Import Doc. Header"; ErrorMsg: Text)
    begin
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Error;
        ImportDocHeader."Error Message" := CopyStr(ErrorMsg, 1, 2048);
        ImportDocHeader."Processing Started At" := 0DT;
        ImportDocHeader."Processing Stage" := '';
        ImportDocHeader.Modify();

        // Try to process next pending document even if this one failed
        ProcessNextIfAvailable();
    end;

    local procedure ProcessNextIfAvailable()
    var
        BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
    begin
        // Start next pending document if concurrency allows
        if BatchProcessingMgt.IsConcurrencyAvailable() then
            BatchProcessingMgt.ProcessNextPending();
    end;

    local procedure SetProcessingStage(var ImportDocHeader: Record "PaperTide Import Doc. Header"; Stage: Text)
    var
        TimeText: Text;
    begin
        TimeText := Format(Time(), 0, '<Hours24>:<Minutes,2>:<Seconds,2>');
        ImportDocHeader."Processing Stage" := CopyStr(Stage + ' - ' + TimeText, 1, 100);
        ImportDocHeader.Modify();
        Commit(); // Commit so UI can see the progress update immediately
    end;
}
