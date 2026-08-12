package billing

import "math/big"

type Inputs struct {
	Gross         *big.Rat
	RetentionRate *big.Rat
	VATRate       *big.Rat
	EWTRate       *big.Rat
}

type Totals struct {
	Gross, Retention, VAT, EWT, Net *big.Rat
}

func Calculate(input Inputs) Totals {
	retention := new(big.Rat).Mul(input.Gross, percent(input.RetentionRate))
	vat := new(big.Rat).Mul(input.Gross, percent(input.VATRate))
	ewt := new(big.Rat).Mul(input.Gross, percent(input.EWTRate))
	net := new(big.Rat).Sub(new(big.Rat).Sub(new(big.Rat).Add(input.Gross, vat), retention), ewt)
	return Totals{Gross: new(big.Rat).Set(input.Gross), Retention: retention, VAT: vat, EWT: ewt, Net: net}
}

func percent(value *big.Rat) *big.Rat { return new(big.Rat).Quo(value, big.NewRat(100, 1)) }
