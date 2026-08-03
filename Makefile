KIND_CLUSTER ?= 'cluster-local-telesto'
KIND_CLUSTER_NAME ?=cluster-local-telesto
KIND_CLUSTER_CONFIG ?= deploy/$(KIND_CLUSTER_NAME)/$(KIND_CLUSTER_NAME).yaml
KIND_CLUSTER_KUBECONFIG ?= deploy/$(KIND_CLUSTER_NAME)/$(KIND_CLUSTER_NAME).kubeconfig.yaml
LOAD_CONTAINER_IMAGE ?= true
TANKA_ARGS:=""
TANKA_ENV:="deploy/environments/local"

.PHONY: kube-bench
kube-bench:
	kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/refs/tags/v0.15.6/job.yaml
	PODNAME=$$(kubectl get po -l job-name=kube-bench -o json | jq '.items[0].metadata.name' -r); kubectl logs $$PODNAME

### tanka
.PHONY: tk
tk:
	tk $(TANKA_ARGS)

### go server
.PHONY: test
test:
	go test ./...

.PHONY: build
build:
	goreleaser release --snapshot --clean
	if [ "$(LOAD_CONTAINER_IMAGE)" = "true" ]; \
	then \
	    kind load docker-image $$(jq -r ".[] | select(.type == \"Docker Image\") | select(.name | contains(\"amd64\")) | .name" dist/artifacts.json) -n $(KIND_CLUSTER); \
    fi;

.PHONY: server-restart
server-restart:
	kubectl rollout restart deployment -n telesto telesto

.PHONY: release
release:
	goreleaser release --clean

### kind cluster management
.PHONY: cluster-create
cluster-create:
	kind create cluster --config "$(KIND_CLUSTER_CONFIG)" --kubeconfig $(KIND_CLUSTER_KUBECONFIG)

config-download:
	kind get kubeconfig --name $(KIND_CLUSTER_NAME)

cluster-delete:
	kind delete cluster --name $(KIND_CLUSTER_NAME)
