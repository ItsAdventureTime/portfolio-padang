package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/itsadventuretime/padang-erp/backend/internal/domain/billing"
	"github.com/itsadventuretime/padang-erp/backend/internal/domain/inventory"
	"github.com/itsadventuretime/padang-erp/backend/internal/domain/role"
	mw "github.com/itsadventuretime/padang-erp/backend/internal/middleware"
	"github.com/jackc/pgx/v5"
)

type projectInput struct {
	ProjectCode      string `json:"project_code"`
	ProjectName      string `json:"project_name"`
	ClientID         string `json:"client_id"`
	ContractType     string `json:"contract_type"`
	ProjectType      string `json:"project_type"`
	ContractAmount   string `json:"contract_amount"`
	ProjectManagerID string `json:"project_manager_id"`
	StartDate        string `json:"start_date"`
	TargetEndDate    string `json:"target_end_date"`
	Location         string `json:"location"`
	Description      string `json:"description"`
}

func (s Server) actorID(ctx context.Context) (uuid.UUID, error) {
	principal, ok := mw.PrincipalFromContext(ctx)
	if !ok {
		return uuid.Nil, fmt.Errorf("principal missing")
	}
	if !principal.Demo {
		return principal.Subject, nil
	}
	if s.Pool == nil {
		return uuid.Nil, nil
	}
	var id uuid.UUID
	err := s.Pool.QueryRow(ctx, `SELECT id FROM users WHERE is_active AND deleted_at IS NULL ORDER BY email LIMIT 1`).Scan(&id)
	return id, err
}

func parseID(value string) (uuid.UUID, bool) {
	id, err := uuid.Parse(strings.TrimSpace(value))
	return id, err == nil
}

func parseMoney(value string) (*big.Rat, bool) {
	if strings.TrimSpace(value) == "" {
		return big.NewRat(0, 1), true
	}
	rat, ok := new(big.Rat).SetString(value)
	return rat, ok && rat.Sign() >= 0
}

func ratMoney(value *big.Rat) string { return value.FloatString(4) }

func (s Server) createProject(w http.ResponseWriter, r *http.Request) {
	var input projectInput
	if err := Decode(r, &input); err != nil || strings.TrimSpace(input.ProjectCode) == "" || strings.TrimSpace(input.ProjectName) == "" {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Project code and name are required")
		return
	}
	clientID, ok := parseID(input.ClientID)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "A valid client_id is required")
		return
	}
	amount, ok := parseMoney(input.ContractAmount)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Contract amount must be a non-negative number")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": uuid.New(), "project_code": input.ProjectCode, "project_name": input.ProjectName, "status": "planning"}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start project transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var id uuid.UUID
	err = tx.QueryRow(r.Context(), `
		INSERT INTO projects (project_code, project_name, client_id, client_name,
			contract_type, project_type, contract_amount, project_manager_id,
			start_date, target_end_date, location, description, created_by, updated_by)
		SELECT $1, $2, c.id, c.name, $3, $4, $5::numeric, NULLIF($6, '')::uuid,
			NULLIF($7, '')::date, NULLIF($8, '')::date, $9, $10, $11, $11
		FROM clients c WHERE c.id = $12 AND c.deleted_at IS NULL
		RETURNING id`, input.ProjectCode, input.ProjectName, input.ContractType,
		input.ProjectType, ratMoney(amount), input.ProjectManagerID, input.StartDate,
		input.TargetEndDate, input.Location, input.Description, actor, clientID).Scan(&id)
	if err != nil {
		if err == pgx.ErrNoRows {
			Error(w, http.StatusNotFound, "NOT_FOUND", "Client not found")
			return
		}
		Error(w, http.StatusConflict, "CONFLICT", "Project code already exists or project data is invalid")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, "project", id, actor, "created", nil, map[string]any{"project_code": input.ProjectCode, "project_name": input.ProjectName, "status": "planning"}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record project audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit project")
		return
	}
	JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": id, "project_code": input.ProjectCode, "project_name": input.ProjectName, "status": "planning"}})
}

