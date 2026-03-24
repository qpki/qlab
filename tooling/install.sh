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
NC='\033[0m'

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
# Check if binary already exists
# =============================================================================

if [[ -x "$LAB_ROOT/bin/qpki" ]]; then
    echo ""
    echo -e "${GREEN}QPKI tool already installed at: $LAB_ROOT/bin/qpki${NC}"
    echo ""
    "$LAB_ROOT/bin/qpki" --version 2>/dev/null || echo -e "${YELLOW}(version check not available)${NC}"
    echo ""
    echo -e "To rebuild from source, remove the binary first:"
    echo -e "  ${CYAN}rm $LAB_ROOT/bin/qpki && ./tooling/install.sh${NC}"
    echo ""
    exit 0
fi

# =============================================================================
# Download pre-built binary from GitHub releases
# =============================================================================

GITHUB_REPO="qpki/qpki"
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

# Create bin directory
mkdir -p "$LAB_ROOT/bin"

# Download and extract
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if curl -sL --fail -o "$TEMP_DIR/$BINARY_NAME" "$DOWNLOAD_URL"; then
    echo -e "Extracting..."
    tar xzf "$TEMP_DIR/$BINARY_NAME" -C "$TEMP_DIR"

    # Find and install the binary
    if [[ -f "$TEMP_DIR/qpki" ]]; then
        mv "$TEMP_DIR/qpki" "$LAB_ROOT/bin/qpki"
        chmod +x "$LAB_ROOT/bin/qpki"

        echo ""
        echo -e "${GREEN}=============================================="
        echo "  QPKI installed successfully!"
        echo "=============================================="
        echo -e "${NC}"
        echo ""
        "$LAB_ROOT/bin/qpki" --version 2>/dev/null || true
        echo ""
        echo -e "Binary location: ${CYAN}$LAB_ROOT/bin/qpki${NC}"
        echo ""
        echo -e "You can now run the demos:"
        echo -e "  ${CYAN}./journey/00-revelation/demo.sh${NC}"
        echo ""
        exit 0
    else
        echo -e "${RED}Binary not found in archive${NC}"
    fi
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
echo "  2. Build the binary:"
echo -e "     ${CYAN}cd qpki && go build -o ../qlab/bin/qpki ./cmd/qpki${NC}"
echo ""
echo "  3. Run this script again to verify:"
echo -e "     ${CYAN}./tooling/install.sh${NC}"
echo ""

exit 1
