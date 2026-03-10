page 50103 "Invoice Image FactBox"
{
    Caption = 'Original Image';
    PageType = CardPart;
    SourceTable = "Temp Invoice Buffer";

    layout
    {
        area(Content)
        {
            field(ImagePreview; Rec."Media ID")
            {
                ApplicationArea = All;
                ShowCaption = false;
                ToolTip = 'Original invoice image for verification';
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        // Ensure we display the header record which contains the image
        if Rec."Line No." <> 0 then begin
            if not Rec.Get(Rec."Entry No.", 0) then
                Clear(Rec);
        end;
    end;
}
