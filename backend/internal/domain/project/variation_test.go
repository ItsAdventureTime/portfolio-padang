package project

import (
	"math/big"
	"testing"
)

func TestVariationCap(t *testing.T) {
	warning := CheckVariation(big.NewRat(100, 1), big.NewRat(8, 1))
	if !warning.Warning || warning.Blocked {
		t.Fatalf("8%% variation should warn only")
	}
	blocked := CheckVariation(big.NewRat(100, 1), big.NewRat(11, 1))
	if !blocked.Blocked {
		t.Fatalf("variation above 10%% should block")
	}
	exact := CheckVariation(big.NewRat(100, 1), big.NewRat(10, 1))
	if !exact.Warning || !exact.Blocked {
		t.Fatalf("variation at exactly 10%% should warn and block")
	}
}
