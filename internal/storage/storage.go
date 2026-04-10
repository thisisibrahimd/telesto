package storage

import (
	"log/slog"

	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/query"
	"github.com/thisisibrahimd/telesto/internal/telemetry"
	"goki.dev/rqlite"
	"gorm.io/gorm"
)

type Config struct {
	Migrate    bool
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
	query  *query.Query
	db     *gorm.DB
}

func (s *Storage) Migrate() error {
	err := s.db.AutoMigrate(&model.Otelcol{})
	if err != nil {
		return xerrors.New("automigration failed", err)
	}

	return nil
}

func (s *Storage) Wipe() error {
	err := s.db.Migrator().DropTable(&model.Otelcol{})
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

	db, err := gorm.Open(rqlite.Open(sto.config.DSN), &gorm.Config{
		Logger: sto.config.GormLogger,
	})
	if err != nil {
		slog.Error("unable to connect to db", slog.Any("error", err))
	}

	sto.db = db
	sto.query = query.Use(db)

	err = sto.EnsureDBReady()
	if err != nil {
		return nil, xerrors.New("failed to setup database", err)
	}

	return sto, nil
}
