
ARG BASE_IMAGE=powershell:ubuntu
ARG UBUNTU_VERSION=24.04
FROM ${BASE_IMAGE}

# Set build arguments that may change frequently
ARG python_version=3.13.3-14344076652
ARG TARGETARCH

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (rarely changes)
RUN apt-get -qq update -y && \
    apt-get -qq -y install g++ gcc git libz-dev make pkg-config python3 sudo && \
    apt autoclean

# Clone only if not already present (improves cache if repo doesn't change)
RUN if [ ! -d /python-versions ]; then git clone https://github.com/actions/python-versions.git /python-versions; fi
WORKDIR /python-versions

# Checkout and update submodules (split for better cache)
RUN git checkout tags/${python_version} && \
    git submodule init && \
    git submodule update

# Build Python and copy output
RUN RUNNER_TEMP=/tmp pwsh builders/build-python.ps1 "${python_version}" linux ${TARGETARCH}

CMD ["/bin/bash"]
