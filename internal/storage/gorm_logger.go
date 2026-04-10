package storage

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/thisisibrahimd/telesto/internal/telemetry"
	"gorm.io/gorm/logger"
)

type StorageGormLogger struct {
	*telemetry.Logger
}

func (l *StorageGormLogger) LogMode(level logger.LogLevel) logger.Interface {
	return l.LogMode(level)
}

func (l *StorageGormLogger) Info(ctx context.Context, msg string, data ...interface{}) {
	l.InfoContext(ctx, msg, data...)
}

func (l *StorageGormLogger) Warn(ctx context.Context, msg string, data ...interface{}) {
	l.WarnContext(ctx, msg, data...)
}

func (l *StorageGormLogger) Error(ctx context.Context, msg string, data ...interface{}) {
	l.ErrorContext(ctx, msg, data...)
}

func (l *StorageGormLogger) Trace(ctx context.Context, begin time.Time, fc func() (string, int64), err error) {
	elapsed := time.Since(begin)
	sql, rows := fc()

	traceL := l.With(
		slog.Duration("elapsed", elapsed),
		slog.Int64("rows", rows),
		slog.String("sql", sql),
	)
	if err != nil && !errors.Is(err, logger.ErrRecordNotFound) {
		traceL.ErrorContext(ctx, "SQL Error", slog.Any("error", err))
	} else {
		traceL.DebugContext(ctx, "SQL Trace")
	}
}

func NewStorageGormLogger(l *telemetry.Logger) *StorageGormLogger {
	return &StorageGormLogger{l}
}