func (s Server) projectDetail(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(chi.URLParam(r, "id"))
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid project id")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": id}})
		return
	}
	var row map[string]any
	var code, name, clientName, contractType, projectType, status string
	var amount string
	var location, description *string
	err := s.Pool.QueryRow(r.Context(), `
		SELECT project_code, project_name, client_name, contract_type, project_type,
			contract_amount::text, status, location, description
		FROM projects WHERE id=$1 AND deleted_at IS NULL`, id).Scan(&code, &name,
		&clientName, &contractType, &projectType, &amount, &status, &location, &description)
	if err == pgx.ErrNoRows {
		Error(w, http.StatusNotFound, "NOT_FOUND", "Project not found")
		return
	}
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load project")
		return
	}
	row = map[string]any{"id": id, "project_code": code, "project_name": name, "client_name": clientName, "contract_type": contractType, "project_type": projectType, "contract_amount": amount, "status": status, "location": location, "description": description}
	JSON(w, http.StatusOK, map[string]any{"data": row})
}

func (s Server) updateProject(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(chi.URLParam(r, "id"))
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid project id")
		return
	}
	var input projectInput
	if err := Decode(r, &input); err != nil || strings.TrimSpace(input.ProjectName) == "" {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Project name is required")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": id, "project_name": input.ProjectName}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start project transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var beforeName, beforeStatus string
	var beforeLocation, beforeDescription *string
	err = tx.QueryRow(r.Context(), `SELECT project_name, location, description, status FROM projects WHERE id=$1 AND deleted_at IS NULL FOR UPDATE`, id).Scan(&beforeName, &beforeLocation, &beforeDescription, &beforeStatus)
	if err == pgx.ErrNoRows {
		Error(w, http.StatusNotFound, "NOT_FOUND", "Project not found")
		return
	}
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load project")
		return
	}
	command, err := tx.Exec(r.Context(), `
		UPDATE projects SET project_name=$1, location=$2, description=$3,
			updated_at=now(), updated_by=$4 WHERE id=$5 AND deleted_at IS NULL`,
		input.ProjectName, input.Location, input.Description, actor, id)
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to update project")
		return
	}
	if command.RowsAffected() == 0 {
		Error(w, http.StatusNotFound, "NOT_FOUND", "Project not found")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, "project", id, actor, "updated", map[string]any{"project_name": beforeName, "location": beforeLocation, "description": beforeDescription, "status": beforeStatus}, map[string]any{"project_name": input.ProjectName, "location": input.Location, "description": input.Description, "status": beforeStatus}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record project audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit project")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": id, "project_name": input.ProjectName}})
}

func (s Server) createFabricationJob(w http.ResponseWriter, r *http.Request) {
	var input struct {
		JobNumber       string `json:"job_number"`
		ClientID        string `json:"client_id"`
		ProjectID       string `json:"project_id"`
		Description     string `json:"description"`
		FabricationType string `json:"fabrication_type"`
		ProposedPrice   string `json:"proposed_price"`
	}
	if err := Decode(r, &input); err != nil || input.JobNumber == "" || input.Description == "" || input.FabricationType == "" {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Job number, description, and fabrication type are required")
		return
	}
	clientID, ok := parseID(input.ClientID)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "A valid client_id is required")
		return
	}
	price, ok := parseMoney(input.ProposedPrice)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Proposed price must be non-negative")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": uuid.New(), "job_number": input.JobNumber, "status": "estimate"}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start fabrication transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var id uuid.UUID
	err = tx.QueryRow(r.Context(), `
		INSERT INTO fabrication_jobs (job_number, project_id, client_id, client_name,
			description, fabrication_type, proposed_price, created_by, updated_by)
		SELECT $1, NULLIF($2, '')::uuid, c.id, c.name, $3, $4, $5::numeric, $6, $6
		FROM clients c WHERE c.id=$7 AND c.deleted_at IS NULL RETURNING id`,
		input.JobNumber, input.ProjectID, input.Description, input.FabricationType,
		ratMoney(price), actor, clientID).Scan(&id)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Fabrication job data is invalid or already exists")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, "fabrication_job", id, actor, "created", nil, map[string]any{"job_number": input.JobNumber, "status": "estimate"}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record fabrication audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit fabrication job")
		return
	}
	JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": id, "job_number": input.JobNumber, "status": "estimate"}})
}

