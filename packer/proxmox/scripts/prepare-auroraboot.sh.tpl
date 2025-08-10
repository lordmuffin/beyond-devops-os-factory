#!/bin/bash
#
# AuroraBoot Preparation Script
# Built: ${build_timestamp}
# Purpose: Prepare system for Kairos deployment with AuroraBoot

set -euo pipefail

# Configuration
AURORABOOT_VERSION="v0.8.1"
GITHUB_REPO_DEFAULT="your-org/beyond-devops-os-factory"
DOWNLOAD_DIR="/opt/auroraboot/images"
CONFIG_DIR="/etc/auroraboot"
LOG_FILE="/var/log/auroraboot-prepare.log"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Main preparation function
prepare_auroraboot() {
    log "Starting AuroraBoot preparation..."
    
    # Create necessary directories
    sudo mkdir -p "$DOWNLOAD_DIR" "$CONFIG_DIR" "$(dirname "$LOG_FILE")"
    sudo chown "$(whoami):$(whoami)" "$DOWNLOAD_DIR" "$CONFIG_DIR"
    
    # Download AuroraBoot container image
    log "Pulling AuroraBoot container image..."
    if ! docker pull "quay.io/kairos/auroraboot:$AURORABOOT_VERSION"; then
        handle_error "Failed to pull AuroraBoot container image"
    fi
    
    # Create AuroraBoot wrapper script
    log "Creating AuroraBoot wrapper script..."
    cat > /usr/local/bin/auroraboot << 'EOF'
#!/bin/bash
# AuroraBoot wrapper script

AURORABOOT_VERSION="v0.8.1"
DOWNLOAD_DIR="/opt/auroraboot/images"
CONFIG_DIR="/etc/auroraboot"

# Default AuroraBoot command with common options
docker run --rm -ti \
    --net host \
    -v "$DOWNLOAD_DIR:/downloads" \
    -v "$CONFIG_DIR:/config" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "quay.io/kairos/auroraboot:$AURORABOOT_VERSION" \
    "$@"
EOF
    
    sudo chmod +x /usr/local/bin/auroraboot
    
    # Create GitHub release fetcher script
    log "Creating GitHub release fetcher..."
    cat > /usr/local/bin/fetch-kairos-images << 'EOF'
#!/bin/bash
# Fetch latest Kairos images from GitHub releases

set -euo pipefail

GITHUB_REPO="$${1:-$${GITHUB_REPO_DEFAULT}}"
DOWNLOAD_DIR="/opt/auroraboot/images"
VERSION="$${2:-latest}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

if [ "$VERSION" = "latest" ]; then
    log "Fetching latest release info for $GITHUB_REPO..."
    LATEST_RELEASE=$(gh release list --repo "$GITHUB_REPO" --limit 1 --json tagName,publishedAt --jq '.[0]')
    VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tagName')
    PUBLISHED_AT=$(echo "$LATEST_RELEASE" | jq -r '.publishedAt')
    log "Latest release: $VERSION (published: $PUBLISHED_AT)"
fi

log "Downloading Kairos images for version $VERSION..."

# Create version-specific directory
mkdir -p "$DOWNLOAD_DIR/$VERSION"
cd "$DOWNLOAD_DIR/$VERSION"

# Download ISO and RAW images if they exist
for ASSET_TYPE in "iso" "raw" "qcow2"; do
    log "Looking for $ASSET_TYPE assets..."
    ASSETS=$(gh release view "$VERSION" --repo "$GITHUB_REPO" --json assets --jq ".assets[] | select(.name | test(\"\\.$ASSET_TYPE$\")) | .name")
    
    for ASSET in $ASSETS; do
        if [ ! -f "$ASSET" ]; then
            log "Downloading $ASSET..."
            gh release download "$VERSION" --repo "$GITHUB_REPO" --pattern "$ASSET" --clobber
        else
            log "$ASSET already exists, skipping..."
        fi
    done
done

log "Download completed for version $VERSION"
log "Images available in: $DOWNLOAD_DIR/$VERSION"

# Create symlinks for latest version
if [ "$VERSION" != "latest" ]; then
    log "Creating symlinks for latest version..."
    cd "$DOWNLOAD_DIR"
    rm -f latest
    ln -sf "$VERSION" latest
    log "Latest symlink created: $DOWNLOAD_DIR/latest -> $VERSION"
fi
EOF
    
    sudo chmod +x /usr/local/bin/fetch-kairos-images
    
    # Create AuroraBoot deployment script
    log "Creating AuroraBoot deployment script..."
    cat > /usr/local/bin/deploy-kairos-vm << 'EOF'
#!/bin/bash
# Deploy Kairos to VM using AuroraBoot

set -euo pipefail

GITHUB_REPO="$${GITHUB_REPO:-$${GITHUB_REPO_DEFAULT}}"
VERSION="$${VERSION:-latest}"
CLOUD_CONFIG="$${CLOUD_CONFIG:-/etc/auroraboot/cloud-config.yaml}"
VM_NAME="$${VM_NAME:-kairos-vm}"
DOWNLOAD_DIR="/opt/auroraboot/images"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -r, --repo REPO       GitHub repository (default: $GITHUB_REPO)"
    echo "  -v, --version VERSION Kairos version (default: latest)"
    echo "  -c, --config CONFIG   Cloud-config file (default: $CLOUD_CONFIG)"
    echo "  -n, --name NAME       VM name (default: $VM_NAME)"
    echo "  -h, --help           Show this help"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -c|--config)
            CLOUD_CONFIG="$2"
            shift 2
            ;;
        -n|--name)
            VM_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

