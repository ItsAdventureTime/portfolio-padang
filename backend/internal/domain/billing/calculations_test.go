package billing

import (
	"math/big"
	"testing"
)

func TestCalculateProgressBilling(t *testing.T) {
	totals := Calculate(Inputs{
		Gross: big.NewRat(100000, 1), RetentionRate: big.NewRat(10, 1),
		VATRate: big.NewRat(12, 1), EWTRate: big.NewRat(2, 1),
	})
	if got := totals.Net.FloatString(2); got != "100000.00" {
		t.Fatalf("net = %s, want 100000.00", got)
	}
	if got := totals.Retention.FloatString(2); got != "10000.00" {
		t.Fatalf("retention = %s, want 10000.00", got)
	}
}
