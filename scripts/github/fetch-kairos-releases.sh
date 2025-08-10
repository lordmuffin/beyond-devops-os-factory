#!/bin/bash
#
# GitHub Kairos Release Fetcher
# Fetches Kairos images from GitHub releases for AuroraBoot deployment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$PROJECT_ROOT/images/kairos}"
GITHUB_REPO="${GITHUB_REPO:-your-org/beyond-devops-os-factory}"
LOG_FILE="${LOG_FILE:-/tmp/fetch-kairos-releases.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
GitHub Kairos Release Fetcher

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -r, --repo REPO          GitHub repository (default: $GITHUB_REPO)
    -v, --version VERSION    Specific version to download (default: latest)
    -d, --dir DIRECTORY      Download directory (default: $DOWNLOAD_DIR)
    -t, --types TYPES        Image types to download (default: iso,raw,qcow2)
    -l, --list              List available releases
    -c, --cleanup           Clean old releases (keep latest 3)
    -f, --force             Force re-download existing files
    -q, --quiet             Quiet mode (minimal output)
    -h, --help              Show this help

EXAMPLES:
    # Download latest release
    $0

    # Download specific version
    $0 --version v1.2.0

    # List available releases
    $0 --list

    # Download only ISO files
    $0 --types iso

    # Download to custom directory
    $0 --dir /opt/kairos/images

ENVIRONMENT VARIABLES:
    GITHUB_REPO            GitHub repository (format: owner/repo)
    GITHUB_TOKEN           GitHub personal access token
    DOWNLOAD_DIR           Default download directory
    LOG_FILE              Log file location

EOF
}

# Check dependencies
check_dependencies() {
    local deps=("gh" "jq" "curl" "wget")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log "Please install missing dependencies and try again"
        exit 1
    fi
}

# Authenticate with GitHub
authenticate_github() {
    if ! gh auth status >/dev/null 2>&1; then
        log "GitHub CLI not authenticated. Please run 'gh auth login' first"
        if [ -n "${GITHUB_TOKEN:-}" ]; then
            log "Using GITHUB_TOKEN environment variable"
            echo "$GITHUB_TOKEN" | gh auth login --with-token
        else
            handle_error "GitHub authentication required"
        fi
    fi
}

# List available releases
list_releases() {
    log "Listing releases for $GITHUB_REPO..."
    
    if ! gh release list --repo "$GITHUB_REPO" --limit 20 --json tagName,name,publishedAt,isLatest --template '
{{- range . -}}
{{- if .isLatest }}[LATEST] {{ end }}{{ .tagName | printf "%-15s" }} {{ .name | printf "%-40s" }} {{ .publishedAt | timeago }}
{{ end -}}'; then
        handle_error "Failed to list releases for $GITHUB_REPO"
    fi
}

# Get release information
get_release_info() {
    local version="$1"
    
    if [ "$version" = "latest" ]; then
        log "Getting latest release info for $GITHUB_REPO..."
        if ! gh release view --repo "$GITHUB_REPO" --json tagName,name,publishedAt,assets 2>/dev/null; then
            handle_error "Failed to get latest release info"
        fi
    else
        log "Getting release info for $version..."
        if ! gh release view "$version" --repo "$GITHUB_REPO" --json tagName,name,publishedAt,assets 2>/dev/null; then
            handle_error "Failed to get release info for $version"
        fi
    fi
}

# Download release assets
download_assets() {
    local version="$1"
    local asset_types="$2"
    local force_download="$3"
    
    # Create version directory
    local version_dir="$DOWNLOAD_DIR/$version"
    mkdir -p "$version_dir"
    
    log "Downloading assets to $version_dir..."
    
    # Get release info
    local release_info
    release_info=$(get_release_info "$version")
    
    # Extract actual version tag
    local actual_version
    actual_version=$(echo "$release_info" | jq -r '.tagName')
    
    # Update version directory if needed
    if [ "$version" = "latest" ]; then
        version_dir="$DOWNLOAD_DIR/$actual_version"
        mkdir -p "$version_dir"
        log "Actual version: $actual_version"
    fi
    
    # Parse asset types
    IFS=',' read -ra TYPES <<< "$asset_types"
    
    # Download matching assets
    local downloaded_count=0
    local skipped_count=0
    
    for asset_type in "${TYPES[@]}"; do
        log "Looking for $asset_type assets..."
        
        # Get matching assets using jq
        local matching_assets
        matching_assets=$(echo "$release_info" | jq -r --arg type "$asset_type" '.assets[] | select(.name | test("\\." + $type + "$")) | .name')
        
        if [ -z "$matching_assets" ]; then
            log_warning "No $asset_type assets found for $actual_version"
            continue
        fi
        
        # Download each matching asset
        while read -r asset_name; do
            [ -z "$asset_name" ] && continue
            
            local asset_path="$version_dir/$asset_name"
            
            # Check if file exists and skip if not forcing
            if [ -f "$asset_path" ] && [ "$force_download" = "false" ]; then
                log "Asset already exists: $asset_name (use --force to re-download)"
                ((skipped_count++))
                continue
            fi
            
            log "Downloading: $asset_name"
            
            # Download using gh CLI
            if gh release download "$actual_version" --repo "$GITHUB_REPO" --pattern "$asset_name" --dir "$version_dir" --clobber; then
                log_success "Downloaded: $asset_name"
                ((downloaded_count++))
                
                # Verify download
                if [ -f "$asset_path" ]; then
                    local file_size
                    file_size=$(du -h "$asset_path" | cut -f1)
                    log "File size: $file_size"
                else
                    log_warning "Downloaded file not found: $asset_path"
                fi
            else
                log_error "Failed to download: $asset_name"
            fi
            
        done <<< "$matching_assets"
    done
    
    # Create/update latest symlink
    if [ "$version" = "latest" ] || [ "$actual_version" != "$version" ]; then
        local latest_link="$DOWNLOAD_DIR/latest"
        if [ -L "$latest_link" ]; then
            rm -f "$latest_link"
        fi
        ln -sf "$actual_version" "$latest_link"
        log "Updated latest symlink: latest -> $actual_version"
    fi
    
    # Summary
    log_success "Download completed!"
    log "Downloaded: $downloaded_count assets"
    log "Skipped: $skipped_count assets"
    log "Location: $version_dir"
    
    # List downloaded files
    if [ -d "$version_dir" ]; then
        log "Downloaded files:"
        find "$version_dir" -type f -exec ls -lh {} \; | while read -r line; do
            log "  $line"
        done
    fi
}

