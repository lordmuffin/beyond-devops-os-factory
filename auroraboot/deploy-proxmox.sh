#!/bin/bash
#
# AuroraBoot Proxmox Deployment Script
# Deploys Kairos OS to Proxmox VMs using AuroraBoot

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.yaml}"
CLOUD_CONFIG="${CLOUD_CONFIG:-$SCRIPT_DIR/cloud-config.yaml}"
IMAGES_DIR="${IMAGES_DIR:-$PROJECT_ROOT/images/kairos}"
LOG_FILE="${LOG_FILE:-/tmp/auroraboot-proxmox-deploy.log}"

# Default values
GITHUB_REPO="${GITHUB_REPO:-your-org/beyond-devops-os-factory}"
KAIROS_VERSION="${KAIROS_VERSION:-latest}"
AURORABOOT_VERSION="${AURORABOOT_VERSION:-v0.8.1}"
VM_NAME="${VM_NAME:-kairos-proxmox}"
DEPLOYMENT_METHOD="${DEPLOYMENT_METHOD:-iso}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log_error "$1"
    exit 1
}

# Help function
show_help() {
    cat << EOF
AuroraBoot Proxmox Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -r, --repo REPO          GitHub repository (default: $GITHUB_REPO)
    -v, --version VERSION    Kairos version to deploy (default: $KAIROS_VERSION)
    -n, --name NAME          VM name (default: $VM_NAME)
    -m, --method METHOD      Deployment method: iso, network, hybrid (default: $DEPLOYMENT_METHOD)
    -c, --config FILE        AuroraBoot config file (default: $CONFIG_FILE)
    --cloud-config FILE      Cloud-config file (default: $CLOUD_CONFIG)
    -i, --images-dir DIR     Images directory (default: $IMAGES_DIR)
    --auroraboot-version VER AuroraBoot version (default: $AURORABOOT_VERSION)
    --fetch-only             Only fetch images, don't deploy
    --deploy-only            Only deploy (skip image fetch)
    --dry-run                Show commands without executing
    -h, --help               Show this help

DEPLOYMENT METHODS:
    iso      - Boot from ISO image (recommended for VMs)
    network  - PXE network boot
    hybrid   - Try network first, fallback to ISO

EXAMPLES:
    # Deploy latest Kairos version
    $0

    # Deploy specific version with custom VM name
    $0 --version v1.2.0 --name kairos-prod

    # Network deployment
    $0 --method network

    # Fetch images only
    $0 --fetch-only

    # Deploy with custom configuration
    $0 --config ./custom-config.yaml --cloud-config ./custom-cloud-config.yaml

ENVIRONMENT VARIABLES:
    GITHUB_REPO             GitHub repository for Kairos images
    KAIROS_VERSION          Kairos version to deploy
    AURORABOOT_VERSION      AuroraBoot container version
    VM_NAME                 Target VM name
    DEPLOYMENT_METHOD       Deployment method
    CONFIG_FILE             AuroraBoot configuration file
    CLOUD_CONFIG            Cloud-config file path
    IMAGES_DIR              Directory for Kairos images
    LOG_FILE                Log file location

EOF
}

# Check dependencies
check_dependencies() {
    local deps=("docker" "jq" "yq" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log "Please install missing dependencies:"
        for dep in "${missing[@]}"; do
            case $dep in
                docker)
                    log "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                jq)
                    log "  - jq: sudo apt install jq"
                    ;;
                yq)
                    log "  - yq: sudo apt install yq"
                    ;;
                curl)
                    log "  - curl: sudo apt install curl"
                    ;;
            esac
        done
        exit 1
    fi
}

# Validate configuration files
validate_configuration() {
    log "Validating configuration files..."
    
    # Check AuroraBoot config
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "AuroraBoot config not found: $CONFIG_FILE"
        log "Creating default configuration..."
        create_default_config
    else
        log "AuroraBoot config: $CONFIG_FILE"
        # Validate YAML syntax
        if ! yq eval '.' "$CONFIG_FILE" >/dev/null 2>&1; then
            handle_error "Invalid YAML syntax in $CONFIG_FILE"
        fi
    fi
    
    # Check cloud-config
    if [ ! -f "$CLOUD_CONFIG" ]; then
        handle_error "Cloud-config file not found: $CLOUD_CONFIG"
    else
        log "Cloud-config: $CLOUD_CONFIG"
        # Validate YAML syntax
        if ! yq eval '.' "$CLOUD_CONFIG" >/dev/null 2>&1; then
            handle_error "Invalid YAML syntax in $CLOUD_CONFIG"
        fi
    fi
    
    log_success "Configuration validation completed"
}

