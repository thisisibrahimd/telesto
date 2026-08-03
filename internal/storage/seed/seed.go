package seed

import (
	"context"
	"slices"

	"github.com/mdobak/go-xerrors"
	ory "github.com/ory/kratos-client-go/v26"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
)

func getIdentity(identities []ory.Identity, name string) (*ory.Identity, error) {
	userIndex := slices.IndexFunc(identities, func(i ory.Identity) bool {
		return i.GetTraits().(map[string]interface{})["username"].(string) == name
	})
	if userIndex == -1 {
		return nil, xerrors.New("users not available")
	}

	user := identities[userIndex]
	return &user, nil
}

func SeedSenario1(sto *storage.Storage, oryClient *ory.APIClient) error {
	ctx := context.Background()

	// identities, ListIdentitiesRes, err := oryClient.IdentityAPI.ListIdentities(ctx).Execute()
	identities, _, err := oryClient.IdentityAPI.ListIdentities(ctx).Execute()
	if err != nil {
	}

	alice, err := getIdentity(identities, "alice")
	if err != nil {
		return err
	}

	otelcols := []*model.Otelcol{
		{
			Name:   "apple",
			UserID: alice.Id,
		},
		{
			Name:   "banana",
			UserID: alice.Id,
		},
		{
			Name:   "mango",
			UserID: alice.Id,
		},
	}

	for _, o := range otelcols {
		if err := sto.CreateOtelcol(ctx, o); err != nil {
			return err
		}
	}

	return nil
}
