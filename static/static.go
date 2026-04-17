package static

import "embed"

//go:embed css/* js/*
var Dir embed.FS
