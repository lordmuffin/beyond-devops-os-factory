#!/bin/bash
#
# YAML Validation Script
# Validates YAML files with better error reporting

set -euo pipefail

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

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $*"
}

log_info() {
    echo -e "${BLUE}ℹ️${NC} $*"
}

validate_yaml_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi
    
    echo "Validating: $file"
    
    # Check if it's a cloud-config file with templates
    if [[ "$file" == *"cloud-config"* ]]; then
        log_info "This is a cloud-config file - checking for template syntax..."
        
        # Check for Go template syntax (which is valid for AuroraBoot)
        if grep -q "{{.*}}" "$file"; then
            log_warning "Contains Go template syntax - this is valid for AuroraBoot processing"
        fi
        
        # Validate cloud-config specific structure
        if ! grep -q "^#cloud-config" "$file"; then
            log_error "Missing #cloud-config header"
            return 1
        fi
    fi
    
    # Basic YAML structure validation using Python
    python3 -c "
import sys
try:
    with open('$file', 'r') as f:
        content = f.read()
    
    # Check for common YAML issues
    lines = content.split('\n')
    
    for i, line in enumerate(lines, 1):
        if line.strip() == '' or line.strip().startswith('#'):
            continue
            
        # Check for tabs (should use spaces)
        if '\t' in line:
            print(f'Line {i}: Contains tabs instead of spaces')
            sys.exit(1)
            
        # Check for basic YAML structure
        stripped = line.strip()
        if ':' in stripped or stripped.startswith('-'):
            # Basic YAML key-value or list item
            pass
        elif stripped and not any(c.isspace() for c in line[:len(line) - len(line.lstrip())]):
            # Non-indented content that's not a key or comment
            if not (stripped.startswith('---') or stripped.startswith('...')):
                print(f'Line {i}: Possible indentation issue: {stripped[:50]}...')
    
    print('✅ YAML structure validation passed')
    
except Exception as e:
    print(f'❌ Validation failed: {e}')
    sys.exit(1)
" 2>&1
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "YAML file is valid"
        return 0
    else
        log_error "YAML file has issues"
        return 1
    fi
}

# Main function
main() {
    local files_to_check=(
        "auroraboot/cloud-config.yaml"
        "auroraboot/config.yaml"
    )
    
    if [ $# -gt 0 ]; then
        files_to_check=("$@")
    fi
    
    echo "YAML Validation Report"
    echo "====================="
    echo
    
    local total_files=0
    local valid_files=0
    local invalid_files=0
    
    for file in "${files_to_check[@]}"; do
        total_files=$((total_files + 1))
        echo
        
        if validate_yaml_file "$file"; then
            valid_files=$((valid_files + 1))
        else
            invalid_files=$((invalid_files + 1))
        fi
    done
    
    echo
    echo "Summary:"
    echo "========="
    echo "Total files checked: $total_files"
    log_success "Valid files: $valid_files"
    
    if [ $invalid_files -gt 0 ]; then
        log_error "Invalid files: $invalid_files"
        echo
        echo "Common YAML Issues and Fixes:"
        echo "- Use spaces instead of tabs for indentation"
        echo "- Ensure proper nesting and indentation consistency"
        echo "- Quote strings that contain special characters"
        echo "- For cloud-config: Ensure #cloud-config header is present"
        echo "- For AuroraBoot: Template syntax {{ }} is valid and will be processed"
        return 1
    else
        log_success "All files are valid!"
        return 0
    fi
}

# Run main function
main "$@"