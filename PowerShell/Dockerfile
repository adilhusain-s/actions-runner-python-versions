ARG UBUNTU_VERSION=24.04
ARG TARGETARCH
ARG POWERSHELL_VERSION=v7.5.1

# Base stage for common build tools and dependencies.
FROM ubuntu:${UBUNTU_VERSION} AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -qq update && \
    apt-get -qq install -y cmake g++ gcc git grep libicu-dev make patch unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Builds the native PowerShell library (libpsl-native).
FROM base AS native

ARG POWERSHELL_NATIVE_VERSION=v7.4.0
ARG TARGETARCH

COPY patch/powershell-native-${POWERSHELL_NATIVE_VERSION}.patch /tmp/
WORKDIR /

# Clone, patch, build, and install libpsl-native.so
RUN git clone https://github.com/PowerShell/PowerShell-Native.git /PowerShell-Native && \
    cd /PowerShell-Native && \
    git checkout tags/${POWERSHELL_NATIVE_VERSION} -b ${TARGETARCH} && \
    git apply /tmp/powershell-native-${POWERSHELL_NATIVE_VERSION}.patch && \
    git submodule update --init && \
    cd src/libpsl-native && \
    cmake -DCMAKE_BUILD_TYPE=Debug . && \
    make && \
    (make test || cat Testing/Temporary/LastTest.log || true) && \
    cp ../powershell-unix/libpsl-native.so /usr/lib/

# Prepares PowerShell source and installs the .NET SDK.
FROM native AS source

ARG POWERSHELL_VERSION
ARG TARGETARCH

# Copy PowerShell source patches and build scripts
COPY patch/powershell-${TARGETARCH}-${POWERSHELL_VERSION}.patch /tmp/powershell.patch
COPY patch/powershell-gen-${POWERSHELL_VERSION}.tar.gz /tmp/
COPY update-dotnet-sdk-and-tfm.sh /tmp/
COPY dotnet-install.sh /tmp/dotnet-install.sh

# Make build scripts executable
RUN chmod +x /tmp/update-dotnet-sdk-and-tfm.sh /tmp/dotnet-install.sh

# Install .NET SDK
RUN /tmp/dotnet-install.sh --arch=${TARGETARCH}

# Performs an initial Debug build of PowerShell.
FROM source AS build

ARG TARGETARCH
ARG POWERSHELL_VERSION
WORKDIR /

# Clone PowerShell, apply patches, and perform initial Debug build
RUN git clone https://github.com/PowerShell/PowerShell.git /PowerShell && \
    cd /PowerShell && \
    git checkout ${POWERSHELL_VERSION} -b ${TARGETARCH}-${POWERSHELL_VERSION} && \
    git apply /tmp/powershell.patch && \
    cp /tmp/update-dotnet-sdk-and-tfm.sh . && \
    ./update-dotnet-sdk-and-tfm.sh -g && \
    echo "📝 Final updated global.json:" && grep '"version":' global.json && \
    echo "📝 Sample updated TargetFrameworks:" && find . -name '*.csproj' -exec grep -H '<TargetFramework' {} \; && \
    tar -xzf /tmp/powershell-gen-${POWERSHELL_VERSION}.tar.gz -C .  && \
    dotnet publish -c Debug -r linux-${TARGETARCH} --self-contained true

# Copy Debug build binaries for use in subsequent stages
RUN mkdir -p /usr/local/pwsh && \
    cd /PowerShell/src/powershell-unix/bin/Debug && \
    NET_DIR=$(ls -d net* | head -n1) && \
    cd "$NET_DIR"/linux-${TARGETARCH} && \
    echo "Listing contents of $(pwd):" && \
    ls -al && \
    tar -cf - . | (cd /usr/local/pwsh && tar -xf -)

# Performs a clean Release build and creates the .deb package.
FROM source AS rebuild

ARG POWERSHELL_VERSION
ARG TARGETARCH

WORKDIR /

# Add /usr/local/pwsh to PATH and symlink pwsh binary for this stage
# Copy pwsh binary from build stage and ensure it's in PATH
COPY --from=build /usr/local/pwsh /usr/local/pwsh
ENV PATH=${PATH}:/usr/local/pwsh

# Re-clone PowerShell, apply patches, and modify packaging scripts
COPY update-csproj-rtr.sh /tmp/
RUN chmod +x /tmp/update-csproj-rtr.sh && \
    apt-get install -qy sudo  && \
    rm -rf /PowerShell && \
    git clone https://github.com/PowerShell/PowerShell.git /PowerShell && \
    cd /PowerShell && \
    git checkout tags/${POWERSHELL_VERSION} -b ${TARGETARCH}-${POWERSHELL_VERSION} && \
    git apply /tmp/powershell.patch && \
    # IMPORTANT: Adjust HostArchitecture for ppc64el packaging and ValidateSet
    sed -i 's/HostArchitecture = "amd64"/HostArchitecture = "ppc64el"/' /PowerShell/tools/packaging/packaging.psm1 && \
    sed -i '/ValidateSet.*"arm64"/s/"arm64"/"arm64", "ppc64el"/' /PowerShell/tools/packaging/packaging.psm1 && \
    cp /tmp/update-dotnet-sdk-and-tfm.sh . && \
    ./update-dotnet-sdk-and-tfm.sh -g && \
    echo "📝 Final updated global.json:" && grep '"version":' global.json && \
    echo "📝 Sample updated TargetFrameworks:" && find . -name '*.csproj' -exec grep -H '<TargetFramework' {} \; && \
    tar -xzf /tmp/powershell-gen-${POWERSHELL_VERSION}.tar.gz -C .  && \
    # Execute update-csproj-rtr.sh as ./update-csproj-rtr.sh in /PowerShell before release and packaging
    cp /tmp/update-csproj-rtr.sh . && \
    ./update-csproj-rtr.sh -e && \
    # Build PowerShell Release and create .deb package
    pwsh -Command " \
    Set-Location /PowerShell; \
    Import-Module ./build.psm1 -ArgumentList \$true; \
    Start-PSBuild -UseNuGetOrg; \
    Import-Module ./tools/packaging/packaging.psm1; \
    Start-PSBootstrap -Scenario Package; \
    Start-PSBuild -Clean -PSModuleRestore -Runtime linux-${TARGETARCH} -Configuration Release; \
    Start-PSPackage -Type deb -Version \"${POWERSHELL_VERSION#v}\" \
    " && \
    mkdir -p /tmp/artifacts && \
    cp /PowerShell/powershell_${POWERSHELL_VERSION#v}-1.deb_ppc64el.deb /tmp/artifacts/

# Final runtime image: Installs PowerShell from the .deb package.


FROM ubuntu:${UBUNTU_VERSION} AS final
ARG POWERSHELL_VERSION
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# Install base system packages and PowerShell's runtime dependencies
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    ca-certificates \
    curl \
    libc6 \
    libgcc1 \
    libgssapi-krb5-2 \
    libstdc++6 \
    zlib1g \
    libicu74 \
    libssl3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the built native library
COPY --from=rebuild /usr/lib/libpsl-native.so /usr/lib/

# Copy the .deb package and install PowerShell
COPY --from=rebuild /tmp/artifacts/powershell_${POWERSHELL_VERSION#v}-1.deb_ppc64el.deb /tmp/powershell.deb
RUN dpkg -i /tmp/powershell.deb && \
    apt-get update && \
    apt-get install -f -y && \
    rm /tmp/powershell.deb

# Set PATH for pwsh
ENV PATH="${PATH}:/usr/bin"

# Verify PowerShell installation
RUN pwsh --version
CMD ["/bin/bash"]