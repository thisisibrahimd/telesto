package routes

import (
	"context"
	"fmt"

	"github.com/danielgtaylor/huma/v2"
	"github.com/thisisibrahimd/telesto/pkg/server"
	"go.uber.org/fx"
)

type GreetingHandler struct{}

// GreetingOutput represents the greeting operation response.
type GreetingInput struct {
	Name string `path:"name" maxLength:"30" example:"world" doc:"Name to greet"`
}

// GreetingOutput represents the greeting operation response.
type GreetingOutput struct {
	Body struct {
		Message string `json:"message" example:"Hello, world!" doc:"Greeting message"`
	}
}

func NewGreetingHandler(lc fx.Lifecycle, api *server.TelestoAPI) {
	// Register GET /greeting/{name} handler.
	huma.Get(api.Api, "/greeting/{name}", func(ctx context.Context, input *GreetingInput) (*GreetingOutput, error) {
		resp := &GreetingOutput{}
		resp.Body.Message = fmt.Sprintf("Hello, %s!", input.Name)
		return resp, nil
	})

}
