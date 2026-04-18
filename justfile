# Define variables
kind_cluster := "telesto-local-cluster"
tanka_environment_directory := "./deploy/environments"
crd_filter := "--target 'CustomResourceDefinition/.+'"

start-live:
    reflex -r '.go$' -R '^templates/' -s -- just start

start:
    goreman -f ./procfile start

test:
    go test -v ./...

# auth
start-auth:
    kratos serve --dev -c kratos.yml
    
wait-for-auth:
    while true; do curl -o /dev/null -sf localhost:4434/health/ready && echo "auth ready" && exit; done
wait-for-users:
    while true; do kratos ls identities -e http://localhost:4434 --format json | jq --exit-status '.identities | length != 0' && echo "users are ready" && exit; done

init-auth:
    just wait-for-auth
    just seed-auth

seed-auth:
    cat default-users.json| kratos import identities -e http://localhost:4434

# api
gen-api:
    jsonnet ./api/api.jsonnet > ./api/api.yaml
gen-api-jsonnet-lib:
    go run ./internal/scripts/openapi-lib-gen.go -library-name openapi -json-schema ./internal/scripts/openapi-lib-gen/openapi.jsonschema.json -output ./api/openapi.jsonnet -template-file ./internal/scripts/openapi-lib-gen/jsonnet.tmpl && jsonnetfmt ./api/openapi.jsonnet -i
gen-api-jsonnet-lib-parse:
    go run ./internal/scripts/openapi-lib-gen.go -library-name openapi -json-schema ./internal/scripts/openapi-lib-gen/openapi.jsonschema.json -output ./api/openapi.jsonnet -parse -template-file ./internal/scripts/openapi-lib-gen/jsonnet.tmpl 

# database
start-db:
    rqlited -node-id=1 "$(mktemp -d)/"

wait-for-db:
    while true; do curl -o /dev/null -sf localhost:4001/readyz && echo "db ready" && exit; done

stop-db:
    PID=$(ps | grep "just start-db" | grep -v "grep" | awk '{print $1}'); kill $PID
        
init-db:
    just wait-for-db
    just seed-db

seed-db:
    just wait-for-users
    go run ./internal/scripts/seed.go

gen-query:
    go generate ./internal/storage/query/...

# server
start-server:
    just wait-for-db
    TELESTO_INITIAL_USERNAME=admin TELESTO_INITIAL_PASSWORD=Password1! templ generate --watch --cmd="go run ./cmd/telesto-server/main.go serve --migrate"

gen-server:
    just gen-api
    go generate ./internal/server/api/...

# client
client *ARGS:
    go run ./cmd/telestoctl/main.go {{ARGS}}

# observability
install-openobserve:
    curl -L https://raw.githubusercontent.com/openobserve/openobserve/main/downloadO2.sh | sh -s opensource v0.70.0

start-openobserve:
    ZO_ROOT_USER_EMAIL=admin@telesto.io ZO_ROOT_USER_PASSWORD=Password1! ./openobserve


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
    kubectl get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | pbcopy

start-kind-lb:
    goreman -f ./kind-loadbalancer.procfile start

download-hosts:
    kubectl get ing -A -o json | jq -r '.items[] | "\(.status.loadBalancer.ingress[0].ip)\t\(.spec.rules[0].host)"' > ./.etchosts

cpk:
    sudo -n cloud-provider-kind

sync-ing-to-hosts:
    just download-hosts
    sudo -n hostctl add telesto -f .etchosts

sync-ing-to-hosts-watch:
    while true; do just sync-ing-to-hosts; sleep 5; done

tk-lint ENVIRONMENT_NAME:
    tk lint "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}"

tk-diff ENVIRONMENT_NAME:
    tk diff "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}" 

tk-apply ENVIRONMENT_NAME:
    tk apply "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}" --auto-approve always && tk prune "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}" 

tk-apply-crds ENVIRONMENT_NAME:
    tk apply "{{tanka_environment_directory}}/{{ENVIRONMENT_NAME}}" --target 'CustomResourceDefinition/.+' --auto-approve always --validate

create-local-cluster:
    kind create cluster --config ./deploy/{{kind_cluster}}/{{kind_cluster}}.yaml --kubeconfig ./deploy/{{kind_cluster}}/{{kind_cluster}}.kubeconfig.yaml

download-config:
    kind get kubeconfig --name {{kind_cluster}}

delete-local-cluster:
    kind delete cluster --name {{kind_cluster}}
