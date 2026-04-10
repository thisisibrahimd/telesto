package telemetry

import (
	"log/slog"
	"os"
)

type Logger struct {
	*slog.Logger
}

func (l *Logger) NewSubLogger(name string) *Logger {
	subLogger := &Logger{
		l.With(
			slog.String("name", name),
		),
	}

	return subLogger
}

func NewLogger() *Logger {
	options := &slog.HandlerOptions{
		AddSource:   true,
		Level:       slog.LevelDebug,
		ReplaceAttr: replaceAttr,
	}
	logger := &Logger{slog.New(slog.NewTextHandler(os.Stdout, options))}

	return logger
}
