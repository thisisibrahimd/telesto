package token

import (
	"crypto/rand"
	"crypto/subtle"
	"fmt"
	"strings"
)

type Token struct {
	ID      string
	Name    string
	Token   string
	UserID  string
	Telesto any
	Seen    bool
}

func (t *Token) Validate(incomingTokenString string) bool {
	return subtle.ConstantTimeCompare([]byte(t.Token), []byte(incomingTokenString)) == 1
}

func NewTokenString() string {
	t := strings.ToLower(rand.Text())
	return fmt.Sprintf("tel_auth_%s", t)
}
