#!/bin/bash
#
# Install Dependencies Script
# Handles installation of required tools including Packer license workarounds

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# Install Packer (handling license issues)
install_packer() {
    log "Installing Packer..."
    
    local os_type
    os_type=$(detect_os)
    
    # Check if packer is already installed
    if command -v packer >/dev/null 2>&1; then
        local version
        version=$(packer version | head -1 | awk '{print $2}')
        log "Packer already installed: $version"
        return 0
    fi
    
    case $os_type in
        "macos")
            install_packer_macos
            ;;
        "debian")
            install_packer_debian
            ;;
        "redhat")
            install_packer_redhat
            ;;
        *)
            install_packer_binary
            ;;
    esac
}

# Install Packer on macOS (avoiding brew due to license issues)
install_packer_macos() {
    log "Installing Packer on macOS using direct download..."
    
    # Get latest version (before BUSL license)
    local version="1.9.4"  # Last MPL version
    local arch
    arch=$(uname -m)
    
    # Map architecture
    case $arch in
        "x86_64")
            arch="amd64"
            ;;
        "arm64")
            arch="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    local url="https://releases.hashicorp.com/packer/${version}/packer_${version}_darwin_${arch}.zip"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    log "Downloading Packer $version for darwin_$arch..."
    if curl -L -o "$temp_dir/packer.zip" "$url"; then
        log "Extracting Packer..."
        cd "$temp_dir"
        unzip -q packer.zip
        
        # Install to /usr/local/bin
        log "Installing Packer to /usr/local/bin..."
        sudo mv packer /usr/local/bin/
        sudo chmod +x /usr/local/bin/packer
        
        # Cleanup
        rm -rf "$temp_dir"
        
        log_success "Packer installed successfully"
        packer version
    else
        log_error "Failed to download Packer"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Install Packer on Debian/Ubuntu
install_packer_debian() {
    log "Installing Packer on Debian/Ubuntu..."
    
    # Try package manager first (may have older version)
    if apt-cache show packer >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y packer
        log_success "Packer installed from package manager"
    else
        # Fallback to binary installation
        install_packer_binary
    fi
}

# Install Packer on RedHat/CentOS
install_packer_redhat() {
    log "Installing Packer on RedHat/CentOS..."
    
    # Try yum/dnf first
    if command -v dnf >/dev/null 2>&1; then
        if dnf info packer >/dev/null 2>&1; then
            sudo dnf install -y packer
            log_success "Packer installed from dnf"
            return 0
        fi
    elif command -v yum >/dev/null 2>&1; then
        if yum info packer >/dev/null 2>&1; then
            sudo yum install -y packer
            log_success "Packer installed from yum"
            return 0
        fi
    fi
    
    # Fallback to binary installation
    install_packer_binary
}

# Install Packer via direct binary download
install_packer_binary() {
    log "Installing Packer via binary download..."
    
    local version="1.9.4"  # Last MPL version
    local os_name arch
    
    case $(uname -s) in
        "Linux")
            os_name="linux"
            ;;
        "Darwin")
            os_name="darwin"
            ;;
        *)
            log_error "Unsupported OS: $(uname -s)"
            return 1
            ;;
    esac
    
    case $(uname -m) in
        "x86_64")
            arch="amd64"
            ;;
        "arm64"|"aarch64")
            arch="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    local url="https://releases.hashicorp.com/packer/${version}/packer_${version}_${os_name}_${arch}.zip"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    log "Downloading Packer $version for ${os_name}_${arch}..."
    if curl -L -o "$temp_dir/packer.zip" "$url"; then
        cd "$temp_dir"
        unzip -q packer.zip
        
        # Determine install location
        local install_dir="/usr/local/bin"
        if [ ! -w "/usr/local/bin" ]; then
            install_dir="$HOME/.local/bin"
            mkdir -p "$install_dir"
            log "Installing to user directory: $install_dir"
        fi
        
        # Install binary
        if [ "$install_dir" = "/usr/local/bin" ]; then
            sudo mv packer "$install_dir/"
            sudo chmod +x "$install_dir/packer"
        else
            mv packer "$install_dir/"
            chmod +x "$install_dir/packer"
            
            # Add to PATH if not already there
            if [[ ":$PATH:" != *":$install_dir:"* ]]; then
                echo "export PATH=\"\$PATH:$install_dir\"" >> "$HOME/.bashrc"
                echo "export PATH=\"\$PATH:$install_dir\"" >> "$HOME/.zshrc" 2>/dev/null || true
                log_warning "Added $install_dir to PATH. Please restart your shell or run: export PATH=\"\$PATH:$install_dir\""
            fi
        fi
        
        rm -rf "$temp_dir"
        log_success "Packer installed successfully"
        
        # Test installation
        if command -v packer >/dev/null 2>&1; then
            packer version
        else
            log_warning "Packer installed but not in current PATH. Please restart your shell."
        fi
    else
        log_error "Failed to download Packer"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Install Terraform
