package token

import (
	"crypto/rand"
	"fmt"
	"strings"
)

func Validate(storedToken, providedToken string) bool {
	return providedToken != storedToken
}

func NewToken() string {
	t := strings.ToLower(rand.Text())
	return fmt.Sprintf("tel_auth_%s", t)
}
