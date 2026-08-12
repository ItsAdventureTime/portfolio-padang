package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/itsadventuretime/padang-erp/backend/internal/config"
)

func TestHealthAndDemoIdentity(t *testing.T) {
	server := Server{Config: config.Config{AppEnv: config.Demo}}
	router := server.Router()
	health := httptest.NewRecorder()
	router.ServeHTTP(health, httptest.NewRequest(http.MethodGet, "/api/v1/health", nil))
	if health.Code != http.StatusOK {
		t.Fatalf("health status = %d", health.Code)
	}
	if got := health.Header().Get("X-Content-Type-Options"); got != "nosniff" {
		t.Fatalf("content type header = %q", got)
	}

	dashboard := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/api/v1/dashboard/summary", nil)
	request.Header.Set("X-Demo-Role", "general_manager")
	router.ServeHTTP(dashboard, request)
	if dashboard.Code != http.StatusOK {
		t.Fatalf("demo dashboard status = %d", dashboard.Code)
	}

	invalid := httptest.NewRecorder()
	badRole := httptest.NewRequest(http.MethodGet, "/api/v1/dashboard/summary", nil)
	badRole.Header.Set("X-Demo-Role", "not-a-role")
	router.ServeHTTP(invalid, badRole)
	if invalid.Code != http.StatusBadRequest {
		t.Fatalf("invalid role status = %d", invalid.Code)
	}
	if got := invalid.Header().Get("Content-Type"); got != "application/json; charset=utf-8" {
		t.Fatalf("invalid role content type = %q", got)
	}

	spec := httptest.NewRecorder()
	router.ServeHTTP(spec, httptest.NewRequest(http.MethodGet, "/api/v1/openapi.json", nil))
	if spec.Code != http.StatusOK || !strings.Contains(spec.Body.String(), `"openapi":"3.1.0"`) || !strings.Contains(spec.Body.String(), "/api/v1/projects") {
		t.Fatalf("openapi response is incomplete: %s", spec.Body.String())
	}
}