func (s Server) transition(w http.ResponseWriter, r *http.Request, table, idColumn, from, to string, fields string, args ...any) {
	s.transitionFrom(w, r, table, idColumn, []string{from}, to, fields, args...)
}

func auditStateChange(ctx context.Context, tx pgx.Tx, r *http.Request, entityType string, id, actor uuid.UUID, action string, before, after any) error {
	principal, ok := mw.PrincipalFromContext(ctx)
	if !ok {
		return fmt.Errorf("principal missing")
	}
	beforeJSON, err := json.Marshal(before)
	if err != nil {
		return err
	}
	afterJSON, err := json.Marshal(after)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `INSERT INTO audit_log (entity_type, entity_id, action, actor_id, actor_email, before_state, after_state, ip_address, user_agent) VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7::jsonb,$8,$9)`, entityType, id, action, actor, principal.Email, beforeJSON, afterJSON, r.RemoteAddr, r.UserAgent())
	return err
}

func (s Server) transitionFrom(w http.ResponseWriter, r *http.Request, table, idColumn string, allowedFrom []string, to, fields string, args ...any) {
	id, ok := parseID(chi.URLParam(r, "id"))
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid resource id")
		return
	}
	_, ok = mw.PrincipalFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": id, "status": to}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start workflow transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var current string
	err = tx.QueryRow(r.Context(), fmt.Sprintf("SELECT status FROM %s WHERE %s=$1 AND deleted_at IS NULL FOR UPDATE", table, idColumn), id).Scan(&current)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Resource is missing or not in the expected state")
		return
	}
	allowed := false
	for _, candidate := range allowedFrom {
		if current == candidate {
			allowed = true
			break
		}
	}
	if !allowed {
		Error(w, http.StatusConflict, "CONFLICT", "Resource is missing or not in the expected state")
		return
	}
	query := fmt.Sprintf("UPDATE %s SET status=$1, updated_at=now(), updated_by=$2%s WHERE %s=$3 AND status=$4 AND deleted_at IS NULL", table, fields, idColumn)
	params := []any{to, actor, id, current}
	params = append(params, args...)
	command, err := tx.Exec(r.Context(), query, params...)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Resource cannot make that state transition")
		return
	}
	if command.RowsAffected() != 1 {
		Error(w, http.StatusConflict, "CONFLICT", "Resource is missing or not in the expected state")
		return
	}
	action := "status_changed"
	if to == "rejected" {
		action = "rejected"
	} else if to == "approved" || (current == "gm_approval" && (to == "dcs_payment" || to == "issued")) {
		action = "approved"
	}
	entityType := map[string]string{"projects": "project", "fabrication_jobs": "fabrication_job", "purchase_requests": "purchase_request", "fund_requests": "fund_request", "progress_billings": "progress_billing"}[table]
	if entityType == "" {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unsupported workflow entity")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, entityType, id, actor, action, map[string]string{"status": current}, map[string]string{"status": to}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record workflow audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit workflow transition")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": id, "status": to}})
}

