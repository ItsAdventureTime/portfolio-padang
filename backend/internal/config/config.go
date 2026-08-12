package config

import (
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

const (
	Demo       = "demo"
	Production = "production"
)

type Config struct {
	AppEnv            string
	RunMode           string
	HTTPAddr          string
	DatabaseURL       string
	JWTIssuer         string
	JWTPrivateKeyPath string
	JWTPublicKeyPath  string
	EmailProvider     string
	EmailFrom         string
	ResendAPIKey      string
	B2Endpoint        string
	B2Bucket          string
	B2Prefix          string
	B2KeyID           string
	B2ApplicationKey  string
	DemoResetDatabase string
}

func Load() (Config, error) {
	emailProvider := strings.TrimSpace(os.Getenv("EMAIL_PROVIDER"))
	if emailProvider == "" {
		emailProvider = "resend"
		if strings.TrimSpace(os.Getenv("APP_ENV")) == Demo {
			emailProvider = "log"
		}
	}
	cfg := Config{
		AppEnv:            envOr("APP_ENV", Production),
		RunMode:           envOr("RUN_MODE", "api"),
		HTTPAddr:          envOr("HTTP_ADDR", ":8080"),
		DatabaseURL:       os.Getenv("DATABASE_URL"),
		JWTIssuer:         envOr("JWT_ISSUER", "padang-erp"),
		JWTPrivateKeyPath: envOr("JWT_PRIVATE_KEY_PATH", "/run/secrets/jwt-private-key"),
		JWTPublicKeyPath:  envOr("JWT_PUBLIC_KEY_PATH", "/run/secrets/jwt-public-key"),
		EmailProvider:     emailProvider,
		EmailFrom:         envOr("EMAIL_FROM", "Padang ERP <noreply@example.invalid>"),
		ResendAPIKey:      secretOrEnv("resend-api-key", "RESEND_API_KEY"),
		B2Endpoint:        envOr("B2_ENDPOINT", "https://s3.us-west-001.backblazeb2.com"),
		B2Bucket:          envOr("B2_BUCKET", "bridge-ph"),
		B2Prefix:          envOr("B2_PREFIX", "padang/"),
		B2KeyID:           secretOrEnv("b2-key-id", "B2_KEY_ID"),
		B2ApplicationKey:  secretOrEnv("b2-application-key", "B2_APPLICATION_KEY"),
		DemoResetDatabase: envOr("DEMO_RESET_DATABASE", "padang_demo"),
	}
	if cfg.DatabaseURL == "" && os.Getenv("DB_HOST") != "" {
		password := secretOrEnv("db-password", "DB_PASSWORD")
		cfg.DatabaseURL = "postgres://" + url.QueryEscape(os.Getenv("DB_USER")) + ":" + url.QueryEscape(password) + "@" + os.Getenv("DB_HOST") + ":" + envOr("DB_PORT", "5432") + "/" + os.Getenv("DB_NAME") + "?sslmode=disable"
	}
	if cfg.AppEnv != Demo && cfg.AppEnv != Production {
		return Config{}, fmt.Errorf("APP_ENV must be %q or %q", Demo, Production)
	}
	if cfg.AppEnv == Demo && cfg.DemoResetDatabase != "padang_demo" {
		return Config{}, errors.New("demo reset database must be padang_demo")
	}
	return cfg, nil
}

func envOr(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func secretOrEnv(name, envName string) string {
	path := filepath.Join("/run/secrets", name)
	if value, err := os.ReadFile(path); err == nil {
		return strings.TrimSpace(string(value))
	}
	return strings.TrimSpace(os.Getenv(envName))
}
