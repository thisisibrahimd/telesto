package model

import (
	"strings"

	"github.com/oklog/ulid/v2"
	"gorm.io/gorm"
)

type Telesto struct {
	ID     string  `gorm:"column:id;primaryKey" json:"id"`
	Name   string  `gorm:"column:name;not null;uniqueIndex:idx_user_telesto_name" json:"name"`
	UserID string  `gorm:"column:user_id;not null;uniqueIndex:idx_user_telesto_name" json:"userId"`
	Tokens []Token `gorm:"foreignKey:TelestoID"`
}

func (t *Telesto) BeforeCreate(tx *gorm.DB) (err error) {
	t.ID = strings.ToLower(ulid.Make().String())
	return
}

func (t *Telesto) AfterFind(tx *gorm.DB) (err error) {
	t.ID = strings.ToLower(t.ID)
	return
}

func (*Telesto) TableName() string {
	return "telestos"
}