func (s Server) changeFabricationStatus(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Status string `json:"status"`
	}
	if err := Decode(r, &input); err != nil {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Status is required")
		return
	}
	principal, ok := mw.PrincipalFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
		return
	}
	transitions := map[string]struct {
		from  []string
		roles map[string]bool
	}{
		"job_order":     {from: []string{"estimate"}, roles: map[string]bool{role.Administrator: true, role.FabricationSupervisor: true}},
		"in_production": {from: []string{"job_order"}, roles: map[string]bool{role.Administrator: true, role.FabricationSupervisor: true}},
		"delivered":     {from: []string{"in_production"}, roles: map[string]bool{role.Administrator: true, role.FabricationSupervisor: true}},
		"billed":        {from: []string{"delivered"}, roles: map[string]bool{role.Administrator: true, role.BillingClerk: true}},
		"completed":     {from: []string{"billed"}, roles: map[string]bool{role.Administrator: true, role.BillingClerk: true}},
		"cancelled":     {from: []string{"estimate", "job_order", "in_production", "delivered"}, roles: map[string]bool{role.Administrator: true, role.FabricationSupervisor: true}},
	}
	rule, ok := transitions[input.Status]
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Unsupported fabrication status")
		return
	}
	if !rule.roles[principal.Role] {
		Error(w, http.StatusForbidden, "FORBIDDEN", "Insufficient role for fabrication transition")
		return
	}
	s.transitionFrom(w, r, "fabrication_jobs", "id", rule.from, input.Status, "")
}

func (s Server) createPurchaseRequest(w http.ResponseWriter, r *http.Request) {
	var input struct {
		ProjectID string `json:"project_id"`
		FabJobID  string `json:"fab_job_id"`
		Purpose   string `json:"purpose"`
	}
	if err := Decode(r, &input); err != nil || strings.TrimSpace(input.Purpose) == "" {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Purpose is required")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": uuid.New(), "status": "draft", "purpose": input.Purpose}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start purchase request transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var id uuid.UUID
	err = tx.QueryRow(r.Context(), `INSERT INTO purchase_requests (project_id, fab_job_id, purpose, requested_by, created_by, updated_by) VALUES (NULLIF($1,'')::uuid, NULLIF($2,'')::uuid, $3, $4, $4, $4) RETURNING id`, input.ProjectID, input.FabJobID, input.Purpose, actor).Scan(&id)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Purchase request data is invalid")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, "purchase_request", id, actor, "created", nil, map[string]any{"purpose": input.Purpose, "status": "draft"}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record purchase request audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit purchase request")
		return
	}
	JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": id, "status": "draft", "purpose": input.Purpose}})
}

func (s Server) changePurchaseRequest(w http.ResponseWriter, r *http.Request, from, to string) {
	fields := ""
	if to == "approved" {
		fields = ", approved_by=$2, approved_at=now()"
	}
	s.transition(w, r, "purchase_requests", "id", from, to, fields)
}

func (s Server) createFundRequest(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Type      string `json:"fr_type"`
		POID      string `json:"po_id"`
		ProjectID string `json:"project_id"`
		Amount    string `json:"amount"`
		Purpose   string `json:"purpose"`
	}
	if err := Decode(r, &input); err != nil || input.Type == "" || input.Purpose == "" {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Fund request type, purpose, and amount are required")
		return
	}
	amount, ok := parseMoney(input.Amount)
	if !ok || amount.Sign() <= 0 {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Amount must be greater than zero")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": uuid.New(), "status": "draft", "amount": ratMoney(amount)}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start fund request transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var id uuid.UUID
	err = tx.QueryRow(r.Context(), `INSERT INTO fund_requests (fr_type, po_id, project_id, amount, purpose, requested_by, created_by, updated_by) VALUES ($1, NULLIF($2,'')::uuid, NULLIF($3,'')::uuid, $4::numeric, $5, $6, $6, $6) RETURNING id`, input.Type, input.POID, input.ProjectID, ratMoney(amount), input.Purpose, actor).Scan(&id)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Fund request data is invalid")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, "fund_request", id, actor, "created", nil, map[string]any{"fr_type": input.Type, "purpose": input.Purpose, "amount": ratMoney(amount), "status": "draft"}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record fund request audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit fund request")
		return
	}
	JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": id, "status": "draft", "amount": ratMoney(amount)}})
}

