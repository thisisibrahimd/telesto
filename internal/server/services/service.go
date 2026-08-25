package services

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/storage"
)

type Service[T any] interface {
	GetAll(ctx context.Context) ([]*T, error)
	Get(ctx context.Context, id string) (*T, error)
	Create(ctx context.Context, entity *T) error
	Update(ctx context.Context, id string, entity *T) error
	Delete(ctx context.Context, id string) error
}

type ServiceByUser[T any] interface {
	ByUser(string) Service[T]
}

type ServiceByTelesto[T any] interface {
	ByTelesto(string) Service[T]
}

type ServicesConfig struct {
	Storage *storage.Storage
}

type Services struct {
	Telesto ITelestoService
	Token   ITokenService
	Argo    IArgoService
}

func NewServices(sto *storage.Storage) *Services {
	telestoService := newTelestoService(sto.Repos.Telesto)
	tokenService := newTokenService(sto.Repos.Token)
	argoService := newArgoService(sto.Repos.Telesto)

	return &Services{
		Telesto: telestoService,
		Token:   tokenService,
		Argo:    argoService,
	}
}

type (
	ServiceGetAllFunc[Out any] func(context.Context) ([]*Out, error)
	ServiceGetFunc[Out any]    func(context.Context, string) (*Out, error)
	ServiceCreateFunc[In any]  func(context.Context, *In) error
	ServiceUpdateFunc[In any]  func(context.Context, string, *In) error
	ServiceDeleteFunc          func(context.Context, string) error
)
