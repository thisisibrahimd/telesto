package v1

import (
	"github.com/danielgtaylor/huma/v2"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/db/query"
	"gorm.io/gorm"
)

type V1Routes struct {
	api   huma.API
	db    *gorm.DB
	query *query.Query
}

func (r *V1Routes) WithDB(db *gorm.DB) *V1Routes {
	r.db = db
	return r
}
func (r *V1Routes) WithQuery(query *query.Query) *V1Routes {
	r.query = query
	return r
}
func (r *V1Routes) WithAPI(api huma.API) *V1Routes {
	r.api = api
	return r
}

func (r *V1Routes) SetupRoutes() *V1Routes {
	v1Group := huma.NewGroup(r.api, "/v1")
	NewOtelColRoutes().WithDB(r.db).WithQuery(r.query).WithAPI(v1Group).SetupRoutes()
	NewGetParamExecuteRoutes().WithDB(r.db).WithQuery(r.query).WithAPI(v1Group).SetupRoutes()
	return r
}

func NewV1Routes() *V1Routes {
	return &V1Routes{}
}
