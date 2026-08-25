package transport

import (
	"crypto/tls"
	"crypto/x509"
	"net/http"
)

func NewTLSRoundTripper(caCert []byte) http.RoundTripper {
	rootCACertPool := x509.NewCertPool()
	rootCACertPool.AppendCertsFromPEM(caCert)
	tlsCfg := &tls.Config{
		InsecureSkipVerify: true,
		RootCAs:            rootCACertPool,
	}
	tr := &http.Transport{
		TLSClientConfig: tlsCfg,
	}
	return tr
}
