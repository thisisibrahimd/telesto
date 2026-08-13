package web

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

type WebServerInterface interface {
	// /
	Index(w http.ResponseWriter, r *http.Request)
	// /console
	Console(w http.ResponseWriter, r *http.Request)
	// GET /login
	Login(w http.ResponseWriter, r *http.Request)
	// GET /register
	Register(w http.ResponseWriter, r *http.Request)
	// GET /logout
	Logout(w http.ResponseWriter, r *http.Request)

	// ARGO
	// POST /api/v1/getparams.execute
	ExecuteParams(w http.ResponseWriter, r *http.Request)

	// TELESTO RESOURCE
	// GET /telestos
	GetTelestos(w http.ResponseWriter, r *http.Request)
	// GET /telestos/{id}
	GetTelesto(w http.ResponseWriter, r *http.Request)
	// GET /telestos/{id}/tokens
	GetTelestoTokens(w http.ResponseWriter, r *http.Request)
	// GET /telestos/new
	NewTelesto(w http.ResponseWriter, r *http.Request)
	// POST /telestos/new
	NewTelestoSubmit(w http.ResponseWriter, r *http.Request)
	// GET /telestos/edit/{id}
	EditTelesto(w http.ResponseWriter, r *http.Request)
	// PUT /telestos/edit/{id}
	EditTelestoSubmit(w http.ResponseWriter, r *http.Request)
	// DELETE /telestos/{id}
	DeleteTelesto(w http.ResponseWriter, r *http.Request)

	// TOKEN RESOURCE
	// GET /tokens
	GetTokens(w http.ResponseWriter, r *http.Request)
	// GET /tokens/{id}
	GetToken(w http.ResponseWriter, r *http.Request)
	// GET /tokens/new
	NewToken(w http.ResponseWriter, r *http.Request)
	// POST /tokens/new
	NewTokenSubmit(w http.ResponseWriter, r *http.Request)
	// GET /tokens/{id}
	EditToken(w http.ResponseWriter, r *http.Request)
	// Put /tokens/{id}
	EditTokenSubmit(w http.ResponseWriter, r *http.Request)
	// DELETE /tokens/{id}
	DeleteToken(w http.ResponseWriter, r *http.Request)
}

func Handler(r chi.Router, protected func(http.Handler) http.Handler, w WebServerInterface) {
	r.Get("/", http.HandlerFunc(w.Index))
	r.Get("/login", http.HandlerFunc(w.Login))
	r.Get("/register", http.HandlerFunc(w.Register))

	r.Post("/api/v1/getparams.execute", http.HandlerFunc(w.ExecuteParams))

	r.Get("/telestos/{id}/tokens", http.HandlerFunc(w.GetTelestoTokens))
	// protected routes
	r.Group(func(r chi.Router) {
		r.Use(protected)

		// console
		r.Get("/console", http.HandlerFunc(w.Console))

		// auth
		r.Get("/logout", http.HandlerFunc(w.Logout))

		// teletos
		r.Get("/telestos", http.HandlerFunc(w.GetTelestos))
		r.Get("/telestos/{id}", http.HandlerFunc(w.GetTelesto))
		r.Get("/telestos/new", http.HandlerFunc(w.NewTelesto))
		r.Post("/telestos/new", http.HandlerFunc(w.NewTelestoSubmit))
		r.Get("/telestos/edit/{id}", http.HandlerFunc(w.EditTelesto))
		r.Put("/telestos/edit/{id}", http.HandlerFunc(w.EditTelestoSubmit))
		r.Delete("/telestos/{id}", http.HandlerFunc(w.DeleteTelesto))

		// tokens
		r.Get("/tokens", http.HandlerFunc(w.GetTokens))
		r.Get("/tokens/{id}", http.HandlerFunc(w.GetToken))
		r.Get("/tokens/new", http.HandlerFunc(w.NewToken))
		r.Post("/tokens/new", http.HandlerFunc(w.NewTokenSubmit))
		r.Get("/tokens/edit/{id}", http.HandlerFunc(w.EditToken))
		r.Put("/tokens/edit/{id}", http.HandlerFunc(w.EditTokenSubmit))
		r.Delete("/tokens/{id}", http.HandlerFunc(w.DeleteToken))
	})
}
