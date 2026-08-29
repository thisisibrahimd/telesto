package telestoconfig_test

import (
	"testing"

	"github.com/sebdah/goldie/v2"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/telestoconfig"
)

// verifyLibsonnetFileMatch verify that the generated libsonnet file matches the golden libsonnet file in our golden directory
func verifyTelestoConfig(t *testing.T, v []byte) {
	g := goldie.New(
		t,
		goldie.WithFixtureDir("./testdata"),
		goldie.WithNameSuffix(".golden.yaml"),
		goldie.WithTestNameForDir(false),
		goldie.WithSubTestNameForDir(false),
	)

	g.Assert(t, t.Name(), v)
}

func TestRender(t *testing.T) {
	tests := []struct {
		name string // description of this test case
		// Named input parameters for target function.
		td      *telestoconfig.TemplateData
		wantErr bool
	}{
		{
			name:    "telesto with no token",
			td:      &telestoconfig.TemplateData{Telesto: &model.Telesto{Name: "rocket"}},
			wantErr: false,
		},
		{
			name:    "telesto with tokens",
			td:      &telestoconfig.TemplateData{Telesto: &model.Telesto{Name: "banana", Tokens: []model.Token{{Name: "apple"}}}},
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			renderedTelestoConfig, gotErr := telestoconfig.Render(tt.td)
			if gotErr != nil {
				if !tt.wantErr {
					t.Errorf("Render() failed: %v", gotErr)
				}
				return
			}
			if tt.wantErr {
				t.Fatal("Render() succeeded unexpectedly")
			}

			verifyTelestoConfig(t, []byte(renderedTelestoConfig))
		})
	}
}
