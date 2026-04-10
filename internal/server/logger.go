package server

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"github.com/thisisibrahimd/telesto/internal/telemetry"
)

type Logger struct {
	*telemetry.Logger
}

func (l *Logger) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)

		start := time.Now()
		defer func() {
			l.Info("HTTP Request",
				slog.String("method", r.Method),
				slog.String("path", r.URL.Path),
				slog.String("ip", r.RemoteAddr),
				slog.Int("status", ww.Status()),
				slog.Int("bytes", ww.BytesWritten()),
				slog.Duration("elasped", time.Since(start)),
			)

		}()

		next.ServeHTTP(ww, r)
	})
}

func NewServerLogger(l *telemetry.Logger) *Logger {
	return &Logger{l}
}
