# AI Invoice Extractor - Project Documentation

## Project Overview

**Project Name:** AI Invoice Extractor  
**Type:** Per-Tenant Extension (PTE)  
**Version:** 1.0.0.0  
**Target Platform:** Microsoft Dynamics 365 Business Central  
**Minimum Version:** 2024 Release Wave 2 (v27.4)  
**Runtime Version:** 14.0  

## Purpose

Automate the creation of purchase invoices in Business Central by extracting data from invoice images using Alibaba Cloud's Qwen-VL AI vision model. The solution provides a preview workflow where users can review and edit AI-extracted data before committing to the database.

## Business Value

- **Time Savings:** Reduce manual data entry time by 80%+
- **Accuracy:** Minimize typos and data entry errors
- **Audit Trail:** Original image attached to preview for verification
- **Flexibility:** Configurable to work with various invoice formats
- **Integration:** Native Business Central experience

## Scope

### In Scope (v1.0)

- **Batch Import** - Upload multiple invoice images with queue management
- **Concurrency Control** - Process up to 3 images simultaneously
- **Import Queue** - Review and manage all imported documents in a list
- AI extraction via Qwen-VL API
- Preview page with original image display
- Manual review and editing capability
- Creation of standard Purchase Invoices
- Configuration page for API settings
- System prompt customization
- Default G/L Account for invoice lines

### Out of Scope (v1.0)

- PDF file support (planned for v2.0)
- Automatic vendor matching beyond exact name lookup
- Multi-language OCR optimization
- Mobile device camera integration
- Automatic GL account assignment
- VAT calculation validation

## Architecture Decisions

### Why Qwen-VL?

- Strong vision capabilities for document understanding
- Competitive pricing
- JSON-structured output support
- Good performance on invoice documents

### Why Not PDF Support in v1.0?

- Business Central AL has no built-in PDF rendering capability
- External PDF conversion requires additional service (Azure Function, etc.)
- Users can convert PDF to image using standard tools
- Reserved for v2.0 when additional infrastructure is available

### Why Temporary Table for Preview?

- No database persistence until user confirms
- Easy to discard and restart
- Supports complex field editing
- Can display in standard page framework

## Object Catalog

### Tables

| ID | Name | Type | Records |
|----|------|------|---------|
| 50100 | AI Extraction Setup | Singleton | 1 |
| 50101 | Temp Invoice Buffer | Temporary | Session-only |
| 50102 | Import Document Header | Persistent | One per uploaded image |
| 50103 | Import Document Line | Persistent | Invoice lines per document |

### Pages

| ID | Name | Type | Source Table |
|----|------|------|--------------|
| 50100 | AI Extraction Setup | Card | AI Extraction Setup |
| 50101 | Invoice Preview | Card | Import Document Header |
| 50102 | Invoice Preview Subform V2 | ListPart | Import Document Line |
| 50103 | Invoice Image FactBox V2 | CardPart | Import Document Header |
| 50104 | Batch Upload | Card | - |
| 50105 | Import Document List | List | Import Document Header |

### Codeunits

| ID | Name | Access | Purpose |
|----|------|--------|---------|
| 50100 | Qwen VL API | Internal | HTTP communication with AI service |
| 50101 | Invoice Extraction | Internal | JSON parsing and invoice creation |
| 50102 | Batch Processing Mgt | Internal | Queue management and concurrency control |
| 50103 | Batch API Worker | Internal | Individual document processing |

### Page Extensions

| ID | Name | Extends |
|----|------|---------|
| 50100 | Purch. Invoice List Ext | Purchase Invoices |

### Permission Sets

