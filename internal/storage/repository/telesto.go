package repository

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/model"
)

type TelestoRepo interface {
	GetTelestos(ctx context.Context) ([]*model.Telesto, error)
	GetTelesto(ctx context.Context, id string) (*model.Telesto, error)
	CreateTelesto(ctx context.Context, telesto *model.Telesto) error
	UpdateTelesto(ctx context.Context, id string, telesto *model.Telesto) error
	DeleteTelesto(ctx context.Context, id string) error
}
