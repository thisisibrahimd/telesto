package storage

// Storage configuration for the database connection and settings
type StorageConfig struct {
	DSN     string `mapstructure:"dsn" json:"dsn" validate:"required"`
	Migrate bool   `mapstructure:"migrate" json:"migrate,omitempty" default:"true"`
}
