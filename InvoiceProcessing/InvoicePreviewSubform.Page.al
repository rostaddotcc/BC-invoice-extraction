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
                    Width = 6;
                }
                field("Line Description"; Rec."Line Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Description of the line item';
                    ShowMandatory = true;
                }
                field("Line Quantity"; Rec."Line Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Quantity of the line item';
                    BlankZero = true;
                }
                field("Line Unit Price"; Rec."Line Unit Price")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unit price of the line item';
                    BlankZero = true;
                    AutoFormatType = 2;
                }
                field("Line Amount"; Rec."Line Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total amount for the line';
                    BlankZero = true;
                    AutoFormatType = 1;
                }
                field("Line VAT %"; Rec."Line VAT %")
                {
                    ApplicationArea = All;
                    ToolTip = 'VAT percentage for the line';
                    BlankZero = true;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DeleteLine)
            {
                ApplicationArea = All;
                Caption = 'Delete Line';
                ToolTip = 'Remove this line from the invoice';
                Image = Delete;

                trigger OnAction()
                begin
                    if Confirm('Delete this line?', false) then
                        Rec.Delete();
                end;
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        // Ensure new lines are assigned proper line numbers
        if Rec."Line No." = 0 then begin
            Rec."Entry No." := 1;
            Rec."Line No." := GetNextLineNo();
        end;
    end;

    local procedure GetNextLineNo(): Integer
    var
        TempBuffer: Record "Temp Invoice Buffer";
    begin
        TempBuffer.SetRange("Entry No.", 1);
        if TempBuffer.FindLast() then
            exit(TempBuffer."Line No." + 10000);
        exit(10000);
    end;
}
