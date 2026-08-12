package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/itsadventuretime/padang-erp/backend/internal/auth"
	"github.com/itsadventuretime/padang-erp/backend/internal/config"
	"github.com/itsadventuretime/padang-erp/backend/internal/email"
	"github.com/itsadventuretime/padang-erp/backend/internal/httpapi"
	"github.com/itsadventuretime/padang-erp/backend/internal/repository"
	"github.com/itsadventuretime/padang-erp/backend/internal/storage"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	var pool *pgxpool.Pool
	if cfg.DatabaseURL != "" {
		pool, err = pgxpool.New(ctx, cfg.DatabaseURL)
		if err != nil {
			logger.Error("database pool initialization failed", "error", err)
			os.Exit(1)
		}
		defer pool.Close()
	}
	var tokens *auth.TokenManager
	if cfg.AppEnv == config.Production {
		tokens, err = auth.NewTokenManager(cfg.JWTPrivateKeyPath, cfg.JWTPublicKeyPath, cfg.JWTIssuer)
		if err != nil {
			logger.Error("JWT key initialization failed", "error", err)
			os.Exit(1)
		}
	}
	var authService *auth.Service
	if pool != nil && tokens != nil {
		var sender email.Sender = email.LogSender{Logger: logger}
		if cfg.EmailProvider == "resend" {
			if cfg.ResendAPIKey == "" {
				logger.Error("resend provider selected without a Podman secret")
				os.Exit(1)
			}
			sender = email.NewResendSender(cfg.ResendAPIKey, cfg.EmailFrom)
		}
		authService = &auth.Service{Store: repository.AuthStore{Pool: pool}, Tokens: tokens, Email: sender, From: cfg.EmailFrom}
	}
	b2Storage, err := storage.NewB2Service(ctx, cfg)
	if err != nil {
		logger.Error("B2 storage initialization failed", "error", err)
		os.Exit(1)
	}
	if cfg.AppEnv == config.Production && !b2Storage.Configured {
		logger.Error("production B2 storage requires Podman secrets")
		os.Exit(1)
	}
	server := &http.Server{Addr: cfg.HTTPAddr, Handler: (httpapi.Server{Config: cfg, Pool: pool, Auth: authService, Tokens: tokens, Storage: b2Storage}).Router(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 15 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 60 * time.Second}
	go func() {
		logger.Info("api listening", "addr", cfg.HTTPAddr, "environment", cfg.AppEnv)
		if serveErr := server.ListenAndServe(); serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
			logger.Error("api stopped unexpectedly", "error", serveErr)
			stop()
		}
	}()
	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = server.Shutdown(shutdownCtx)
}
