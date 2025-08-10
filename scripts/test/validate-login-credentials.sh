#!/bin/bash
#
# Kairos Login Credentials Validation Test
# Tests login credentials for Kairos VMs to ensure they work properly
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
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

# Help function
show_help() {
    cat << EOF
Kairos Login Credentials Validation Test

USAGE:
    $0 [OPTIONS] VM_IP_ADDRESS

DESCRIPTION:
    Tests login credentials for Kairos VMs to validate they work properly.
    
ARGUMENTS:
    VM_IP_ADDRESS    IP address or hostname of the Kairos VM to test

OPTIONS:
    --ssh-key FILE   SSH private key file to test (default: ~/.ssh/id_rsa)
    --timeout SEC    Connection timeout in seconds (default: 10)
    --verbose        Enable verbose output
    --dry-run        Show commands without executing
    -h, --help       Show this help

TESTS PERFORMED:
    1. SSH key authentication test (if available)
    2. Password authentication test (kairos/kairos)
    3. User account validation
    4. Group membership verification
    5. Sudo access test

EXAMPLES:
    # Test VM at specific IP
    $0 192.168.1.100
    
    # Test with custom SSH key
    $0 --ssh-key /path/to/key 192.168.1.100
    
    # Verbose test output
    $0 --verbose 192.168.1.100

EOF
}

# Test SSH key authentication
test_ssh_key_auth() {
    local vm_ip="$1"
    local ssh_key="$2"
    local timeout="$3"
    
    if [ ! -f "$ssh_key" ]; then
        log_warning "SSH key not found: $ssh_key"
        return 1
    fi
    
    log "Testing SSH key authentication..."
    
    if ssh -i "$ssh_key" \
           -o ConnectTimeout="$timeout" \
           -o BatchMode=yes \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
           kairos@"$vm_ip" 'echo "SSH key auth successful"' 2>/dev/null; then
        log_success "SSH key authentication works"
        return 0
    else
        log_error "SSH key authentication failed"
        return 1
    fi
}

# Test password authentication
test_password_auth() {
    local vm_ip="$1"
    local timeout="$2"
    
    log "Testing password authentication..."
    log_warning "Note: This requires sshpass to be installed for automated testing"
    
    if ! command -v sshpass >/dev/null 2>&1; then
        log_warning "sshpass not available - manual password test required"
        log "Please try manually: ssh kairos@$vm_ip"
        log "Password should be: kairos"
        return 2  # Skipped
    fi
    
    if sshpass -p "kairos" ssh \
           -o ConnectTimeout="$timeout" \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
           kairos@"$vm_ip" 'echo "Password auth successful"' 2>/dev/null; then
        log_success "Password authentication works"
        return 0
    else
        log_error "Password authentication failed"
        return 1
    fi
}

# Test user account and permissions
test_user_account() {
    local vm_ip="$1"
    local auth_method="$2"
    local ssh_key="$3"
    local timeout="$4"
    
    log "Testing user account configuration..."
    
    # Build SSH command based on auth method
    local ssh_cmd
    if [ "$auth_method" = "key" ]; then
        ssh_cmd="ssh -i $ssh_key -o ConnectTimeout=$timeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR kairos@$vm_ip"
    elif [ "$auth_method" = "password" ] && command -v sshpass >/dev/null; then
        ssh_cmd="sshpass -p kairos ssh -o ConnectTimeout=$timeout -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR kairos@$vm_ip"
    else
        log_warning "Cannot test user account - no working authentication method"
        return 2
    fi
    
    # Test user existence and groups
    local user_info
    if user_info=$($ssh_cmd 'id' 2>/dev/null); then
        log_success "User account exists: $user_info"
        
        # Check specific groups
        if echo "$user_info" | grep -q "admin\|wheel\|sudo"; then
            log_success "User has admin privileges"
        else
            log_warning "User may not have admin privileges"
        fi
    else
        log_error "Cannot retrieve user information"
        return 1
    fi
    
    # Test sudo access
    if $ssh_cmd 'sudo -n true' 2>/dev/null; then
        log_success "Passwordless sudo access works"
    else
        log_warning "Passwordless sudo may not be configured"
    fi
    
    return 0
}

# Test VM connectivity
test_connectivity() {
    local vm_ip="$1"
    local timeout="$2"
    
    log "Testing basic connectivity to $vm_ip..."
    
    if ping -c 1 -W "$timeout" "$vm_ip" >/dev/null 2>&1; then
        log_success "VM is reachable via ping"
    else
        log_error "VM is not reachable via ping"
        return 1
    fi
    
    # Test SSH port
    if timeout "$timeout" bash -c "</dev/tcp/$vm_ip/22" 2>/dev/null; then
        log_success "SSH port (22) is open"
    else
        log_error "SSH port (22) is not accessible"
        return 1
    fi
    
    return 0
}

