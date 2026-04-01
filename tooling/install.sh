#!/bin/bash
# =============================================================================
# QPKI Tool Installation Script
# Post-Quantum PKI Lab (QLAB)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

GITHUB_REPO="qpki/qpki"
INSTALL_DIR="/usr/local/bin"

echo -e "${CYAN}"
echo "=============================================="
echo "  QLAB - Post-Quantum PKI Lab"
echo "  Installing QPKI (Post-Quantum PKI) toolkit"
echo "=============================================="
echo -e "${NC}"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Detected:${NC} $OS / $ARCH"

# =============================================================================
# Check if qpki is already installed (system PATH or local fallback)
# =============================================================================

EXISTING_BIN=""
if command -v qpki &>/dev/null; then
    EXISTING_BIN="$(command -v qpki)"
elif [[ -x "$LAB_ROOT/bin/qpki" ]]; then
    EXISTING_BIN="$LAB_ROOT/bin/qpki"
fi

if [[ -n "$EXISTING_BIN" ]]; then
    INSTALLED_VERSION=$("$EXISTING_BIN" --version 2>/dev/null | awk '{print $3}')

    # Check latest version from GitHub
    LATEST_TAG=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/')

    if [[ -n "$LATEST_TAG" && "$INSTALLED_VERSION" != "$LATEST_TAG" ]]; then
        echo ""
        echo -e "${YELLOW}QPKI update available: ${INSTALLED_VERSION} → ${LATEST_TAG}${NC}"
        echo -e "${DIM}  Installed at: $EXISTING_BIN${NC}"
        echo ""
        read -p "$(echo -e "  Update now? [Y/n]: ")" response
        case "$response" in
            [nN][oO]|[nN])
                echo -e "  ${DIM}Skipped. Run ./tooling/install.sh again to update later.${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "  ${CYAN}Updating...${NC}"
                INSTALL_DIR="$(dirname "$EXISTING_BIN")"
                # Fall through to download
                ;;
        esac
    else
        echo ""
        echo -e "${GREEN}QPKI ${INSTALLED_VERSION} is up to date.${NC}"
        echo -e "${DIM}  Location: $EXISTING_BIN${NC}"
        echo ""
        exit 0
    fi
fi

# =============================================================================
# Download pre-built binary from GitHub releases
# =============================================================================

VERSION="${PKI_VERSION:-latest}"

echo ""
echo -e "${CYAN}Downloading QPKI from GitHub Releases...${NC}"
echo ""

# Get version tag
if [[ "$VERSION" == "latest" ]]; then
    RELEASE_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    VERSION_TAG=$(curl -s "$RELEASE_URL" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
else
    VERSION_TAG="$VERSION"
fi

if [[ -z "$VERSION_TAG" ]]; then
    echo -e "${RED}Failed to get version from GitHub API${NC}"
    show_manual_instructions
    exit 1
fi

# Remove 'v' prefix for filename (v0.13.0 -> 0.13.0)
VERSION_NUM="${VERSION_TAG#v}"

echo -e "Version: ${GREEN}$VERSION_TAG${NC}"

# Build download URL
BINARY_NAME="qpki_${VERSION_NUM}_${OS}_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$VERSION_TAG/$BINARY_NAME"

echo -e "Downloading: $BINARY_NAME"

# Download and extract
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if curl -sL --fail -o "$TEMP_DIR/$BINARY_NAME" "$DOWNLOAD_URL"; then
    echo -e "Extracting..."
    tar xzf "$TEMP_DIR/$BINARY_NAME" -C "$TEMP_DIR"

    if [[ ! -f "$TEMP_DIR/qpki" ]]; then
        echo -e "${RED}Binary not found in archive${NC}"
        exit 1
    fi

    # Install to INSTALL_DIR, fallback to qlab/bin if no write access
    if [[ -w "$INSTALL_DIR" ]] || [[ ! -d "$INSTALL_DIR" && -w "$(dirname "$INSTALL_DIR")" ]]; then
        mkdir -p "$INSTALL_DIR"
        mv "$TEMP_DIR/qpki" "$INSTALL_DIR/qpki"
        chmod +x "$INSTALL_DIR/qpki"
    elif command -v sudo &>/dev/null; then
        echo -e "${DIM}  Writing to $INSTALL_DIR requires elevated privileges...${NC}"
        sudo mkdir -p "$INSTALL_DIR"
        sudo mv "$TEMP_DIR/qpki" "$INSTALL_DIR/qpki"
        sudo chmod +x "$INSTALL_DIR/qpki"
    else
        echo -e "${YELLOW}Cannot write to $INSTALL_DIR, installing to $LAB_ROOT/bin/ instead${NC}"
        INSTALL_DIR="$LAB_ROOT/bin"
        mkdir -p "$INSTALL_DIR"
        mv "$TEMP_DIR/qpki" "$INSTALL_DIR/qpki"
        chmod +x "$INSTALL_DIR/qpki"
    fi

    echo ""
    echo -e "${GREEN}=============================================="
    echo "  QPKI installed successfully!"
    echo "=============================================="
    echo -e "${NC}"
    echo ""
    "$INSTALL_DIR/qpki" --version 2>/dev/null || true
    echo ""
    echo -e "Binary location: ${CYAN}$INSTALL_DIR/qpki${NC}"
    echo ""
    echo -e "You can now run the demos:"
    echo -e "  ${CYAN}./journey/00-revelation/demo.sh${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}Download failed${NC}"
fi

# =============================================================================
# Fallback: Manual instructions
# =============================================================================

echo ""
echo -e "${YELLOW}=============================================="
echo "  Download failed - Manual installation required"
echo "=============================================="
echo -e "${NC}"
echo ""
echo "To use QLAB, you need to build QPKI from source:"
echo ""
echo "  1. Clone the QPKI repository:"
echo -e "     ${CYAN}git clone https://github.com/$GITHUB_REPO.git${NC}"
echo ""
echo "  2. Build and install:"
echo -e "     ${CYAN}cd qpki && make install${NC}"
echo ""
echo "  3. Run this script again to verify:"
echo -e "     ${CYAN}./tooling/install.sh${NC}"
echo ""

exit 1
