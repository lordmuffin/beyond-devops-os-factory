#!/bin/bash
#
# Comprehensive Proxmox VM Deployment Script for Kairos
# Combines Terraform, Packer, and AuroraBoot for complete automation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/proxmox"
AURORABOOT_DIR="$PROJECT_ROOT/auroraboot"
PACKER_DIR="$PROJECT_ROOT/packer/proxmox"

# Default values
VM_NAME="${VM_NAME:-kairos-vm-$(date +%Y%m%d-%H%M%S)}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
KAIROS_VERSION="${KAIROS_VERSION:-latest}"
GITHUB_REPO="${GITHUB_REPO:-your-org/beyond-devops-os-factory}"
LOG_FILE="${LOG_FILE:-/tmp/deploy-kairos-vm.log}"

# Colors
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
Comprehensive Proxmox VM Deployment Script for Kairos

USAGE:
    $0 [OPTIONS] COMMAND

COMMANDS:
    full-deploy      Complete deployment (template + VM + Kairos)
    template-only    Build Packer template only
    vm-only          Deploy VM using Terraform only
    kairos-only      Deploy Kairos using AuroraBoot only
    cleanup          Clean up resources
    status           Show deployment status

OPTIONS:
    -n, --name NAME          VM name (default: auto-generated)
    -r, --repo REPO          GitHub repository (default: $GITHUB_REPO)
    -v, --version VERSION    Kairos version (default: $KAIROS_VERSION)
    --proxmox-node NODE      Proxmox node (default: $PROXMOX_NODE)
    --tf-vars FILE           Terraform variables file
    --packer-vars FILE       Packer variables file
    --cloud-config FILE      Cloud-config file for AuroraBoot
    --dry-run                Show commands without executing
    --force                  Force overwrite existing resources
    --skip-template          Skip Packer template build
    --skip-fetch             Skip fetching Kairos images
    -h, --help               Show this help

DEPLOYMENT STAGES:
    1. Packer Template Build  - Creates base VM template with AuroraBoot support
    2. Image Fetching        - Downloads latest Kairos images from GitHub
    3. Terraform VM Deploy   - Creates VM from template using Terraform
    4. AuroraBoot Install    - Installs Kairos OS using AuroraBoot

EXAMPLES:
    # Complete deployment
    $0 full-deploy --name kairos-prod

    # Build template only
    $0 template-only

    # Deploy VM with custom configuration
    $0 vm-only --tf-vars ./custom.tfvars

    # Install Kairos on existing VM
    $0 kairos-only --name existing-vm

    # Dry run full deployment
    $0 full-deploy --dry-run

ENVIRONMENT VARIABLES:
    PROXMOX_API_URL          Proxmox API URL
    PROXMOX_API_TOKEN        Proxmox API token
    PROXMOX_NODE             Proxmox node name
    GITHUB_REPO              GitHub repository
    KAIROS_VERSION           Kairos version
    VM_NAME                  VM name

EOF
}

# Check dependencies
check_dependencies() {
    local deps=("terraform" "packer" "docker" "jq" "yq")
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
                terraform)
                    log "  - Terraform: https://developer.hashicorp.com/terraform/downloads"
                    ;;
                packer)
                    log "  - Packer: https://developer.hashicorp.com/packer/downloads"
                    ;;
                docker)
                    log "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                jq)
                    log "  - jq: sudo apt install jq"
                    ;;
                yq)
                    log "  - yq: sudo apt install yq"
                    ;;
            esac
        done
        exit 1
    fi
}

# Validate Proxmox configuration
validate_proxmox_config() {
    log "Validating Proxmox configuration..."
    
    # Check required environment variables
    local required_vars=("PROXMOX_API_URL" "PROXMOX_API_TOKEN")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log "Please set the following environment variables:"
        log "  export PROXMOX_API_URL='https://your-proxmox:8006/api2/json'"
        log "  export PROXMOX_API_TOKEN='user@realm!token=secret'"
        exit 1
    fi
    
    # Test Proxmox connectivity
    log "Testing Proxmox API connectivity..."
    if ! curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" "${PROXMOX_API_URL}/version" >/dev/null; then
        log_error "Failed to connect to Proxmox API"
        log "Please check PROXMOX_API_URL and PROXMOX_API_TOKEN"
        exit 1
    fi
    
    log_success "Proxmox configuration validated"
}