func (s Server) changeFundRequest(w http.ResponseWriter, r *http.Request, from, to string) {
	if to == "completed" {
		var input struct{ PaymentReference, PaymentBank, ActualAmountPaid string }
		if err := Decode(r, &input); err != nil || input.PaymentReference == "" {
			Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Payment reference is required")
			return
		}
		amount, ok := parseMoney(input.ActualAmountPaid)
		if !ok || amount.Sign() <= 0 {
			Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Actual amount paid must be greater than zero")
			return
		}
		s.transition(w, r, "fund_requests", "id", from, to, ", payment_reference=$5, payment_bank=$6, actual_amount_paid=$7::numeric, dcs_processed_by=$2, dcs_processed_at=now()", input.PaymentReference, input.PaymentBank, ratMoney(amount))
		return
	}
	fields := ""
	if to == "dcs_payment" {
		fields = ", gm_approved_by=$2, gm_approved_at=now()"
	}
	s.transition(w, r, "fund_requests", "id", from, to, fields)
}

func (s Server) createInventoryItem(w http.ResponseWriter, r *http.Request) {
	var input struct {
		ItemCode     string `json:"item_code"`
		Description  string `json:"description"`
		Unit         string `json:"unit"`
		Category     string `json:"category"`
		ReorderPoint string `json:"reorder_point"`
	}
	if err := Decode(r, &input); err != nil || input.ItemCode == "" || input.Description == "" || input.Unit == "" || input.Category == "" {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Item code, description, unit, and category are required")
		return
	}
	reorder, ok := parseMoney(input.ReorderPoint)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Reorder point must be non-negative")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": uuid.New(), "item_code": input.ItemCode, "current_qty": "0.0000"}})
		return
	}
	var id uuid.UUID
	err = s.Pool.QueryRow(r.Context(), `INSERT INTO inventory_items (item_code, description, unit, category, reorder_point, created_by, updated_by) VALUES ($1,$2,$3,$4,$5::numeric,$6,$6) RETURNING id`, input.ItemCode, input.Description, input.Unit, input.Category, ratMoney(reorder), actor).Scan(&id)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Inventory item code already exists or is invalid")
		return
	}
	JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": id, "item_code": input.ItemCode, "current_qty": "0.0000"}})
}

