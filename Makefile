PYTHON_VERSION ?= 3.9.9
POWERSHELL_VERSION ?= v7.5.1
POWERSHELL_NATIVE_VERSION ?= v7.4.0
ARCH ?= $(shell uname -m)
UBUNTU_VERSION ?= 24.04

all: python-versions/output/python-$(PYTHON_VERSION)-linux-$(ARCH).tar.gz 

.PHONY: powershell

python-versions/output/python-$(PYTHON_VERSION)-linux-$(ARCH).tar.gz: powershell
	cd python-versions; \
	mkdir -p output; \
	docker buildx build --platform=linux/$(ARCH) \
		--build-arg python_version=$(PYTHON_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg TARGETARCH=$(ARCH) \
		--build-arg BASE_IMAGE=powershell:ubuntu \
		--output type=local,dest=./output \
		--tag pyvers:build .

powershell: PowerShell/Dockerfile \
           PowerShell/patch/powershell-native-$(POWERSHELL_NATIVE_VERSION).patch \
           PowerShell/patch/powershell-$(ARCH)-$(POWERSHELL_VERSION).patch \
           PowerShell/patch/powershell-gen-$(POWERSHELL_VERSION).tar.gz
	cd PowerShell; \
	docker buildx build --platform=linux/$(ARCH) \
		--build-arg POWERSHELL_VERSION=$(POWERSHELL_VERSION) \
		--build-arg POWERSHELL_NATIVE_VERSION=$(POWERSHELL_NATIVE_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg TARGETARCH=$(ARCH) \
		--output type=docker \
		--tag powershell:ubuntu .

# Pattern rule to help diagnose missing patch files
PowerShell/patch/%.tar.gz:
	@if [ ! -f "$@" ]; then \
		echo "Error: Required patch file $@ is missing."; \
		exit 1; \
	fi
