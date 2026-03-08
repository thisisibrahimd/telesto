package api

import (
	"github.com/danielgtaylor/huma/v2"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/db/query"
	v1 "github.com/thisisibrahimd/telesto/apps/telesto-api/internal/server/routes/api/v1"
	"gorm.io/gorm"
)

type ApiRoutes struct {
	api   huma.API
	db    *gorm.DB
	query *query.Query
}

func (r *ApiRoutes) WithDB(db *gorm.DB) *ApiRoutes {
	r.db = db
	return r
}
func (r *ApiRoutes) WithQuery(query *query.Query) *ApiRoutes {
	r.query = query
	return r
}

func (r *ApiRoutes) WithAPI(api huma.API) *ApiRoutes {
	r.api = api
	return r
}
func (r *ApiRoutes) SetupRoutes() {
	apiGroup := huma.NewGroup(r.api, "/api")
	v1Routes := v1.NewV1Routes().WithDB(r.db).WithQuery(r.query).WithAPI(apiGroup)
	v1Routes.SetupRoutes()
}

func NewApiRoutes() *ApiRoutes {
	return &ApiRoutes{}
}
