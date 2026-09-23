package services

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/model"
	"github.com/thisisibrahimd/telesto/internal/storage"
)

type TelestoService struct {
	sto *storage.Storage
}

func (s *TelestoService) ByUser(id string) *TelestoService {
	return &TelestoService{
		sto: s.sto.ForUser(id),
	}
}

func (s *TelestoService) GetAll(ctx context.Context) ([]*model.Telesto, error) {
	telestos, err := s.sto.GetTelestos(ctx)
	if err != nil {
		return nil, err
	}

	return telestos, nil
}

func (s *TelestoService) Get(ctx context.Context, id string) (*model.Telesto, error) {
	telesto, err := s.sto.GetTelesto(ctx, id)
	if err != nil {
		return nil, err
	}

	return telesto, nil
}

func (s *TelestoService) GetTokens(ctx context.Context, id string) ([]model.Token, error) {
	telesto, err := s.sto.GetTelesto(ctx, id)
	if err != nil {
		return nil, err
	}

	return telesto.Tokens, nil
}

func (s *TelestoService) Create(ctx context.Context, t *model.Telesto) error {
	return s.sto.CreateTelesto(ctx, t)
}

func (s *TelestoService) Update(ctx context.Context, id string, t *model.Telesto) error {
	if err := s.sto.UpdateTelesto(ctx, id, t); err != nil {
		return err
	}

	return nil
}

func (s *TelestoService) Delete(ctx context.Context, id string) error {
	if err := s.sto.DeleteTelesto(ctx, id); err != nil {
		return err
	}
	return nil
}

func newTelestoService(sto *storage.Storage) *TelestoService {
	return &TelestoService{sto: sto}
}
