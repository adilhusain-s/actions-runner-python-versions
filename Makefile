PYTHON_VERSION ?= 3.9.9
POWERSHELL_VERSION ?= v7.5.1
POWERSHELL_NATIVE_VERSION ?= v7.4.0
ARCH ?= $(shell uname -m)
UBUNTU_VERSION ?= 24.04
CONTAINER_ENGINE := $(shell command -v podman 2>/dev/null || command -v docker)

ifeq ($(findstring podman,$(CONTAINER_ENGINE)),podman)
    ifeq ($(shell uname),Linux)
        VOLUME_FLAG := -v $(abspath ./python-versions/output):/tmp/artifact:z
    else
        VOLUME_FLAG := -v ./python-versions/output:/tmp/artifact:z
    endif
else
    VOLUME_FLAG := -v ./python-versions/output:/tmp/artifact
endif

all: python-versions/output/python-$(PYTHON_VERSION)-linux-$(ARCH).tar.gz 

.PHONY: powershell

python-versions/output/python-$(PYTHON_VERSION)-linux-$(ARCH).tar.gz: powershell
	cd python-versions; \
	mkdir -p output; \
	$(CONTAINER_ENGINE) build --platform=linux/$(ARCH) --build-arg python_version=$(PYTHON_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg TARGETARCH=$(ARCH) \
		$(if $(findstring podman,$(CONTAINER_ENGINE)),--build-arg BASE_IMAGE=localhost/powershell:ubuntu,) \
		--tag pyvers:build $(VOLUME_FLAG) .

powershell: PowerShell/Dockerfile PowerShell/patch/powershell-native-$(POWERSHELL_NATIVE_VERSION).patch PowerShell/patch/powershell-$(ARCH)-$(POWERSHELL_VERSION).patch PowerShell/patch/powershell-gen-$(POWERSHELL_VERSION).tar.gz
	cd PowerShell; \
	$(CONTAINER_ENGINE) build --platform=linux/$(ARCH) --build-arg POWERSHELL_VERSION=$(POWERSHELL_VERSION) \
		--build-arg POWERSHELL_NATIVE_VERSION=$(POWERSHELL_NATIVE_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg TARGETARCH=$(ARCH) \
		--tag powershell:ubuntu .

# Pattern rule to help diagnose missing patch files
PowerShell/patch/%.tar.gz:
	@if [ ! -f "$@" ]; then \
		echo "Error: Required patch file $@ is missing."; \
		exit 1; \
	fi
