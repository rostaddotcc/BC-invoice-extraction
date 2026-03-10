page 50103 "Invoice Image FactBox V2"
{
    Caption = 'Original Image';
    PageType = CardPart;
    SourceTable = "Import Document Header";

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
}
