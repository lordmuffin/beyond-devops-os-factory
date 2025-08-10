#!/bin/bash
#
# Deployment Validation Script
# Tests the complete Proxmox-AuroraBoot-Kairos deployment pipeline

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="${LOG_FILE:-/tmp/validate-deployment.log}"
TEST_VM_NAME="kairos-test-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

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

# Test result functions
test_start() {
    local test_name="$1"
    log "🧪 Starting test: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    local test_name="$1"
    log_success "✅ Test passed: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local test_name="$1"
    local error_msg="$2"
    log_error "❌ Test failed: $test_name - $error_msg"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$test_name")
}

# Help function
show_help() {
    cat << EOF
Deployment Validation Script

USAGE:
    $0 [OPTIONS] [TEST_SUITE]

TEST SUITES:
    dependencies     Test all required dependencies
    configuration    Test configuration files
    connectivity     Test Proxmox and GitHub connectivity  
    build-template   Test Packer template build
    fetch-images     Test GitHub image fetching
    deploy-vm        Test Terraform VM deployment
    deploy-kairos    Test AuroraBoot Kairos deployment
    full-pipeline    Test complete deployment pipeline
    cleanup          Clean up test resources

OPTIONS:
    --vm-name NAME       Test VM name (default: auto-generated)
    --keep-resources     Don't cleanup test resources after tests
    --verbose           Enable verbose output
    --dry-run           Show test plan without executing
    -h, --help          Show this help

EXAMPLES:
    # Test all dependencies
    $0 dependencies

    # Test full pipeline
    $0 full-pipeline

    # Test with custom VM name
    $0 deploy-vm --vm-name test-kairos-01

    # Dry run full pipeline
    $0 full-pipeline --dry-run

ENVIRONMENT VARIABLES:
    PROXMOX_API_URL      Proxmox API URL
    PROXMOX_API_TOKEN    Proxmox API token
    PROXMOX_NODE         Proxmox node name
    GITHUB_REPO          GitHub repository

EOF
}