func (s Server) stockMovement(w http.ResponseWriter, r *http.Request, direction string) {
	var input struct {
		ItemID          string `json:"item_id"`
		Quantity        string `json:"quantity"`
		UnitCost        string `json:"unit_cost"`
		ProjectID       string `json:"project_id"`
		FabJobID        string `json:"fab_job_id"`
		Notes           string `json:"notes"`
		DirectToProject bool   `json:"direct_to_project"`
	}
	if err := Decode(r, &input); err != nil {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Item and quantity are required")
		return
	}
	itemID, ok := parseID(input.ItemID)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid item_id")
		return
	}
	qty, ok := parseMoney(input.Quantity)
	if !ok || qty.Sign() <= 0 {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Quantity must be greater than zero")
		return
	}
	cost, ok := parseMoney(input.UnitCost)
	if direction == "stock_in" && (!ok || cost.Sign() < 0) {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Unit cost is required for stock in")
		return
	}
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"item_id": itemID, "transaction_type": direction, "quantity": ratMoney(qty)}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start inventory transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var currentQtyText, currentCostText string
	err = tx.QueryRow(r.Context(), `SELECT current_qty::text, avg_unit_cost::text FROM inventory_items WHERE id=$1 AND deleted_at IS NULL FOR UPDATE`, itemID).Scan(&currentQtyText, &currentCostText)
	if err == pgx.ErrNoRows {
		Error(w, http.StatusNotFound, "NOT_FOUND", "Inventory item not found")
		return
	}
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load inventory item")
		return
	}
	currentQty, ok1 := new(big.Rat).SetString(currentQtyText)
	currentCost, ok2 := new(big.Rat).SetString(currentCostText)
	if !ok1 || !ok2 {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Stored inventory cost is invalid")
		return
	}
	if input.DirectToProject {
		if _, ok := parseID(input.ProjectID); !ok {
			Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Direct-to-project movement requires a valid project_id")
			return
		}
		var transactionID uuid.UUID
		err = tx.QueryRow(r.Context(), `INSERT INTO inventory_transactions (item_id, transaction_type, quantity, unit_cost, project_id, fab_job_id, is_direct_to_project, notes, created_by) VALUES ($1,'material_issue',$2::numeric,NULLIF($3,'')::numeric,$4::uuid,NULLIF($5,'')::uuid,TRUE,$6,$7) RETURNING id`, itemID, ratMoney(qty), ratMoney(cost), input.ProjectID, input.FabJobID, input.Notes, actor).Scan(&transactionID)
		if err != nil {
			Error(w, http.StatusConflict, "CONFLICT", "Direct-to-project movement is invalid")
			return
		}
		if err = auditStateChange(r.Context(), tx, r, "inventory_transaction", transactionID, actor, "created", nil, map[string]any{"item_id": itemID, "transaction_type": "material_issue", "quantity": ratMoney(qty), "direct_to_project": true}); err != nil {
			Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record inventory audit event")
			return
		}
		if err = tx.Commit(r.Context()); err != nil {
			Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit material issue")
			return
		}
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"item_id": itemID, "transaction_type": "material_issue", "quantity": ratMoney(qty), "direct_to_project": true}})
		return
	}
	newQty := new(big.Rat).Set(currentQty)
	newCost := new(big.Rat).Set(currentCost)
	transactionType := direction
	if direction == "stock_in" {
		newQty.Add(newQty, qty)
		newCost = inventory.WeightedAverage(currentQty, currentCost, qty, cost)
	} else {
		if currentQty.Cmp(qty) < 0 {
			Error(w, http.StatusUnprocessableEntity, "BUSINESS_RULE_ERROR", "Stock out exceeds available quantity")
			return
		}
		newQty.Sub(newQty, qty)
		transactionType = "stock_out"
	}
	if newQty.Sign() < 0 {
		Error(w, http.StatusUnprocessableEntity, "BUSINESS_RULE_ERROR", "Inventory quantity cannot be negative")
		return
	}
	_, err = tx.Exec(r.Context(), `UPDATE inventory_items SET current_qty=$1::numeric, avg_unit_cost=$2::numeric, updated_at=now(), updated_by=$3 WHERE id=$4`, ratMoney(newQty), ratMoney(newCost), actor, itemID)
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to update inventory balance")
		return
	}
	var transactionID uuid.UUID
	err = tx.QueryRow(r.Context(), `INSERT INTO inventory_transactions (item_id, transaction_type, quantity, unit_cost, project_id, fab_job_id, is_direct_to_project, notes, created_by) VALUES ($1,$2,$3::numeric,NULLIF($4,'')::numeric,NULLIF($5,'')::uuid,NULLIF($6,'')::uuid,$7,$8,$9) RETURNING id`, itemID, transactionType, ratMoney(qty), ratMoney(cost), input.ProjectID, input.FabJobID, input.DirectToProject, input.Notes, actor).Scan(&transactionID)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Inventory movement is invalid")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, "inventory_transaction", transactionID, actor, "created", map[string]any{"current_qty": currentQtyText, "avg_unit_cost": currentCostText}, map[string]any{"item_id": itemID, "transaction_type": transactionType, "quantity": ratMoney(qty), "current_qty": ratMoney(newQty), "avg_unit_cost": ratMoney(newCost)}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record inventory audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit inventory movement")
		return
	}
	JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"item_id": itemID, "transaction_type": transactionType, "quantity": ratMoney(qty), "current_qty": ratMoney(newQty), "avg_unit_cost": ratMoney(newCost)}})
}