# Validate cloud-config files
validate_cloud_config() {
    log "Validating cloud-config files..."
    
    local config_files=(
        "$PROJECT_ROOT/packer/kairos/cloud-config.yaml"
        "$PROJECT_ROOT/packer/kairos/osartifact.yaml"
    )
    
    local issues=0
    
    for config_file in "${config_files[@]}"; do
        if [ ! -f "$config_file" ]; then
            log_warning "Config file not found: $config_file"
            continue
        fi
        
        log "Checking $config_file..."
        
        # Check for hashed password
        if grep -q 'passwd: "kairos"' "$config_file" || grep -q "passwd: kairos" "$config_file"; then
            log_error "Found plaintext password in $config_file"
            log "Password should be hashed (starts with \$6\$)"
            ((issues++))
        fi
        
        # Check for proper template syntax
        if grep -q '{{ trunc' "$config_file"; then
            log_error "Found Go template syntax in $config_file"
            log "Should use cloud-init syntax: \${machine_id:0:4}"
            ((issues++))
        fi
        
        # Check for required groups
        if ! grep -A 10 "groups:" "$config_file" | grep -q -E "(admin|wheel|sudo)"; then
            log_warning "User may not have admin groups in $config_file"
        fi
    done
    
    if [ "$issues" -eq 0 ]; then
        log_success "Cloud-config validation passed"
        return 0
    else
        log_error "Found $issues configuration issues"
        return 1
    fi
}

# Main test function
run_tests() {
    local vm_ip="$1"
    local ssh_key="$2"
    local timeout="$3"
    local verbose="$4"
    
    log "Starting Kairos login credentials validation"
    log "Target VM: $vm_ip"
    log "SSH Key: $ssh_key"
    log "Timeout: ${timeout}s"
    echo
    
    local test_results=()
    local working_auth_method=""
    
    # Test 1: Validate cloud-config files
    log "=== Test 1: Cloud-config Validation ==="
    if validate_cloud_config; then
        test_results+=("cloud-config:PASS")
    else
        test_results+=("cloud-config:FAIL")
    fi
    echo
    
    # Test 2: Basic connectivity
    log "=== Test 2: Basic Connectivity ==="
    if test_connectivity "$vm_ip" "$timeout"; then
        test_results+=("connectivity:PASS")
    else
        test_results+=("connectivity:FAIL")
        log_error "Cannot reach VM - aborting remaining tests"
        return 1
    fi
    echo
    
    # Test 3: SSH key authentication
    log "=== Test 3: SSH Key Authentication ==="
    if test_ssh_key_auth "$vm_ip" "$ssh_key" "$timeout"; then
        test_results+=("ssh-key:PASS")
        working_auth_method="key"
    else
        test_results+=("ssh-key:FAIL")
    fi
    echo
    
    # Test 4: Password authentication
    log "=== Test 4: Password Authentication ==="
    case $(test_password_auth "$vm_ip" "$timeout") in
        0)
            test_results+=("password:PASS")
            if [ -z "$working_auth_method" ]; then
                working_auth_method="password"
            fi
            ;;
        1)
            test_results+=("password:FAIL")
            ;;
        2)
            test_results+=("password:SKIP")
            ;;
    esac
    echo
    
    # Test 5: User account validation
    if [ -n "$working_auth_method" ]; then
        log "=== Test 5: User Account Validation ==="
        if test_user_account "$vm_ip" "$working_auth_method" "$ssh_key" "$timeout"; then
            test_results+=("user-account:PASS")
        else
            test_results+=("user-account:FAIL")
        fi
    else
        log "=== Test 5: User Account Validation ==="
        log_error "Skipping user account tests - no working authentication method"
        test_results+=("user-account:SKIP")
    fi
    echo
    
    # Summary
    log "=== Test Results Summary ==="
    local passed=0
    local failed=0
    local skipped=0
    
    for result in "${test_results[@]}"; do
        local test_name="${result%%:*}"
        local test_status="${result##*:}"
        
        case "$test_status" in
            PASS)
                log_success "$test_name: PASSED"
                ((passed++))
                ;;
            FAIL)
                log_error "$test_name: FAILED"
                ((failed++))
                ;;
            SKIP)
                log_warning "$test_name: SKIPPED"
                ((skipped++))
                ;;
        esac
    done
    
    echo
    log "Total: $passed passed, $failed failed, $skipped skipped"
    
    if [ "$failed" -eq 0 ]; then
        log_success "All critical tests passed!"
        
        if [ -n "$working_auth_method" ]; then
            echo
            log "=== Login Instructions ==="
            if [ "$working_auth_method" = "key" ]; then
                log "SSH with key: ssh -i $ssh_key kairos@$vm_ip"
            fi
            if [ "$working_auth_method" = "password" ] || grep -q "password:PASS" <<< "${test_results[*]}"; then
                log "SSH with password: ssh kairos@$vm_ip"
                log "Password: kairos"
            fi
        fi
        
        return 0
    else
        log_error "Some tests failed - login may not work properly"
        return 1
    fi
}

# Main script
main() {
    local vm_ip=""
    local ssh_key="$HOME/.ssh/id_rsa"
    local timeout=10
    local verbose=false
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ssh-key)
                ssh_key="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$vm_ip" ]; then
                    vm_ip="$1"
                else
                    log_error "Too many arguments: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$vm_ip" ]; then
        log_error "VM IP address is required"
        show_help
        exit 1
    fi
    
    # Validate IP format (basic check)
    if ! [[ "$vm_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|^[a-zA-Z0-9.-]+$ ]]; then
        log_error "Invalid IP address or hostname: $vm_ip"
        exit 1
    fi
    
    if [ "$dry_run" = "true" ]; then
        log "DRY RUN - Would test VM: $vm_ip"
        log "SSH Key: $ssh_key"
        log "Timeout: ${timeout}s"
        exit 0
    fi
    
    # Run tests
    run_tests "$vm_ip" "$ssh_key" "$timeout" "$verbose"
}

# Run main function with all arguments
main "$@"