# Cleanup old releases
cleanup_old_releases() {
    local keep_count=3
    
    log "Cleaning up old releases (keeping latest $keep_count)..."
    
    # Get sorted list of version directories (excluding symlinks)
    local version_dirs
    version_dirs=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type d -name "v*" | sort -V | head -n -$keep_count)
    
    if [ -z "$version_dirs" ]; then
        log "No old releases to clean up"
        return
    fi
    
    while read -r dir; do
        [ -z "$dir" ] && continue
        
        local version_name
        version_name=$(basename "$dir")
        log "Removing old release: $version_name"
        rm -rf "$dir"
    done <<< "$version_dirs"
    
    log_success "Cleanup completed"
}

# Generate deployment script
generate_deployment_script() {
    local version="$1"
    local script_path="$DOWNLOAD_DIR/deploy-$version.sh"
    
    log "Generating deployment script: $script_path"
    
    cat > "$script_path" << EOF
#!/bin/bash
# Auto-generated deployment script for Kairos $version
# Generated: $(date)

set -euo pipefail

KAIROS_VERSION="$version"
IMAGE_DIR="$DOWNLOAD_DIR/$version"
CLOUD_CONFIG="\${CLOUD_CONFIG:-./auroraboot/cloud-config.yaml}"

echo "Deploying Kairos \$KAIROS_VERSION with AuroraBoot..."

# Find available images
ISO_FILE=\$(find "\$IMAGE_DIR" -name "*.iso" | head -1)
RAW_FILE=\$(find "\$IMAGE_DIR" -name "*.raw" | head -1)
QCOW2_FILE=\$(find "\$IMAGE_DIR" -name "*.qcow2" | head -1)

if [ -z "\$ISO_FILE" ] && [ -z "\$RAW_FILE" ] && [ -z "\$QCOW2_FILE" ]; then
    echo "ERROR: No suitable images found in \$IMAGE_DIR"
    exit 1
fi

# Prefer ISO for bootable deployment
IMAGE_FILE="\${ISO_FILE:-\${RAW_FILE:-\$QCOW2_FILE}}"
echo "Using image: \$IMAGE_FILE"

# Check for cloud-config
if [ ! -f "\$CLOUD_CONFIG" ]; then
    echo "WARNING: Cloud-config not found: \$CLOUD_CONFIG"
    echo "Please create a cloud-config file for deployment"
    exit 1
fi

# Deploy with AuroraBoot
echo "Starting AuroraBoot deployment..."
docker run --rm -ti \\
    --net host \\
    -v "\$(dirname "\$IMAGE_FILE"):/images" \\
    -v "\$(dirname "\$CLOUD_CONFIG"):/config" \\
    -v /var/run/docker.sock:/var/run/docker.sock \\
    quay.io/kairos/auroraboot:v0.8.1 \\
    --set "container_image=/images/\$(basename "\$IMAGE_FILE")" \\
    --cloud-config "/config/\$(basename "\$CLOUD_CONFIG")"

echo "Deployment completed!"
EOF
    
    chmod +x "$script_path"
    log_success "Deployment script created: $script_path"
}

# Main function
main() {
    local version="latest"
    local asset_types="iso,raw,qcow2"
    local force_download="false"
    local list_only="false"
    local cleanup_mode="false"
    local quiet_mode="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            -v|--version)
                version="$2"
                shift 2
                ;;
            -d|--dir)
                DOWNLOAD_DIR="$2"
                shift 2
                ;;
            -t|--types)
                asset_types="$2"
                shift 2
                ;;
            -l|--list)
                list_only="true"
                shift
                ;;
            -c|--cleanup)
                cleanup_mode="true"
                shift
                ;;
            -f|--force)
                force_download="true"
                shift
                ;;
            -q|--quiet)
                quiet_mode="true"
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
    
    # Quiet mode setup
    if [ "$quiet_mode" = "true" ]; then
        exec 1>/dev/null
    fi
    
    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"
    
    # Initialize log
    log "Starting GitHub Kairos Release Fetcher"
    log "Repository: $GITHUB_REPO"
    log "Download directory: $DOWNLOAD_DIR"
    
    # Check dependencies
    check_dependencies
    
    # Authenticate with GitHub
    authenticate_github
    
    # Handle different modes
    if [ "$list_only" = "true" ]; then
        list_releases
        exit 0
    fi
    
    if [ "$cleanup_mode" = "true" ]; then
        cleanup_old_releases
        exit 0
    fi
    
    # Download assets
    download_assets "$version" "$asset_types" "$force_download"
    
    # Generate deployment script
    generate_deployment_script "$version"
    
    log_success "All operations completed successfully!"
}

# Run main function with all arguments
main "$@"