# Test dependencies
test_dependencies() {
    test_start "dependencies"
    
    local deps=("terraform" "packer" "docker" "jq" "yq" "gh" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        else
            log "  ✓ $dep found: $(command -v "$dep")"
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        test_pass "dependencies"
    else
        test_fail "dependencies" "Missing tools: ${missing[*]}"
    fi
}

# Test configuration files
test_configuration() {
    test_start "configuration"
    
    local config_files=(
        "terraform/proxmox/main.tf"
        "terraform/proxmox/variables.tf"
        "packer/proxmox/kairos-base.pkr.hcl"
        "auroraboot/cloud-config.yaml"
        "auroraboot/config.yaml"
    )
    
    local missing_files=()
    local invalid_files=()
    
    for file in "${config_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        if [ ! -f "$full_path" ]; then
            missing_files+=("$file")
        else
            log "  ✓ Found: $file"
            
            # Validate YAML files
            if [[ "$file" == *.yaml ]] || [[ "$file" == *.yml ]]; then
                if ! yq eval '.' "$full_path" >/dev/null 2>&1; then
                    invalid_files+=("$file")
                else
                    log "    ✓ Valid YAML syntax"
                fi
            fi
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ] && [ ${#invalid_files[@]} -eq 0 ]; then
        test_pass "configuration"
    else
        local error_msg=""
        [ ${#missing_files[@]} -gt 0 ] && error_msg="Missing files: ${missing_files[*]} "
        [ ${#invalid_files[@]} -gt 0 ] && error_msg+="Invalid files: ${invalid_files[*]}"
        test_fail "configuration" "$error_msg"
    fi
}

# Test connectivity
test_connectivity() {
    test_start "connectivity"
    
    local errors=()
    
    # Test Proxmox API connectivity
    if [ -n "${PROXMOX_API_URL:-}" ] && [ -n "${PROXMOX_API_TOKEN:-}" ]; then
        log "  Testing Proxmox API connectivity..."
        if curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" "${PROXMOX_API_URL}/version" >/dev/null; then
            log "    ✓ Proxmox API accessible"
        else
            errors+=("Proxmox API not accessible")
        fi
    else
        errors+=("Proxmox credentials not configured")
    fi
    
    # Test GitHub API connectivity
    log "  Testing GitHub API connectivity..."
    if curl -s https://api.github.com/rate_limit >/dev/null; then
        log "    ✓ GitHub API accessible"
    else
        errors+=("GitHub API not accessible")
    fi
    
    # Test GitHub CLI authentication
    if gh auth status >/dev/null 2>&1; then
        log "    ✓ GitHub CLI authenticated"
    else
        errors+=("GitHub CLI not authenticated")
    fi
    
    # Test Docker daemon
    if docker version >/dev/null 2>&1; then
        log "    ✓ Docker daemon accessible"
    else
        errors+=("Docker daemon not accessible")
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        test_pass "connectivity"
    else
        test_fail "connectivity" "${errors[*]}"
    fi
}

# Test Packer template build
test_build_template() {
    test_start "build-template"
    
    cd "$PROJECT_ROOT/packer/proxmox"
    
    # Validate Packer template
    log "  Validating Packer template..."
    if packer validate kairos-base.pkr.hcl; then
        log "    ✓ Packer template is valid"
        test_pass "build-template"
    else
        test_fail "build-template" "Packer template validation failed"
    fi
    
    cd "$PROJECT_ROOT"
}

# Test GitHub image fetching
test_fetch_images() {
    test_start "fetch-images"
    
    local fetch_script="$PROJECT_ROOT/scripts/github/fetch-kairos-releases.sh"
    
    if [ ! -f "$fetch_script" ]; then
        test_fail "fetch-images" "Fetch script not found"
        return
    fi
    
    # Test with --list flag (read-only operation)
    log "  Testing GitHub release listing..."
    if "$fetch_script" --list >/dev/null 2>&1; then
        log "    ✓ Successfully listed GitHub releases"
        test_pass "fetch-images"
    else
        test_fail "fetch-images" "Failed to list GitHub releases"
    fi
}

# Test Terraform VM deployment (dry run)
test_deploy_vm() {
    test_start "deploy-vm"
    
    cd "$PROJECT_ROOT/terraform/proxmox"
    
    # Create test variables file
    local test_vars_file="test.tfvars"
    cat > "$test_vars_file" << EOF
proxmox_api_url = "${PROXMOX_API_URL:-https://proxmox:8006/api2/json}"
proxmox_api_token = "${PROXMOX_API_TOKEN:-test-token}"
vm_name = "$TEST_VM_NAME"
proxmox_node_name = "${PROXMOX_NODE:-pve}"
EOF
    
    # Test Terraform init and validate
    log "  Testing Terraform initialization..."
    if terraform init >/dev/null 2>&1; then
        log "    ✓ Terraform initialized successfully"
        
        log "  Testing Terraform validation..."
        if terraform validate; then
            log "    ✓ Terraform configuration is valid"
            
            log "  Testing Terraform plan..."
            if terraform plan -var-file="$test_vars_file" >/dev/null 2>&1; then
                log "    ✓ Terraform plan successful"
                test_pass "deploy-vm"
            else
                test_fail "deploy-vm" "Terraform plan failed"
            fi
        else
            test_fail "deploy-vm" "Terraform validation failed"
        fi
    else
        test_fail "deploy-vm" "Terraform init failed"
    fi
    
    # Cleanup
    rm -f "$test_vars_file"
    cd "$PROJECT_ROOT"
}

# Test AuroraBoot deployment (dry run)
test_deploy_kairos() {
    test_start "deploy-kairos"
    
    local auroraboot_script="$PROJECT_ROOT/auroraboot/deploy-proxmox.sh"
    
    if [ ! -f "$auroraboot_script" ]; then
        test_fail "deploy-kairos" "AuroraBoot script not found"
        return
    fi
    
    # Test AuroraBoot script with dry-run
    log "  Testing AuroraBoot deployment script..."
    if "$auroraboot_script" --dry-run --name "$TEST_VM_NAME" >/dev/null 2>&1; then
        log "    ✓ AuroraBoot script executed successfully in dry-run mode"
        test_pass "deploy-kairos"
    else
        test_fail "deploy-kairos" "AuroraBoot dry-run failed"
    fi
}

# Test full pipeline (dry run)
test_full_pipeline() {
    test_start "full-pipeline"
    
    local deploy_script="$PROJECT_ROOT/scripts/proxmox/deploy-kairos-vm.sh"
    
    if [ ! -f "$deploy_script" ]; then
        test_fail "full-pipeline" "Main deployment script not found"
        return
    fi
    
    # Test full deployment in dry-run mode
    log "  Testing full deployment pipeline..."
    if "$deploy_script" full-deploy --name "$TEST_VM_NAME" --dry-run >/dev/null 2>&1; then
        log "    ✓ Full deployment pipeline executed successfully in dry-run mode"
        test_pass "full-pipeline"
    else
        test_fail "full-pipeline" "Full deployment pipeline dry-run failed"
    fi
}

# Cleanup test resources
cleanup_test_resources() {
    test_start "cleanup"
    
    log "  Cleaning up test resources..."
    
    # Clean up Terraform state
    if [ -d "$PROJECT_ROOT/terraform/proxmox/.terraform" ]; then
        rm -rf "$PROJECT_ROOT/terraform/proxmox/.terraform"
        log "    ✓ Cleaned up Terraform state"
    fi
    
    # Clean up temporary files
    find "$PROJECT_ROOT" -name "test.tfvars" -delete
    find "$PROJECT_ROOT" -name "*.log" -path "*/tmp/*" -delete 2>/dev/null || true
    
    log "    ✓ Cleaned up temporary files"
    test_pass "cleanup"
}

# Generate test report
generate_test_report() {
    log ""
    log "============================================"
    log "TEST RESULTS SUMMARY"
    log "============================================"
    log "Tests run: $TESTS_RUN"
    log "Tests passed: $TESTS_PASSED"
    log "Tests failed: $TESTS_FAILED"
    log ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! 🎉"
        log ""
        log "Your deployment pipeline is ready for use:"
        log "  1. Configure your environment variables"
        log "  2. Run: ./scripts/proxmox/deploy-kairos-vm.sh full-deploy"
        log "  3. Monitor deployment logs"
        log ""
        return 0
    else
        log_error "Some tests failed ❌"
        log ""
        log "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            log "  - $test"
        done
        log ""
        log "Please fix the issues above before proceeding with deployment."
        log "Check the full log at: $LOG_FILE"
        return 1
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
    local test_suite=""
    local keep_resources="false"
    local verbose="false"
    local dry_run="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            dependencies|configuration|connectivity|build-template|fetch-images|deploy-vm|deploy-kairos|full-pipeline|cleanup)
                test_suite="$1"
                shift
                ;;
            --vm-name)
                TEST_VM_NAME="$2"
                shift 2
                ;;
            --keep-resources)
                keep_resources="true"
                shift
                ;;
            --verbose)
                verbose="true"
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
                if [ -z "$test_suite" ]; then
                    test_suite="$1"
                else
                    log_error "Unknown option: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to full pipeline if no test suite specified
    if [ -z "$test_suite" ]; then
        test_suite="full-pipeline"
    fi
    
    # Load environment variables first
    load_environment
    
    # Initialize log
    log "Deployment Validation Starting..."
    log "Test suite: $test_suite"
    log "Test VM name: $TEST_VM_NAME"
    log "Dry run: $dry_run"
    log ""
    
    # Set verbose mode
    if [ "$verbose" = "true" ]; then
        set -x
    fi
    
    # Run specified test suite
    case $test_suite in
        dependencies)
            test_dependencies
            ;;
        configuration)
            test_configuration
            ;;
        connectivity)
            test_connectivity
            ;;
        build-template)
            test_build_template
            ;;
        fetch-images)
            test_fetch_images
            ;;
        deploy-vm)
            test_deploy_vm
            ;;
        deploy-kairos)
            test_deploy_kairos
            ;;
        full-pipeline)
            test_dependencies
            test_configuration
            test_connectivity
            test_build_template
            test_fetch_images
            test_deploy_vm
            test_deploy_kairos
            ;;
        cleanup)
            cleanup_test_resources
            ;;
        *)
            log_error "Unknown test suite: $test_suite"
            show_help
            exit 1
            ;;
    esac
    
    # Cleanup unless keeping resources
    if [ "$keep_resources" != "true" ] && [ "$test_suite" != "cleanup" ]; then
        cleanup_test_resources
    fi
    
    # Generate final report
    generate_test_report
}

# Run main function with all arguments
main "$@"