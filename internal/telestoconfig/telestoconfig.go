package telestoconfig

import (
	_ "embed"
	"strings"
	"text/template"

	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
)

//go:embed telestoconfig.tmpl.yaml
var telestoConfigTemplateFile string

var telestoConfigTemplate = template.Must(template.New("telesto-config").Parse(telestoConfigTemplateFile))

type TemplateData struct {
	Telesto *model.Telesto `json:"telesto"`
}

func Render(td *TemplateData) (string, error) {
	var renderedTelestoConfig strings.Builder
	err := telestoConfigTemplate.Execute(&renderedTelestoConfig, td)
	if err != nil {
		return "", xerrors.New("error rendering telesto config template", err)
	}

	return renderedTelestoConfig.String(), nil
}
