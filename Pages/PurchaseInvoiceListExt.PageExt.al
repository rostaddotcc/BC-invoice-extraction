pageextension 50100 "PaperTide Purch. Inv. List Ext" extends "Purchase Invoices"
{
    actions
    {
        addlast(Creation)
        {
            fileUploadAction(UploadInvoices)
            {
                ApplicationArea = All;
                Caption = 'PaperTide Upload';
                ToolTip = 'Upload invoice images or PDFs for AI extraction';
                Image = Import;
                AllowMultipleFiles = true;
                AllowedFileExtensions = '.jpg', '.jpeg', '.png', '.pdf';

                trigger OnAction(Files: List of [FileUpload])
                var
                    CurrentFile: FileUpload;
                    BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
                    FileManagement: Codeunit "File Management";
                    InStream: InStream;
                    FileName: Text;
                    FileExtension: Text;
                    UploadCount: Integer;
                begin
                    foreach CurrentFile in Files do begin
                        FileName := CurrentFile.FileName();
                        FileExtension := LowerCase(FileManagement.GetExtension(FileName));

                        if BatchProcessingMgt.IsValidUploadExtension(FileExtension) then begin
                            CurrentFile.CreateInStream(InStream);
                            if BatchProcessingMgt.ImportFile(InStream, FileName) then
                                UploadCount += 1;
                        end;
                    end;

                    if UploadCount > 0 then begin
                        Message('%1 file(s) queued for processing.', UploadCount);
                        BatchProcessingMgt.ScheduleProcessing();
                    end;
                end;
            }
            action(ViewImportQueue)
            {
                ApplicationArea = All;
                Caption = 'View Import Queue';
                ToolTip = 'View all imported documents waiting for review';
                Image = List;

                trigger OnAction()
                begin
                    Page.Run(Page::"PaperTide Import Documents");
                end;
            }
        }
        addlast(Promoted)
        {
            group(PaperTideGroup)
            {
                Caption = 'PaperTide';
                actionref(UploadInvoicesRef; UploadInvoices)
                {
                }
                actionref(ViewImportQueueRef; ViewImportQueue)
                {
                }
            }
        }
    }
}
