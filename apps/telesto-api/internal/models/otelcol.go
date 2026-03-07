package models

import (
	ulid "github.com/oklog/ulid/v2"
	"gorm.io/gorm"
)

type OtelCol struct {
	ID   string `json:"id" gorm:"primarykey,unique"`
	Name string `json:"name" gorm:"unique"`
}

func (o *OtelCol) BeforeCreate(tx *gorm.DB) (err error) {
	o.ID = ulid.Make().String()
	return
}
