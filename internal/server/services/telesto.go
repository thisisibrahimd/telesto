package services

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/repository"
)

type ITelestoService interface {
	Service[model.Telesto]
	ServiceByUser[model.Telesto]
}

type TelestoService struct {
	repo repository.Repo[model.Telesto]
}

func (s *TelestoService) ByUser(id string) Service[model.Telesto] {
	return &TelestoService{repo: s.repo.(repository.ITelestoRepo).ByUser(id)}
}

func (s *TelestoService) GetAll(ctx context.Context) ([]*model.Telesto, error) {
	telestos, err := s.repo.GetAll(ctx)
	if err != nil {
		return nil, err
	}

	return telestos, nil
}

func (s *TelestoService) Get(ctx context.Context, id string) (*model.Telesto, error) {
	telesto, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}

	return telesto, nil
}

func (s *TelestoService) GetTokens(ctx context.Context, id string) ([]model.Token, error) {
	telesto, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}

	return telesto.Tokens, nil
}

func (s *TelestoService) Create(ctx context.Context, t *model.Telesto) error {
	return s.repo.New(ctx, t)
}

func (s *TelestoService) Update(ctx context.Context, id string, t *model.Telesto) error {
	if _, err := s.repo.Edit(ctx, id, t); err != nil {
		return err
	}

	return nil
}

func (s *TelestoService) Delete(ctx context.Context, id string) error {
	if _, err := s.repo.Delete(ctx, id); err != nil {
		return err
	}
	return nil
}

func newTelestoService(repo repository.Repo[model.Telesto]) ITelestoService {
	return &TelestoService{repo: repo}
}
