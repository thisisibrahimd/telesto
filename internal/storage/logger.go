package storage

import (
	"github.com/thisisibrahimd/telesto/internal/telemetry"
)

type Logger struct {
	*telemetry.Logger
}

func NewLogger(l *telemetry.Logger) *Logger {
	return &Logger{l.NewSubLogger("storage")}
}
