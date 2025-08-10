#!/bin/bash
#
# Test Proxmox API Connection
# Validates your Proxmox credentials

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}✅${NC} $*"
}

log_error() {
    echo -e "${RED}❌${NC} $*"
}

log_info() {
    echo -e "${BLUE}ℹ️${NC} $*"
}

# Check environment variables
if [ -z "${PROXMOX_API_URL:-}" ]; then
    log_error "PROXMOX_API_URL not set"
    exit 1
fi

if [ -z "${PROXMOX_API_TOKEN:-}" ]; then
    log_error "PROXMOX_API_TOKEN not set"
    exit 1
fi

echo "Testing Proxmox API Connection"
echo "=============================="
echo

log_info "API URL: $PROXMOX_API_URL"
log_info "Token: ${PROXMOX_API_TOKEN%%=*}=***hidden***"
echo

# Test API connection
log_info "Testing API connectivity..."

# Test version endpoint
if response=$(curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" "${PROXMOX_API_URL}/version" 2>/dev/null); then
    if echo "$response" | jq -e '.data' >/dev/null 2>&1; then
        version=$(echo "$response" | jq -r '.data.version')
        release=$(echo "$response" | jq -r '.data.release')
        log_success "Connected to Proxmox VE $version-$release"
    else
        log_error "API responded but with unexpected format:"
        echo "$response"
        exit 1
    fi
else
    log_error "Failed to connect to Proxmox API"
    echo
    echo "Common issues:"
    echo "1. Wrong API URL (check IP address and port)"
    echo "2. Incomplete API token (missing secret part)"
    echo "3. Token doesn't have proper permissions"
    echo "4. SSL certificate issues (we use -k to ignore)"
    echo
    echo "Your token should look like:"
    echo "  PROXMOX_API_TOKEN=user@realm!tokenname=secret-value"
    echo
    echo "Current token format analysis:"
    if [[ "$PROXMOX_API_TOKEN" == *"="* ]]; then
        log_info "✓ Token contains '=' (has secret part)"
    else
        log_error "✗ Token missing '=' (no secret part)"
    fi
    
    if [[ "$PROXMOX_API_TOKEN" == *"@"* ]]; then
        log_info "✓ Token contains '@' (has realm)"
    else
        log_error "✗ Token missing '@' (no realm)"
    fi
    
    if [[ "$PROXMOX_API_TOKEN" == *"!"* ]]; then
        log_info "✓ Token contains '!' (has token name)"
    else
        log_error "✗ Token missing '!' (no token name)"
    fi
    
    exit 1
fi

# Test node access
if [ -n "${PROXMOX_NODE:-}" ]; then
    log_info "Testing access to node: $PROXMOX_NODE"
    
    if response=$(curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" "${PROXMOX_API_URL}/nodes/${PROXMOX_NODE}/status" 2>/dev/null); then
        if echo "$response" | jq -e '.data' >/dev/null 2>&1; then
            status=$(echo "$response" | jq -r '.data.status')
            uptime=$(echo "$response" | jq -r '.data.uptime')
            log_success "Node $PROXMOX_NODE is $status (uptime: ${uptime}s)"
        else
            log_error "Node access failed:"
            echo "$response"
        fi
    else
        log_error "Failed to access node $PROXMOX_NODE"
    fi
fi

# Test VM listing permissions
log_info "Testing VM listing permissions..."

if response=$(curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" "${PROXMOX_API_URL}/nodes/${PROXMOX_NODE:-pve}/qemu" 2>/dev/null); then
    if echo "$response" | jq -e '.data' >/dev/null 2>&1; then
        vm_count=$(echo "$response" | jq '.data | length')
        log_success "Can list VMs (found $vm_count VMs)"
    else
        log_error "VM listing failed:"
        echo "$response"
    fi
else
    log_error "Failed to list VMs"
fi

echo
log_success "Proxmox API connection test completed!"
echo
echo "If all tests passed, your credentials are working correctly."
echo "You can now proceed with the deployment pipeline."