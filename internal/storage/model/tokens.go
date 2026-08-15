package model

import (
	"strings"

	"github.com/oklog/ulid/v2"
	"gorm.io/gorm"
)

type Token struct {
	ID        string `gorm:"column:id;primaryKey" json:"id"`
	Name      string `gorm:"column:name;not null;uniqueIndex:idx_user_token_name" json:"name"`
	Token     string `gorm:"column:token;not null" json:"-"`
	UserID    string `gorm:"column:user_id;not null;uniqueIndex:idx_user_token_name" json:"userId"`
	Seen      bool   `gorm:"column:seen;not null;default:false"`
	TelestoID string `gorm:"column:telesto_id;not null" json:"telestoId"`
	Telesto   Telesto
}

func (t *Token) BeforeCreate(tx *gorm.DB) (err error) {
	t.ID = strings.ToLower(ulid.Make().String())
	return
}

func (t *Token) AfterFind(tx *gorm.DB) (err error) {
	t.ID = strings.ToLower(t.ID)
	return
}

func (*Token) TableName() string {
	return "tokens"
}
