package repository

import (
	"context"

	"gorm.io/gen"
)

type Repo[T any] interface {
	GetAll(ctx context.Context) ([]*T, error)
	Get(ctx context.Context, id string) (*T, error)
	New(ctx context.Context, entity *T) error
	Edit(ctx context.Context, id string, entity *T) (gen.ResultInfo, error)
	Delete(ctx context.Context, id string) (gen.ResultInfo, error)
}

type RepoByUser[T any] interface {
	ByUser(id string) Repo[T]
}

type RepoByTelesto[T any] interface {
	ByTelesto(id string) Repo[T]
}
