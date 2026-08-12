package inventory

import (
	"math/big"
	"testing"
)

func TestWeightedAverage(t *testing.T) {
	got := WeightedAverage(big.NewRat(10, 1), big.NewRat(100, 1), big.NewRat(5, 1), big.NewRat(130, 1))
	if got.FloatString(2) != "110.00" {
		t.Fatalf("weighted cost = %s, want 110.00", got.FloatString(2))
	}
}
