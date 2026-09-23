package storage

import (
	"context"

	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/model"
	"github.com/thisisibrahimd/telesto/internal/storage/query"
	"github.com/thisisibrahimd/telesto/internal/storage/repository"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type Storage struct {
	l  *Logger
	db *gorm.DB
}

var (
	_ repository.ForUserRepo[Storage]    = (*Storage)(nil)
	_ repository.ForTelestoRepo[Storage] = (*Storage)(nil)
	_ repository.TelestoRepo             = (*Storage)(nil)
	_ repository.TokenRepo               = (*Storage)(nil)
)

func (s *Storage) query() *query.Query {
	return query.Use(s.db)
}

func (s *Storage) ForUser(id string) *Storage {
	userStorage := &Storage{
		l:  s.l,
		db: s.db.Scopes(func(d *gorm.DB) *gorm.DB { return d.Where("user_id = ?", id) }),
	}
	return userStorage
}

func (s *Storage) ForTelesto(id string) *Storage {
	telestoStorage := &Storage{
		l:  s.l,
		db: s.db.Scopes(func(d *gorm.DB) *gorm.DB { return d.Where("telesto_id = ?", id) }),
	}
	return telestoStorage
}

func (s *Storage) GetTelestos(ctx context.Context) ([]*model.Telesto, error) {
	return s.query().
		Telesto.WithContext(ctx).
		Preload(s.query().Telesto.Tokens).
		Find()
}

func (s *Storage) GetTelesto(ctx context.Context, id string) (*model.Telesto, error) {
	return s.query().
		Telesto.WithContext(ctx).
		Where(s.query().Telesto.ID.Eq(id)).
		Preload(s.query().Telesto.Tokens).
		First()
}

func (s *Storage) CreateTelesto(ctx context.Context, telesto *model.Telesto) error {
	return s.query().
		Telesto.WithContext(ctx).
		Create(telesto)
}

func (s *Storage) UpdateTelesto(ctx context.Context, id string, telesto *model.Telesto) error {
	_, err := s.query().
		Telesto.WithContext(ctx).
		Where(s.query().Telesto.ID.Eq(id)).
		Preload(s.query().Telesto.Tokens).
		Updates(telesto)
	return err
}

func (s *Storage) DeleteTelesto(ctx context.Context, id string) error {
	_, err := s.query().
		Telesto.WithContext(ctx).
		Where(s.query().Telesto.ID.Eq(id)).
		Preload(s.query().Telesto.Tokens).
		Delete()
	return err
}

func (s *Storage) GetTokens(ctx context.Context) ([]*model.Token, error) {
	return s.query().
		Token.WithContext(ctx).
		Preload(s.query().Token.Telesto).
		Find()
}

func (s *Storage) GetToken(ctx context.Context, id string) (*model.Token, error) {
	return s.query().
		Token.WithContext(ctx).
		Where(s.query().Token.ID.Eq(id)).
		Preload(s.query().Token.Telesto).
		First()
}

func (s *Storage) CreateToken(ctx context.Context, otelcol *model.Token) error {
	return s.query().
		Token.WithContext(ctx).
		Create(otelcol)
}

func (s *Storage) UpdateToken(ctx context.Context, id string, token *model.Token) error {
	_, err := s.query().
		Token.WithContext(ctx).
		Where(s.query().Token.ID.Eq(id)).
		Updates(token)
	return err
}

func (s *Storage) MarkTokenSeen(ctx context.Context, id string) error {
	_, err := s.query().
		Token.WithContext(ctx).
		Where(s.query().Token.ID.Eq(id)).
		Update(s.query().Token.Seen, true)
	return err
}

func (s *Storage) DeleteToken(ctx context.Context, id string) error {
	_, err := s.query().
		Token.WithContext(ctx).
		Where(s.query().Token.ID.Eq(id)).
		Delete()
	return err
}

func NewStorage(cfg *StorageConfig, logger *Logger, gormLogger *GormLogger) *Storage {
	sto := &Storage{l: logger}

	// create db
	db, err := gorm.Open(postgres.Open(cfg.DSN), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		panic(xerrors.New("unable to connect to db", err))
	}

	// migrate
	if cfg.Migrate {
		if err := db.AutoMigrate(
			&model.Telesto{},
			&model.Token{},
		); err != nil {
			panic(xerrors.New("error performing automigration of db", err))
		}
	}

	// init repos
	sto.db = db

	return sto
}
