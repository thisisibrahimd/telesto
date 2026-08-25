package public

import (
	"net/http"

	"github.com/thisisibrahimd/telesto/templates/pages"
)

type ConsoleHandler struct{}

func newConsoleHandler() *ConsoleHandler {
	return &ConsoleHandler{}
}

func (h *ConsoleHandler) Index(w http.ResponseWriter, r *http.Request) {
	pages.Console().Render(r.Context(), w)
}
