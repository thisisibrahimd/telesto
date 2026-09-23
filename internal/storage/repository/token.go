package repository

import (
	"context"

	"github.com/thisisibrahimd/telesto/internal/model"
)

type TokenRepo interface {
	GetTokens(ctx context.Context) ([]*model.Token, error)
	GetToken(ctx context.Context, id string) (*model.Token, error)
	CreateToken(ctx context.Context, token *model.Token) error
	UpdateToken(ctx context.Context, id string, token *model.Token) error
	DeleteToken(ctx context.Context, id string) error
	MarkTokenSeen(ctx context.Context, id string) error
}
