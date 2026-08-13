package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/itsadventuretime/padang-erp/backend/internal/auth"
	"github.com/itsadventuretime/padang-erp/backend/internal/config"
)

type ActiveUserLookup func(context.Context, uuid.UUID) (auth.Principal, bool)

func Authenticate(env string, tokens *auth.TokenManager, lookup ActiveUserLookup) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if env == config.Demo {
				principal, ok := DemoPrincipal(r.Header.Get("X-Demo-Role"))
				if !ok {
					writeError(w, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid demo role")
					return
				}
				next.ServeHTTP(w, r.WithContext(WithPrincipal(r.Context(), principal)))
				return
			}
			if tokens == nil {
				writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Authentication is not configured")
				return
			}
			header := strings.TrimSpace(r.Header.Get("Authorization"))
			if !strings.HasPrefix(header, "Bearer ") {
				writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Bearer token required")
				return
			}
			principal, err := tokens.ParseAccess(strings.TrimSpace(strings.TrimPrefix(header, "Bearer ")))
			if err != nil {
				writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid access token")
				return
			}
			if lookup == nil {
				writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Authentication is not configured")
				return
			}
			current, ok := lookup(r.Context(), principal.Subject)
			if !ok || !current.Active() {
				writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid access token")
				return
			}
			next.ServeHTTP(w, r.WithContext(WithPrincipal(r.Context(), current)))
		})
	}
}
