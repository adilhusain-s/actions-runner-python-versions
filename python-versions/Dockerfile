# ================= GLOBAL BUILD ARGS =================
ARG UBUNTU_VERSION=24.04
ARG BASE_IMAGE=powershell:ubuntu-${UBUNTU_VERSION}
ARG TARGETARCH
ARG PYTHON_VERSION=3.13.3
ARG ACTIONS_PYTHON_VERSIONS=3.13.3-14344076652

# ================= BUILDER STAGE =====================
FROM ${BASE_IMAGE} AS builder

# Re-declare all ARGs inside this stage
ARG UBUNTU_VERSION
ARG BASE_IMAGE
ARG TARGETARCH
ARG PYTHON_VERSION
ARG ACTIONS_PYTHON_VERSIONS

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    CC=gcc \
    CXX=g++ \
    CFLAGS="-O3 -fPIC -march=native" \
    CXXFLAGS="-O3 -fPIC -march=native"

# Set up the time zone
RUN export DEBIAN_FRONTEND=noninteractive && \
    echo "tzdata tzdata/Areas select Asia" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Asia select Kolkata" | debconf-set-selections && \
    apt-get -qq update -y && \
    apt-get -qq -y install tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install dependencies
RUN export DEBIAN_FRONTEND=noninteractive && \
    pkgs="g++ gcc git libz-dev make pkg-config python3 sudo build-essential libffi-dev libssl-dev zlib1g-dev libncurses-dev libbz2-dev libreadline-dev libsqlite3-dev uuid-dev libgdbm-dev liblzma-dev tk-dev libmpdec-dev libbluetooth-dev"; \
    apt-get -qq update -y && \
    for pkg in $pkgs; do \
        echo "-----------------------------------------"; \
        echo "Attempting to install: $pkg"; \
        apt-get -qq -y install "$pkg" || { \
            echo "WARNING: Could not install '$pkg'. It might not be available for your system or there was an error."; \
            echo "Continuing with the next package..."; \
        }; \
    done; \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clone and checkout the specified Python version
RUN if [ ! -d /python-versions ]; then git clone https://github.com/actions/python-versions.git /python-versions; fi
WORKDIR /python-versions

RUN git checkout "${ACTIONS_PYTHON_VERSIONS}" && \
    git submodule init && \
    git submodule update

# Build Python
# Set RUNNER_TEMP env var globally in this stage
ENV RUNNER_TEMP=/tmp

ENV RUNNER_TEMP=/tmp

RUN pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& { ./builders/build-python.ps1 '${PYTHON_VERSION}' linux ${TARGETARCH}; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }"

# ================= FINAL STAGE =====================
FROM ubuntu:${UBUNTU_VERSION} AS final

ARG UBUNTU_VERSION

# Copy artifacts
COPY --from=builder /tmp/artifact /tmp/artifact

CMD ["/bin/bash"]
