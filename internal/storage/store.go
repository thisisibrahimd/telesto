package storage

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/storage/model"
)

// OTELCOL
type OtelcolStore interface {
	CreateOtelcol(ctx context.Context, otelcol *model.Otelcol) error
	GetOtelcols(ctx context.Context) ([]*model.Otelcol, error)
	GetOtelcol(ctx context.Context, id string) (*model.Otelcol, error)
	UpdateOtelcol(ctx context.Context, id string, otelcol *model.Otelcol) error
	DeleteOtelcol(ctx context.Context, id string) error

	// by user
	CreateOtelcolByUserId(ctx context.Context, userId string, otelcol *model.Otelcol) error
	GetOtelcolsByUserId(ctx context.Context, userId string) ([]*model.Otelcol, error)
	GetOtelcolByUserId(ctx context.Context, userId, id string) (*model.Otelcol, error)
	UpdateOtelcolByUserId(ctx context.Context, userId, id string, otelcol *model.Otelcol) error
	DeleteOtelcolByUserId(ctx context.Context, userId, id string) error
}

var _ OtelcolStore = (*Storage)(nil)

// CreateOtelcol implements [OtelcolStore].
func (s *Storage) CreateOtelcol(ctx context.Context, otelcol *model.Otelcol) error {
	return s.query.Otelcol.WithContext(ctx).Create(otelcol)
}

// GetOtelcols implements [OtelcolStore].
func (s *Storage) GetOtelcols(ctx context.Context) ([]*model.Otelcol, error) {
	return s.query.Otelcol.WithContext(ctx).Find()
}

// GetOtelcol implements [OtelcolStore].
func (s *Storage) GetOtelcol(ctx context.Context, id string) (*model.Otelcol, error) {
	return s.query.Otelcol.WithContext(ctx).Where(s.query.Otelcol.ID.Eq(id)).First()
}

// UpdateOtelcol implements [OtelcolStore].
func (s *Storage) UpdateOtelcol(ctx context.Context, id string, otelcol *model.Otelcol) error {
	_, err := s.query.Otelcol.WithContext(ctx).Where(s.query.Otelcol.ID.Eq(id)).Updates(otelcol)
	return err
}

// DeleteOtelcol implements [OtelcolStore].
func (s *Storage) DeleteOtelcol(ctx context.Context, id string) error {
	_, err := s.query.Otelcol.WithContext(ctx).Where(s.query.Otelcol.ID.Eq(id)).Delete()
	return err
}

// GetOtelcolsByUserId implements [OtelcolStore].
func (s *Storage) GetOtelcolsByUserId(ctx context.Context, userId string) ([]*model.Otelcol, error) {
	return s.query.Otelcol.WithContext(ctx).
		Where(
			s.query.Otelcol.UserID.Eq(userId),
		).
		Find()
}

// GetOtelcolByUserId implements [OtelcolStore].
func (s *Storage) GetOtelcolByUserId(ctx context.Context, userId, id string) (*model.Otelcol, error) {
	return s.query.Otelcol.WithContext(ctx).
		Where(
			s.query.Otelcol.UserID.Eq(userId),
			s.query.Otelcol.ID.Eq(id),
		).
		First()
}

// CreateOtelcolByUserId implements [OtelcolStore].
func (s *Storage) CreateOtelcolByUserId(ctx context.Context, userId string, otelcol *model.Otelcol) error {
	otelcol.UserID = userId
	return s.query.Otelcol.WithContext(ctx).
		Create(otelcol)
}

// UpdateOtelcolByUserId implements [OtelcolStore].
func (s *Storage) UpdateOtelcolByUserId(ctx context.Context, userId, id string, otelcol *model.Otelcol) error {
	_, err := s.query.Otelcol.WithContext(ctx).
		Where(
			s.query.Otelcol.UserID.Eq(userId),
			s.query.Otelcol.ID.Eq(id),
		).
		Updates(otelcol)
	return err
}

// DeleteOtelcolByUserId implements [OtelcolStore].
func (s *Storage) DeleteOtelcolByUserId(ctx context.Context, userId, id string) error {
	_, err := s.query.Otelcol.WithContext(ctx).
		Where(
			s.query.Otelcol.UserID.Eq(userId),
			s.query.Otelcol.ID.Eq(id),
		).
		Delete()
	return err
}
