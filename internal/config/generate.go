package config

//go:generate go run ../scripts/generate-config-json-schema.go --output ./config.jsonschema.json
//go:generate k8s-gen generate jsonschema --debug --schema ./config.jsonschema.json --output ../../deploy/lib/telesto-config/config.libsonnet
