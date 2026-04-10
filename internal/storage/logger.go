package storage

import (
	"github.com/thisisibrahimd/telesto/internal/telemetry"
)

type StorageLogger struct {
	*telemetry.Logger
}

func NewStorageLogger(l *telemetry.Logger) *StorageLogger {
	return &StorageLogger{l}
}
