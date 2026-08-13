# API.md — Padang ERP Lite

## Conventions

- **Base URL:** `https://delegateops.business/padang/api/v1/` (production)
- **Base URL:** `https://delegateops.business/padang/demo/api/v1/` (demo)
- **Format:** JSON (`Content-Type: application/json; charset=utf-8`)
- **Auth:** Production protected endpoints use `Authorization: Bearer <access-token>`; demo has no authentication.
- **Spec:** OpenAPI 3.1 at `/api/v1/openapi.json`; source of truth is
  `backend/openapi/openapi.yaml`, embedded and served by the API
- **Versioning:** URL path (`/v1/`); breaking changes increment version

---

## Authentication

### Production public endpoints (no auth required)

| Method | Path | Description |
|---|---|---|
| GET  | `/api/v1/health`              | Health check; returns 200 + status |
| POST | `/api/v1/auth/request-otp`    | Submit email → send 6-digit OTP code via email |
| POST | `/api/v1/auth/verify-otp`     | Submit code → access token + refresh token (HttpOnly cookie) |
| POST | `/api/v1/auth/refresh`        | Refresh token cookie → new access token |

### Production protected endpoints

All other production endpoints require `Authorization: Bearer <access-token>`.

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/auth/logout` | Revoke refresh token |
| GET | `/api/v1/auth/me` | Current user profile + role |

### Token Specification

| Token | Lifetime | Storage |
|---|---|---|
| Access token | 15 minutes | Memory (frontend); never localStorage |
| Refresh token | 7 days, rotated on use | HttpOnly Secure SameSite=Strict cookie (web); OS secure storage (future mobile) |

Demo: no authentication is performed. Requests receive a synthetic demo
identity and may use `X-Demo-Role` only with one canonical role identifier:
`administrator`, `general_manager`, `disbursing_check_signing_officer`,
`project_manager`, `procurement_officer`,
`fabrication_supervisor`, `finance_staff`, `billing_clerk`,
`inventory_clerk`, or `viewer`. The header is ignored outside `APP_ENV=demo`.

Mobile clients use the same refresh endpoint and rotation rules, but store the
refresh token in iOS Keychain or Android Keystore-backed secure storage. No
client-supplied role is trusted by the API.

Every production request revalidates the token subject against the active user
row; role changes and deactivation take effect without waiting for JWT expiry.
OTP consumption and refresh-token rotation use conditional database updates;
a code or refresh token can succeed only once under concurrent requests.

---

## Response Envelope

### Success (single resource)
```json
{
  "data": { ... },
  "meta": { "request_id": "..." }
}
```

`meta.request_id` is included when the request has a Chi request ID. Clients
should retain it with their local error or support logs. Error responses use
the same envelope and `Content-Type` as successful responses.

### Success (list/paginated)
```json
{
  "data": [ ... ],
  "meta": {
    "request_id": "...",
    "total": 47,
    "page": 1,
    "per_page": 20,
    "total_pages": 3
  }
}
```

### Error
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      { "field": "amount", "message": "Amount must be greater than 0" }
    ]
  },
  "meta": { "request_id": "..." }
}
```

### Standard Error Codes

| HTTP | Code | Meaning |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Request body/params invalid |
| 401 | `UNAUTHORIZED` | Missing or invalid token |
| 403 | `FORBIDDEN` | Valid token; insufficient role |
| 404 | `NOT_FOUND` | Resource not found |
| 409 | `CONFLICT` | State conflict (e.g., duplicate) |
| 422 | `BUSINESS_RULE_ERROR` | Violates business rule (e.g., VO > 10% cap) |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Unexpected server error |

---

## Pagination

All list endpoints support:

| Query param | Default | Description |
|---|---|---|
| `page` | 1 | Page number (1-indexed) |
| `per_page` | 20 | Items per page (max 100) |
| `sort` | varies | Sort column |
| `order` | `desc` | `asc` or `desc` |
| `search` | — | Full-text search where applicable |

---

