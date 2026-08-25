package transport

import "net/http"

func NewDefaultRoundTripper() http.RoundTripper {
	return http.DefaultTransport
}
