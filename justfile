# Define variables
kind_cluster := "cluster-local-telesto"
tanka_environment_directory := "./deploy/environments"
crd_filter := "--target 'CustomResourceDefinition/.+'"

kubeconfig_file := f"./deploy/{{kind_cluster}}/{{kind_cluster}}.kubeconfig.yaml"
kubeconfig_env := f"KUBECONFIG=\"{{kubeconfig_file}}\""
kubeconfig_flag := f'--kubeconfig {{kubeconfig_file}}'
tanka_secret_flag := "--ext-code \"secret_json=importstr '/dev/stdin'\""
secrets_file := "secrets.local.enc.json"
sops_age_key_cmd := "op item get nfbawiqc4kr4yvrmxwpq7etrbm --vault 'telesto' --format json --fields password | jq .value -r"

sops *ARGS:
    SOPS_AGE_KEY=$({{ sops_age_key_cmd }}) sops {{ ARGS }}

start-live:
    reflex -r '.go$' -R '^templates/' -s -- just start

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
    go run ./cmd/telestoctl/main.go {{ ARGS }}

get-current-version:
    jq -r .version dist/metadata.json

# deploy
start-kind-lb:
    rm .etchosts || echo '.etchosts is not existent';
    goreman -f ./kind-loadbalancer.procfile start

download-hosts:
    kubectl get gateway -A -o json | jq '.items[] | "\(.status.addresses[0].value)\t\(.spec.listeners[0].hostname)"' -r > ./.etchosts

cpk:
    sudo -n cloud-provider-kind --gateway-channel disabled

sync-ing-to-hosts:
    just download-hosts
    sudo -n hostctl replace telesto -f .etchosts

sync-ing-to-hosts-watch:
    while true; do just sync-ing-to-hosts; sleep 5; done

tk-lint ENVIRONMENT_NAME *ARGS:
    just sops decrypt {{ secrets_file }} | {{ kubeconfig_env }} tk lint "{{ tanka_environment_directory }}/{{ ENVIRONMENT_NAME }}" {{ ARGS }}

tk-diff ENVIRONMENT_NAME *ARGS:
    just sops decrypt {{ secrets_file }} | {{ kubeconfig_env }} tk diff "{{ tanka_environment_directory }}/{{ ENVIRONMENT_NAME }}" {{ tanka_secret_flag }} {{ ARGS }}

tk-apply ENVIRONMENT_NAME *ARGS:
    just sops decrypt {{ secrets_file }} | {{ kubeconfig_env }} tk apply "{{ tanka_environment_directory }}/{{ ENVIRONMENT_NAME }}" {{ tanka_secret_flag }} {{ ARGS }} --auto-approve always && just tk-prune {{ ENVIRONMENT_NAME }}
tk-prune ENVIRONMENT_NAME:
    just sops decrypt {{ secrets_file }} | {{ kubeconfig_env }} tk prune "{{ tanka_environment_directory }}/{{ ENVIRONMENT_NAME }}" {{ tanka_secret_flag }} --auto-approve always

tk-apply-crds ENVIRONMENT_NAME:
    just tk-apply {{ ENVIRONMENT_NAME }} --target 'CustomResourceDefinition/.+' --validate

# # test otelcols instances
test-otelcol ID:
    telemetrygen traces --otlp-endpoint {{ ID }}.o.telesto.test:4318 --traces 10 --otlp-http
