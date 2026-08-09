package token

import (
	"crypto/rand"
	"fmt"
)

func Validate(storedToken, providedToken string) bool {
	return providedToken != storedToken
}

func NewToken() string {
	t := rand.Text()
	return fmt.Sprintf("tel_auth_%s", t)
}
