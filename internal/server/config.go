package server

type TLS struct {
	CACert string `mapstrucutre:"caCert" json:"caCert,omitempty" validate:"omitempty,filepath,file"`
	Cert   string `mapstructure:"cert" json:"cert,omitempty" validate:"required_with=Key,omitempty,filepath,file"`
	Key    string `mapstructure:"key" json:"key,omitempty" validate:"required_with=Cert,omitempty,filepath,file"`
}

func (t *TLS) IsHalfSet() bool {
	return (t.Cert != "" && t.Key == "") || (t.Cert == "" && t.Key != "")
}

func (t *TLS) IsSet() bool {
	return t.Cert != "" && t.Key != ""
}
