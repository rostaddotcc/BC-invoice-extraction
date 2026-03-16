# Paper Tide for Business Central

A Per-Tenant Extension (PTE) for Business Central that uses AI vision models to extract invoice data from images and PDF files, with a preview and approval workflow. Compatible with any OpenAI-compatible API (OpenAI, DashScope, Azure OpenAI, Groq, Ollama, etc.).

## Features

- **AI-Powered OCR** - Extract invoice data using any OpenAI-compatible vision model
- **Full PDF Support** - Upload multi-page PDF invoices with automatic conversion to images via Gotenberg (all pages rendered)
- **Multi-Page PDF Attachment** - Original PDF (all pages) attached to created Purchase Invoice
- **Batch Import** - Upload and process multiple invoice images/PDFs simultaneously
- **Concurrency Control** - Process up to 10 images at once with automatic queue management (configurable)
- **Import Queue** - View and manage all imported documents with status tracking
- **Preview & Edit** - Review extracted data with original image in FactBox before creating
- **Auto Coding** - Dedicated text AI model for account and item classification with confidence levels, reasoning, and dimension suggestions
- **Item Support** - AI can suggest both G/L Accounts and Items based on your chart of accounts and item list
- **Dimension Suggestions** - AI suggests dimension values (Global Dimension 1 & 2) based on posting history, editable before invoice creation
- **AI GL Account Suggestion** - AI analyzes your chart of accounts and suggests the most appropriate G/L account for each invoice line (vision model mode)
- **PO Number Extraction** - AI extracts purchase order references from invoices
- **Vendor Name Learning** - System learns vendor name aliases from user corrections for automatic future matching
- **Multi-Field Vendor Matching** - Match vendors by VAT Registration No., bank account/IBAN, name mapping, or name
- **Fraud Detection** - Automated verification of VAT numbers and bank accounts against known vendor data
- **Provider Agnostic** - Built-in presets for OpenAI, DashScope, Azure OpenAI, Groq, Ollama, LocalAI
- **Configurable** - Set up your own API endpoint, model, system prompt, and default G/L account
- **Secure API Key Storage** - API keys stored encrypted in Isolated Storage (per-company isolation, not visible in database backups)
- **Status Tracking** - Track documents from Pending -> Processing -> Ready -> Created
- **Auto Coding Status Logging** - See exactly what the AI classified and why, with detailed result summaries
- **Duplicate Detection** - Prevent duplicate vendor invoice numbers

## Requirements

- Business Central 2024 Wave 2 (v27.4) or later
- AI vision API access (any OpenAI-compatible provider: OpenAI, DashScope, Azure OpenAI, Groq, Ollama, etc.)
- Gotenberg service (for PDF support, optional)
- AL Language extension for VS Code

## Installation

### 1. Clone/Copy the Project

```bash
cd paper-tide
```

### 2. Download Symbols

In VS Code:
- Press `Ctrl+Shift+P`
- Select `AL: Download symbols`
- Ensure your `launch.json` is configured (see below)

### 3. Build the Extension

- Press `Ctrl+Shift+B` to build
- Or run: `alc /project:. /packagecachepath:./.alpackages`

### 4. Publish

- Press `Ctrl+F5` to publish to your sandbox
- Or use: `AL: Publish` command

## Configuration

After publishing, configure the extension:

1. Search for **"PaperTide AI Setup"** in Business Central
2. Fill in the following fields:

| Field | Example Value | Description |
|-------|---------------|-------------|
| API Base URL | `https://api.openai.com/v1` | AI API endpoint (OpenAI-compatible) |
| API Key | `sk-xxxxxxxx` | Your API key (stored encrypted in Isolated Storage) |
| Model Name | `gpt-4o` | Vision model identifier |
| Max Tokens | `2048` | Response length limit |
| Temperature | `0.1` | AI creativity (0.0 = strict) |
| Request Timeout | `60000` | API request timeout in milliseconds |
| Default G/L Account | `6110` | Default G/L account for invoice lines |
| Enable AI GL Suggestion | `Yes` | Let AI suggest G/L accounts based on your chart of accounts |
| Enable PDF Conversion | `Yes` | Allow PDF uploads with automatic image conversion |
| PDF Converter Endpoint | `https://pdf.example.com` | Gotenberg service URL |
| System Prompt | *(see below)* | Instructions for data extraction |

### Auto Coding (Recommended)

Auto Coding uses a separate text AI model to classify invoice lines against your chart of accounts, item list, and dimension values. It runs automatically after vision extraction.

