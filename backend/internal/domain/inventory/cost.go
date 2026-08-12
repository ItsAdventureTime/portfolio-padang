package inventory

import "math/big"

func WeightedAverage(existingQty, existingCost, receivedQty, receivedCost *big.Rat) *big.Rat {
	denominator := new(big.Rat).Add(existingQty, receivedQty)
	if denominator.Sign() == 0 {
		return new(big.Rat)
	}
	numerator := new(big.Rat).Add(new(big.Rat).Mul(existingQty, existingCost), new(big.Rat).Mul(receivedQty, receivedCost))
	return new(big.Rat).Quo(numerator, denominator)
}
