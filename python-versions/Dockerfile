
ARG UBUNTU_VERSION=24.04
ARG BASE_IMAGE=powershell:ubuntu-${UBUNTU_VERSION}
FROM ${BASE_IMAGE} AS builder

# Set build arguments that may change frequently
ARG python_version=3.13.3-14344076652
ARG TARGETARCH

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive



RUN export DEBIAN_FRONTEND=noninteractive && \
    echo "tzdata tzdata/Areas select Asia" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/Asia select Kolkata" | debconf-set-selections && \
    apt-get -qq update -y && \
    apt-get -qq -y install tzdata g++ gcc git libz-dev make pkg-config python3 sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clone only if not already present (improves cache if repo doesn't change)
RUN if [ ! -d /python-versions ]; then git clone https://github.com/actions/python-versions.git /python-versions; fi
WORKDIR /python-versions

# Checkout and update submodules (split for better cache)
RUN git checkout tags/3.13.3-14344076652 && \
    git submodule init && \
    git submodule update

# Build Python and copy output
RUN RUNNER_TEMP=/tmp pwsh builders/build-python.ps1 "${python_version}" linux ${TARGETARCH}



# Start a new final stage with Ubuntu base image
FROM ubuntu:${UBUNTU_VERSION} AS final

# Copy the entire artifact folder from the builder stage, preserving the path
COPY --from=builder /tmp/artifact /tmp/artifact

CMD ["/bin/bash"]