# Create default AuroraBoot configuration
create_default_config() {
    log "Creating default AuroraBoot configuration at $CONFIG_FILE"
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    cat > "$CONFIG_FILE" << EOF
artifact_version: "$KAIROS_VERSION"
github_repository: "$GITHUB_REPO"
deployment_method: "$DEPLOYMENT_METHOD"
vm_name: "$VM_NAME"
cloud_config_file: "$CLOUD_CONFIG"
container_image: "quay.io/kairos/auroraboot:$AURORABOOT_VERSION"
EOF
    
    log_success "Default configuration created"
}

# Pull AuroraBoot container
pull_auroraboot_container() {
    log "Pulling AuroraBoot container: quay.io/kairos/auroraboot:$AURORABOOT_VERSION"
    
    if docker pull "quay.io/kairos/auroraboot:$AURORABOOT_VERSION"; then
        log_success "AuroraBoot container pulled successfully"
    else
        handle_error "Failed to pull AuroraBoot container"
    fi
}

# Fetch Kairos images
fetch_kairos_images() {
    log "Fetching Kairos images for version $KAIROS_VERSION..."
    
    # Use the fetch script if available
    local fetch_script="$PROJECT_ROOT/scripts/github/fetch-kairos-releases.sh"
    if [ -f "$fetch_script" ]; then
        log "Using fetch script: $fetch_script"
        if "$fetch_script" --repo "$GITHUB_REPO" --version "$KAIROS_VERSION" --dir "$IMAGES_DIR"; then
            log_success "Images fetched successfully using fetch script"
        else
            log_warning "Fetch script failed, trying alternative method..."
            fetch_images_alternative
        fi
    else
        log "Fetch script not found, using alternative method"
        fetch_images_alternative
    fi
}

# Alternative image fetch method
fetch_images_alternative() {
    log "Fetching images using AuroraBoot..."
    
    mkdir -p "$IMAGES_DIR/$KAIROS_VERSION"
    
    # Use AuroraBoot to download images
    docker run --rm \
        -v "$IMAGES_DIR:/downloads" \
        -v "$SCRIPT_DIR:/config" \
        "quay.io/kairos/auroraboot:$AURORABOOT_VERSION" \
        --set "artifact_version=$KAIROS_VERSION" \
        --set "github_repository=$GITHUB_REPO" \
        --download-only \
        --output-dir "/downloads/$KAIROS_VERSION"
    
    log_success "Images downloaded using AuroraBoot"
}

# Find suitable image for deployment
find_deployment_image() {
    local version_dir="$IMAGES_DIR/$KAIROS_VERSION"
    
    # Handle 'latest' version
    if [ "$KAIROS_VERSION" = "latest" ] && [ -L "$IMAGES_DIR/latest" ]; then
        version_dir="$IMAGES_DIR/latest"
        local actual_version
        actual_version=$(readlink "$IMAGES_DIR/latest")
        log "Latest version resolves to: $actual_version"
    fi
    
    if [ ! -d "$version_dir" ]; then
        handle_error "Version directory not found: $version_dir"
    fi
    
    # Find images based on deployment method
    case $DEPLOYMENT_METHOD in
        iso|hybrid)
            # Prefer ISO for VM deployment
            local iso_file
            iso_file=$(find "$version_dir" -name "*.iso" | head -1)
            if [ -n "$iso_file" ]; then
                echo "$iso_file"
                return 0
            fi
            
            if [ "$DEPLOYMENT_METHOD" = "hybrid" ]; then
                log_warning "No ISO found, looking for RAW image..."
                local raw_file
                raw_file=$(find "$version_dir" -name "*.raw" | head -1)
                if [ -n "$raw_file" ]; then
                    echo "$raw_file"
                    return 0
                fi
            fi
            ;;
        network)
            # For network boot, we need kernel and initrd
            local kernel_file initrd_file
            kernel_file=$(find "$version_dir" -name "*kernel*" -o -name "*vmlinuz*" | head -1)
            initrd_file=$(find "$version_dir" -name "*initrd*" -o -name "*initramfs*" | head -1)
            
            if [ -n "$kernel_file" ] && [ -n "$initrd_file" ]; then
                echo "$kernel_file $initrd_file"
                return 0
            fi
            ;;
    esac
    
    handle_error "No suitable image found for deployment method: $DEPLOYMENT_METHOD"
}

