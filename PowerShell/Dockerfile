# -----------------------------
# Stage 1: Base Build Environment
# -----------------------------
ARG UBUNTU_VERSION
FROM ubuntu:${UBUNTU_VERSION} AS base

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# install dependencies
RUN apt-get -qq update && \
    apt-get -qq install -y cmake g++ gcc git grep libicu-dev make patch unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------
# Stage 2: Build PowerShell-Native
# -----------------------------
FROM base AS native

ARG POWERSHELL_NATIVE_VERSION=v7.4.0
ARG TARGETARCH

COPY patch/powershell-native-${POWERSHELL_NATIVE_VERSION}.patch /tmp/
WORKDIR /root

RUN git clone https://github.com/PowerShell/PowerShell-Native.git && \
    cd PowerShell-Native && \
    git checkout tags/${POWERSHELL_NATIVE_VERSION} -b ${TARGETARCH} && \
    git apply /tmp/powershell-native-${POWERSHELL_NATIVE_VERSION}.patch && \
    git submodule update --init && \
    cd src/libpsl-native && \
    cmake -DCMAKE_BUILD_TYPE=Debug . && \
    make && \
    (make test || cat Testing/Temporary/LastTest.log || true) && \
    cp ../powershell-unix/libpsl-native.so /usr/lib/
# -----------------------------
# Stage 3: Prepare PowerShell Source
# -----------------------------
FROM native AS source

# Set PowerShell version and target architecture
ARG POWERSHELL_VERSION=v7.5.1
ARG TARGETARCH

# Copy patch and build helper scripts to the image
COPY patch/powershell-${TARGETARCH}-${POWERSHELL_VERSION}.patch /tmp/powershell.patch
COPY patch/powershell-gen-${POWERSHELL_VERSION}.tar.gz /tmp/
COPY build.sh /tmp/
COPY update-dotnet-sdk-and-tfm.sh /tmp/
COPY dotnet-install.sh /tmp/dotnet-install.sh

# Make scripts executable
RUN chmod +x /tmp/build.sh /tmp/update-dotnet-sdk-and-tfm.sh /tmp/dotnet-install.sh

RUN /tmp/dotnet-install.sh --arch=${TARGETARCH}

# -----------------------------
# Stage 4: Build PowerShell (Initial Build)
# -----------------------------
FROM source AS build

ARG TARGETARCH
ARG POWERSHELL_VERSION=v7.5.1
WORKDIR /root

RUN  git clone https://github.com/PowerShell/PowerShell.git && \
    cd PowerShell && \
    git checkout ${POWERSHELL_VERSION} -b ${TARGETARCH}-${POWERSHELL_VERSION} && \
    git apply /tmp/powershell.patch && \
    cp /tmp/update-dotnet-sdk-and-tfm.sh . && \
    ./update-dotnet-sdk-and-tfm.sh -g && \
    echo "📝 Final updated global.json:" && grep '"version":' global.json && \
    echo "📝 Sample updated TargetFrameworks:" && find . -name '*.csproj' -exec grep -H '<TargetFramework' {} \; && \
    tar -xzf /tmp/powershell-gen-${POWERSHELL_VERSION}.tar.gz -C .  && \
    dotnet publish -c Debug -r linux-${TARGETARCH} --self-contained true 

RUN     mkdir -p /usr/local/pwsh && \
        cd PowerShell/src/powershell-unix/bin/Debug && \
        NET_DIR=$(ls -d net* | head -n1) && \
        cd "$NET_DIR"/linux-${TARGETARCH} && \
        tar -cf - . | tar -xf - -C /usr/local/pwsh

# -----------------------------
# Stage 5: Rebuild PowerShell (Clone Again + build.sh)
# -----------------------------
FROM source AS rebuild

ARG POWERSHELL_VERSION=v7.5.1
ARG TARGETARCH

WORKDIR /root

ENV PATH=${PATH}:/usr/local/pwsh

# Copy output from build stage
COPY --from=build /usr/local/pwsh /usr/local/pwsh

RUN rm -rf PowerShell && \
    git clone https://github.com/PowerShell/PowerShell.git && \
    cd PowerShell && \
    git checkout tags/${POWERSHELL_VERSION} -b ${TARGETARCH}-${POWERSHELL_VERSION} && \
    git apply /tmp/powershell.patch && \
    cp /tmp/update-dotnet-sdk-and-tfm.sh . && \
    ./update-dotnet-sdk-and-tfm.sh -g && \
    echo "📝 Final updated global.json:" && grep '"version":' global.json && \
    echo "📝 Sample updated TargetFrameworks:" && find . -name '*.csproj' -exec grep -H '<TargetFramework' {} \; && \
    tar -xzf /tmp/powershell-gen-${POWERSHELL_VERSION}.tar.gz -C .  && \
    /tmp/build.sh

RUN rm -rf /usr/local/pwsh/* && \
    cd PowerShell/src/powershell-unix/bin/Debug/net*/linux-${TARGETARCH} && \
    tar -cf - . | tar -xf - -C /usr/local/pwsh

# -----------------------------
# Final Stage: Runtime Image
# -----------------------------
FROM ubuntu:${UBUNTU_VERSION} AS final

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive


COPY --from=rebuild /usr/lib/libpsl-native.so /usr/lib/
COPY --from=rebuild /usr/local/pwsh /usr/local/pwsh

COPY dotnet-install.sh /tmp/dotnet-install.sh
RUN chmod +x /tmp/dotnet-install.sh
RUN /tmp/dotnet-install.sh  --arch=${TARGETARCH}

ENV PATH="${PATH}:/usr/local/pwsh"
RUN pwsh --version
CMD ["/bin/bash"]
