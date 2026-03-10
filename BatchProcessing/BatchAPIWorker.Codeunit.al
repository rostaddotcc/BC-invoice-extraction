codeunit 50103 "Batch API Worker"
{
    Access = Internal;

    var
        ProcessingErr: Label 'Error processing document %1: %2';

    procedure ProcessDocument(EntryNo: Integer)
    var
        ImportDocHeader: Record "Import Document Header";
        QwenVLAPI: Codeunit "Qwen VL API";
        InvoiceExtraction: Codeunit "Invoice Extraction";
        ExtractedData: JsonObject;
    begin
        if not ImportDocHeader.Get(EntryNo) then
            exit;

        // Ensure we have the media
        if not ImportDocHeader."Media ID".HasValue() then begin
            MarkAsError(ImportDocHeader, 'No image data found');
            exit;
        end;

        try
            // Call AI API
            if not QwenVLAPI.ExtractFromImage(ImportDocHeader."Media ID", ExtractedData) then begin
            MarkAsError(ImportDocHeader, 'Failed to extract data from image');
            exit;
        end;

        // Parse and save to Import Document tables
        InvoiceExtraction.ParseAndSaveToImportDoc(ExtractedData, ImportDocHeader);

        // Mark as ready for review
        ImportDocHeader.Status := ImportDocHeader.Status::Ready;
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Completed;
        ImportDocHeader.Modify();

        // Try to process next pending document
        ProcessNextIfAvailable();

        catch
            MarkAsError(ImportDocHeader, GetLastErrorText());
    end;
    end;

    local procedure MarkAsError(var ImportDocHeader: Record "Import Document Header"; ErrorMsg: Text)
    begin
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Error;
        ImportDocHeader."Error Message" := CopyStr(ErrorMsg, 1, 2048);
        ImportDocHeader.Modify();

        // Try to process next pending document even if this one failed
        ProcessNextIfAvailable();
    end;

    local procedure ProcessNextIfAvailable()
    var
        BatchProcessingMgt: Codeunit "Batch Processing Mgt";
    begin
        // Start next pending document if concurrency allows
        if BatchProcessingMgt.IsConcurrencyAvailable() then
            BatchProcessingMgt.ProcessNextPending();
    end;
}
