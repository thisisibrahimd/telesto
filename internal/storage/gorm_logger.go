package storage

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/thisisibrahimd/telesto/internal/telemetry"
	"gorm.io/gorm/logger"
)

type GormLogger struct {
	*telemetry.Logger
}

func (l *GormLogger) LogMode(level logger.LogLevel) logger.Interface {
	return l.LogMode(level)
}

func (l *GormLogger) Info(ctx context.Context, msg string, data ...interface{}) {
	l.InfoContext(ctx, msg, data...)
}

func (l *GormLogger) Warn(ctx context.Context, msg string, data ...interface{}) {
	l.WarnContext(ctx, msg, data...)
}

func (l *GormLogger) Error(ctx context.Context, msg string, data ...interface{}) {
	l.ErrorContext(ctx, msg, data...)
}

func (l *GormLogger) Trace(ctx context.Context, begin time.Time, fc func() (string, int64), err error) {
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

func NewGormLogger(l *telemetry.Logger) *GormLogger {
	return &GormLogger{l.NewSubLogger("gorm")}
}
