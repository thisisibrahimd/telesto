package services

import (
	"context"

	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/repository"
)

type ITokenService interface {
	Service[model.Token]
	ServiceByUser[model.Token]
	ServiceByTelesto[model.Token]
	MarkSeen(ctx context.Context, id string) error
}

type TokenService struct {
	repo repository.Repo[model.Token]
}

func (s *TokenService) ByUser(id string) Service[model.Token] {
	return &TokenService{repo: s.repo.(repository.RepoByUser[model.Token]).ByUser(id)}
}

func (s *TokenService) ByTelesto(id string) Service[model.Token] {
	return &TokenService{repo: s.repo.(repository.RepoByTelesto[model.Token]).ByTelesto(id)}
}

func (s *TokenService) GetAll(ctx context.Context) ([]*model.Token, error) {
	tokens, err := s.repo.GetAll(ctx)
	if err != nil {
		return nil, err
	}

	return tokens, nil
}

func (s *TokenService) Get(ctx context.Context, id string) (*model.Token, error) {
	telesto, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}

	return telesto, nil
}

func (s *TokenService) MarkSeen(ctx context.Context, id string) error {
	token, err := s.Get(ctx, id)
	if err != nil {
		return err
	}
	token.Seen = true
	if _, err = s.repo.(repository.ITokenRepo).MarkSeen(ctx, id); err != nil {
		return xerrors.New("error marking token as seen")
	}

	return nil
}

func (s *TokenService) Create(ctx context.Context, t *model.Token) error {
	return s.repo.New(ctx, t)
}

func (s *TokenService) Update(ctx context.Context, id string, t *model.Token) error {
	if _, err := s.repo.Edit(ctx, id, t); err != nil {
		return err
	}

	return nil
}

func (s *TokenService) Delete(ctx context.Context, id string) error {
	if _, err := s.repo.Delete(ctx, id); err != nil {
		return err
	}
	return nil
}

func newTokenService(repo repository.Repo[model.Token]) ITokenService {
	return &TokenService{repo: repo}
}
