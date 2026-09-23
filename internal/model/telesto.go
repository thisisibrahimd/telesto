package model

import (
	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/id"
	"github.com/thisisibrahimd/telesto/internal/telestoconfig"
	"gorm.io/gorm"
)

type Telesto struct {
	ID                  string  `gorm:"column:id;primaryKey" json:"id"`
	Name                string  `gorm:"column:name;not null;uniqueIndex:idx_user_telesto_name" json:"name"`
	UserID              string  `gorm:"column:user_id;not null;uniqueIndex:idx_user_telesto_name" json:"userId"`
	DestinationURL      string  `gorm:"column:destionation_url" json:"destionationUrl"`
	AuthorizationHeader string  `gorm:"column:authorizationHeader" json:"authorizationHeader"`
	Tokens              []Token `gorm:"foreignKey:TelestoID" json:"tokens"`
}

func (t *Telesto) BeforeCreate(tx *gorm.DB) (err error) {
	t.ID = id.New()
	return
}

func (*Telesto) TableName() string {
	return "telestos"
}

func (t *Telesto) GenerateConfig() (string, error) {
	var tc string
	tcTemplateData := &telestoconfig.TemplateData{
		Endpoint:        t.DestinationURL,
		TokensAvailable: len(t.Tokens) > 0,
	}
	tc, err := telestoconfig.Render(tcTemplateData)
	if err != nil {
		return tc, xerrors.New("error generating telesto config", err)
	}

	return tc, nil
}
