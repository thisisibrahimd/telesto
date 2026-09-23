package services

import (
	"github.com/thisisibrahimd/telesto/internal/storage"
)

type Services struct {
	Telesto *TelestoService
	Token   *TokenService
}

func NewServices(sto *storage.Storage) *Services {
	telestoService := newTelestoService(sto)
	tokenService := newTokenService(sto)

	return &Services{
		Telesto: telestoService,
		Token:   tokenService,
	}
}
