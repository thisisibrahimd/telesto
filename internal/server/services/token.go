package services

import (
	"context"

	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/model"
	"github.com/thisisibrahimd/telesto/internal/storage"
)

type TokenService struct {
	sto *storage.Storage
}

func (s *TokenService) ByUser(id string) *TokenService {
	return &TokenService{
		sto: s.sto.ForUser(id),
	}
}

func (s *TokenService) ByTelesto(id string) *TokenService {
	return &TokenService{
		sto: s.sto.ForTelesto(id),
	}
}

func (s *TokenService) List(ctx context.Context) ([]*model.Token, error) {
	tokens, err := s.sto.GetTokens(ctx)
	if err != nil {
		return nil, err
	}

	return tokens, nil
}

func (s *TokenService) Get(ctx context.Context, id string) (*model.Token, error) {
	telesto, err := s.sto.GetToken(ctx, id)
	if err != nil {
		return nil, err
	}

	return telesto, nil
}

func (s *TokenService) MarkSeen(ctx context.Context, id string) error {
	token, err := s.sto.GetToken(ctx, id)
	if err != nil {
		return err
	}
	token.Seen = true
	if err = s.sto.MarkTokenSeen(ctx, id); err != nil {
		return xerrors.New("error marking token as seen")
	}

	return nil
}

func (s *TokenService) Create(ctx context.Context, t *model.Token) error {
	return s.sto.CreateToken(ctx, t)
}

func (s *TokenService) Update(ctx context.Context, id string, t *model.Token) error {
	if err := s.sto.UpdateToken(ctx, id, t); err != nil {
		return err
	}

	return nil
}

func (s *TokenService) Delete(ctx context.Context, id string) error {
	if err := s.sto.DeleteToken(ctx, id); err != nil {
		return err
	}
	return nil
}

func newTokenService(sto *storage.Storage) *TokenService {
	return &TokenService{sto: sto}
}