# Deploy with AuroraBoot
deploy_with_auroraboot() {
    local dry_run="$1"
    
    log "Starting AuroraBoot deployment..."
    log "Method: $DEPLOYMENT_METHOD"
    log "VM Name: $VM_NAME"
    log "Version: $KAIROS_VERSION"
    
    # Find deployment image
    local image_file
    image_file=$(find_deployment_image)
    log "Using image: $image_file"
    
    # Prepare deployment command
    local cmd_args=(
        "docker" "run" "--rm" "-ti"
        "--net" "host"
        "-v" "$IMAGES_DIR:/images"
        "-v" "$SCRIPT_DIR:/config"
        "-v" "/var/run/docker.sock:/var/run/docker.sock"
        "quay.io/kairos/auroraboot:$AURORABOOT_VERSION"
    )
    
    # Add deployment-specific arguments
    case $DEPLOYMENT_METHOD in
        iso)
            cmd_args+=(
                "--set" "container_image=/images/$(basename "$image_file")"
                "--cloud-config" "/config/$(basename "$CLOUD_CONFIG")"
                "build-iso"
                "--name" "$VM_NAME"
            )
            ;;
        network)
            cmd_args+=(
                "--cloud-config" "/config/$(basename "$CLOUD_CONFIG")"
                "--set" "artifact_version=$KAIROS_VERSION"
            )
            ;;
        hybrid)
            # Try network first, then ISO
            cmd_args+=(
                "--set" "container_image=/images/$(basename "$image_file")"
                "--cloud-config" "/config/$(basename "$CLOUD_CONFIG")"
                "--set" "deployment_method=hybrid"
            )
            ;;
    esac
    
    # Execute deployment
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would execute:"
        echo "${cmd_args[*]}"
    else
        log "Executing AuroraBoot deployment..."
        if "${cmd_args[@]}"; then
            log_success "AuroraBoot deployment completed successfully"
        else
            handle_error "AuroraBoot deployment failed"
        fi
    fi
}

# Post-deployment verification
verify_deployment() {
    log "Performing post-deployment verification..."
    
    # Check if VM is accessible (this would need Proxmox API integration)
    log "Note: Manual verification required for Proxmox VM"
    log "Please check:"
    log "  1. VM boot status in Proxmox console"
    log "  2. Network connectivity to VM"
    log "  3. K3s cluster status"
    log "  4. Health check script execution"
    
    # Generate verification commands
    cat << EOF

MANUAL VERIFICATION STEPS:

1. Check VM in Proxmox:
   - Open Proxmox web interface
   - Navigate to VM "$VM_NAME"
   - Check console for boot messages

2. SSH to VM (once network is up):
   ssh kairos@<vm-ip>

3. Check K3s status:
   sudo systemctl status k3s
   kubectl get nodes

4. Run health check:
   sudo /usr/local/bin/proxmox-health-check.sh

5. Check logs:
   sudo journalctl -u k3s -f
   sudo tail -f /var/log/auroraboot.log

EOF
    
    log_success "Verification information provided"
}

# Cleanup function
cleanup() {
    log "Performing cleanup..."
    
    # Remove temporary files
    # docker system prune -f >/dev/null 2>&1 || true
    
    log "Cleanup completed"
}

# Main function
main() {
    local fetch_only="false"
    local deploy_only="false"
    local dry_run="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            -v|--version)
                KAIROS_VERSION="$2"
                shift 2
                ;;
            -n|--name)
                VM_NAME="$2"
                shift 2
                ;;
            -m|--method)
                DEPLOYMENT_METHOD="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --cloud-config)
                CLOUD_CONFIG="$2"
                shift 2
                ;;
            -i|--images-dir)
                IMAGES_DIR="$2"
                shift 2
                ;;
            --auroraboot-version)
                AURORABOOT_VERSION="$2"
                shift 2
                ;;
            --fetch-only)
                fetch_only="true"
                shift
                ;;
            --deploy-only)
                deploy_only="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Setup signal handling
    trap cleanup EXIT
    
    # Initialize log
    log "AuroraBoot Proxmox Deployment starting..."
    log "Repository: $GITHUB_REPO"
    log "Version: $KAIROS_VERSION"
    log "VM Name: $VM_NAME"
    log "Method: $DEPLOYMENT_METHOD"
    log "Images directory: $IMAGES_DIR"
    
    # Check dependencies
    check_dependencies
    
    # Validate configuration
    validate_configuration
    
    # Pull AuroraBoot container
    pull_auroraboot_container
    
    # Fetch images (unless deploy-only)
    if [ "$deploy_only" != "true" ]; then
        fetch_kairos_images
    fi
    
    # Deploy (unless fetch-only)
    if [ "$fetch_only" != "true" ]; then
        deploy_with_auroraboot "$dry_run"
        
        if [ "$dry_run" != "true" ]; then
            verify_deployment
        fi
    fi
    
    log_success "AuroraBoot Proxmox deployment process completed!"
}

# Run main function with all arguments
main "$@"