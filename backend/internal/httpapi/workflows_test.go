package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/itsadventuretime/padang-erp/backend/internal/config"
)

func TestParseMoney(t *testing.T) {
	valid, ok := parseMoney("1245000.25")
	if !ok || ratMoney(valid) != "1245000.2500" {
		t.Fatalf("parseMoney valid = %v, %v", valid, ok)
	}
	if _, ok := parseMoney("-1"); ok {
		t.Fatal("negative money was accepted")
	}
	if _, ok := parseMoney("not-a-number"); ok {
		t.Fatal("invalid money was accepted")
	}
}

func TestDemoWorkflowRoutes(t *testing.T) {
	router := (Server{Config: config.Config{AppEnv: config.Demo}}).Router()
	request := httptest.NewRequest(http.MethodPost, "/api/v1/projects", strings.NewReader(`{"project_code":"PRJ-NEW","project_name":"New demo project","client_id":"00000000-0000-0000-0000-000000000001","contract_amount":"1000"}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Demo-Role", "project_manager")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusCreated {
		t.Fatalf("demo project create status = %d, body = %s", response.Code, response.Body.String())
	}

	for _, path := range []string{"/api/v1/inventory/stock-in", "/api/v1/billing/progress"} {
		request := httptest.NewRequest(http.MethodPost, path, strings.NewReader(`{}`))
		request.Header.Set("Content-Type", "application/json")
		request.Header.Set("X-Demo-Role", "viewer")
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
		if response.Code != http.StatusForbidden {
			t.Fatalf("viewer mutation %s status = %d", path, response.Code)
		}
	}
}