install_terraform() {
    log "Installing Terraform..."
    
    local os_type
    os_type=$(detect_os)
    
    # Check if terraform is already installed
    if command -v terraform >/dev/null 2>&1; then
        local version
        version=$(terraform version | head -1 | awk '{print $2}')
        log "Terraform already installed: $version"
        return 0
    fi
    
    case $os_type in
        "macos")
            if command -v brew >/dev/null 2>&1; then
                log "Installing Terraform via Homebrew..."
                brew tap hashicorp/tap
                brew install hashicorp/tap/terraform
            else
                install_terraform_binary
            fi
            ;;
        "debian")
            log "Installing Terraform on Debian/Ubuntu..."
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
            sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
            sudo apt-get update && sudo apt-get install terraform
            ;;
        "redhat")
            log "Installing Terraform on RedHat/CentOS..."
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum -y install terraform
            ;;
        *)
            install_terraform_binary
            ;;
    esac
    
    log_success "Terraform installed successfully"
    terraform version
}

# Install Terraform via binary download
install_terraform_binary() {
    log "Installing Terraform via binary download..."
    
    local version="1.6.6"  # Stable version
    local os_name arch
    
    case $(uname -s) in
        "Linux")
            os_name="linux"
            ;;
        "Darwin")
            os_name="darwin"
            ;;
        *)
            log_error "Unsupported OS: $(uname -s)"
            return 1
            ;;
    esac
    
    case $(uname -m) in
        "x86_64")
            arch="amd64"
            ;;
        "arm64"|"aarch64")
            arch="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    local url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${os_name}_${arch}.zip"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    log "Downloading Terraform $version..."
    if curl -L -o "$temp_dir/terraform.zip" "$url"; then
        cd "$temp_dir"
        unzip -q terraform.zip
        
        local install_dir="/usr/local/bin"
        if [ ! -w "/usr/local/bin" ]; then
            install_dir="$HOME/.local/bin"
            mkdir -p "$install_dir"
        fi
        
        if [ "$install_dir" = "/usr/local/bin" ]; then
            sudo mv terraform "$install_dir/"
            sudo chmod +x "$install_dir/terraform"
        else
            mv terraform "$install_dir/"
            chmod +x "$install_dir/terraform"
        fi
        
        rm -rf "$temp_dir"
        log_success "Terraform installed successfully"
    else
        log_error "Failed to download Terraform"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Install other dependencies
install_common_tools() {
    log "Installing common tools..."
    
    local os_type
    os_type=$(detect_os)
    
    case $os_type in
        "macos")
            if command -v brew >/dev/null 2>&1; then
                log "Installing tools via Homebrew..."
                brew install jq yq gh curl docker
            else
                log_error "Homebrew not found. Please install Homebrew first or install tools manually."
                return 1
            fi
            ;;
        "debian")
            log "Installing tools on Debian/Ubuntu..."
            sudo apt-get update
            sudo apt-get install -y curl wget jq git
            
            # Install yq
            if ! command -v yq >/dev/null 2>&1; then
                log "Installing yq..."
                sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                sudo chmod +x /usr/local/bin/yq
            fi
            
            # Install GitHub CLI
            if ! command -v gh >/dev/null 2>&1; then
                log "Installing GitHub CLI..."
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
                sudo apt-get update && sudo apt-get install gh
            fi
            
            # Install Docker
            if ! command -v docker >/dev/null 2>&1; then
                log "Installing Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sh get-docker.sh
                sudo usermod -aG docker "$USER"
                rm get-docker.sh
                log_warning "Please log out and back in for Docker group membership to take effect"
            fi
            ;;
        "redhat")
            log "Installing tools on RedHat/CentOS..."
            sudo yum install -y curl wget jq git
            
            # Install yq
            if ! command -v yq >/dev/null 2>&1; then
                sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                sudo chmod +x /usr/local/bin/yq
            fi
            
            # Install GitHub CLI
            if ! command -v gh >/dev/null 2>&1; then
                sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                sudo dnf install gh
            fi
            
            # Install Docker
            if ! command -v docker >/dev/null 2>&1; then
                sudo yum install -y docker
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker "$USER"
            fi
            ;;
        *)
            log_error "Unsupported OS for automatic tool installation"
            return 1
            ;;
    esac
}

