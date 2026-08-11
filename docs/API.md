# API.md — Padang ERP Lite

## Conventions

- **Base URL:** `https://delegateops.business/padang/api/v1/` (production)
- **Base URL:** `https://delegateops.business/padang/demo/api/v1/` (demo)
- **Format:** JSON (Content-Type: application/json)
- **Auth:** Bearer JWT in `Authorization: Bearer <token>` header
- **Spec:** OpenAPI 3.1 at `/api/v1/openapi.json`
- **Versioning:** URL path (`/v1/`); breaking changes increment version

---

## Authentication

### Public Endpoints (no auth required)

| Method | Path | Description |
|---|---|---|
| GET  | `/api/v1/health`              | Health check; returns 200 + status |
| POST | `/api/v1/auth/request-otp`    | Submit email → send 6-digit OTP code via email |
| POST | `/api/v1/auth/verify-otp`     | Submit code → access token + refresh token (HttpOnly cookie) |
| POST | `/api/v1/auth/refresh`        | Refresh token cookie → new access token |

### Protected Endpoints

All other endpoints require `Authorization: Bearer <access_token>`.

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/auth/logout` | Revoke refresh token |
| GET | `/api/v1/auth/me` | Current user profile + role |

### Token Specification

| Token | Lifetime | Storage |
|---|---|---|
| Access token | 15 minutes | Memory (frontend); never localStorage |
| Refresh token | 7 days | HttpOnly cookie (production) |

Demo: all requests treated as Admin with optional `X-Demo-Role` header to simulate role switching.

---

## Response Envelope

### Success (single resource)
```json
{
  "data": { ... },
  "meta": { "request_id": "..." }
}
```

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
| GET | `/users` | admin | List users |
| POST | `/users` | admin | Create user |
| GET | `/users/{id}` | admin | Get user |
| PUT | `/users/{id}` | admin | Update user |
| PATCH | `/users/{id}/deactivate` | admin | Deactivate user |

### Projects

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/projects` | all | List projects (role-filtered) |
| POST | `/projects` | admin, project_manager | Create project |
| GET | `/projects/{id}` | all | Get project detail |
| PUT | `/projects/{id}` | admin, project_manager | Update project |
| GET | `/projects/{id}/budget` | all | Get BOQ |
| POST | `/projects/{id}/budget` | admin, project_manager | Add BOQ item |
| PUT | `/projects/{id}/budget/{item_id}` | admin, project_manager | Update BOQ item |
| GET | `/projects/{id}/costing` | all | Budget vs actual |
| GET | `/projects/{id}/progress` | all | Progress entries |
| POST | `/projects/{id}/progress` | project_manager | Add progress entry |
| GET | `/projects/{id}/variation-orders` | all | List VOs |
| POST | `/projects/{id}/variation-orders` | project_manager | Create VO |
| PATCH | `/projects/{id}/variation-orders/{vo_id}/approve` | gm | Approve VO |
| PATCH | `/projects/{id}/variation-orders/{vo_id}/reject` | gm | Reject VO |
| GET | `/projects/{id}/profitability` | gm, admin, project_manager | Profitability report |
| GET | `/projects/{id}/attachments` | all | List attachments |
| POST | `/projects/{id}/attachments` | project_manager, admin | Upload attachment |

### Fabrication

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/fabrication` | all | List fab jobs |
| POST | `/fabrication` | fabrication_supervisor, admin | Create fab job |
| GET | `/fabrication/{id}` | all | Get fab job detail |
| PUT | `/fabrication/{id}` | fabrication_supervisor, admin | Update fab job |
| PATCH | `/fabrication/{id}/status` | fabrication_supervisor, admin | Advance status |
| GET | `/fabrication/{id}/billing` | all | Get fab billing |
| POST | `/fabrication/{id}/billing` | billing_clerk, admin | Create fab billing |
| PATCH | `/fabrication/{id}/billing/approve` | gm | Approve billing |
| GET | `/fabrication/{id}/profitability` | gm, admin, fabrication_supervisor | Profitability |

### Procurement

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/procurement/purchase-requests` | all | List PRs |
| POST | `/procurement/purchase-requests` | project_manager, procurement_officer, admin | Create PR |
| GET | `/procurement/purchase-requests/{id}` | all | Get PR |
| PUT | `/procurement/purchase-requests/{id}` | creator, admin | Update PR (draft only) |
| PATCH | `/procurement/purchase-requests/{id}/submit` | creator | Submit PR |
| PATCH | `/procurement/purchase-requests/{id}/approve` | gm, admin | Approve PR |
| PATCH | `/procurement/purchase-requests/{id}/reject` | gm, admin | Reject PR |
| GET | `/procurement/purchase-orders` | all | List POs |
| POST | `/procurement/purchase-orders` | procurement_officer, admin | Create PO from PR |
| GET | `/procurement/purchase-orders/{id}` | all | Get PO |
| PUT | `/procurement/purchase-orders/{id}` | procurement_officer, admin | Update PO |
| PATCH | `/procurement/purchase-orders/{id}/approve` | gm | Approve PO |
| GET | `/procurement/fund-requests` | all | List fund requests |
| POST | `/procurement/fund-requests` | procurement_officer, finance_staff, admin | Create FR |
| GET | `/procurement/fund-requests/{id}` | all | Get FR |
| PATCH | `/procurement/fund-requests/{id}/submit` | creator | Submit FR |
| PATCH | `/procurement/fund-requests/{id}/approve` | gm | GM approve |
| PATCH | `/procurement/fund-requests/{id}/reject` | gm | GM reject |
| PATCH | `/procurement/fund-requests/{id}/pay` | dcs | Record payment |
| GET | `/procurement/suppliers` | all | List suppliers |
| POST | `/procurement/suppliers` | procurement_officer, admin | Create supplier |
| GET | `/procurement/suppliers/{id}` | all | Get supplier |
| PUT | `/procurement/suppliers/{id}` | procurement_officer, admin | Update supplier |
| GET | `/procurement/suppliers/{id}/soa` | all | Supplier SOA |

