ARG     BASE_IMAGE=powershell:ubuntu
ARG     UBUNTU_VERSION=24.10
FROM    ${BASE_IMAGE}

ARG     python_version=3.13.3-14344076652
ARG     TARGETARCH

ENV     DEBIAN_FRONTEND=noninteractive

RUN     apt-get -qq update -y && \
        apt-get -qq -y install g++ gcc git libz-dev make pkg-config python3 sudo && \
        apt autoclean


RUN git clone https://github.com/actions/python-versions.git && \
    cd python-versions && \
    git checkout tags/3.13.3-14344076652 && \
    git submodule init && \
    git submodule update && \
    RUNNER_TEMP=/tmp pwsh builders/build-python.ps1 "${python_version}" linux ${TARGETARCH} && \
    mkdir -p /python-versions/output && \
    cp /tmp/artifact/python-*.tar.gz /python-versions/output/ || true

CMD     /bin/bash
