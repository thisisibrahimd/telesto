# Define variables
kind_cluster := "telesto-local-cluster"
tanka_environment_directory := "./deploy/environments"
crd_filter := "--target 'CustomResourceDefinition/.+'"

kubeconfig_file := f"./deploy/{{kind_cluster}}/{{kind_cluster}}.kubeconfig.yaml"
kubeconfig_env := f"KUBECONFIG=\"{{kubeconfig_file}}\""
kubeconfig_flag := f'--kubeconfig {{kubeconfig_file}}'
tanka_secret_flag := "--ext-code \"secret_json=importstr '/dev/stdin'\""
secrets_file := "secrets.local.enc.json"
sops_age_key_cmd := "op item get 'local-age-key' --vault 'telesto' --format json --fields password | jq .value -r"
sops *ARGS:
    SOPS_AGE_KEY=$({{sops_age_key_cmd}}) sops {{ARGS}}

start-live:
    reflex -r '.go$' -R '^templates/' -s -- just start

start:
    goreman -f ./procfile start

test:
    go test -v ./...

# api
gen-api:
    jsonnet ./api/api.jsonnet > ./api/api.yaml
gen-api-jsonnet-lib:
    go run ./internal/scripts/openapi-lib-gen.go -library-name openapi -json-schema ./internal/scripts/openapi-lib-gen/openapi.jsonschema.json -output ./api/openapi.jsonnet -template-file ./internal/scripts/openapi-lib-gen/jsonnet.tmpl && jsonnetfmt ./api/openapi.jsonnet -i
gen-api-jsonnet-lib-parse:
    go run ./internal/scripts/openapi-lib-gen.go -library-name openapi -json-schema ./internal/scripts/openapi-lib-gen/openapi.jsonschema.json -output ./api/openapi.jsonnet -parse -template-file ./internal/scripts/openapi-lib-gen/jsonnet.tmpl 

gen-server:
    just gen-api
    go generate ./internal/server/api/...

# client
client *ARGS:
    go run ./cmd/telestoctl/main.go {{ARGS}}

# build process
build:
    just goreleaser release --clean --snapshot

build-local:
    just goreleaser release --snapshot --clean
    kind load docker-image $(jq -r ".[] | select(.type == \"Docker Image\") | select(.name | contains(\"amd64\")) | .name" dist/artifacts.json) -n {{kind_cluster}}

get-current-version:
    jq -r .version dist/metadata.json

goreleaser *ARGS:
    GORELEASER_PREVIOUS_TAG=$(git tag -l "telesto/v*" --sort -refname| choose -f "/" -o / 1 | head -2 | tail -1) GORELEASER_CURRENT_TAG=$(git tag -l "telesto/v*" --sort -refname | choose -f "/" -o / 1 | head -1) goreleaser {{ARGS}}

# deploy
get-argo-admin-password:
    just k get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | pbcopy

start-kind-lb:
    rm .etchosts || echo '.etchosts is not existent';
    goreman -f ./kind-loadbalancer.procfile start

download-hosts:
    just k get gateway -o json | jq '.items[] | "\(.status.addresses[0].value)\t\(.spec.listeners[0].hostname)"' -r > ./.etchosts

cpk:
    sudo -n cloud-provider-kind --gateway-channel disabled

sync-ing-to-hosts:
    just download-hosts
    sudo -n hostctl replace telesto -f .etchosts

sync-ing-to-hosts-watch:
    while true; do just sync-ing-to-hosts; sleep 5; done

tk-lint ENVIRONMENT_NAME *ARGS:
    just sops decrypt {{secrets_file}} | {{kubeconfig_env}} tk lint {{tanka_secret_flag}} {{ARGS}} "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}"

tk-diff ENVIRONMENT_NAME *ARGS:
    just sops decrypt {{secrets_file}} | {{kubeconfig_env}} tk diff {{tanka_secret_flag}} {{ARGS}} "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}"  

tk-apply ENVIRONMENT_NAME *ARGS:
    just sops decrypt {{secrets_file}} | {{kubeconfig_env}} tk apply {{tanka_secret_flag}} {{ARGS}} "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}" --auto-approve always && \
    just sops decrypt {{secrets_file}} | {{kubeconfig_env}} tk prune {{tanka_secret_flag}} "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}" --auto-approve always

tk-apply-crds ENVIRONMENT_NAME:
    just tk-apply --target 'CustomResourceDefinition/.+' --auto-approve always --validate

k *ARGS:
    kubectl {{kubeconfig_flag}} {{ARGS}}
k9s *ARGS:
    k9s {{kubeconfig_flag}} {{ARGS}}

create-local-cluster:
    kind create cluster --config ./deploy/{{kind_cluster}}/{{kind_cluster}}.yaml {{kubeconfig_flag}}

download-config:
    kind get kubeconfig --name {{kind_cluster}}

delete-local-cluster:
    kind delete cluster --name {{kind_cluster}}


## test otelcols instances
test-otelcol ID:
    telemetrygen traces --otlp-endpoint {{ID}}.o.telesto.test:4318 --traces 10 --otlp-http
