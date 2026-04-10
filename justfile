kind_cluster := "telesto-single-cluster"

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
    kind load docker-image quay.io/telesto/telesto:$(jq -r .version dist/metadata.json) -n {{kind_cluster}}

get-current-version:
    jq -r .version dist/metadata.json

goreleaser *ARGS:
    GORELEASER_PREVIOUS_TAG=$(git tag -l "telesto/v*" --sort -refname| choose -f "/" -o / 1 | head -2 | tail -1) GORELEASER_CURRENT_TAG=$(git tag -l "telesto/v*" --sort -refname | choose -f "/" -o / 1 | head -1) goreleaser {{ARGS}}