# Build Packer template
build_packer_template() {
    local dry_run="$1"
    local force="$2"
    
    log "Building Packer template for Kairos base..."
    
    cd "$PACKER_DIR"
    
    # Check if template already exists
    if [ "$force" != "true" ]; then
        # TODO: Add check for existing template
        log "Checking for existing template..."
    fi
    
    # Clean up any old terraform.tfvars files that might confuse Packer
    rm -f "$PACKER_DIR/terraform.tfvars"
    
    # Prepare Packer variables
    local packer_vars_file="$PACKER_DIR/build.pkrvars.hcl"
    log "Creating Packer variables file..."
    cat > "$packer_vars_file" << EOF
proxmox_api_url = "$PROXMOX_API_URL"
proxmox_api_token_id = "$(echo "$PROXMOX_API_TOKEN" | cut -d'=' -f1)"
proxmox_api_token_secret = "$(echo "$PROXMOX_API_TOKEN" | cut -d'=' -f2)"
proxmox_node = "$PROXMOX_NODE"
ssh_username = "packer"
ssh_password = "packer"
vm_name = "kairos-base-template"
EOF
    
    # Build template
    local packer_cmd=(
        "packer" "build"
        "-var-file=$packer_vars_file"
        "kairos-base.pkr.hcl"
    )
    
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would execute:"
        echo "cd $PACKER_DIR && ${packer_cmd[*]}"
    else
        log "Executing Packer build..."
        if "${packer_cmd[@]}"; then
            log_success "Packer template built successfully"
        else
            handle_error "Packer build failed"
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Fetch Kairos images
fetch_kairos_images() {
    local dry_run="$1"
    
    log "Fetching Kairos images for version $KAIROS_VERSION..."
    
    local fetch_script="$PROJECT_ROOT/scripts/github/fetch-kairos-releases.sh"
    if [ ! -f "$fetch_script" ]; then
        handle_error "Fetch script not found: $fetch_script"
    fi
    
    local fetch_cmd=(
        "$fetch_script"
        "--repo" "$GITHUB_REPO"
        "--version" "$KAIROS_VERSION"
        "--dir" "$PROJECT_ROOT/images/kairos"
    )
    
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would execute:"
        echo "${fetch_cmd[*]}"
    else
        if "${fetch_cmd[@]}"; then
            log_success "Kairos images fetched successfully"
        else
            handle_error "Failed to fetch Kairos images"
        fi
    fi
}

# Deploy VM with Terraform
deploy_vm_terraform() {
    local dry_run="$1"
    local tf_vars_file="$2"
    
    log "Deploying VM with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    local init_cmd=("terraform" "init")
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would execute: ${init_cmd[*]}"
    else
        if ! "${init_cmd[@]}"; then
            handle_error "Terraform init failed"
        fi
    fi
    
    # Prepare variables
    if [ -z "$tf_vars_file" ]; then
        tf_vars_file="$TERRAFORM_DIR/terraform.tfvars"
        
        if [ ! -f "$tf_vars_file" ]; then
            log "Creating Terraform variables file..."
            cp "$TERRAFORM_DIR/terraform.tfvars.example" "$tf_vars_file"
            
            # Update with current values
            sed -i "s/your-org\/beyond-devops-os-factory/$GITHUB_REPO/g" "$tf_vars_file"
            sed -i "s/kairos-k3s-01/$VM_NAME/g" "$tf_vars_file"
        fi
    fi
    
    # Plan deployment
    local plan_cmd=(
        "terraform" "plan"
        "-var-file=$tf_vars_file"
        "-out=tfplan"
    )
    
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would execute: ${plan_cmd[*]}"
    else
        if ! "${plan_cmd[@]}"; then
            handle_error "Terraform plan failed"
        fi
    fi
    
    # Apply deployment
    local apply_cmd=(
        "terraform" "apply"
        "-auto-approve"
        "tfplan"
    )
    
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would execute: ${apply_cmd[*]}"
    else
        if "${apply_cmd[@]}"; then
            log_success "VM deployed successfully with Terraform"
            
            # Get VM information
            terraform output -json > vm_output.json
            log "VM deployment details saved to: $TERRAFORM_DIR/vm_output.json"
        else
            handle_error "Terraform apply failed"
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Deploy Kairos with AuroraBoot
deploy_kairos_auroraboot() {
    local dry_run="$1"
    local cloud_config_file="$2"
    
    log "Deploying Kairos with AuroraBoot..."
    
    local auroraboot_script="$AURORABOOT_DIR/deploy-proxmox.sh"
    if [ ! -f "$auroraboot_script" ]; then
        handle_error "AuroraBoot script not found: $auroraboot_script"
    fi
    
    # Prepare cloud-config
    if [ -z "$cloud_config_file" ]; then
        cloud_config_file="$AURORABOOT_DIR/cloud-config.yaml"
    fi
    
    local auroraboot_cmd=(
        "$auroraboot_script"
        "--repo" "$GITHUB_REPO"
        "--version" "$KAIROS_VERSION"
        "--name" "$VM_NAME"
        "--cloud-config" "$cloud_config_file"
        "--deploy-only"  # Skip image fetch since we already did it
    )
    
    if [ "$dry_run" = "true" ]; then
        auroraboot_cmd+=("--dry-run")
    fi
    
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would execute:"
        echo "${auroraboot_cmd[*]}"
    else
        if "${auroraboot_cmd[@]}"; then
            log_success "Kairos deployed successfully with AuroraBoot"
        else
            handle_error "AuroraBoot deployment failed"
        fi
    fi
}

# Show deployment status
show_deployment_status() {
    log "Checking deployment status..."
    
    # Check Terraform state
    cd "$TERRAFORM_DIR"
    if [ -f "terraform.tfstate" ]; then
        log "Terraform state found"
        if command -v terraform >/dev/null 2>&1; then
            terraform show -json terraform.tfstate > current_state.json 2>/dev/null || true
            log "Terraform state exported to: $TERRAFORM_DIR/current_state.json"
        fi
    else
        log "No Terraform state found"
    fi
    
    # Check for VM outputs
    if [ -f "vm_output.json" ]; then
        log "VM deployment information:"
        jq -r 'to_entries[] | "  \(.key): \(.value.value)"' vm_output.json 2>/dev/null || true
    fi
    
    # Check for running VMs (would need pvesh or API call)
    log "Manual verification required:"
    log "  1. Check Proxmox web interface for VM: $VM_NAME"
    log "  2. Verify VM console for boot messages"
    log "  3. Test SSH connectivity once VM is running"
    
    cd "$PROJECT_ROOT"
}

# Cleanup resources
cleanup_resources() {
    local dry_run="$1"
    
    log "Cleaning up resources..."
    
    # Terraform cleanup
    cd "$TERRAFORM_DIR"
    if [ -f "terraform.tfstate" ]; then
        local destroy_cmd=("terraform" "destroy" "-auto-approve")
        
        if [ "$dry_run" = "true" ]; then
            log "DRY RUN - Would execute: ${destroy_cmd[*]}"
        else
            log "Destroying Terraform resources..."
            if "${destroy_cmd[@]}"; then
                log_success "Terraform resources destroyed"
            else
                log_error "Failed to destroy Terraform resources"
            fi
        fi
    fi
    
    # Clean up temporary files
    rm -f tfplan vm_output.json current_state.json terraform.tfvars
    
    cd "$PROJECT_ROOT"
    
    log_success "Cleanup completed"
}

# Full deployment process
full_deploy() {
    local dry_run="$1"
    local force="$2"
    local skip_template="$3"
    local skip_fetch="$4"
    local tf_vars_file="$5"
    local packer_vars_file="$6"
    local cloud_config_file="$7"
    
    log "Starting full Kairos deployment process..."
    log "VM Name: $VM_NAME"
    log "Kairos Version: $KAIROS_VERSION"
    log "GitHub Repository: $GITHUB_REPO"
    log "Proxmox Node: $PROXMOX_NODE"
    
    # Stage 1: Build Packer template (if not skipped)
    if [ "$skip_template" != "true" ]; then
        build_packer_template "$dry_run" "$force"
    else
        log "Skipping Packer template build"
    fi
    
    # Stage 2: Fetch Kairos images (if not skipped)
    if [ "$skip_fetch" != "true" ]; then
        fetch_kairos_images "$dry_run"
    else
        log "Skipping Kairos image fetch"
    fi
    
    # Stage 3: Deploy VM with Terraform
    deploy_vm_terraform "$dry_run" "$tf_vars_file"
    
    # Stage 4: Deploy Kairos with AuroraBoot
    if [ "$dry_run" != "true" ]; then
        # Wait a bit for VM to be ready
        log "Waiting for VM to be ready..."
        sleep 30
    fi
    
    deploy_kairos_auroraboot "$dry_run" "$cloud_config_file"
    
    log_success "Full deployment process completed!"
    
    if [ "$dry_run" != "true" ]; then
        show_deployment_status
    fi
}

# Load environment variables
load_environment() {
    # Load from .env file if it exists
    if [ -f ".env" ]; then
        log "Loading environment from .env file..."
        # Source the file while being careful about spaces and special characters
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove leading/trailing whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            # Export the variable
            if [ -n "$key" ] && [ -n "$value" ]; then
                export "$key=$value"
                log "  ✓ Loaded $key"
            fi
        done < .env
    else
        log "No .env file found, using existing environment variables"
    fi
}

# Main function
main() {
    local command=""
    local dry_run="false"
    local force="false"
    local skip_template="false"
    local skip_fetch="false"
    local tf_vars_file=""
    local packer_vars_file=""
    local cloud_config_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            full-deploy|template-only|vm-only|kairos-only|cleanup|status)
                command="$1"
                shift
                ;;
            -n|--name)
                VM_NAME="$2"
                shift 2
                ;;
            -r|--repo)
                GITHUB_REPO="$2"
                shift 2
                ;;
            -v|--version)
                KAIROS_VERSION="$2"
                shift 2
                ;;
            --proxmox-node)
                PROXMOX_NODE="$2"
                shift 2
                ;;
            --tf-vars)
                tf_vars_file="$2"
                shift 2
                ;;
            --packer-vars)
                packer_vars_file="$2"
                shift 2
                ;;
            --cloud-config)
                cloud_config_file="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --force)
                force="true"
                shift
                ;;
            --skip-template)
                skip_template="true"
                shift
                ;;
            --skip-fetch)
                skip_fetch="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$command" ]; then
                    command="$1"
                else
                    log_error "Unknown option: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate command
    if [ -z "$command" ]; then
        log_error "No command specified"
        show_help
        exit 1
    fi
    
    # Load environment variables first
    load_environment
    
    # Initialize log
    log "Proxmox Kairos VM Deployment starting..."
    log "Command: $command"
    log "VM Name: $VM_NAME"
    
    # Check dependencies
    check_dependencies
    
    # Validate Proxmox configuration (except for status command)
    if [ "$command" != "status" ]; then
        validate_proxmox_config
    fi
    
    # Execute command
    case $command in
        full-deploy)
            full_deploy "$dry_run" "$force" "$skip_template" "$skip_fetch" "$tf_vars_file" "$packer_vars_file" "$cloud_config_file"
            ;;
        template-only)
            build_packer_template "$dry_run" "$force"
            ;;
        vm-only)
            deploy_vm_terraform "$dry_run" "$tf_vars_file"
            ;;
        kairos-only)
            deploy_kairos_auroraboot "$dry_run" "$cloud_config_file"
            ;;
        cleanup)
            cleanup_resources "$dry_run"
            ;;
        status)
            show_deployment_status
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
    
    log_success "Command '$command' completed successfully!"
}

# Run main function with all arguments
main "$@"