package public

import (
	"net/http"

	"github.com/thisisibrahimd/telesto/templates/pages"
)

type RootHandler struct{}

func newRootHandler() *RootHandler {
	return &RootHandler{}
}

func (h *RootHandler) Index(w http.ResponseWriter, r *http.Request) {
	pages.Index().Render(r.Context(), w)
}