# Verify installations
verify_installations() {
    log "Verifying installations..."
    
    local tools=("terraform" "packer" "docker" "jq" "yq" "gh" "curl")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=""
            case $tool in
                "terraform")
                    version=$(terraform version | head -1 | awk '{print $2}')
                    ;;
                "packer")
                    version=$(packer version | head -1 | awk '{print $2}')
                    ;;
                "docker")
                    version=$(docker --version | awk '{print $3}' | sed 's/,//')
                    ;;
                "jq")
                    version=$(jq --version | sed 's/jq-//')
                    ;;
                "yq")
                    version=$(yq --version | awk '{print $4}')
                    ;;
                "gh")
                    version=$(gh --version | head -1 | awk '{print $3}')
                    ;;
                "curl")
                    version=$(curl --version | head -1 | awk '{print $2}')
                    ;;
            esac
            
            log_success "✅ $tool: $version"
        else
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        log_success "All required tools are installed!"
        return 0
    else
        log_error "Missing tools: ${missing[*]}"
        return 1
    fi
}

# Show help
show_help() {
    cat << EOF
Install Dependencies Script

USAGE:
    $0 [OPTIONS] [TOOL]

TOOLS:
    all          Install all required tools (default)
    terraform    Install Terraform only
    packer       Install Packer only (handles license issues)
    common       Install common tools (jq, yq, gh, docker, curl)
    verify       Verify installations only

OPTIONS:
    --force      Force reinstallation even if tools exist
    --user       Install to user directory instead of system-wide
    -h, --help   Show this help

EXAMPLES:
    # Install all tools
    $0

    # Install only Packer (avoiding brew license issues)
    $0 packer

    # Verify current installations
    $0 verify

NOTES:
    - Packer is installed via direct download due to HashiCorp BUSL license
    - On macOS, Homebrew is preferred for most tools except Packer
    - Docker may require logout/login for group membership
    - Some installations may require sudo privileges

EOF
}

# Main function
main() {
    local tool="all"
    local force_install="false"
    local user_install="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            all|terraform|packer|common|verify)
                tool="$1"
                shift
                ;;
            --force)
                force_install="true"
                shift
                ;;
            --user)
                user_install="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$tool" ] || [ "$tool" = "all" ]; then
                    tool="$1"
                else
                    log_error "Unknown option: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    log "Starting dependency installation..."
    log "Target tool(s): $tool"
    log "OS detected: $(detect_os)"
    
    # Install based on selection
    case $tool in
        "all")
            install_terraform
            install_packer
            install_common_tools
            verify_installations
            ;;
        "terraform")
            install_terraform
            ;;
        "packer")
            install_packer
            ;;
        "common")
            install_common_tools
            ;;
        "verify")
            verify_installations
            ;;
        *)
            log_error "Unknown tool: $tool"
            show_help
            exit 1
            ;;
    esac
    
    log_success "Dependency installation completed!"
    
    # Show next steps
    log ""
    log "Next steps:"
    log "1. Restart your shell if PATH was modified"
    log "2. Run: ./scripts/test/validate-deployment.sh dependencies"
    log "3. Configure your environment variables for Proxmox"
    log "4. Start your deployment: ./scripts/proxmox/deploy-kairos-vm.sh"
}

# Run main function
main "$@"