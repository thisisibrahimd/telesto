package v1

import (
	"context"
	"fmt"

	"github.com/danielgtaylor/huma/v2"
	"github.com/oklog/ulid/v2"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/db/query"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/models"
	"gorm.io/gorm"
)

type OtelColRoutes struct {
	api   huma.API
	db    *gorm.DB
	query *query.Query
}

func (r *OtelColRoutes) WithDB(db *gorm.DB) *OtelColRoutes {
	r.db = db
	return r
}
func (r *OtelColRoutes) WithQuery(query *query.Query) *OtelColRoutes {
	r.query = query
	return r
}
func (r *OtelColRoutes) WithAPI(api huma.API) *OtelColRoutes {
	r.api = api
	return r
}

type OtelColListRequest struct{}
type OtelColListResponseBodyItems struct {
	Items []*models.OtelCol `json:"items"`
}
type OtelColListResponse struct {
	Body *OtelColListResponseBodyItems
}

type OtelColGetRequest struct {
	ID string `path:"id" maxLength:"30" example:"world" doc:"Name to greet"`
}
type OtelColGetResponse struct {
	Body *models.OtelCol
}

type OtelColPostRequest struct {
	Body struct {
		Name string `json:"name"`
	}
}
type OtelColPostResponse struct {
	Body *models.OtelCol
}

type OtelColPutRequest struct {
	ID   string `path:"id" maxLength:"30" example:"world" doc:"Name to greet"`
	Body struct {
		Name string `json:"name"`
	}
}
type OtelColPutResponse struct {
}

type OtelColDeleteRequest struct {
	ID string `path:"id" maxLength:"30" example:"world" doc:"Name to greet"`
}
type OtelColDeleteResponse struct{}

func (r *OtelColRoutes) SetupRoutes() {
	o := r.query.OtelCol

	otelcolApi := huma.NewGroup(r.api, "/otelcol")
	huma.Get(otelcolApi, "/{id}", func(ctx context.Context, input *OtelColGetRequest) (*OtelColGetResponse, error) {
		oc, err := o.WithContext(ctx).Where(o.ID.Eq(input.ID)).First()
		if err != nil {
			return nil, fmt.Errorf("unable to read otelcols: %v", err)
		}
		return &OtelColGetResponse{Body: oc}, nil
	})
	huma.Get(otelcolApi, "/", func(ctx context.Context, input *OtelColListRequest) (*OtelColListResponse, error) {
		oc, err := o.WithContext(ctx).Find()
		if err != nil {
			return nil, fmt.Errorf("unable to read otelcols: %v", err)
		}
		return &OtelColListResponse{Body: &OtelColListResponseBodyItems{Items: oc}}, nil
	})
	huma.Post(otelcolApi, "/", func(ctx context.Context, input *OtelColPostRequest) (*OtelColPostResponse, error) {
		id := ulid.Make().String()
		newOtelCol := &models.OtelCol{
			ID:   id,
			Name: input.Body.Name,
		}
		if err := o.WithContext(ctx).Create(newOtelCol); err != nil {
			return nil, huma.Error400BadRequest("", err)
		}
		return &OtelColPostResponse{Body: newOtelCol}, nil
	})
	huma.Put(otelcolApi, "/{id}", func(ctx context.Context, input *OtelColPutRequest) (*OtelColPutResponse, error) {
		_, err := o.WithContext(ctx).Where(o.ID.Eq(input.ID)).Updates(input)
		if err != nil {
			return nil, huma.Error500InternalServerError("otelcol update failed", err)
		}

		return &OtelColPutResponse{}, nil
	})
	huma.Delete(otelcolApi, "/{id}", func(ctx context.Context, input *OtelColDeleteRequest) (*OtelColDeleteResponse, error) {
		_, err := o.WithContext(ctx).Where(o.ID.Eq(input.ID)).Delete()
		if err != nil {
			return nil, huma.Error500InternalServerError("deleteion failed", err)
		}
		return nil, nil
	})
}

func NewOtelColRoutes() *OtelColRoutes {
	return &OtelColRoutes{}
}
