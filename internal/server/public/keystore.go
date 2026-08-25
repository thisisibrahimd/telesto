package public

import "github.com/gorilla/securecookie"

type KeyStore struct {
	CookieStoreKey  []byte
	CookieEncKey    []byte
	SessionStoreKey []byte
	SessionEncKey   []byte
	CsrfKey         []byte
}

func NewKeyStore() *KeyStore {
	return nil
}

func RandomKeyStore() *KeyStore {
	return &KeyStore{
		CookieStoreKey:  securecookie.GenerateRandomKey(32),
		CookieEncKey:    securecookie.GenerateRandomKey(32),
		SessionStoreKey: securecookie.GenerateRandomKey(32),
		SessionEncKey:   securecookie.GenerateRandomKey(32),
		CsrfKey:         securecookie.GenerateRandomKey(32),
	}
}
