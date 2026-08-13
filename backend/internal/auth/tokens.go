package auth

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Principal struct {
	Subject           uuid.UUID
	Email, Name, Role string
	Demo              bool
}

func (p Principal) Active() bool {
	return p.Subject != uuid.Nil && p.Role != ""
}

type TokenManager struct {
	private               *rsa.PrivateKey
	public                *rsa.PublicKey
	issuer                string
	accessTTL, refreshTTL time.Duration
}

func NewTokenManager(privatePath, publicPath, issuer string) (*TokenManager, error) {
	privateBytes, err := os.ReadFile(privatePath)
	if err != nil {
		return nil, err
	}
	publicBytes, err := os.ReadFile(publicPath)
	if err != nil {
		return nil, err
	}
	private, err := parsePrivate(privateBytes)
	if err != nil {
		return nil, err
	}
	public, err := parsePublic(publicBytes)
	if err != nil {
		return nil, err
	}
	return &TokenManager{private: private, public: public, issuer: issuer, accessTTL: 15 * time.Minute, refreshTTL: 7 * 24 * time.Hour}, nil
}

func NewTestTokenManager(private *rsa.PrivateKey, issuer string) *TokenManager {
	return &TokenManager{private: private, public: &private.PublicKey, issuer: issuer, accessTTL: 15 * time.Minute, refreshTTL: 7 * 24 * time.Hour}
}

func (m *TokenManager) Access(p Principal, now time.Time) (string, error) {
	claims := jwt.MapClaims{"sub": p.Subject.String(), "email": p.Email, "name": p.Name, "role": p.Role, "iss": m.issuer, "iat": now.Unix(), "exp": now.Add(m.accessTTL).Unix()}
	return jwt.NewWithClaims(jwt.SigningMethodRS256, claims).SignedString(m.private)
}

func (m *TokenManager) ParseAccess(raw string) (Principal, error) {
	token, err := jwt.Parse(raw, func(token *jwt.Token) (any, error) {
		if token.Method != jwt.SigningMethodRS256 {
			return nil, errors.New("unexpected signing method")
		}
		return m.public, nil
	}, jwt.WithIssuer(m.issuer))
	if err != nil || !token.Valid {
		return Principal{}, errors.New("invalid access token")
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return Principal{}, errors.New("invalid token claims")
	}
	sub, ok := claims["sub"].(string)
	if !ok {
		return Principal{}, errors.New("missing subject")
	}
	id, err := uuid.Parse(sub)
	if err != nil {
		return Principal{}, errors.New("invalid subject")
	}
	role, _ := claims["role"].(string)
	email, _ := claims["email"].(string)
	name, _ := claims["name"].(string)
	return Principal{Subject: id, Email: email, Name: name, Role: role}, nil
}

func (m *TokenManager) RefreshTTL() time.Duration { return m.refreshTTL }

func parsePrivate(raw []byte) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode(raw)
	if block == nil {
		return nil, errors.New("private key is not PEM")
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err == nil {
		if rsaKey, ok := key.(*rsa.PrivateKey); ok {
			return rsaKey, nil
		}
	}
	if rsaKey, pkcs1Err := x509.ParsePKCS1PrivateKey(block.Bytes); pkcs1Err == nil {
		return rsaKey, nil
	}
	return nil, errors.New("private key is not RSA")
}
func parsePublic(raw []byte) (*rsa.PublicKey, error) {
	block, _ := pem.Decode(raw)
	if block == nil {
		return nil, errors.New("public key is not PEM")
	}
	key, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err == nil {
		if rsaKey, ok := key.(*rsa.PublicKey); ok {
			return rsaKey, nil
		}
	}
	if rsaKey, pkcs1Err := x509.ParsePKCS1PublicKey(block.Bytes); pkcs1Err == nil {
		return rsaKey, nil
	}
	return nil, errors.New("public key is not RSA")
}
