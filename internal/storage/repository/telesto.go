package repository

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/query"
	"gorm.io/gen"
	"gorm.io/gorm"
)

type TelestoRepo struct {
	db *gorm.DB
}

var _ RepoByUser[model.Telesto] = (*TelestoRepo)(nil)

func (r *TelestoRepo) query() *query.Query {
	return query.Use(r.db)
}

func (r *TelestoRepo) ByUser(id string) Repo[model.Telesto] {
	return NewTelestoRepo(r.db.Scopes(func(d *gorm.DB) *gorm.DB {
		return d.Where("user_id = ?", id)
	}))
}

func (r *TelestoRepo) GetAll(ctx context.Context) ([]*model.Telesto, error) {
	return r.query().
		Telesto.WithContext(ctx).
		Preload(r.query().Telesto.Tokens).
		Find()
}

func (r *TelestoRepo) Get(ctx context.Context, id string) (*model.Telesto, error) {
	return r.query().
		Telesto.WithContext(ctx).
		Where(r.query().Telesto.ID.Eq(id)).
		Preload(r.query().Telesto.Tokens).
		First()
}

func (r *TelestoRepo) New(ctx context.Context, otelcol *model.Telesto) error {
	return r.query().
		Telesto.WithContext(ctx).
		Create(otelcol)
}

func (r *TelestoRepo) Edit(ctx context.Context, id string, otelcol *model.Telesto) (gen.ResultInfo, error) {
	return r.query().
		Telesto.WithContext(ctx).
		Where(r.query().Telesto.ID.Eq(id)).
		Preload(r.query().Telesto.Tokens).
		Updates(otelcol)
}

func (r *TelestoRepo) Delete(ctx context.Context, id string) (gen.ResultInfo, error) {
	return r.query().
		Telesto.WithContext(ctx).
		Where(r.query().Telesto.ID.Eq(id)).
		Preload(r.query().Telesto.Tokens).
		Delete()
}

func NewTelestoRepo(db *gorm.DB) RepoByUser[model.Telesto] {
	return &TelestoRepo{db: db}
}