### Inventory

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/inventory/items` | all | List items |
| POST | `/inventory/items` | inventory_clerk, admin | Create item |
| GET | `/inventory/items/{id}` | all | Get item |
| PUT | `/inventory/items/{id}` | inventory_clerk, admin | Update item |
| GET | `/inventory/transactions` | all | List transactions |
| POST | `/inventory/stock-in` | inventory_clerk, admin | Record stock in |
| POST | `/inventory/stock-out` | inventory_clerk, admin | Record stock out |
| POST | `/inventory/material-issue` | inventory_clerk, admin | Issue materials |

### Billing & Collections

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/billing/progress` | all | List progress billings |
| POST | `/billing/progress` | billing_clerk, admin | Create progress billing |
| GET | `/billing/progress/{id}` | all | Get billing detail |
| PUT | `/billing/progress/{id}` | billing_clerk, admin | Update billing (draft) |
| PATCH | `/billing/progress/{id}/submit` | billing_clerk | Submit for GM approval |
| PATCH | `/billing/progress/{id}/approve` | gm | Approve billing |
| PATCH | `/billing/progress/{id}/reject` | gm | Reject billing |
| PATCH | `/billing/progress/{id}/issue` | billing_clerk | Mark as issued to client |
| POST | `/billing/progress/{id}/collections` | billing_clerk, admin | Record collection |
| GET | `/billing/progress/{id}/collections` | all | List collections for billing |
| GET | `/billing/soa` | all | Statement of account |
| GET | `/billing/aging` | gm, admin, billing_clerk | AR aging report |

### Finance Operations

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/finance/reimbursements` | all | List reimbursements |
| POST | `/finance/reimbursements` | finance_staff, admin | Create reimbursement |
| PATCH | `/finance/reimbursements/{id}/submit` | creator | Submit |
| PATCH | `/finance/reimbursements/{id}/approve` | gm | Approve |
| PATCH | `/finance/reimbursements/{id}/pay` | dcs | Record payment |
| GET | `/finance/liquidations` | all | List liquidations |
| POST | `/finance/liquidations` | finance_staff, admin | Create liquidation |
| PATCH | `/finance/liquidations/{id}/submit` | creator | Submit |
| PATCH | `/finance/liquidations/{id}/approve` | gm | Approve |

### Reports

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/reports/project-profitability` | gm, admin | Project profitability |
| GET | `/reports/fabrication-profitability` | gm, admin, fabrication_supervisor | Fab profitability |
| GET | `/reports/budget-vs-actual` | gm, admin, project_manager | Budget vs actual |
| GET | `/reports/collections-aging` | gm, admin, billing_clerk | Collections aging |
| GET | `/reports/purchases` | gm, admin, procurement_officer | Purchase report |
| GET | `/reports/revenue-summary` | gm, admin | Revenue summary |
| GET | `/reports/expense-summary` | gm, admin | Expense summary |
| GET | `/reports/cash-summary` | gm, admin, finance_staff | Cash summary |

All report endpoints support:
- `format=json` (default) or `format=xlsx` or `format=csv`
- Date range params

### Approvals Queue

| Method | Path | Role | Description |
|---|---|---|---|
| GET | `/approvals/pending` | gm, dcs | Consolidated pending approvals |

### File Attachments

| Method | Path | Description |
|---|---|---|
| POST | `/attachments/upload` | Upload file; returns `storage_key` + presigned URL |
| GET | `/attachments/{id}/url` | Get fresh presigned download URL (1h) |
| DELETE | `/attachments/{id}` | Soft-delete attachment |

### QBO Export

| Method | Path | Description |
|---|---|---|
| GET | `/qbo/export/{type}` | Export: customers, vendors, bills, expenses, invoices, collections, payments |

---

## Rate Limiting

| Endpoint class | Limit |
|---|---|
| `/auth/request-otp` | 3 req per email per 15 min; 10 req/min per IP |
| `/auth/verify-otp`  | 5 failed attempts per OTP before code invalidated; 10 req/min per IP |
| `/auth/refresh`     | 20 req/min per IP |
| All other endpoints | 300 req/min per user |

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
