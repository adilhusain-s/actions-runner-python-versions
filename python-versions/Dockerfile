ARG UBUNTU_VERSION=24.04
ARG BASE_IMAGE=powershell:ubuntu-${UBUNTU_VERSION}
FROM ${BASE_IMAGE} AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    CC=gcc \
    CXX=g++

# Set up the time zone
RUN export DEBIAN_FRONTEND=noninteractive && \
    echo "tzdata tzdata/Areas select Asia" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Asia select Kolkata" | debconf-set-selections && \
    apt-get -qq update -y && \
    apt-get -qq -y install tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install all required dependencies using a package array
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


# Arguments for upstream and downstream Python versions
ARG PYTHON_VERSION
ARG ACTIONS_PYTHON_VERSIONS

# Clone only if not already present (improves cache if repo doesn't change)
RUN if [ ! -d /python-versions ]; then git clone https://github.com/actions/python-versions.git /python-versions; fi
WORKDIR /python-versions

# Checkout the specified version and update submodules (split for better cache)
RUN git checkout "${ACTIONS_PYTHON_VERSIONS}" && \
    git submodule init && \
    git submodule update



# Build Python and copy output
RUN RUNNER_TEMP=/tmp pwsh builders/build-python.ps1 "${PYTHON_VERSION}" linux ${UBUNTU_VERSION}
FROM ubuntu:${UBUNTU_VERSION} AS final
# Copy the entire artifact folder from the builder stage, preserving the path
COPY --from=builder /tmp/artifact /tmp/artifact

CMD ["/bin/bash"]
