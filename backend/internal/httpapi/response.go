package httpapi

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5/middleware"
)

type requestIDWriter struct {
	http.ResponseWriter
	id string
}

func (w requestIDWriter) RequestID() string { return w.id }

func requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := middlewareRequestID(r)
		next.ServeHTTP(requestIDWriter{ResponseWriter: w, id: id}, r)
	})
}

func middlewareRequestID(r *http.Request) string {
	if id := middleware.GetReqID(r.Context()); id != "" {
		return id
	}
	if id := r.Header.Get("X-Request-ID"); id != "" {
		return id
	}
	return ""
}

func responseMeta(w http.ResponseWriter) map[string]any {
	meta := map[string]any{}
	if provider, ok := w.(interface{ RequestID() string }); ok && provider.RequestID() != "" {
		meta["request_id"] = provider.RequestID()
	}
	return meta
}

func addResponseMeta(w http.ResponseWriter, value any) any {
	meta := responseMeta(w)
	if len(meta) == 0 {
		return value
	}
	if object, ok := value.(map[string]any); ok {
		merged := map[string]any{}
		for key, item := range object {
			merged[key] = item
		}
		if existing, ok := object["meta"].(map[string]any); ok {
			for key, item := range existing {
				meta[key] = item
			}
		}
		if existing, ok := object["meta"].(map[string]int); ok {
			for key, item := range existing {
				meta[key] = item
			}
		}
		merged["meta"] = meta
		return merged
	}
	return value
}

func JSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(addResponseMeta(w, value))
}
func Error(w http.ResponseWriter, status int, code, message string) {
	JSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": message}})
}
func Decode(r *http.Request, destination any) error {
	decoder := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	return decoder.Decode(destination)
}
