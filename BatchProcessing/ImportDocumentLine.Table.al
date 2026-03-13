table 50103 "Import Document Line"
{
    Caption = 'Import Document Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
        }
        field(10; "Description"; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(11; "Quantity"; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(12; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            DataClassification = CustomerContent;
            AutoFormatType = 2;
        }
        field(13; "Line Amount"; Decimal)
        {
            Caption = 'Line Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
        field(14; "VAT %"; Decimal)
        {
            Caption = 'VAT %';
            DataClassification = CustomerContent;
        }
        field(20; "Type"; Enum "Purchase Line Type")
        {
            Caption = 'Type';
            DataClassification = CustomerContent;
            InitValue = "G/L Account";
        }
        field(21; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
            TableRelation = IF (Type = CONST("G/L Account")) "G/L Account" WHERE("Account Type" = CONST(Posting), Blocked = CONST(false))
            ELSE IF (Type = CONST(Item)) Item WHERE(Blocked = CONST(false))
            ELSE IF (Type = CONST("Fixed Asset")) "Fixed Asset" WHERE(Blocked = CONST(false))
            ELSE IF (Type = CONST("Charge (Item)")) "Item Charge";
        }
    }

    keys
    {
        key(PK; "Entry No.", "Line No.")
        {
            Clustered = true;
        }
    }
}
