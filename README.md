# AI Invoice Extractor for Business Central

A Per-Tenant Extension (PTE) for Business Central that uses AI (Qwen-VL) to extract invoice data from images, with a preview and approval workflow.

## Features

- 🤖 **AI-Powered OCR** - Extract invoice data using Qwen-VL vision model
- � **Batch Import** - Upload and process multiple invoice images simultaneously
- ⚡ **Concurrency Control** - Process up to 3 images at once with automatic queue management
- 📋 **Import Queue** - View and manage all imported documents with status tracking
- 👁️ **Preview & Edit** - Review extracted data with original image in FactBox before creating
- ⚙️ **Configurable** - Set up your own API endpoint, model, system prompt, and default G/L account
- 🔒 **Secure** - API keys stored as SecretText (encrypted)
- 📊 **Status Tracking** - Track documents from Pending → Processing → Ready → Created

## Requirements

- Business Central 2024 Wave 2 (v27.4) or later
- Qwen-VL API access (Alibaba Cloud DashScope or compatible)
- AL Language extension for VS Code

## Installation

### 1. Clone/Copy the Project

```bash
cd AIInvoiceExtractor
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

1. Search for **"AI Extraction Setup"** in Business Central
2. Fill in the following fields:

| Field | Example Value | Description |
|-------|---------------|-------------|
| API Base URL | `https://dashscope.aliyuncs.com/compatible-mode/v1` | Qwen-VL API endpoint |
| API Key | `sk-xxxxxxxx` | Your API key from Alibaba Cloud |
| Model Name | `qwen-vl-max` | Model identifier |
| Max Tokens | `2048` | Response length limit |
| Temperature | `0.1` | AI creativity (0.0 = strict) |
| Request Timeout | `60000` | API request timeout in milliseconds |
| Default G/L Account | `6110` | Default G/L account for invoice lines |
| System Prompt | *(see below)* | Instructions for data extraction |

### Default System Prompt

The extension includes a default system prompt that instructs the AI to return JSON in this format:

```json
{
  "VendorNo": "VEND001",
  "VendorName": "Acme Supplies",
  "InvoiceNo": "INV-2024-001",
  "InvoiceDate": "2024-03-15",
  "DueDate": "2024-04-15",
  "AmountInclVAT": 12500.00,
  "AmountExclVAT": 10000.00,
  "VATAmount": 2500.00,
  "CurrencyCode": "SEK",
  "Lines": [
    {
      "Description": "Consulting services",
      "Quantity": 10,
      "UnitPrice": 1000.00,
      "Amount": 10000.00
    }
  ]
}
```

You can customize the system prompt in the setup page to match your specific invoice formats.

## Usage

### Batch Import (Recommended)

1. Navigate to **Purchase Invoices** page
2. Click **"Batch Import Invoices"** in the ribbon
3. Select one or more JPG/PNG files (select multiple files in sequence)
4. Files are queued and processed automatically (max 3 concurrent)
5. Click **"View Import Queue"** to see all imported documents
6. Review status: Pending → Processing → Ready → Created

### Processing Individual Documents

1. In the **Import Document List**, find a document with status **"Ready"**
2. Click on the row to open **Invoice Preview**
3. Review extracted data with original image in the FactBox
4. Click **"Edit Values"** to make corrections if needed
5. Click **"Accept & Create Invoice"**
6. The document status changes to **"Created"** and links to the new invoice

### Legacy Single Upload

For single invoice upload (deprecated in favor of batch):
1. Navigate to **Purchase Invoices** page
2. Use **"Upload Single Invoice"** (hidden by default)

### Supported File Formats

| Format | Status | Notes |
|--------|--------|-------|
| JPG/JPEG | ✅ Supported | Recommended |
| PNG | ✅ Supported | Recommended |
| PDF | ❌ Not supported (v1.0) | Convert to image first |

## Architecture

### Batch Import Flow

```
User selects multiple images
        ↓
[Batch Upload Page] → Queue files
        ↓
[Batch Processing Mgt] → Concurrency control (max 3)
        ↓
[Batch API Worker] → Process each image
        ↓
[Qwen VL API Codeunit] → HTTP POST with base64 image
        ↓
Qwen-VL AI processes image
        ↓
[Invoice Extraction Codeunit] → Parse JSON response
        ↓
Save to Import Document Header + Lines
        ↓
[Import Document List] → Display with status
        ↓
User opens Invoice Preview → Review & edit
        ↓
Create Purchase Header + Lines
        ↓
Mark Import Document as "Created"
```

### Status Flow

```
Pending → Processing → Completed → Ready → Created
                    ↘ Error (retryable)
```

## Technical Details

### ID Ranges

- Tables: 50100-50149
- Pages: 50100-50149
- Codeunits: 50100-50149
- Permission Sets: 50100

### Key Objects

| Object | Type | Purpose |
|--------|------|---------|
| AI Extraction Setup | Table | Configuration storage (singleton) |
| Temp Invoice Buffer | Table | Temporary data for preview |
| Qwen VL API | Codeunit | HTTP client for AI service |
| Invoice Extraction | Codeunit | Parser and invoice creator |
| Invoice Preview | Page | Review interface with image FactBox |

## Troubleshooting

### "Setup is not configured"
- Go to AI Extraction Setup page
- Fill in API Base URL and API Key
- Click "Test Connection"

### "HTTP request failed"
- Check your internet connection
- Verify API key is valid
- Ensure API Base URL is correct
- Check timeout setting (increase if needed)

### "Invalid response from AI service"
- AI response may not be valid JSON
- Check system prompt formatting
- Try with a clearer invoice image

### Extension won't publish
- Ensure `allowHttpClientRequests` is enabled in extension settings
- In Extension Management, click Configure → Allow HttpClient Requests

## Future Enhancements (v2.0)

- [ ] PDF support via external conversion service
- [ ] Auto-match vendor using fuzzy search
- [ ] Support for multiple invoice languages
- [ ] Batch processing of multiple images
- [ ] Confidence scores per field
- [ ] Manual field mapping for unknown formats

## License

This is a custom Per-Tenant Extension (PTE) for your organization.

## Support

For issues or questions, contact your Business Central partner or development team.

---

**Version:** 1.0.0  
**Compatible with:** Business Central 27.4+  
**Runtime:** 14.0+
