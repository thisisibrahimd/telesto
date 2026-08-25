package telemetry

import (
	"log/slog"
	"os"

	"go.uber.org/fx/fxevent"
)

type FormatType string

var (
	FORMAT_JSON FormatType = "json"
	FORMAT_TEXT FormatType = "text"
)

type LoggingConfig struct {
	Debug  bool       `json:"debug,omitempty" default:"false"`
	Format FormatType `json:"format,omitempty" default:"text" jsonschema:"enum=text,enum=json" validate:"required,oneof=text json"`
}

type Logger struct {
	*slog.Logger
}

func (l *Logger) LogEvent(ev fxevent.Event) {
	switch evType := ev.(type) {
	default:
		l.Debug("fxevent", slog.Any("asdf", evType))
	}
}

func (l *Logger) NewSubLogger(name string) *Logger {
	subLogger := &Logger{
		l.With(
			slog.String("name", name),
		),
	}

	return subLogger
}

type DebugLeveler struct {
	debug bool
}

func (l *DebugLeveler) Level() slog.Level {
	if l.debug {
		return slog.LevelDebug
	}
	return slog.LevelInfo
}

func NewLogger(cfg LoggingConfig) *Logger {
	options := &slog.HandlerOptions{
		AddSource: false,
		// ReplaceAttr: replaceAttr,
	}

	// set slog leveler based on debug flag in cfg
	debugLeveler := &DebugLeveler{debug: cfg.Debug}
	options.Level = debugLeveler

	// create slog handler
	var handler slog.Handler
	switch cfg.Format {
	case FORMAT_JSON:
		handler = slog.NewJSONHandler(os.Stdout, options)
	case FORMAT_TEXT:
		handler = slog.NewTextHandler(os.Stdout, options)
	default:
		panic("unsupported log format")
	}

	logger := &Logger{slog.New(handler)}
	return logger
}
