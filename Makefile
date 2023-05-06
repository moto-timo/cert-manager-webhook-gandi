OS ?= $(shell go env GOOS)
ARCH ?= $(shell go env GOARCH)

ifeq (Darwin, $(shell uname))
	GREP_PREGEX_FLAG := E
else
	GREP_PREGEX_FLAG := P
endif

GO_VERSION ?= $(shell go mod edit -json | grep -${GREP_PREGEX_FLAG}o '"Go":\s+"([0-9.]+)"' | sed -E 's/.+"([0-9.]+)"/\1/')

IMAGE_NAME := mototimo/cert-manager-webhook-gandi
IMAGE_TAG := 0.3.0

OUT := $(shell pwd)/_out

#KUBEBUILDER_VERSION=2.3.2
#KUBEBUILDER_VERSION=3.10.0
KUBE_VERSION=1.27.1

$(shell mkdir -p "${OUT}")

#test: _test/kubebuilder
#	TEST_ASSET_ETCD=_test/kubebuilder/bin/etcd \
#	TEST_ASSET_KUBE_APISERVER=_test/kubebuilder/bin/kube-apiserver \
#	TEST_ASSET_KUBECTL=_test/kubebuilder/bin/kubectl \
#	go test -v .

#_test/kubebuilder:
#	curl -fsSL https://github.com/kubernetes-sigs/kubebuilder/releases/download/v${KUBEBUILDER_VERSION}/kubebuilder_${KUBEBUILDER_VERSION}_${OS}_${ARCH}.tar.gz -o kubebuilder-tools.tar.gz
#	mkdir -p _test/kubebuilder
#	tar -xvf kubebuilder-tools.tar.gz
#	mv kubebuilder_${KUBEBUILDER_VERSION}_${OS}_${ARCH}/bin _test/kubebuilder/
#	rm kubebuilder-tools.tar.gz
#	rm -R kubebuilder_${KUBEBUILDER_VERSION}_${OS}_${ARCH}

test: _test/kubebuilder
	TEST_ASSET_ETCD=_test/kubebuilder/etcd \
	TEST_ASSET_KUBE_APISERVER=_test/kubebuilder/kube-apiserver \
	TEST_ASSET_KUBECTL=_test/kubebuilder/kubectl \
	go test -v .

_test/kubebuilder:
	curl -fsSL https://go.kubebuilder.io/test-tools/$(KUBE_VERSION)/$(OS)/$(ARCH) -o kubebuilder-tools.tar.gz
	mkdir -p _test/kubebuilder
	tar -xvf kubebuilder-tools.tar.gz
	mv kubebuilder/bin/* _test/kubebuilder/
	rm kubebuilder-tools.tar.gz
	rm -R kubebuilder

clean: clean-kubebuilder

clean-kubebuilder:
	rm -Rf _test/kubebuilder

build:
	docker buildx build --target=image --platform=linux/amd64 --output=type=docker,name=${IMAGE_NAME}:${IMAGE_TAG} --tag=${IMAGE_NAME}:latest --tag=${IMAGE_NAME}:${IMAGE_TAG} --build-arg=GO_VERSION=${GO_VERSION} .

package:
	helm package deploy/cert-manager-webhook-gandi -d charts/
	helm repo index charts/ --url https://bwolf.github.io/cert-manager-webhook-gandi

.PHONY: rendered-manifest.yaml
rendered-manifest.yaml:
	helm template \
        --set image.repository=${IMAGE_NAME} \
        --set image.tag=${IMAGE_TAG} \
        deploy/cert-manager-webhook-gandi > "${OUT}/rendered-manifest.yaml"
