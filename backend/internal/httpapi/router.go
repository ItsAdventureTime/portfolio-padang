package httpapi

import (
	"context"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"
	"github.com/itsadventuretime/padang-erp/backend/internal/auth"
	"github.com/itsadventuretime/padang-erp/backend/internal/config"
	mw "github.com/itsadventuretime/padang-erp/backend/internal/middleware"
	"github.com/itsadventuretime/padang-erp/backend/internal/repository"
	dbrepo "github.com/itsadventuretime/padang-erp/backend/internal/repository/generated"
	"github.com/itsadventuretime/padang-erp/backend/internal/storage"
	"github.com/itsadventuretime/padang-erp/backend/openapi"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Server struct {
	Config  config.Config
	Pool    *pgxpool.Pool
	Auth    *auth.Service
	Tokens  *auth.TokenManager
	Storage storage.Service
	limiter *RateLimiter
}

func (s Server) Router() http.Handler {
	if s.limiter == nil {
		s.limiter = NewRateLimiter()
	}
	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, middleware.Recoverer, middleware.Timeout(30*time.Second), requestIDMiddleware, s.securityHeaders)
	r.Get("/api/v1/health", s.health)
	r.Get("/api/v1/openapi.json", s.openapi)
	r.Route("/api/v1/auth", func(r chi.Router) {
		r.Post("/request-otp", s.requestOTP)
		r.Post("/verify-otp", s.verifyOTP)
		r.Post("/refresh", s.refresh)
		r.With(s.authMiddleware()).Post("/logout", s.logout)
		r.With(s.authMiddleware()).Get("/me", s.me)
	})
	r.With(s.authMiddleware()).Route("/api/v1", func(r chi.Router) {
		r.Get("/dashboard/summary", s.dashboard)
		r.Post("/attachments/presign", s.presign)
		r.With(mw.RequireRoles("administrator", "general_manager", "project_manager", "viewer")).Get("/projects", s.projects)
		r.Get("/fabrication", s.fabrication)
		r.Get("/procurement/purchase-requests", s.purchaseRequests)
		r.Get("/procurement/purchase-orders", s.purchaseOrders)
		r.Get("/procurement/fund-requests", s.fundRequests)
		r.Get("/inventory/items", s.inventoryItems)
		r.Get("/billing/progress", s.progressBillings)
		r.Get("/finance/reimbursements", s.reimbursements)
		r.Get("/finance/liquidations", s.liquidations)
		transitionRoutes(r, s)
	})
	return r
}

func (s Server) securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		if s.Config.AppEnv == config.Production {
			w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}
		next.ServeHTTP(w, r)
	})
}