## Filtering

Module-specific filter params are documented per endpoint.
Common filters:

| Param | Type | Description |
|---|---|---|
| `status` | string | Filter by status value |
| `date_from` | ISO8601 date | Start of date range |
| `date_to` | ISO8601 date | End of date range |
| `project_id` | UUID | Filter by project |

---

## Endpoint Reference

### Users & Auth

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/users` | administrator | List users |
| POST | `/users` | administrator | Create user |
| GET | `/users/{id}` | administrator | Get user |
| PUT | `/users/{id}` | administrator | Update user |
| PATCH | `/users/{id}/deactivate` | administrator | Deactivate user |

### Projects

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/projects` | all | List projects (role-filtered) |
| POST | `/projects` | administrator, project_manager | Create project |
| GET | `/projects/{id}` | all | Get project detail |
| PUT | `/projects/{id}` | administrator, project_manager | Update project |
| GET | `/projects/{id}/budget` | all | Get BOQ |
| POST | `/projects/{id}/budget` | administrator, project_manager | Add BOQ item |
| PUT | `/projects/{id}/budget/{item_id}` | administrator, project_manager | Update BOQ item |
| GET | `/projects/{id}/costing` | all | Budget vs actual |
| GET | `/projects/{id}/progress` | all | Progress entries |
| POST | `/projects/{id}/progress` | project_manager | Add progress entry |
| GET | `/projects/{id}/variation-orders` | all | List VOs |
| POST | `/projects/{id}/variation-orders` | project_manager | Create VO |
| PATCH | `/projects/{id}/variation-orders/{vo_id}/approve` | general_manager | Approve VO |
| PATCH | `/projects/{id}/variation-orders/{vo_id}/reject` | general_manager | Reject VO |
| GET | `/projects/{id}/profitability` | general_manager, administrator, project_manager | Profitability report |
| GET | `/projects/{id}/attachments` | all | List attachments |
| POST | `/projects/{id}/attachments` | project_manager, administrator | Upload attachment |

### Fabrication

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/fabrication` | all | List fab jobs |
| POST | `/fabrication` | fabrication_supervisor, administrator | Create fab job |
| GET | `/fabrication/{id}` | all | Get fab job detail |
| PUT | `/fabrication/{id}` | fabrication_supervisor, administrator | Update fab job |
| PATCH | `/fabrication/{id}/status` | fabrication_supervisor, administrator | Advance status |
| GET | `/fabrication/{id}/billing` | all | Get fab billing |
| POST | `/fabrication/{id}/billing` | billing_clerk, administrator | Create fab billing |
| PATCH | `/fabrication/{id}/billing/approve` | general_manager | Approve billing |
| GET | `/fabrication/{id}/profitability` | general_manager, administrator, fabrication_supervisor | Profitability |

### Procurement

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/procurement/purchase-requests` | all | List PRs |
| POST | `/procurement/purchase-requests` | project_manager, procurement_officer, administrator | Create PR |
| GET | `/procurement/purchase-requests/{id}` | all | Get PR |
| PUT | `/procurement/purchase-requests/{id}` | creator, administrator | Update PR (draft only) |
| PATCH | `/procurement/purchase-requests/{id}/submit` | creator | Submit PR |
| PATCH | `/procurement/purchase-requests/{id}/approve` | general_manager, administrator | Approve PR |
| PATCH | `/procurement/purchase-requests/{id}/reject` | general_manager, administrator | Reject PR |
| GET | `/procurement/purchase-orders` | all | List POs |
| POST | `/procurement/purchase-orders` | procurement_officer, administrator | Create PO from PR |
| GET | `/procurement/purchase-orders/{id}` | all | Get PO |
| PUT | `/procurement/purchase-orders/{id}` | procurement_officer, administrator | Update PO |
| PATCH | `/procurement/purchase-orders/{id}/approve` | general_manager | Approve PO |
| GET | `/procurement/fund-requests` | all | List fund requests |
| POST | `/procurement/fund-requests` | procurement_officer, finance_staff, administrator | Create FR |
| GET | `/procurement/fund-requests/{id}` | all | Get FR |
| PATCH | `/procurement/fund-requests/{id}/submit` | creator | Submit FR |
| PATCH | `/procurement/fund-requests/{id}/approve` | general_manager | GM approve |
| PATCH | `/procurement/fund-requests/{id}/reject` | general_manager | GM reject |
| PATCH | `/procurement/fund-requests/{id}/pay` | disbursing_check_signing_officer | Record payment |
| GET | `/procurement/suppliers` | all | List suppliers |
| POST | `/procurement/suppliers` | procurement_officer, administrator | Create supplier |
| GET | `/procurement/suppliers/{id}` | all | Get supplier |
| PUT | `/procurement/suppliers/{id}` | procurement_officer, administrator | Update supplier |
| GET | `/procurement/suppliers/{id}/soa` | all | Supplier SOA |