1. Enable **"Enable Auto Coding"** in PaperTide AI Setup
2. Configure the **Coding Model Connection** (can be the same or different provider):
   - Coding API Base URL, Coding API Key, Coding Model Name
3. Click **"Refresh Chart of Accounts"** to cache your G/L accounts
4. The AI will:
   - Classify each line as **G/L Account** or **Item** with the best matching number
   - Suggest **dimension values** (Global Dimension 1 & 2) based on posting history
   - Provide **confidence level** (High/Medium/Low) and **reasoning** per line
5. Results are shown in the Preview page where you can review and edit before creating the invoice

**What the AI considers:**
- Line description, quantity, and amount
- Your full chart of accounts (with categories and subcategories)
- Your item list (with item category codes)
- Available dimension values (Global Dimension 1 & 2)
- Posting history from the same vendor (configurable: last N invoices within N days)
- Dimension history from previous postings

**Configuration options:**
| Field | Default | Description |
|-------|---------|-------------|
| Chart Context Max Accounts | 200 | Max G/L accounts + items sent to AI |
| Coding History Invoices | 10 | Recent posted invoices per vendor for context |
| Coding History Days | 0 | Only include invoices from last N days (0 = no limit) |
| Coding Max Tokens | 1024 | Max tokens for coding AI response |
| Coding Temperature | 0.0 | Deterministic for consistent classification |

### AI GL Account Suggestion (Vision Model Mode)

When **Enable AI GL Suggestion** is activated (without Auto Coding):
1. Click **Refresh Chart of Accounts** to cache your G/L accounts
2. The chart of accounts is included in the vision model's system prompt
3. AI suggests G/L accounts directly during image extraction
4. If AI cannot determine a match, the Default G/L Account is used as fallback

*Note: When Auto Coding is enabled, it takes over GL suggestion with better accuracy (separate classification step with more context).*

### Vendor Name Mappings

The system learns from your corrections:
1. AI extracts vendor name "hej AB" from an invoice
2. You manually select vendor "Hejsan AB" in the preview
3. The mapping "hej AB" -> "Hejsan AB" is saved automatically
4. Next time "hej AB" appears, it matches "Hejsan AB" without manual intervention

Manage mappings via **PaperTide AI Setup** -> **PaperTide Vendor Mappings**.

### Default System Prompt

The extension includes a default system prompt that instructs the AI to return JSON in this format:

```json
{
  "VendorNo": "VEND001",
  "VendorName": "Acme Supplies",
  "VendorVATNo": "SE556677889901",
  "VendorBankAccount": "SE1234567890123456",
  "InvoiceNo": "INV-2024-001",
  "InvoiceDate": "2024-03-15",
  "DueDate": "2024-04-15",
  "AmountInclVAT": 12500.00,
  "AmountExclVAT": 10000.00,
  "VATAmount": 2500.00,
  "CurrencyCode": "SEK",
  "PONumber": "PO-2024-100",
  "Lines": [
    {
      "Description": "Consulting services",
      "Quantity": 10,
      "UnitPrice": 1000.00,
      "Amount": 10000.00,
      "GLAccountNo": "6100"
    }
  ]
}
```

You can customize the system prompt in the setup page to match your specific invoice formats.

### Auto Coding AI Response Format

When Auto Coding is enabled, the classification AI returns:

```json
[
  {
    "LineNo": 10000,
    "Type": "G/L Account",
    "No": "6110",
    "Dimensions": [
      {"Code": "DEPARTMENT", "Value": "SALES"},
      {"Code": "PROJECT", "Value": "P001"}
    ],
    "Confidence": "High",
    "Reason": "Matches posting history for this vendor"
  }
]
```

## Usage

### Workflow Overview

```
Upload -> Process (AI) -> Auto Code -> Verify -> Review -> Create Invoice
```

### 1. Upload Invoices

1. Navigate to **Purchase Invoices** page
2. Click **"PaperTide Upload"** in the ribbon
3. Select one or more JPG/PNG/PDF files
4. Files are automatically queued and processed (max concurrency configurable)
5. The **Processing Queue** shows counts: Pending, Processing, Ready for Review, Errors, Created

### 2. Monitor Processing

- **Pending**: Waiting for processing slot
- **Processing**: AI extraction in progress
- **Ready for Review**: Extraction + auto coding complete, ready for your review
- **Errors**: Processing failed (hover to see error message)
- **Created**: Invoice already created from this document

### 3. Review, Verify & Edit