func (s Server) authMiddleware() func(http.Handler) http.Handler {
	var lookup mw.ActiveUserLookup
	if s.Pool != nil {
		store := repository.AuthStore{Pool: s.Pool}
		lookup = func(ctx context.Context, id uuid.UUID) (auth.Principal, bool) {
			user, err := store.UserByID(ctx, id)
			if err != nil || !user.Active {
				return auth.Principal{}, false
			}
			return auth.Principal{Subject: user.ID, Email: user.Email, Name: user.FullName, Role: user.Role}, true
		}
	}
	return mw.Authenticate(s.Config.AppEnv, s.Tokens, lookup)
}
func (s Server) health(w http.ResponseWriter, r *http.Request) {
	status := map[string]any{"status": "ok", "environment": s.Config.AppEnv}
	if s.Pool != nil {
		if err := s.Pool.Ping(r.Context()); err != nil {
			status["status"] = "degraded"
			JSON(w, http.StatusServiceUnavailable, status)
			return
		}
	}
	JSON(w, http.StatusOK, status)
}
func (s Server) requestOTP(w http.ResponseWriter, r *http.Request) {
	if s.Config.AppEnv == config.Demo {
		Error(w, http.StatusNotFound, "AUTH_DISABLED", "Demo mode does not use authentication")
		return
	}
	var input struct {
		Email string `json:"email"`
	}
	if err := Decode(r, &input); err != nil {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Valid email is required")
		return
	}
	key := clientKey(r) + "|" + strings.ToLower(strings.TrimSpace(input.Email))
	if allowed, retryAfter := s.limiter.Allow(key, 3, 15*time.Minute, time.Now()); !allowed {
		rateLimited(w, retryAfter)
		return
	}
	if allowed, retryAfter := s.limiter.Allow("request|"+clientKey(r), 10, time.Minute, time.Now()); !allowed {
		rateLimited(w, retryAfter)
		return
	}
	if s.Auth == nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Authentication is not configured")
		return
	}
	id, err := s.Auth.RequestOTP(r.Context(), input.Email)
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to request a code")
		return
	}
	JSON(w, http.StatusAccepted, map[string]any{"data": map[string]any{"challenge_id": id, "message": "If the account is approved, a code has been sent."}})
}
func (s Server) verifyOTP(w http.ResponseWriter, r *http.Request) {
	if s.Config.AppEnv == config.Demo {
		Error(w, http.StatusNotFound, "AUTH_DISABLED", "Demo mode does not use authentication")
		return
	}
	var input struct {
		ChallengeID string `json:"challenge_id"`
		Code        string `json:"code"`
	}
	if err := Decode(r, &input); err != nil {
		Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "Challenge ID and code are required")
		return
	}
	if allowed, retryAfter := s.limiter.Allow(clientKey(r), 10, time.Minute, time.Now()); !allowed {
		rateLimited(w, retryAfter)
		return
	}
	id, err := uuid.Parse(input.ChallengeID)
	if err != nil || len(input.Code) != 6 || s.Auth == nil {
		Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid one-time code")
		return
	}
	principal, access, refresh, err := s.Auth.VerifyOTP(r.Context(), id, input.Code)
	if err != nil {
		Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid or expired one-time code")
		return
	}
	s.setRefreshCookie(w, refresh)
	JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"access_token": access, "token_type": "Bearer", "expires_in": 900, "user": principal}})
}
func (s Server) refresh(w http.ResponseWriter, r *http.Request) {
	if s.Config.AppEnv == config.Demo {
		Error(w, http.StatusNotFound, "AUTH_DISABLED", "Demo mode does not use authentication")
		return
	}
	if allowed, retryAfter := s.limiter.Allow("refresh|"+clientKey(r), 20, time.Minute, time.Now()); !allowed {
		rateLimited(w, retryAfter)
		return
	}
	cookie, err := r.Cookie("padang_refresh_token")
	if err != nil || s.Auth == nil {
		Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Refresh token required")
		return
	}
	principal, access, refresh, err := s.Auth.Refresh(r.Context(), cookie.Value)
	if err != nil {
		Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid refresh token")
		return
	}
	s.setRefreshCookie(w, refresh)
	JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"access_token": access, "token_type": "Bearer", "expires_in": 900, "user": principal}})
}
func (s Server) logout(w http.ResponseWriter, r *http.Request) {
	if cookie, err := r.Cookie("padang_refresh_token"); err == nil && s.Auth != nil {
		_ = s.Auth.Revoke(r.Context(), cookie.Value)
	}
	http.SetCookie(w, &http.Cookie{Name: "padang_refresh_token", Value: "", Path: "/", MaxAge: -1, HttpOnly: true, Secure: s.Config.AppEnv == config.Production, SameSite: http.SameSiteStrictMode})
	JSON(w, http.StatusOK, map[string]any{"data": map[string]string{"status": "logged_out"}})
}
func (s Server) me(w http.ResponseWriter, r *http.Request) {
	principal, ok := mw.PrincipalFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": principal})
}
func (s Server) dashboard(w http.ResponseWriter, _ *http.Request) {
	JSON(w, http.StatusOK, map[string]any{"data": map[string]any{"active_projects": 5, "fabrication_jobs": 3, "pending_approvals": 7, "accounts_receivable": "1240000.0000"}})
}
func (s Server) projects(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		JSON(w, http.StatusOK, map[string]any{"data": []any{}, "meta": map[string]int{"page": 1, "per_page": 20}})
		return
	}
	queries := dbrepo.New(s.Pool)
	rows, err := queries.ListProjects(r.Context(), dbrepo.ListProjectsParams{Status: "", PageSize: 20, PageOffset: 0})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load projects")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": 1, "per_page": 20}})
}

func listParams(r *http.Request) (int32, int32) {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	perPage, _ := strconv.Atoi(r.URL.Query().Get("per_page"))
	if page < 1 {
		page = 1
	}
	if perPage < 1 || perPage > 100 {
		perPage = 20
	}
	return int32(perPage), int32((page - 1) * perPage)
}

func emptyList(w http.ResponseWriter, r *http.Request) {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	JSON(w, http.StatusOK, map[string]any{"data": []any{}, "meta": map[string]int{"page": page, "per_page": 20}})
}

func (s Server) fabrication(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListFabricationJobs(r.Context(), dbrepo.ListFabricationJobsParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load fabrication jobs")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) purchaseRequests(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListPurchaseRequests(r.Context(), dbrepo.ListPurchaseRequestsParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load purchase requests")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) purchaseOrders(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListPurchaseOrders(r.Context(), dbrepo.ListPurchaseOrdersParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load purchase orders")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) fundRequests(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListFundRequests(r.Context(), dbrepo.ListFundRequestsParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load fund requests")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) inventoryItems(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListInventoryItems(r.Context(), dbrepo.ListInventoryItemsParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load inventory")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) progressBillings(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListProgressBillings(r.Context(), dbrepo.ListProgressBillingsParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load progress billings")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) reimbursements(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListReimbursements(r.Context(), dbrepo.ListReimbursementsParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load reimbursements")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) liquidations(w http.ResponseWriter, r *http.Request) {
	if s.Pool == nil {
		emptyList(w, r)
		return
	}
	limit, offset := listParams(r)
	rows, err := dbrepo.New(s.Pool).ListLiquidations(r.Context(), dbrepo.ListLiquidationsParams{Limit: limit, Offset: offset})
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load liquidations")
		return
	}
	JSON(w, http.StatusOK, map[string]any{"data": rows, "meta": map[string]int{"page": int(offset/limit + 1), "per_page": int(limit)}})
}

func (s Server) openapi(w http.ResponseWriter, _ *http.Request) {
	document, err := openapi.JSON()
	if err != nil {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Unable to load API contract")
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_, _ = w.Write(document)
}
func (s Server) setRefreshCookie(w http.ResponseWriter, value string) {
	http.SetCookie(w, &http.Cookie{Name: "padang_refresh_token", Value: value, Path: "/", MaxAge: 7 * 24 * 60 * 60, HttpOnly: true, Secure: s.Config.AppEnv == config.Production, SameSite: http.SameSiteStrictMode})
}