### Inventory

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/inventory/items` | all | List items |
| POST | `/inventory/items` | inventory_clerk, administrator | Create item |
| GET | `/inventory/items/{id}` | all | Get item |
| PUT | `/inventory/items/{id}` | inventory_clerk, administrator | Update item |
| GET | `/inventory/transactions` | all | List transactions |
| POST | `/inventory/stock-in` | inventory_clerk, administrator | Record stock in |
| POST | `/inventory/stock-out` | inventory_clerk, administrator | Record stock out |
| POST | `/inventory/material-issue` | inventory_clerk, administrator | Issue materials |

### Billing & Collections

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/billing/progress` | all | List progress billings |
| POST | `/billing/progress` | billing_clerk, administrator | Create progress billing |
| GET | `/billing/progress/{id}` | all | Get billing detail |
| PUT | `/billing/progress/{id}` | billing_clerk, administrator | Update billing (draft) |
| PATCH | `/billing/progress/{id}/submit` | billing_clerk | Submit for GM approval |
| PATCH | `/billing/progress/{id}/approve` | general_manager | Approve billing |
| PATCH | `/billing/progress/{id}/reject` | general_manager | Reject billing |
| PATCH | `/billing/progress/{id}/issue` | billing_clerk | Mark as issued to client |
| POST | `/billing/progress/{id}/collections` | billing_clerk, administrator | Record collection |
| GET | `/billing/progress/{id}/collections` | all | List collections for billing |
| GET | `/billing/soa` | all | Statement of account |
| GET | `/billing/aging` | general_manager, administrator, billing_clerk | AR aging report |

### Finance Operations

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/finance/reimbursements` | all | List reimbursements |
| POST | `/finance/reimbursements` | finance_staff, administrator | Create reimbursement |
| PATCH | `/finance/reimbursements/{id}/submit` | creator | Submit |
| PATCH | `/finance/reimbursements/{id}/approve` | general_manager | Approve |
| PATCH | `/finance/reimbursements/{id}/pay` | disbursing_check_signing_officer | Record payment |
| GET | `/finance/liquidations` | all | List liquidations |
| POST | `/finance/liquidations` | finance_staff, administrator | Create liquidation |
| PATCH | `/finance/liquidations/{id}/submit` | creator | Submit |
| PATCH | `/finance/liquidations/{id}/approve` | general_manager | Approve |

### Reports

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/reports/project-profitability` | general_manager, administrator | Project profitability |
| GET | `/reports/fabrication-profitability` | general_manager, administrator, fabrication_supervisor | Fab profitability |
| GET | `/reports/budget-vs-actual` | general_manager, administrator, project_manager | Budget vs actual |
| GET | `/reports/collections-aging` | general_manager, administrator, billing_clerk | Collections aging |
| GET | `/reports/purchases` | general_manager, administrator, procurement_officer | Purchase report |
| GET | `/reports/revenue-summary` | general_manager, administrator | Revenue summary |
| GET | `/reports/expense-summary` | general_manager, administrator | Expense summary |
| GET | `/reports/cash-summary` | general_manager, administrator, finance_staff | Cash summary |

