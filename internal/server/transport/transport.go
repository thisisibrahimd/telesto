package transport

import "net/http"

type Constructor func(http.RoundTripper) http.RoundTripper

type Chain struct {
	constructors []Constructor
}

func New(constructors ...Constructor) Chain {
	return Chain{append(([]Constructor)(nil), constructors...)}
}

func (c Chain) Then(final http.RoundTripper) http.RoundTripper {
	t := final

	for i := range c.constructors {
		t = c.constructors[i](t)
	}

	return t
}
