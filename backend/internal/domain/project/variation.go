package project

import "math/big"

type VariationResult struct {
	Cumulative *big.Rat
	Percent    *big.Rat
	Warning    bool
	Blocked    bool
}

func CheckVariation(contractAmount, approvedAdditions *big.Rat) VariationResult {
	if contractAmount.Sign() <= 0 {
		return VariationResult{Cumulative: new(big.Rat).Set(approvedAdditions), Percent: new(big.Rat), Blocked: approvedAdditions.Sign() > 0}
	}
	pct := new(big.Rat).Mul(new(big.Rat).Quo(approvedAdditions, contractAmount), big.NewRat(100, 1))
	return VariationResult{Cumulative: new(big.Rat).Set(approvedAdditions), Percent: pct, Warning: pct.Cmp(big.NewRat(8, 1)) >= 0, Blocked: pct.Cmp(big.NewRat(10, 1)) >= 0}
}
