package web

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

type WebServerInterface interface {
	// /
	Index(w http.ResponseWriter, r *http.Request)
	// GET /login
	Login(w http.ResponseWriter, r *http.Request)
	// GET /register
	Register(w http.ResponseWriter, r *http.Request)
	// GET /logout
	Logout(w http.ResponseWriter, r *http.Request)

	// OTELCOL RESOURCE
	// GET /otelcols
	ListOtelcols(w http.ResponseWriter, r *http.Request)
	// GET /otelcols/{id}
	GetOtelcol(w http.ResponseWriter, r *http.Request)
	// GET /otelcols/new
	CreateOtelcol(w http.ResponseWriter, r *http.Request)
	// POST /otelcols/new
	CreateOtelcolExec(w http.ResponseWriter, r *http.Request)
	// GET /otelcols/edit/{id}
	UpdateOtelcol(w http.ResponseWriter, r *http.Request)
	// PUT /otelcols/edit/{id}
	UpdateOtelcolExec(w http.ResponseWriter, r *http.Request)
	// DELETE /otelcols/{id}
	DeleteOtelcol(w http.ResponseWriter, r *http.Request)
}

func Handler(r chi.Router, protected func(http.Handler) http.Handler, w WebServerInterface) {

	r.Get("/", http.HandlerFunc(w.Index))
	r.Get("/login", http.HandlerFunc(w.Login))
	r.Get("/register", http.HandlerFunc(w.Register))

	// protect routes
	r.Group(func(r chi.Router) {
		r.Use(protected)
		r.Get("/logout", http.HandlerFunc(w.Logout))
		r.Get("/otelcols", http.HandlerFunc(w.ListOtelcols))
		r.Get("/otelcols/new", http.HandlerFunc(w.CreateOtelcol))
		r.Post("/otelcols/new", http.HandlerFunc(w.CreateOtelcolExec))
		r.Get("/otelcols/{id}", http.HandlerFunc(w.GetOtelcol))
		r.Delete("/otelcols/{id}", http.HandlerFunc(w.DeleteOtelcol))
		r.Get("/otelcols/edit/{id}", http.HandlerFunc(w.UpdateOtelcol))
		r.Put("/otelcols/edit/{id}", http.HandlerFunc(w.UpdateOtelcolExec))
	})
}
