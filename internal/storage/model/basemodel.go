package model

import (
	"github.com/oklog/ulid/v2"
	"gorm.io/gorm"
)

type BaseModel struct {
	ID string `gorm:"column:id;primaryKey" json:"id" schema:"-"`
}

func (bm *BaseModel) BeforeCreate(tx *gorm.DB) (err error) {
	bm.ID = ulid.Make().String()
	return
}