1. Click **"View Import Queue"** to see all documents
2. Find a document with status **"Ready"**
3. Check the **Verification Status** column for fraud detection results
4. Click **"Review & Edit"** to open **Invoice Preview**
5. Review extracted data:
   - Header fields (Vendor, VAT No., Bank Account, Invoice No, Dates, PO Number, Amounts)
   - Fraud Detection section (Verification Status and messages)
   - Line items with Type, No., Description, Amounts
   - **Dimension columns** (Global Dimension 1 & 2, editable)
   - **Confidence & Reason** per line from Auto Coding
   - **Auto Coding Status** summary in Document Information
   - Original image in the FactBox on the right
6. Click **"Edit Values"** to enable editing if corrections are needed
7. Click **"Suggest Accounts"** to re-run Auto Coding classification
8. Click **"Verify"** to re-run fraud checks after edits
9. Make corrections and fields will auto-save

### 4. Fraud Detection

The system automatically verifies extracted data against known vendor records:

| Check | Result |
|-------|--------|
| VAT No. on invoice matches vendor card | **Verified** |
| VAT No. mismatch | **Suspicious** |
| Bank account not in registered vendor accounts | **Suspicious** |
| Vendor has no VAT/bank on file (can't verify) | **Warning** |
| No vendor match at all | **Warning** |
| No VAT/bank on invoice | **Warning** |

- **Verified** (green) - All checks passed
- **Warning** (yellow) - Needs attention, proceed with confirmation
- **Suspicious** (red) - Strong warning with explicit confirmation required

### 5. Create Invoice

1. After review, click **"Accept & Create Invoice"**
2. If invoice is flagged as Suspicious, an explicit confirmation dialog appears
3. System validates:
   - Vendor No. is specified
   - Invoice No. is specified
   - No duplicate vendor invoice number exists
4. Purchase Invoice is created with:
   - Header data from extracted information
   - PO Number stored as Vendor Order No.
   - Lines with Type (G/L Account or Item), No., and amounts
   - **Dimension values** (Shortcut Dimension 1 & 2) applied to purchase lines
   - Original PDF or image attached as Document Attachment
5. Document status changes to **"Created"**
6. Created invoice opens automatically

### 6. Vendor Matching Priority

When the AI extracts vendor information, matching follows this priority:

1. **Vendor Name Mapping** - Previously learned alias (exact match)
2. **Vendor No.** - Direct vendor number from AI
3. **VAT Registration No.** - Match against Vendor."VAT Registration No."
4. **Bank Account / IBAN** - Match against Vendor Bank Account records
5. **Exact Name** - Match against Vendor.Name
6. **Partial Name** - Wildcard match on Vendor.Name

### Supported File Formats

| Format | Status | Notes |
|--------|--------|-------|
| JPG/JPEG | Supported | Direct upload |
| PNG | Supported | Direct upload |
| PDF | Supported | All pages rendered; requires Gotenberg service |

## Architecture

### Batch Import Flow

```
User selects multiple images/PDFs
        |
[PaperTide Upload] -> Queue files (PDF -> buffer original + Gotenberg -> PNG)
        |
[PaperTide Batch Processing Mgt] -> Concurrency control (configurable)
        |
[PaperTide Batch API Worker] -> Process each image
        |
[PaperTide AI Vision API] -> HTTP POST with base64 image
        |
AI vision model processes image
        |
[PaperTide Invoice Extraction] -> Parse JSON + Vendor Lookup + Verify
        |
[PaperTide GL Account Predictor] -> Auto Code lines (account + item + dimensions)
        |
Save to Import Document Header + Lines
        |
[PaperTide Import Documents] -> Display with status + verification
        |
User opens PaperTide Invoice Preview -> Review, verify & edit dimensions
        |
Create Purchase Header + Lines (with dimensions) + Attach PDF/image
        |
Mark Import Document as "Created"
```

### Status Flow

```
Pending -> Processing -> Ready -> Created
   |          |         |
   +----------+---------+-> Error (retryable)
```

| Status | Description |
|--------|-------------|
| **Pending** | Document uploaded, waiting for processing slot |
| **Processing** | AI extraction in progress |
| **Ready** | Extraction complete, ready for review |
| **Created** | Invoice successfully created |
| **Error** | Processing failed, can be retried |
| **Discarded** | Manually discarded by user |

## Security

| Aspect | Implementation |
|--------|---------------|
| API Key Storage | Encrypted in Isolated Storage (per-company, not in DB backups) |
| Auto-Migration | Existing plain-text keys automatically migrated to Isolated Storage |
| HTTP Security | HTTPS enforced for external API calls |
| File Upload | Whitelist validation (JPG/JPEG/PNG/PDF) |
| Data Classification | CustomerContent / EndUserIdentifiableInformation |
| Permissions | Dedicated permission set |

## Technical Details

### ID Ranges

- Tables: 50100-50149
- Pages: 50100-50149
- Codeunits: 50100-50149
- Permission Sets: 50100

### Key Objects

| Object | Type | ID | Purpose |
|--------|------|----|---------|
| PaperTide AI Setup | Table | 50100 | Configuration storage (singleton) |
| PaperTide Temp Invoice Buffer | Table | 50101 | Temporary data for preview |
| PaperTide Import Doc. Header | Table | 50102 | Persistent queue for batch processing |
| PaperTide Import Doc. Line | Table | 50103 | Extracted line items with dimensions |
| PaperTide Vendor Name Mapping | Table | 50104 | Learned vendor name aliases |
| PaperTide AI Vision API | Codeunit | 50100 | HTTP client for AI service |
| PaperTide Invoice Extraction | Codeunit | 50101 | Parser, vendor lookup, verification, invoice creation |
| PaperTide Batch Processing Mgt | Codeunit | 50102 | Queue and concurrency management |
| PaperTide Batch API Worker | Codeunit | 50103 | Individual document processor |
| PaperTide PDF Converter | Codeunit | 50104 | PDF-to-image conversion via Gotenberg |
| PaperTide GL Account Predictor | Codeunit | 50106 | Account, item, and dimension classification via text AI |
| PaperTide AI Setup | Page | 50100 | Setup card |
| PaperTide Invoice Preview | Page | 50101 | Review interface with fraud detection and image FactBox |
| PaperTide Inv. Preview Subform | Page | 50102 | Invoice line subform with dimensions |
| PaperTide Inv. Image FactBox | Page | 50103 | Image preview FactBox |
| PaperTide Import Documents | Page | 50105 | Document queue with verification status |
| PaperTide Vendor Mappings | Page | 50106 | Manage vendor name aliases |
| PaperTide Purch. Inv. List Ext | PageExtension | 50100 | Purchase Invoice list extension |
| PaperTide Import Doc. Status | Enum | 50100 | Document status values |
| PaperTide Import Proc. Status | Enum | 50101 | Processing status values |
| PaperTide Inv. Verif. Status | Enum | 50102 | Verification status values |
| PaperTide | PermissionSet | 50100 | Extension permissions |

## Troubleshooting

### "Setup is not configured"
- Go to **PaperTide AI Setup** page (search for it)
- Fill in **API Base URL** and **API Key**
- Fill in **Model Name** (e.g., `gpt-4o`) or use a Provider Preset
- Click **"Test Connection"**

### "HTTP request failed"
- Check your internet connection
- Verify API key is valid and not expired
- Ensure API Base URL is correct (should end with `/v1`)
- Check timeout setting (increase if needed, default 60s)

### "Invalid response from AI service"
- AI response may not be valid JSON
- Check system prompt formatting
- Try with a clearer invoice image
- Check that the image format is JPG or PNG

### Auto Coding completes but no accounts assigned
- Check the **Auto Coding Status** field on the document for details
- Ensure you have clicked **"Refresh Chart of Accounts"** in setup
- Verify your Coding API connection works (**"Test Coding Connection"**)
- If status shows "API call failed" or "Failed to parse AI response", check your coding model configuration
- The AI must return valid account numbers that exist in your chart of accounts
- Check that G/L accounts are not blocked and are of type Posting

### "Image Blob is empty"
- The uploaded file may be corrupted
- Try uploading the image again
- Check that the file is not 0 bytes

### Extension won't publish
- Ensure `allowHttpClientRequests` is enabled in extension settings
- In Extension Management, click Configure -> Allow HttpClient Requests

### Cannot see PaperTide AI Setup page
- Ensure you have the **"PaperTide"** permission set assigned
- Go to Users -> select your user -> Permission Sets -> add "PaperTide"

## Changelog

### v1.1.0.0 (2026-03-16)
- **Secure API Key Storage** - All API keys (Vision, Coding, PDF Converter) migrated from plain-text database fields to encrypted Isolated Storage with per-company isolation. Existing keys are automatically migrated on first access.
- **Auto Coding: Item Support** - AI can now suggest Items in addition to G/L Accounts. Line Type is set automatically based on AI classification.
- **Auto Coding: Dimension Suggestions** - AI suggests Global Dimension 1 & 2 values based on posting history and available dimension values. Dimensions are editable in the preview before invoice creation.
- **Auto Coding: Improved Reliability** - Fallback index-based line matching when AI returns incorrect LineNo values. Detailed status logging instead of silent failures.
- **Auto Coding: Better Prompt** - AI now always suggests an account (never leaves lines empty), includes item list and dimension values in context.
- **Editable Dimensions in Preview** - Shortcut Dimension 1 & 2 columns added to invoice line preview with lookup to dimension values.
- **Dimensions Applied to Purchase Invoice** - Dimension values from preview are applied to purchase lines when creating the invoice.
- **Auto Coding Status** - New field on Import Document showing classification results (e.g., "3 of 4 lines classified: 2 High, 1 Medium, 0 Low").

### v1.0.2.2 (2026-03-16)
- Removed Batch Upload page; PaperTide Upload action now opens file dialog directly from Purchase Invoices toolbar
- Fix batch concurrency race condition, add stuck document recovery

### v1.0.2.1 (2026-03-15)
- **Multi-Page PDF Support** - All pages from multi-page PDFs are now rendered and sent to the AI, not just the first page. Pages are stacked vertically into a single image for complete document analysis.

### v1.0.2.0 (2026-03-15)
- **PaperTide Branding** - Full rebrand of all AL objects with PaperTide prefix for consistent naming
- **Auto Coding (Separate AI Model)** - New feature: dedicated text AI model for GL account classification, separate from vision model. Configurable connection, model, and system prompt. Includes vendor posting history context for better predictions.
- **GL Suggestion Confidence** - AI returns confidence level (High/Medium/Low) and reasoning per line suggestion
- **Configurable Concurrency** - Max concurrent processing now configurable in setup (1-10, default 3)
- Fixed syntax issues in AI Setup page and Invoice Preview Subform
- Fixed ActionRef/Promoted property conflicts in Batch Upload page

### v1.0.1.1 (2026-03-15)
- **Provider Agnostic** - Renamed internal API codeunit from Qwen VL API to AI Vision API; removed all provider-specific references
- **Provider Presets** - Built-in quick setup for OpenAI, DashScope (Alibaba), Azure OpenAI, Groq, Ollama, LocalAI
- Generalized tooltips and documentation for multi-provider compatibility

### v1.0.1.0 (2026-03-15)
- **PO Number Extraction** - AI extracts purchase order references from invoices, stored as Vendor Order No.
- **Multi-Page PDF Attachment** - Original PDF (all pages) attached to created Purchase Invoice instead of first-page PNG only
- **Vendor Name Learning** - Automatic alias mapping when user corrects vendor in preview, used for future matching
- **Multi-Field Vendor Matching** - Match by VAT Registration No., bank account/IBAN, name mapping, in addition to name
- **Fraud Detection** - Automated cross-validation of extracted VAT/bank data against vendor records with Verified/Warning/Suspicious status
- **Verify Action** - Manual re-verification button in Invoice Preview after editing fields
- New table: PaperTide Vendor Name Mapping (50104)
- New page: PaperTide Vendor Mappings (50106)
- New enum: PaperTide Inv. Verif. Status

### v1.0.0.24
- Multi-file drag & drop upload
- PDF support via Gotenberg conversion service
- AI GL Account Suggestion
- Batch processing with concurrency control
- Invoice image preview and document attachment

## Upcoming Features

- [ ] **Vendor Auto Coding Setup** - Per-vendor configuration for auto coding preferences: default line type, preferred G/L accounts, dimension defaults, and classification rules. Each vendor gets its own coding profile for maximum accuracy.
- [ ] **Email Inbox Monitoring** - Configure a REST email endpoint to automatically fetch PDF/image attachments from a shared mailbox with job queue polling
- [ ] **Purchase Order Matching** - Automatically link invoices to existing POs via extracted PO number and "Get Receipt Lines"
- [ ] **VIES VAT Validation** - Validate vendor VAT numbers against the EU VIES service at import
- [ ] **Azure File Storage Import** - Connect to Azure File Storage for automated invoice import
- [ ] Confidence scores per extracted field
- [ ] Configurable field mapping for non-standard invoices
- [ ] Mobile app for camera capture
- [ ] Automatic approval for high-confidence extractions

## License

This is a custom Per-Tenant Extension (PTE) for your organization.

## Support

For issues or questions, contact your Business Central partner or development team.

---

**Version:** 1.1.0.0
**Compatible with:** Business Central 27.4+
**Runtime:** 14.0+
**Last Updated:** 2026-03-16
