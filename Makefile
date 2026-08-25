KIND_CLUSTER?=cluster-local-telesto
KIND_CLUSTER_NAME?=cluster-local-telesto
KIND_CLUSTER_CONFIG?=deploy/$(KIND_CLUSTER_NAME)/$(KIND_CLUSTER_NAME).yaml
KIND_CLUSTER_KUBECONFIG?=deploy/$(KIND_CLUSTER_NAME)/$(KIND_CLUSTER_NAME).kubeconfig.yaml
LOAD_CONTAINER_IMAGE?=true

## deploy
### kube-bench test security of clusters
# .PHONY: kube-bench
# kube-bench:
# 	kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/refs/tags/v0.15.6/job.yaml
# 	PODNAME=$$(kubectl get po -l job-name=kube-bench -o json | jq '.items[0].metadata.name' -r); kubectl logs $$PODNAME

.PHONY: jb-update
jb-update:
	cd deploy/ && jb update

.PHONY: charts-vendor
charts-vendor:
	cd deploy/ && tk tool charts vendor

.PHONY: install-tk-deps
install-tk-deps: jb-update charts-vendor
	
TANKA_ENVIRONMENT_PATH=deploy/environments/local
TANKA_ENVIRONMENT_NAME=$(notdir $(TANKA_ENVIRONMENT_PATH))
TANKA_EXT_FLAGS = \
	--ext-str "secretsJson=$$(sops decrypt secrets/local/tanka.json)"
TANKA_CRD_FILTER=--target 'CustomResourceDefinition/.+'
TANKA_NON_CRD_FILTER=--target '!CustomResourceDefinition/.+'
TANKA_ARGS:=
### tanka
.PHONY: tk
tk:
	tk $(TANKA_ARGS)

.PHONY: tk-lint
tk-lint:
	tk lint $(TANKA_ENVIRONMENT_PATH)

.PHONY: tk-diff
tk-diff:
	tk diff $(TANKA_ENVIRONMENT_PATH) $(TANKA_EXT_FLAGS)

.PHONY: tk-apply-crds
tk-apply-crds:
	tk apply $(TANKA_ENVIRONMENT_PATH) $(TANKA_EXT_FLAGS) $(TANKA_CRD_FILTER) --auto-approve always

.PHONY: tk-apply
tk-apply:
	tk apply $(TANKA_ENVIRONMENT_PATH) $(TANKA_EXT_FLAGS) $(TANKA_NON_CRD_FILTER) --auto-approve always

.PHONY: tk-prune
tk-prune:
	tk prune $(TANKA_ENVIRONMENT_PATH) $(TANKA_EXT_FLAGS) --auto-approve always

.PHONY: vendor-charts
vendor-charts:
	tk tool charts vednor

### jsonnet-bundler
.PHONY: install
install:
	jb install

### kind cluster management
.PHONY: cluster-create
cluster-create:
	kind create cluster --config "$(KIND_CLUSTER_CONFIG)" --kubeconfig $(KIND_CLUSTER_KUBECONFIG)

config-download:
	kind get kubeconfig --name $(KIND_CLUSTER_NAME) > $(KIND_CLUSTER_KUBECONFIG)

cluster-delete:
	kind delete cluster --name $(KIND_CLUSTER_NAME)

### libsonnet libraries
.PHONY: gen-libsonnet-libraries
gen-libsonnet-libraries:
	k8s-gen --config "./deploy/lib/cloudnative-pg-crds/config.json"
	k8s-gen --config "./deploy/lib/argocd-crds/config.json"
	k8s-gen --config "./deploy/lib/external-secrets-crds/config.json"
	
## application
### go server
.PHONY: test
test:
	go test ./...

.PHONY: gen-templates
gen-templates:
	find templates -name "*_templ.go" -delete
	templ generate

.PHONY: build
build:
	goreleaser release --snapshot --clean
	if [ "$(LOAD_CONTAINER_IMAGE)" = "true" ]; \
	then \
	    kind load docker-image $$(jq -r ".[] | select(.type == \"Docker Image\") | select(.name | contains(\"amd64\")) | .name" dist/artifacts.json) -n $(KIND_CLUSTER); \
    fi;

.PHONY: server-restart
server-restart:
	kubectl rollout restart deployment -n app telesto

.PHONY: lint
lint:
	golangci-lint run ./...

.PHONY: release
release:
	goreleaser release --clean


.PHONY: kind-lb
kind-lb:
	rm .etchosts || echo '.etchosts is not existent';
	goreman -f ./kind-loadbalancer.procfile start
	
.PHONY: cpk
cpk:
	sudo -n cloud-provider-kind --gateway-channel disabled

# you need to run this command to allow hostctl to run automatically
.PHONY: sudoers-install
sudoers-install:
	echo "$$USER ALL=(root) NOPASSWD: $$(which hostctl) *" | sudo tee /etc/sudoers.d/hostctl
	echo "$$USER ALL=(root) NOPASSWD: $$(which cloud-provider-kind) *" | sudo EDITOR="tee" visudo -f /etc/sudoers.d/cpk

.PHONY: sudoers-uninstall
sudoers-uninstall:
	sudo rm /etc/sudoers.d/hostctl /etc/sudoers.d/cpk

.PHONY: sync-gw-to-hosts
sync-gw-to-hosts:
	kubectl get gateway -A -o json | jq '.items[] | "\(.status.addresses[0].value)\t\(.spec.listeners[0].hostname)"' -r > .etchosts
	sudo -n hostctl replace telesto -f .etchosts

.PHONY: sync-gw-to-hosts-watch
sync-gw-to-hosts-watch:
	while true; do make sync-gw-to-hosts; sleep 5; done
    
# # test otelcols instances
test-otelcol ID:
	telemetrygen traces --otlp-endpoint $(TELESTO_ID).t.telesto.test:4318 --otlp-header Authorization=\"Bearer\ $$(TELESTO_AUTH_TOKEN)\" --traces 1 --otlp-http

## database
.PHONY: gen-query
gen-query:
	find internal/storage/query -type f -name '*gen.go' -delete
	go generate ./internal/storage/query/...

.PHONY: gen-cfg-jsonschema
gen-cfg-jsonschema:
	go generate ./internal/config/...
	

# sops
.PHONY: sops
sops:
	sops $(SOPS_ARGS)

# ca
# https://learnings.bolmaster2.com/posts/add-certificates-to-trust-stores#macos-trust-store
# https://ss64.com/mac/security-cert.html
.PHONY: install-local-root-ca-macos
install-local-root-ca-macos:
	mkdir -p tmp
	kubectl get secrets -n cert-manager cert-root-ca-telesto -o json | jq -r '.data.["tls.crt"]' | base64 -d > ./tmp/ca.crt
	sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./tmp/ca.crt

.PHONY: gen-token
gen-token:
	openssl rand -hex 32
