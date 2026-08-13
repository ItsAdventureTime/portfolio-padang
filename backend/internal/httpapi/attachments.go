package httpapi

import (
	"encoding/json"
	"fmt"
	"mime"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
	mw "github.com/itsadventuretime/padang-erp/backend/internal/middleware"
	"github.com/itsadventuretime/padang-erp/backend/internal/storage"
	"github.com/jackc/pgx/v5"
)

const maxAttachmentSize int64 = 50 * 1024 * 1024

var attachmentExtensions = map[string]map[string]bool{
	"application/pdf":             {".pdf": true},
	"application/acad":            {".dwg": true},
	"application/vnd.autocad.dwg": {".dwg": true},
	"application/vnd.openxmlformats-officedocument.wordprocessingml.document": {".docx": true},
	"image/jpeg": {".jpg": true, ".jpeg": true},
	"image/png":  {".png": true},
	"image/webp": {".webp": true},
	"text/plain": {".txt": true},
	"text/csv":   {".csv": true},
	"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": {".xlsx": true},
}

var attachmentEntities = map[string]struct {
	query string
	roles map[string]bool
}{
	"project": {
		query: `SELECT 1 FROM projects WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2 OR project_manager_id=$2)`,
		roles: map[string]bool{"administrator": true, "project_manager": true},
	},
	"fabrication_job": {
		query: `SELECT 1 FROM fabrication_jobs WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2)`,
		roles: map[string]bool{"administrator": true, "fabrication_supervisor": true},
	},
	"purchase_request": {
		query: `SELECT 1 FROM purchase_requests WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2 OR requested_by=$2)`,
		roles: map[string]bool{"administrator": true, "procurement_officer": true, "project_manager": true},
	},
	"purchase_order": {
		query: `SELECT 1 FROM purchase_orders WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2)`,
		roles: map[string]bool{"administrator": true, "procurement_officer": true},
	},
	"fund_request": {
		query: `SELECT 1 FROM fund_requests WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2 OR requested_by=$2)`,
		roles: map[string]bool{"administrator": true, "procurement_officer": true, "finance_staff": true},
	},
	"progress_billing": {
		query: `SELECT 1 FROM progress_billings WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2)`,
		roles: map[string]bool{"administrator": true, "billing_clerk": true},
	},
	"fabrication_billing": {
		query: `SELECT 1 FROM fabrication_billings WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2)`,
		roles: map[string]bool{"administrator": true, "billing_clerk": true},
	},
	"collection": {
		query: `SELECT 1 FROM collections WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR recorded_by=$2)`,
		roles: map[string]bool{"administrator": true, "billing_clerk": true},
	},
	"client": {
		query: `SELECT 1 FROM clients WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2)`,
		roles: map[string]bool{"administrator": true, "finance_staff": true},
	},
	"supplier": {
		query: `SELECT 1 FROM suppliers WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2)`,
		roles: map[string]bool{"administrator": true, "procurement_officer": true},
	},
	"reimbursement": {
		query: `SELECT 1 FROM reimbursements WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2 OR requester_id=$2)`,
		roles: map[string]bool{"administrator": true, "finance_staff": true},
	},
	"liquidation": {
		query: `SELECT 1 FROM liquidations WHERE id=$1 AND deleted_at IS NULL AND ($3 = 'administrator' OR created_by=$2 OR submitted_by=$2)`,
		roles: map[string]bool{"administrator": true, "finance_staff": true},
	},
}

func attachmentObject(fileName, contentType string, size int64) (string, string, bool) {
	if size <= 0 || size > maxAttachmentSize {
		return "", "", false
	}
	parsedType, _, err := mime.ParseMediaType(strings.TrimSpace(contentType))
	if err != nil {
		return "", "", false
	}
	parsedType = strings.ToLower(parsedType)
	name := strings.TrimSpace(fileName)
	if name == "" || len(name) > 255 || strings.ContainsAny(name, `/\\`) || filepath.Base(name) != name {
		return "", "", false
	}
	ext := strings.ToLower(filepath.Ext(name))
	if !attachmentExtensions[parsedType][ext] {
		return "", "", false
	}
	return parsedType, ext, true
}

func (s Server) presign(w http.ResponseWriter, r *http.Request) {
	var input struct {
		EntityType  string `json:"entity_type"`
		EntityID    string `json:"entity_id"`
		FileName    string `json:"file_name"`
		ContentType string `json:"content_type"`
		Size        int64  `json:"size"`
		Category    string `json:"category"`
	}
	if err := Decode(r, &input); err != nil {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Attachment metadata is invalid")
		return
	}
	entity, ok := attachmentEntities[input.EntityType]
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Unsupported attachment entity")
		return
	}
	entityID, ok := parseID(input.EntityID)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "A valid entity_id is required")
		return
	}
	contentType, extension, ok := attachmentObject(input.FileName, input.ContentType, input.Size)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "File name, MIME type, extension, and size must be valid")
		return
	}
	if input.Category != "" && !map[string]bool{"contract": true, "drawing": true, "permit": true, "photo": true, "report": true, "receipt": true, "other": true}[input.Category] {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Unsupported attachment category")
		return
	}
	principal, ok := mw.PrincipalFromContext(r.Context())
	if !ok || !entity.roles[principal.Role] {
		Error(w, http.StatusForbidden, "FORBIDDEN", "Insufficient role for attachment")
		return
	}
	if s.Pool == nil || s.Storage == nil {
		Error(w, http.StatusServiceUnavailable, "STORAGE_UNAVAILABLE", "Attachment storage is not configured")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start attachment transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var exists int
	if err = tx.QueryRow(r.Context(), entity.query, entityID, actor, principal.Role).Scan(&exists); err != nil {
		if err == pgx.ErrNoRows {
			Error(w, http.StatusNotFound, "NOT_FOUND", "Attachment entity not found or not owned by the acting user")
			return
		}
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to authorize attachment entity")
		return
	}
	attachmentID := uuid.New()
	storageKey := fmt.Sprintf("%s/%s/%s%s", input.EntityType, entityID, attachmentID, extension)
	url, err := s.Storage.PresignUpload(r.Context(), storage.Object{Key: storageKey, ContentType: contentType, Size: input.Size})
	if err != nil {
		Error(w, http.StatusServiceUnavailable, "STORAGE_UNAVAILABLE", "Unable to create upload URL")
		return
	}
	_, err = tx.Exec(r.Context(), `INSERT INTO attachments (id, entity_type, entity_id, file_name, storage_key, content_type, file_size, category, uploaded_by) VALUES ($1,$2,$3,$4,$5,$6,$7,NULLIF($8,''),$9)`, attachmentID, input.EntityType, entityID, input.FileName, storageKey, contentType, input.Size, input.Category, actor)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Attachment metadata could not be recorded")
		return
	}
	after, _ := json.Marshal(map[string]any{"entity_type": input.EntityType, "entity_id": entityID, "file_name": input.FileName, "storage_key": storageKey, "content_type": contentType, "file_size": input.Size})
	_, err = tx.Exec(r.Context(), `INSERT INTO audit_log (entity_type, entity_id, action, actor_id, actor_email, after_state, ip_address, user_agent) VALUES ('attachment',$1,'created',$2,$3,$4::jsonb,$5,$6)`, attachmentID, actor, principal.Email, after, r.RemoteAddr, r.UserAgent())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record attachment audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit attachment metadata")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"attachment_id": attachmentID, "storage_key": storageKey, "upload_url": url, "method": http.MethodPut}})
}
