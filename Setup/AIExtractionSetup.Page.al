page 50100 "AI Extraction Setup"
{
    Caption = 'AI Extraction Setup';
    PageType = Card;
    SourceTable = "AI Extraction Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the base URL for the Qwen-VL API';
                }
                field("API Key"; Rec."API Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the API key for Qwen-VL service';
                    ExtendedDatatype = Masked;
                }
                field("Model Name"; Rec."Model Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the model name (qwen-vl-max recommended)';
                }
            }

            group(Parameters)
            {
                Caption = 'AI Parameters';

                field("Max Tokens"; Rec."Max Tokens")
                {
                    ApplicationArea = All;
                    ToolTip = 'Maximum tokens for AI response';
                }
                field(Temperature; Rec.Temperature)
                {
                    ApplicationArea = All;
                    ToolTip = 'Temperature for AI creativity (0.0-1.0 recommended)';
                }
                field("Request Timeout (ms)"; Rec."Request Timeout (ms)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Timeout for API requests in milliseconds';
                }
            }

            group(Defaults)
            {
                Caption = 'Default Values';

                field("Default G/L Account"; Rec."Default G/L Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Default G/L account for invoice lines';
                }
            }

            group(SystemPrompt)
            {
                Caption = 'System Prompt';

                field(SystemPromptControl; SystemPromptText)
                {
                    ApplicationArea = All;
                    Caption = 'System Prompt';
                    ToolTip = 'Instructions for the AI on how to extract and format invoice data';
                    MultiLine = true;
                    ShowCaption = false;
                    ExtendedDatatype = RichContent;

                    trigger OnValidate()
                    begin
                        Rec.SetSystemPrompt(SystemPromptText);
                    end;
                }
            }

            group(FutureFeatures)
            {
                Caption = 'Future Features (Reserved)';
                Visible = false; // Hidden until PDF conversion is implemented

                field("Enable PDF Conversion"; Rec."Enable PDF Conversion")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable PDF conversion (reserved for v2.0)';
                    Enabled = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection';
                ToolTip = 'Test the connection to Qwen-VL API';
                Image = TestDatabase;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    QwenVLAPI: Codeunit "Qwen VL API";
                begin
                    if QwenVLAPI.TestConnection() then
                        Message('Connection successful! API is reachable.')
                    else
                        Message('Connection failed. Please check your settings.');
                end;
            }
            action(ResetToDefaultPrompt)
            {
                ApplicationArea = All;
                Caption = 'Reset to Default Prompt';
                ToolTip = 'Reset system prompt to default values';
                Image = Restore;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    if Confirm('Reset system prompt to default? This will overwrite any custom prompt.', false) then begin
                        SystemPromptText := Rec.GetDefaultSystemPrompt();
                        Rec.SetSystemPrompt(SystemPromptText);
                    end;
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetOrCreateSetup();
        SystemPromptText := Rec.GetSystemPrompt();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if SystemPromptText <> '' then
            Rec.SetSystemPrompt(SystemPromptText);
        exit(true);
    end;

    var
        SystemPromptText: Text;
}
