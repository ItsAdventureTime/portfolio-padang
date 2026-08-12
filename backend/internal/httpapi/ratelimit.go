package httpapi

import (
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

// RateLimiter is intentionally process-local. The production deployment runs
// one API replica; a shared limiter can be introduced when that changes.
type RateLimiter struct {
	mu      sync.Mutex
	entries map[string][]time.Time
}

func NewRateLimiter() *RateLimiter {
	return &RateLimiter{entries: make(map[string][]time.Time)}
}

func (l *RateLimiter) Allow(key string, limit int, window time.Duration, now time.Time) (bool, time.Duration) {
	if l == nil || limit <= 0 || window <= 0 {
		return true, 0
	}
	now = now.UTC()
	cutoff := now.Add(-window)

	l.mu.Lock()
	defer l.mu.Unlock()
	events := l.entries[key][:0]
	for _, event := range l.entries[key] {
		if event.After(cutoff) {
			events = append(events, event)
		}
	}
	if len(events) >= limit {
		l.entries[key] = events
		return false, events[0].Add(window).Sub(now)
	}
	l.entries[key] = append(events, now)
	return true, 0
}

func clientKey(r *http.Request) string {
	remote := strings.TrimSpace(r.RemoteAddr)
	if remote == "" {
		return "unknown"
	}
	return remote
}

func rateLimited(w http.ResponseWriter, retryAfter time.Duration) {
	seconds := int(retryAfter.Seconds())
	if seconds < 1 {
		seconds = 1
	}
	w.Header().Set("Retry-After", strconv.Itoa(seconds))
	Error(w, http.StatusTooManyRequests, "RATE_LIMITED", "Too many authentication attempts")
}
