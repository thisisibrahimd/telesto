package storage

import (
	"log/slog"

	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/repository"
	"github.com/thisisibrahimd/telesto/internal/telemetry"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type DBType string

var DB_TYPE_POSTGRES string = "postgres"

type Config struct {
	Migrate    bool
	Type       string
	DSN        string
	Logger     *StorageLogger
	GormLogger *StorageGormLogger
}

func DefaultConfig() *Config {
	return &Config{
		Migrate:    false,
		Logger:     NewStorageLogger(telemetry.NewLogger()),
		GormLogger: NewStorageGormLogger(telemetry.NewLogger()),
	}
}

type Storage struct {
	config *Config
	db     *gorm.DB
	Repos  struct {
		Telesto repository.RepoByUser[model.Telesto]
		Token   repository.RepoByUserAndTelesto[model.Token]
	}
}

func (s *Storage) Migrate() error {
	err := s.db.AutoMigrate(&model.Telesto{}, &model.Token{})
	if err != nil {
		return xerrors.New("automigration failed", err)
	}

	return nil
}

func (s *Storage) Wipe() error {
	err := s.db.Migrator().DropTable(&model.Telesto{}, &model.Token{})
	if err != nil {
		return xerrors.New("dropping of tables failed", err)
	}

	return nil
}

func (s *Storage) EnsureDBReady() error {
	if s.config.Migrate {
		err := s.Migrate()
		if err != nil {
			return xerrors.New("failed to ensure db is ready", err)
		}
	}

	return nil
}

func NewStorage(cfg *Config) (*Storage, error) {
	sto := &Storage{
		config: cfg,
	}

	var db *gorm.DB
	var err error
	switch sto.config.Type {
	case DB_TYPE_POSTGRES:
		db, err = gorm.Open(postgres.Open(sto.config.DSN), &gorm.Config{
			Logger: sto.config.GormLogger,
		})
	default:
		err = xerrors.New("unsupported db")
	}

	if err != nil {
		slog.Error("unable to connect to db", slog.Any("error", err))
	}

	sto.db = db

	// init repos
	sto.Repos.Telesto = repository.NewTelestoRepo(sto.db)
	sto.Repos.Token = repository.NewTokenRepo(sto.db)

	err = sto.EnsureDBReady()
	if err != nil {
		return nil, xerrors.New("failed to setup database", err)
	}

	return sto, nil
}
