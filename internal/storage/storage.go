package storage

import (
	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/repository"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type Storage struct {
	l     *Logger
	db    *gorm.DB
	Repos struct {
		Telesto repository.ITelestoRepo
		Token   repository.ITokenRepo
	}
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
	sto.Repos.Telesto = repository.NewTelestoRepo(sto.db)
	sto.Repos.Token = repository.NewTokenRepo(sto.db)

	return sto
}
