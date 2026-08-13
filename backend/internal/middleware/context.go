package middleware

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/itsadventuretime/padang-erp/backend/internal/auth"
	"github.com/itsadventuretime/padang-erp/backend/internal/domain/role"
)

type contextKey string

const principalKey contextKey = "principal"

func WithPrincipal(ctx context.Context, principal auth.Principal) context.Context {
	return context.WithValue(ctx, principalKey, principal)
}
func PrincipalFromContext(ctx context.Context) (auth.Principal, bool) {
	value, ok := ctx.Value(principalKey).(auth.Principal)
	return value, ok
}

func DemoPrincipal(header string) (auth.Principal, bool) {
	if header == "" {
		header = role.Viewer
	}
	if !role.Valid(header) {
		return auth.Principal{}, false
	}
	return auth.Principal{Subject: uuid.Nil, Email: "demo@padang.invalid", Name: "Demo Operator", Role: header, Demo: true}, true
}

func RequireRoles(roles ...string) func(http.Handler) http.Handler {
	allowed := make(map[string]struct{}, len(roles))
	for _, value := range roles {
		allowed[value] = struct{}{}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			principal, ok := PrincipalFromContext(r.Context())
			if !ok {
				writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
				return
			}
			if _, ok := allowed[principal.Role]; !ok {
				writeError(w, http.StatusForbidden, "FORBIDDEN", "Insufficient role")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	payload := map[string]any{"error": map[string]string{"code": code, "message": message}}
	if provider, ok := w.(interface{ RequestID() string }); ok && provider.RequestID() != "" {
		payload["meta"] = map[string]string{"request_id": provider.RequestID()}
	}
	_ = json.NewEncoder(w).Encode(payload)
}