func (s Server) createProgressBilling(w http.ResponseWriter, r *http.Request) {
	var input struct {
		BillingNumber string `json:"billing_number"`
		ProjectID     string `json:"project_id"`
		BillingDate   string `json:"billing_date"`
		GrossAmount   string `json:"gross_amount"`
		RetentionRate string `json:"retention_rate"`
		VATRate       string `json:"vat_rate"`
		EWTRate       string `json:"ewt_rate"`
		DueDate       string `json:"due_date"`
		Notes         string `json:"notes"`
	}
	if err := Decode(r, &input); err != nil || input.BillingNumber == "" || input.BillingDate == "" {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Billing number, project, date, and gross amount are required")
		return
	}
	projectID, ok := parseID(input.ProjectID)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid project_id")
		return
	}
	gross, ok := parseMoney(input.GrossAmount)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Gross amount must be non-negative")
		return
	}
	retention, ok := parseMoney(input.RetentionRate)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Retention rate is invalid")
		return
	}
	vat, ok := parseMoney(input.VATRate)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "VAT rate is invalid")
		return
	}
	ewt, ok := parseMoney(input.EWTRate)
	if !ok {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "EWT rate is invalid")
		return
	}
	totals := billing.Calculate(billing.Inputs{Gross: gross, RetentionRate: retention, VATRate: vat, EWTRate: ewt})
	actor, err := s.actorID(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to resolve the acting user")
		return
	}
	if s.Pool == nil {
		JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": uuid.New(), "billing_number": input.BillingNumber, "gross_amount": ratMoney(totals.Gross), "net_amount": ratMoney(totals.Net), "status": "draft"}})
		return
	}
	tx, err := s.Pool.Begin(r.Context())
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to start billing transaction")
		return
	}
	defer tx.Rollback(r.Context())
	var id uuid.UUID
	err = tx.QueryRow(r.Context(), `INSERT INTO progress_billings (billing_number, project_id, billing_date, gross_amount, retention_rate, retention_amount, vat_rate, vat_amount, ewt_rate, ewt_amount, net_amount, due_date, notes, created_by, updated_by) VALUES ($1,$2,$3::date,$4::numeric,$5::numeric,$6::numeric,$7::numeric,$8::numeric,$9::numeric,$10::numeric,$11::numeric,NULLIF($12,'')::date,$13,$14,$14) RETURNING id`, input.BillingNumber, projectID, input.BillingDate, ratMoney(totals.Gross), ratMoney(retention), ratMoney(totals.Retention), ratMoney(vat), ratMoney(totals.VAT), ratMoney(ewt), ratMoney(totals.EWT), ratMoney(totals.Net), input.DueDate, input.Notes, actor).Scan(&id)
	if err != nil {
		Error(w, http.StatusConflict, "CONFLICT", "Billing data is invalid or billing number already exists")
		return
	}
	if err = auditStateChange(r.Context(), tx, r, "progress_billing", id, actor, "created", nil, map[string]any{"billing_number": input.BillingNumber, "gross_amount": ratMoney(totals.Gross), "net_amount": ratMoney(totals.Net), "status": "draft"}); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to record billing audit event")
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to commit billing")
		return
	}
	JSON(w, http.StatusCreated, map[string]any{"data": map[string]any{"id": id, "billing_number": input.BillingNumber, "gross_amount": ratMoney(totals.Gross), "retention_amount": ratMoney(totals.Retention), "vat_amount": ratMoney(totals.VAT), "ewt_amount": ratMoney(totals.EWT), "net_amount": ratMoney(totals.Net), "status": "draft"}})
}

func (s Server) changeBilling(w http.ResponseWriter, r *http.Request, from, to string) {
	fields := ""
	if to == "gm_approval" {
		fields = ", submitted_by=$2, submitted_at=now()"
	} else if to == "issued" {
		fields = ", gm_approved_by=$2, gm_approved_at=now()"
	}
	s.transition(w, r, "progress_billings", "id", from, to, fields)
}

