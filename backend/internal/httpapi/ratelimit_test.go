package httpapi

import (
	"testing"
	"time"
)

func TestRateLimiterWindow(t *testing.T) {
	limiter := NewRateLimiter()
	now := time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC)
	for i := 0; i < 3; i++ {
		allowed, _ := limiter.Allow("ip|email", 3, 15*time.Minute, now)
		if !allowed {
			t.Fatalf("request %d unexpectedly rejected", i+1)
		}
	}
	if allowed, retry := limiter.Allow("ip|email", 3, 15*time.Minute, now); allowed || retry <= 0 {
		t.Fatalf("fourth request should be rejected with retry duration, allowed=%v retry=%s", allowed, retry)
	}
	if allowed, _ := limiter.Allow("ip|email", 3, 15*time.Minute, now.Add(16*time.Minute)); !allowed {
		t.Fatal("request after the window should be accepted")
	}
}
