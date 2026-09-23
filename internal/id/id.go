package id

import (
	"strings"

	"github.com/oklog/ulid/v2"
)

func New() string {
	return strings.ToLower(ulid.Make().String())
}
