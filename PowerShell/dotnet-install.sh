#!/bin/bash

set -e

# === Default values ===
DEFAULT_SDK_VERSION="9.0.105"
DEFAULT_RUNTIME_VERSION="9.0.4"
ARCH=$(uname -m) # will be mapped later
INSTALL_DIR="/usr/share/dotnet"
PROFILE_SCRIPT="/etc/profile.d/dotnet.sh"
TMP_DIR="/tmp/dotnet-install"

# === Parsed options ===
SDK_VERSION="$DEFAULT_SDK_VERSION"
RUNTIME_VERSION="$DEFAULT_RUNTIME_VERSION"
ARCH_OVERRIDE=""
INSTALL_DEPS=true
INSTALL_SYMBOLS=true
INSTALL_NUPKGS=true
FORCE_DOWNLOAD=false

# === Help ===
print_help() {
  cat <<EOF
Usage: sudo ./install-dotnet.sh [OPTIONS]

Options:
  --sdk-version=VERSION       Set the .NET SDK version (default: $DEFAULT_SDK_VERSION)
  --runtime-version=VERSION   Set the .NET Runtime version (default: $DEFAULT_RUNTIME_VERSION)
  --arch=ARCH                 Override detected architecture (ppc64le or s390x)
  --skip-deps                 Skip installing system dependencies
  --skip-symbols              Skip installing debug symbols
  --skip-nupkgs               Skip extracting .nupkg files
  --force-download            Re-download all files even if they exist
  -h, --help                  Show this help message
EOF
}

# === Parse arguments ===
for arg in "$@"; do
  case $arg in
    --sdk-version=*) SDK_VERSION="${arg#*=}" ;;
    --runtime-version=*) RUNTIME_VERSION="${arg#*=}" ;;
    --arch=*) ARCH_OVERRIDE="${arg#*=}" ;;
    --skip-deps) INSTALL_DEPS=false ;;
    --skip-symbols) INSTALL_SYMBOLS=false ;;
    --skip-nupkgs) INSTALL_NUPKGS=false ;;
    --force-download) FORCE_DOWNLOAD=true ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "❌ Unknown option: $arg"; print_help; exit 1 ;;
  esac
done

# === Detect Architecture ===
normalize_arch() {
  case "$1" in
    ppc64le) echo "ppc64le" ;;
    s390x) echo "s390x" ;;
    *) echo "❌ Unsupported architecture: $1"; exit 1 ;;
  esac
}
ARCH=$(normalize_arch "${ARCH_OVERRIDE:-$ARCH}")

# === URLs & Files ===
BASE_URL="https://github.com/IBM/dotnet-s390x/releases/download/v${SDK_VERSION}"

FILES=(
  "dotnet-sdk-${SDK_VERSION}-linux-${ARCH}.tar.gz"
  "dotnet-runtime-symbols-linux-${ARCH}-${RUNTIME_VERSION}.tar.gz"
  "Microsoft.AspNetCore.App.Runtime.linux-${ARCH}.${RUNTIME_VERSION}.nupkg"
  "Microsoft.NETCore.App.Host.linux-${ARCH}.${RUNTIME_VERSION}.nupkg"
  "Microsoft.NETCore.App.Runtime.linux-${ARCH}.${RUNTIME_VERSION}.nupkg"
  "runtime.linux-${ARCH}.Microsoft.NETCore.ILAsm.${RUNTIME_VERSION}.nupkg"
  "runtime.linux-${ARCH}.Microsoft.NETCore.ILDAsm.${RUNTIME_VERSION}.nupkg"
)

# === Tasks ===

install_curl_and_unzip() {
  local updated=false
  if ! command -v curl >/dev/null 2>&1; then
    echo "📦 Installing curl..."
    apt update && apt install -y curl
    updated=true
  else
    echo "✅ curl is already installed."
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    if [ "$updated" = false ]; then
      apt update
    fi
    echo "📦 Installing unzip..."
    apt install -y unzip
  else
    echo "✅ unzip is already installed."
  fi
}

install_dependencies() {
  if [ "$INSTALL_DEPS" = true ]; then
    echo "📦 Installing native system dependencies..."
    apt update
    apt install -y curl tar libicu-dev libcurl4-openssl-dev zlib1g libssl-dev libkrb5-dev libunwind-dev gettext
  else
    echo "⚠️  Skipping dependency installation (--skip-deps)"
  fi
}

download_files() {
  echo "⬇️  Downloading .NET files for arch=$ARCH, SDK=$SDK_VERSION, Runtime=$RUNTIME_VERSION..."
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"

  for file in "${FILES[@]}"; do
    if [ "$FORCE_DOWNLOAD" = true ] || [ ! -f "$file" ]; then
      echo "📥 Downloading $file..."
      curl -LO "${BASE_URL}/$file"
    else
      echo "✅ Found $file in cache (use --force-download to refresh)"
    fi
  done
}

install_dotnet_sdk() {
  echo "📦 Installing SDK to $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
  tar -xzf "$TMP_DIR/dotnet-sdk-${SDK_VERSION}-linux-${ARCH}.tar.gz" -C "$INSTALL_DIR"
  # Create symlink to /usr/bin/dotnet
  ln -sf "$INSTALL_DIR/dotnet" /usr/bin/dotnet
}

install_runtime_symbols() {
  if [ "$INSTALL_SYMBOLS" = true ]; then
    echo "📦 Installing runtime debug symbols..."
    tar -xzf "$TMP_DIR/dotnet-runtime-symbols-linux-${ARCH}-${RUNTIME_VERSION}.tar.gz" -C "$INSTALL_DIR"
  else
    echo "⚠️  Skipping symbols (--skip-symbols)"
  fi
}

install_nupkgs() {
  if [ "$INSTALL_NUPKGS" = true ]; then
    echo "📦 Extracting .nupkg files..."
    mkdir -p "$INSTALL_DIR/nupkgs"
    for nupkg in "$TMP_DIR"/*.nupkg; do
      name="$(basename "${nupkg%.nupkg}")"
      target_dir="$INSTALL_DIR/nupkgs/$name"
      mkdir -p "$target_dir"
      unzip -q "$nupkg" -d "$target_dir"
    done
  else
    echo "⚠️  Skipping .nupkg extraction (--skip-nupkgs)"
  fi
}

setup_environment() {
  echo "⚙️  Configuring environment in $PROFILE_SCRIPT..."
  cat > "$PROFILE_SCRIPT" <<EOF
export DOTNET_ROOT=$INSTALL_DIR
export PATH=\$DOTNET_ROOT:\$PATH
EOF
  chmod +x "$PROFILE_SCRIPT"
}

verify_installation() {
  echo "🔍 Verifying installation..."
  export DOTNET_ROOT=$INSTALL_DIR
  export PATH=$DOTNET_ROOT:$PATH
  dotnet --info || echo "❌ dotnet failed to run"
}

# === Run steps ===
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script with sudo."
  exit 1
fi

install_curl_and_unzip
install_dependencies
download_files
install_dotnet_sdk
install_runtime_symbols
install_nupkgs
setup_environment
verify_installation

echo "✅ .NET installation complete!"
