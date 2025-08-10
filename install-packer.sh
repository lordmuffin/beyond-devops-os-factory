#!/bin/bash
#
# Install Packer for macOS (avoiding Homebrew due to BUSL license)

set -euo pipefail

echo "Installing Packer v1.9.4 (last MPL version)..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    URL="https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_darwin_arm64.zip"
    echo "Detected Apple Silicon Mac"
elif [ "$ARCH" = "x86_64" ]; then
    URL="https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_darwin_amd64.zip"
    echo "Detected Intel Mac"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Create bin directory
mkdir -p ~/.local/bin

# Download and install
echo "Downloading from: $URL"
curl -L -o /tmp/packer.zip "$URL"

echo "Extracting..."
cd /tmp && unzip -o packer.zip

echo "Installing to ~/.local/bin/packer..."
mv packer ~/.local/bin/
chmod +x ~/.local/bin/packer

# Clean up
rm -f /tmp/packer.zip

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "Adding ~/.local/bin to PATH..."
    echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.zshrc
    echo "Added to ~/.zshrc"
fi

# Export for current session
export PATH="$PATH:$HOME/.local/bin"

# Test installation
if command -v packer >/dev/null 2>&1; then
    echo "✅ Packer installed successfully!"
    packer version
    echo ""
    echo "You can now run:"
    echo "  ./scripts/proxmox/deploy-kairos-vm.sh template-only --dry-run"
    echo ""
    echo "Note: If packer is not found, restart your terminal or run:"
    echo "  source ~/.zshrc"
else
    echo "❌ Installation failed - packer not found in PATH"
    echo "Please restart your terminal and try again"
fi