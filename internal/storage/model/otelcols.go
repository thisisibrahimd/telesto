package model

import (
	"github.com/oklog/ulid/v2"
	"gorm.io/gorm"
)

type Otelcol struct {
	ID     string `gorm:"column:id;primaryKey" json:"id" schema:"-"`
	Name   string `gorm:"column:name;not null,unique" json:"name" schema:"name,required"`
	UserID string `gorm:"column:user_id;not null" json:"userId" schema:"-"`
}

func (o *Otelcol) BeforeCreate(tx *gorm.DB) (err error) {
	o.ID = ulid.Make().String()
	return
}

func (*Otelcol) TableName() string {
	return "otelcols"
}
