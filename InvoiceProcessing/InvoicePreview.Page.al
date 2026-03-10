page 50101 "Invoice Preview"
{
    Caption = 'Invoice Preview';
    PageType = Card;
    SourceTable = "Temp Invoice Buffer";
    DataCaptionExpression = Rec."Vendor Name";
    InsertAllowed = false;
    DeleteAllowed = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            group(Header)
            {
                Caption = 'Invoice Header';
                Editable = IsEditable;

                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor number';
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        UpdateHeaderInBuffer();
                    end;
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor name';
                    Editable = false;
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor invoice number';
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        UpdateHeaderInBuffer();
                    end;
                }
                field("Invoice Date"; Rec."Invoice Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the invoice date';

                    trigger OnValidate()
                    begin
                        UpdateHeaderInBuffer();
                    end;
                }
                field("Due Date"; Rec."Due Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the due date';

                    trigger OnValidate()
                    begin
                        UpdateHeaderInBuffer();
                    end;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency code';

                    trigger OnValidate()
                    begin
                        UpdateHeaderInBuffer();
                    end;
                }
            }

            group(Amounts)
            {
                Caption = 'Amounts';
                Editable = IsEditable;

                field("Amount Excl. VAT"; Rec."Amount Excl. VAT")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the amount excluding VAT';
                    Editable = false;
                }
                field("VAT Amount"; Rec."VAT Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the VAT amount';
                    Editable = false;
                }
                field("Amount Incl. VAT"; Rec."Amount Incl. VAT")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the amount including VAT';
                    Style = Strong;
                    Editable = false;
                }
            }

            part(Lines; "Invoice Preview Subform")
            {
                ApplicationArea = All;
                Caption = 'Lines';
                SubPageLink = "Entry No." = field("Entry No.");
                Editable = IsEditable;
            }
        }

        area(FactBoxes)
        {
            part(ImagePreview; "Invoice Image FactBox")
            {
                ApplicationArea = All;
                Caption = 'Original Image';
                SubPageLink = "Entry No." = field("Entry No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AcceptAndCreate)
            {
                ApplicationArea = All;
                Caption = 'Accept && Create Invoice';
                ToolTip = 'Create the purchase invoice with the current values';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    InvoiceExtraction: Codeunit "Invoice Extraction";
                    InvoiceNo: Code[20];
                begin
                    if not ValidateBeforeCreate() then
                        exit;

                    if not Confirm('Create purchase invoice with these values?', false) then
                        exit;

                    InvoiceNo := InvoiceExtraction.CreatePurchaseInvoice(Rec);
                    
                    Message('Purchase Invoice %1 has been created.', InvoiceNo);
                    
                    // Open the created invoice
                    OpenPurchaseInvoice(InvoiceNo);
                    
                    CurrPage.Close();
                end;
            }
            action(ToggleEdit)
            {
                ApplicationArea = All;
                Caption = 'Edit Values';
                ToolTip = 'Toggle editing of extracted values';
                Image = Edit;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    IsEditable := not IsEditable;
                    if IsEditable then
                        Message('Editing enabled. You can now modify the values.')
                    else
                        Message('Editing disabled. Values are locked.');
                end;
            }
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                ToolTip = 'Cancel without creating invoice';
                Image = Cancel;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    if Confirm('Discard this invoice preview?', false) then
                        CurrPage.Close();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        IsEditable := false;
        Rec.Get(Rec."Entry No.", 0); // Get header record
    end;

    trigger OnAfterGetCurrRecord()
    begin
        Rec.Get(Rec."Entry No.", 0); // Always show header
    end;

    local procedure UpdateHeaderInBuffer()
    var
        HeaderBuffer: Record "Temp Invoice Buffer";
    begin
        HeaderBuffer.Get(Rec."Entry No.", 0);
        HeaderBuffer."Vendor No." := Rec."Vendor No.";
        HeaderBuffer."Invoice No." := Rec."Invoice No.";
        HeaderBuffer."Invoice Date" := Rec."Invoice Date";
        HeaderBuffer."Due Date" := Rec."Due Date";
        HeaderBuffer."Currency Code" := Rec."Currency Code";
        HeaderBuffer.Modify();
    end;

    local procedure ValidateBeforeCreate(): Boolean
    var
        Vendor: Record Vendor;
    begin
        if Rec."Vendor No." = '' then begin
            Error('Vendor No. is required.');
            exit(false);
        end;

        if not Vendor.Get(Rec."Vendor No.") then begin
            Error('Vendor %1 does not exist.', Rec."Vendor No.");
            exit(false);
        end;

        if Rec."Invoice No." = '' then begin
            Error('Invoice No. is required.');
            exit(false);
        end;

        // Check for duplicate vendor invoice no.
        if CheckDuplicateInvoiceNo(Rec."Vendor No.", Rec."Invoice No.") then
            if not Confirm('An invoice from this vendor with number %1 already exists. Continue anyway?', false, Rec."Invoice No.") then
                exit(false);

        exit(true);
    end;

    local procedure CheckDuplicateInvoiceNo(VendorNo: Code[20]; InvoiceNo: Code[35]): Boolean
    var
        PurchHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
    begin
        // Check in open invoices
        PurchHeader.SetRange("Document Type", PurchHeader."Document Type"::Invoice);
        PurchHeader.SetRange("Buy-from Vendor No.", VendorNo);
        PurchHeader.SetRange("Vendor Invoice No.", InvoiceNo);
        if not PurchHeader.IsEmpty() then
            exit(true);

        // Check in posted invoices
        PurchInvHeader.SetRange("Buy-from Vendor No.", VendorNo);
        PurchInvHeader.SetRange("Vendor Invoice No.", InvoiceNo);
        if not PurchInvHeader.IsEmpty() then
            exit(true);

        exit(false);
    end;

    local procedure OpenPurchaseInvoice(InvoiceNo: Code[20])
    var
        PurchHeader: Record "Purchase Header";
    begin
        PurchHeader.Get(PurchHeader."Document Type"::Invoice, InvoiceNo);
        Page.Run(Page::"Purchase Invoice", PurchHeader);
    end;

    var
        IsEditable: Boolean;
}

// Subform for lines
page 50102 "Invoice Preview Subform"
{
    Caption = 'Lines';
    PageType = ListPart;
    SourceTable = "Temp Invoice Buffer";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Line number';
                    Editable = false;
                    Visible = false;
                }
                field("Line Description"; Rec."Line Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Description';
                }
                field("Line Quantity"; Rec."Line Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Quantity';
                }
                field("Line Unit Price"; Rec."Line Unit Price")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unit price';
                }
                field("Line Amount"; Rec."Line Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Line amount';
                    Editable = false;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetFilter("Line No.", '>0'); // Show only lines, not header
    end;
}

// FactBox for image preview
page 50103 "Invoice Image FactBox"
{
    Caption = 'Original Image';
    PageType = CardPart;
    SourceTable = "Temp Invoice Buffer";

    layout
    {
        area(Content)
        {
            field(ImageField; Rec."Media ID")
            {
                ApplicationArea = All;
                ShowCaption = false;
                ToolTip = 'Original uploaded invoice image';
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange("Line No.", 0); // Only header has the image
    end;
}
