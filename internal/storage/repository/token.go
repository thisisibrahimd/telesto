package repository

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/query"
	"gorm.io/gen"
	"gorm.io/gorm"
)

type TokenRepo struct {
	RepoByUser[model.Token]
	RepoByTelesto[model.Token]
	db *gorm.DB
}

var (
	_ RepoByTelesto[model.Token] = (*TokenRepo)(nil)
	_ RepoByUser[model.Token]    = (*TokenRepo)(nil)
)

func (r *TokenRepo) query() *query.Query {
	return query.Use(r.db)
}

func (r *TokenRepo) ByTelesto(id string) Repo[model.Token] {
	return NewTokenRepo(r.db.Scopes(func(d *gorm.DB) *gorm.DB {
		return d.Where("telesto_id = ?", id)
	}))
}

func (r *TokenRepo) ByUser(id string) Repo[model.Token] {
	return NewTokenRepo(r.db.Scopes(func(d *gorm.DB) *gorm.DB {
		return d.Where("user_id = ?", id)
	}))
}

func (r *TokenRepo) GetAll(ctx context.Context) ([]*model.Token, error) {
	return r.query().
		Token.WithContext(ctx).
		Preload(r.query().Token.Telesto).
		Find()
}

func (r *TokenRepo) Get(ctx context.Context, id string) (*model.Token, error) {
	return r.query().
		Token.WithContext(ctx).
		Where(r.query().Token.ID.Eq(id)).
		Preload(r.query().Token.Telesto).
		First()
}

func (r *TokenRepo) New(ctx context.Context, otelcol *model.Token) error {
	return r.query().
		Token.WithContext(ctx).
		Create(otelcol)
}

func (r *TokenRepo) Edit(ctx context.Context, id string, otelcol *model.Token) (gen.ResultInfo, error) {
	return r.query().
		Token.WithContext(ctx).
		Where(r.query().Token.ID.Eq(id)).
		Preload(r.query().Token.Telesto).
		Updates(otelcol)
}

func (r *TokenRepo) MarkTokenSeen(ctx context.Context, id string) (gen.ResultInfo, error) {
	return r.query().
		Token.WithContext(ctx).
		Where(r.query().Token.ID.Eq(id)).
		UpdateColumn(r.query().Token.Seen, true)
}

func (r *TokenRepo) Delete(ctx context.Context, id string) (gen.ResultInfo, error) {
	return r.query().
		Token.WithContext(ctx).
		Where(r.query().Token.ID.Eq(id)).
		Delete()
}

func NewTokenRepo(db *gorm.DB) RepoByUserAndTelesto[model.Token] {
	return &TokenRepo{db: db}
}