log "Starting Kairos deployment with AuroraBoot..."
log "Repository: $GITHUB_REPO"
log "Version: $VERSION"
log "Cloud-config: $CLOUD_CONFIG"
log "VM Name: $VM_NAME"

# Ensure images are downloaded
if [ ! -d "$DOWNLOAD_DIR/$VERSION" ] && [ ! -L "$DOWNLOAD_DIR/latest" ]; then
    log "Images not found, downloading..."
    fetch-kairos-images "$GITHUB_REPO" "$VERSION"
fi

# Find available images
IMAGE_DIR="$DOWNLOAD_DIR/$VERSION"
if [ "$VERSION" = "latest" ]; then
    IMAGE_DIR="$DOWNLOAD_DIR/latest"
fi

ISO_FILE=$(find "$IMAGE_DIR" -name "*.iso" | head -1)
RAW_FILE=$(find "$IMAGE_DIR" -name "*.raw" | head -1)

if [ -z "$ISO_FILE" ] && [ -z "$RAW_FILE" ]; then
    log "ERROR: No suitable images found in $IMAGE_DIR"
    exit 1
fi

# Prefer ISO for VM deployment
IMAGE_FILE="$${ISO_FILE:-$$RAW_FILE}"
log "Using image: $IMAGE_FILE"

# Check cloud-config exists
if [ ! -f "$CLOUD_CONFIG" ]; then
    log "WARNING: Cloud-config file not found: $CLOUD_CONFIG"
    log "Creating default cloud-config..."
    
    cat > "$CLOUD_CONFIG" << 'EOFCONFIG'
#cloud-config
hostname: kairos-vm-$$(cat /etc/machine-id | cut -c1-4)

users:
- name: kairos
  passwd: kairos
  groups:
    - admin
  ssh_authorized_keys:
  - github:your-github-username  # Replace with your GitHub username

k3s:
  enabled: true
  
install:
  auto: true
  device: "auto"
  reboot: true

p2p:
  disable_dht: false
  auto:
    enable: true
EOFCONFIG
    
    log "Default cloud-config created. Please edit $CLOUD_CONFIG as needed."
fi

# Deploy with AuroraBoot
log "Starting AuroraBoot deployment..."
auroraboot \
    --set "artifact_version=$VERSION" \
    --set "container_image=$IMAGE_FILE" \
    --cloud-config "$CLOUD_CONFIG" \
    --set "vm_name=$VM_NAME"

log "AuroraBoot deployment completed!"
EOF
    
    sudo chmod +x /usr/local/bin/deploy-kairos-vm
    
    # Create default cloud-config template
    log "Creating default cloud-config template..."
    cat > "$CONFIG_DIR/cloud-config.yaml.template" << 'EOF'
#cloud-config
hostname: kairos-$$(cat /etc/machine-id | cut -c1-4)

users:
- name: kairos
  passwd: kairos
  groups:
    - admin
    - docker
  ssh_authorized_keys:
  - github:your-github-username  # Replace with your GitHub username

# K3s configuration
k3s:
  enabled: true
  args:
  - --disable=traefik,servicelb
  - --flannel-backend=none
  - --disable-network-policy

# P2P mesh networking
p2p:
  disable_dht: false
  auto:
    enable: true
    ha:
      enable: true
      master_nodes: 1

# Installation configuration
install:
  auto: true
  device: "auto"
  reboot: true

# Enterprise monitoring
write_files:
- content: |
    #!/bin/bash
    # Health check script
    systemctl is-active k3s || exit 1
    curl -k https://localhost:6443/healthz || exit 1
    echo "Kairos node healthy"
  path: /usr/local/bin/health-check.sh
  permissions: "0755"
  owner: root:root

# Run health checks
runcmd:
- chmod +x /usr/local/bin/health-check.sh
EOF
    
    log "AuroraBoot preparation completed successfully!"
    log "Available commands:"
    log "  - auroraboot: Run AuroraBoot directly"
    log "  - fetch-kairos-images: Download Kairos images from GitHub"
    log "  - deploy-kairos-vm: Deploy Kairos VM with AuroraBoot"
    log "Configuration directory: $CONFIG_DIR"
    log "Image download directory: $DOWNLOAD_DIR"
}

# Run the main function
prepare_auroraboot "$@"