All report endpoints support:
- `format=json` (default) or `format=xlsx` or `format=csv`
- Date range params

### Approvals Queue

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/approvals/pending` | general_manager, disbursing_check_signing_officer | Consolidated pending approvals |

### File Attachments

The C1 API exposes a server-authorized presign flow. It does not accept a
client-supplied storage key or arbitrary upload URL.

| Method | Path | Role | Description |
|---|---|---|---|
| POST | `/attachments/presign` | entity-scoped writer | Validate metadata, authorize the entity, persist attachment metadata and audit event, and return a B2 PUT URL |

Request body:

```json
{
  "entity_type": "project",
  "entity_id": "00000000-0000-0000-0000-000000000000",
  "file_name": "signed-contract.pdf",
  "content_type": "application/pdf",
  "size": 24576,
  "category": "contract"
}
```

Allowed entity types are `project`, `fabrication_job`, `purchase_request`,
`purchase_order`, `fund_request`, `progress_billing`,
`fabrication_billing`, `collection`, `client`, `supplier`, `reimbursement`,
and `liquidation`. Categories are `contract`, `drawing`, `permit`, `photo`,
`report`, `receipt`, and `other`.

The declared MIME type and filename extension must match an allowlist (PDF,
DWG, DOCX, XLSX, JPEG, PNG, WebP, TXT, or CSV), the file must be 1–50 MiB,
and the acting role must both be allowed for the entity and own or manage the
referenced record. The server derives the object key as
`{entity_type}/{entity_id}/{attachment_uuid}.{extension}`. The client must
upload with `PUT` using the returned URL and the same content type and size
supplied in the metadata request.

Success response:

```json
{
  "data": {
    "attachment_id": "00000000-0000-0000-0000-000000000000",
    "storage_key": "project/00000000-0000-0000-0000-000000000000/attachment.pdf",
    "upload_url": "https://signed.example/…",
    "method": "PUT"
  },
  "meta": { "request_id": "…" }
}
```

The C1 presign step validates declared metadata, but does not inspect file
bytes after upload. Content inspection and download URL endpoints remain
production-hardening work before arbitrary external uploads are enabled.

### QBO Export

| Method | Path | Description |
|---|---|---|
| GET | `/qbo/export/{type}` | Export: customers, vendors, bills, expenses, invoices, collections, payments |

### Client Tax Profiles

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/clients` | all | List clients visible to the role |
| POST | `/clients` | administrator, finance_staff | Create client and tax profile |
| PUT | `/clients/{id}` | administrator, finance_staff | Update client EWT configuration |

Client profiles provide the EWT-enabled flag, EWT rate, TIN, and BIR
reference metadata used by billing and collection workflows.

---

## Rate Limiting

| Endpoint class | Limit |
|---|---|
| `/auth/request-otp` | 3 req per email per 15 min; 10 req/min per IP |
| `/auth/verify-otp`  | 5 failed attempts per OTP before code invalidated; 10 req/min per IP |
| `/auth/refresh`     | 20 req/min per IP |
| All other endpoints | No global limiter in C1; add before multi-replica production |

---

## Security Headers

All responses include:
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'; ...
Referrer-Policy: strict-origin-when-cross-origin
```

---

## CORS

Allowed origins:
- Production: `https://delegateops.business`
- Demo: `https://delegateops.business`

No wildcard origins in production.

---

## OpenAPI Spec

Available at:
- Production: `https://delegateops.business/padang/api/v1/openapi.json`
- Demo: `https://delegateops.business/padang/demo/api/v1/openapi.json`

TypeScript types generated from spec using `openapi-typescript`.
Run: `npm run generate:types` in `frontend/`.
The generated `frontend/types/api.ts` is a checked-in build artifact and must
be regenerated whenever `backend/openapi/openapi.yaml` changes. Runtime JSON
is produced from that same embedded YAML so the served contract and generated
types cannot silently use different source documents.