func transitionRoutes(r chi.Router, s Server) {
	r.With(mw.RequireRoles("administrator", "project_manager")).Post("/projects", s.createProject)
	r.Get("/projects/{id}", s.projectDetail)
	r.With(mw.RequireRoles("administrator", "project_manager")).Put("/projects/{id}", s.updateProject)
	r.With(mw.RequireRoles("administrator", "fabrication_supervisor")).Post("/fabrication", s.createFabricationJob)
	r.With(mw.RequireRoles("administrator", "fabrication_supervisor", "billing_clerk")).Patch("/fabrication/{id}/status", s.changeFabricationStatus)
	r.With(mw.RequireRoles("administrator", "procurement_officer", "project_manager")).Post("/procurement/purchase-requests", s.createPurchaseRequest)
	r.With(mw.RequireRoles("administrator", "project_manager", "procurement_officer")).Patch("/procurement/purchase-requests/{id}/submit", func(w http.ResponseWriter, r *http.Request) { s.changePurchaseRequest(w, r, "draft", "submitted") })
	r.With(mw.RequireRoles("administrator", "general_manager")).Patch("/procurement/purchase-requests/{id}/approve", func(w http.ResponseWriter, r *http.Request) { s.changePurchaseRequest(w, r, "submitted", "approved") })
	r.With(mw.RequireRoles("administrator", "general_manager")).Patch("/procurement/purchase-requests/{id}/reject", func(w http.ResponseWriter, r *http.Request) { s.changePurchaseRequest(w, r, "submitted", "rejected") })
	r.With(mw.RequireRoles("administrator", "procurement_officer", "finance_staff")).Post("/procurement/fund-requests", s.createFundRequest)
	r.With(mw.RequireRoles("administrator", "procurement_officer", "finance_staff")).Patch("/procurement/fund-requests/{id}/submit", func(w http.ResponseWriter, r *http.Request) { s.changeFundRequest(w, r, "draft", "gm_approval") })
	r.With(mw.RequireRoles("administrator", "general_manager")).Patch("/procurement/fund-requests/{id}/approve", func(w http.ResponseWriter, r *http.Request) { s.changeFundRequest(w, r, "gm_approval", "dcs_payment") })
	r.With(mw.RequireRoles("administrator", "general_manager")).Patch("/procurement/fund-requests/{id}/reject", func(w http.ResponseWriter, r *http.Request) { s.changeFundRequest(w, r, "gm_approval", "rejected") })
	r.With(mw.RequireRoles("administrator", "disbursing_check_signing_officer")).Patch("/procurement/fund-requests/{id}/pay", func(w http.ResponseWriter, r *http.Request) { s.changeFundRequest(w, r, "dcs_payment", "completed") })
	r.With(mw.RequireRoles("administrator", "inventory_clerk")).Post("/inventory/items", s.createInventoryItem)
	r.With(mw.RequireRoles("administrator", "inventory_clerk")).Post("/inventory/stock-in", func(w http.ResponseWriter, r *http.Request) { s.stockMovement(w, r, "stock_in") })
	r.With(mw.RequireRoles("administrator", "inventory_clerk")).Post("/inventory/stock-out", func(w http.ResponseWriter, r *http.Request) { s.stockMovement(w, r, "stock_out") })
	r.With(mw.RequireRoles("administrator", "billing_clerk")).Post("/billing/progress", s.createProgressBilling)
	r.With(mw.RequireRoles("administrator", "billing_clerk")).Patch("/billing/progress/{id}/submit", func(w http.ResponseWriter, r *http.Request) { s.changeBilling(w, r, "draft", "gm_approval") })
	r.With(mw.RequireRoles("administrator", "general_manager")).Patch("/billing/progress/{id}/approve", func(w http.ResponseWriter, r *http.Request) { s.changeBilling(w, r, "gm_approval", "issued") })
	r.With(mw.RequireRoles("administrator", "general_manager")).Patch("/billing/progress/{id}/reject", func(w http.ResponseWriter, r *http.Request) { s.changeBilling(w, r, "gm_approval", "draft") })
	r.With(mw.RequireRoles("administrator", "general_manager")).Patch("/billing/progress/{id}/issue", func(w http.ResponseWriter, r *http.Request) { s.changeBilling(w, r, "gm_approval", "issued") })
}