| ID | Name | Permissions |
|----|------|-------------|
| 50100 | AI Invoice Extractor | Full access to all objects |

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                            │
│  Purchase Invoices Page → Upload Invoice Image Action            │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FILE HANDLING                               │
│  - File upload dialog                                            │
│  - Extension validation (JPG, JPEG, PNG)                         │
│  - PDF rejection with helpful message                            │
│  - MIME type detection                                           │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      IMAGE PROCESSING                            │
│  - Import to Media field                                         │
│  - Convert to Base64                                             │
│  - Build JSON request payload                                    │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AI SERVICE CALL                             │
│  Qwen VL API Codeunit                                            │
│  - HTTP POST to /chat/completions                                │
│  - Include system prompt + base64 image                          │
│  - Timeout handling (configurable)                               │
│  - Error handling                                                │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      RESPONSE PROCESSING                         │
│  - Parse JSON response                                           │
│  - Extract content from choices[0].message.content               │
│  - Clean markdown formatting                                     │
│  - Validate JSON structure                                       │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATA EXTRACTION                             │
│  Invoice Extraction Codeunit                                     │
│  - Map JSON fields to buffer fields                              │
│  - Lookup vendor by number or name                               │
│  - Parse dates (ISO 8601 format)                                 │
│  - Process line items array                                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PREVIEW & REVIEW                            │
│  Invoice Preview Page                                            │
│  - Display header fields                                         │
│  - Show line items in subform                                    │
│  - Display original image in FactBox                             │
│  - Toggle edit mode                                              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      INVOICE CREATION                            │
│  - Validate required fields                                      │
│  - Check for duplicate vendor invoice no.                        │
│  - Create Purchase Header                                        │
│  - Create Purchase Lines                                         │
│  - Open created invoice                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Security Considerations

| Aspect | Implementation |
|--------|---------------|
| API Key Storage | SecretText data type (encrypted at rest) |
| HTTP Security | HTTPS only (enforced by URL validation) |
| File Upload | Whitelist validation (JPG/JPEG/PNG only) |
| Data Classification | CustomerContent for all setup data |
| Permissions | Dedicated permission set |

## Configuration Reference

### AI Extraction Setup Fields

| Field | Data Type | Default | Valid Range |
|-------|-----------|---------|-------------|
| API Base URL | Text[250] | - | Valid HTTPS URL |
| API Key | SecretText | - | Non-empty |
| Model Name | Text[50] | qwen-vl-max | Any valid model |
| Max Tokens | Integer | 2048 | 100-4096 |
| Temperature | Decimal | 0.1 | 0.0-2.0 |
| Request Timeout | Integer | 60000 | 10000-300000 |
| System Prompt | Blob | Default prompt | Any valid text |

## Testing Checklist

### Unit Testing

- [ ] API connection test returns success with valid credentials
- [ ] API connection test fails with invalid credentials
- [ ] Image to Base64 conversion works correctly
- [ ] JSON response parsing handles valid responses
- [ ] JSON response parsing handles malformed responses
- [ ] Date parsing works for ISO 8601 format
- [ ] Vendor lookup by number works
- [ ] Vendor lookup by name works
- [ ] Vendor lookup by partial name works

### Integration Testing

- [ ] Full flow: Upload → Extract → Preview → Create
- [ ] Invoice creation with all fields populated
- [ ] Invoice creation with minimal fields
- [ ] Edit mode allows field modification
- [ ] Duplicate invoice detection works
- [ ] Error handling for network failures
- [ ] Error handling for API errors
- [ ] Error handling for invalid images

### User Acceptance Testing

- [ ] Clear and helpful error messages
- [ ] Preview page is intuitive
- [ ] Image display is clear
- [ ] Edit mode is discoverable
- [ ] Workflow feels natural to AP clerks

## Known Limitations

1. **No PDF Support** - Users must convert PDFs to images externally
2. **Single Image** - One invoice per upload (no batch processing)
3. **No Auto-Post** - Invoices created as open, not posted
4. **GL Account Default** - Lines use generic G/L Account type; user must specify account
5. **Currency Limitation** - Currency must be specified; no automatic detection

## Future Roadmap

### Version 2.0

- PDF support via external conversion service
- Confidence scoring per extracted field
- Highlight low-confidence fields for review
- Configurable field mapping for non-standard invoices
- Multi-page invoice support

### Version 3.0

- Azure Document AI as alternative provider
- Machine learning for vendor auto-matching
- Historical pattern learning
- Integration with Continia Document Capture (optional)
- Mobile app for camera capture

## Development Team

- **Solution Architect:** [Name]
- **AL Developer:** [Name]
- **Functional Consultant:** [Name]
- **Test Lead:** [Name]

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-03-10 | Initial release |

---

**Document Version:** 1.0  
**Last Updated:** 2024-03-10
