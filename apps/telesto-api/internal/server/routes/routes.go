package routes

import (
	"github.com/danielgtaylor/huma/v2"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/db/query"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/server/routes/api"
	"gorm.io/gorm"
)

type ServerRoutes struct {
	api   huma.API
	db    *gorm.DB
	query *query.Query
}

func (r *ServerRoutes) WithDB(db *gorm.DB) *ServerRoutes {
	r.db = db
	return r
}
func (r *ServerRoutes) WithQuery(query *query.Query) *ServerRoutes {
	r.query = query
	return r
}
func (r *ServerRoutes) WithAPI(api huma.API) *ServerRoutes {
	r.api = api
	return r
}

func (r *ServerRoutes) SetupRoutes() {
	apiRoutes := api.NewApiRoutes().WithQuery(r.query).WithAPI(r.api)
	apiRoutes.SetupRoutes()
}

func NewServerRoutes() *ServerRoutes {
	return &ServerRoutes{}

}
