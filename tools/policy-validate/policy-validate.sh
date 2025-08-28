#!/bin/bash

# Policy validation script for database migrations (Shell version)
# Validates migration files against organizational policies

set -euo pipefail


# Always resolve paths relative to the script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_PATH="${1:-$SCRIPT_DIR/../../migrations}"
POLICY_PATH="${2:-$SCRIPT_DIR/../../policy/migration-policy.yml}"
BANNED_PATTERNS_PATH="${3:-$SCRIPT_DIR/../../policy/banned-patterns.txt}"

VALIDATIONS_RUN=0
FAILURE_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            echo -e "[$timestamp] [${RED}ERROR${NC}] $message" >&2
            ((FAILURE_COUNT++))
            ;;
        "WARN")
            echo -e "[$timestamp] [${YELLOW}WARN${NC}] $message"
            ;;
        "SUCCESS")
            echo -e "[$timestamp] [${GREEN}SUCCESS${NC}] $message"
            ;;
        *)
            echo "[$timestamp] [INFO] $message"
            ;;
    esac
}

# Check if required tools are available
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        log_message "yq command not found. Please install yq to parse YAML files." "ERROR"
        exit 1
    fi
    
    if ! command -v grep &> /dev/null; then
        log_message "grep command not found." "ERROR"
        exit 1
    fi
}

# Test YAML header exists
test_yaml_header() {
    local content="$1"
    local filename="$2"
    
    ((VALIDATIONS_RUN++))
    
    if ! echo "$content" | grep -Pzo '(?s)/\*---.*?---\*/' > /dev/null; then
        log_message "Missing required YAML metadata header in $filename" "ERROR"
        return 1
    fi
    
    log_message "YAML metadata header found in $filename" "SUCCESS"
    return 0
}

# Extract YAML metadata
get_yaml_metadata() {
    local content="$1"
    echo "$content" | grep -Pzo '(?s)/\*---(.*?)---\*/' | tr -d '\0' | sed -n 's|/\*---\(.*\)---\*/|\1|p'
}

# Test required metadata fields
test_required_fields() {
    local yaml_content="$1"
    local filename="$2"
    
    local required_fields=("change_id" "title" "ticket" "risk" "change_type" "backward_compatible" "owner" "rollout_plan" "rollback_plan")
    local valid_risk_levels=("low" "medium" "high")
    local valid_change_types=("additive" "modification" "deprecation" "removal")
    
    # Check required fields
    for field in "${required_fields[@]}"; do
        ((VALIDATIONS_RUN++))
        if ! echo "$yaml_content" | grep -q "^$field\s*:"; then
            log_message "Missing required metadata field '$field' in $filename" "ERROR"
        else
            log_message "Required field '$field' found in $filename" "SUCCESS"
        fi
    done
    
    # Validate risk level
    ((VALIDATIONS_RUN++))
    if echo "$yaml_content" | grep -q "^risk\s*:"; then
        local risk_level=$(echo "$yaml_content" | grep "^risk\s*:" | sed 's/^risk\s*:\s*//' | tr -d ' ')
        local valid_risk=false
        for valid in "${valid_risk_levels[@]}"; do
            if [[ "$risk_level" == "$valid" ]]; then
                valid_risk=true
                break
            fi
        done
        
        if [[ "$valid_risk" == "false" ]]; then
            log_message "Invalid risk level '$risk_level' in $filename. Must be one of: ${valid_risk_levels[*]}" "ERROR"
        else
            log_message "Valid risk level '$risk_level' in $filename" "SUCCESS"
        fi
    fi
    
    # Validate change type
    ((VALIDATIONS_RUN++))
    if echo "$yaml_content" | grep -q "^change_type\s*:"; then
        local change_type=$(echo "$yaml_content" | grep "^change_type\s*:" | sed 's/^change_type\s*:\s*//' | tr -d ' ')
        local valid_type=false
        for valid in "${valid_change_types[@]}"; do
            if [[ "$change_type" == "$valid" ]]; then
                valid_type=true
                break
            fi
        done
        
        if [[ "$valid_type" == "false" ]]; then
            log_message "Invalid change type '$change_type' in $filename. Must be one of: ${valid_change_types[*]}" "ERROR"
        else
            log_message "Valid change type '$change_type' in $filename" "SUCCESS"
        fi
    fi
}

# Test banned patterns
test_banned_patterns() {
    local content="$1"
    local filename="$2"
    local patterns_file="$3"
    
    if [[ ! -f "$patterns_file" ]]; then
        log_message "Banned patterns file not found: $patterns_file" "WARN"
        return 0
    fi
    
    while IFS= read -r pattern; do
        # Skip empty lines and comments
        if [[ -z "$pattern" ]] || [[ "$pattern" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        ((VALIDATIONS_RUN++))
        
        if echo "$content" | grep -Pqi "$pattern"; then
            log_message "Forbidden pattern '$pattern' found in $filename" "ERROR"
        fi
    done < "$patterns_file"
}

# Test filename convention
test_filename_convention() {
    local filename="$1"
    
    ((VALIDATIONS_RUN++))
    
    if [[ ! "$filename" =~ ^V[0-9]{3}__.+\.sql$ ]]; then
        log_message "Filename '$filename' does not match required pattern 'V###__*.sql'" "ERROR"
    else
        log_message "Filename '$filename' follows naming convention" "SUCCESS"
    fi
}

# Test backward compatibility
test_backward_compatibility() {
    local yaml_content="$1"
    local content="$2"
    local filename="$3"
    
    ((VALIDATIONS_RUN++))
    
    # Check if backward_compatible is explicitly set to false
    if echo "$yaml_content" | grep -q "backward_compatible\s*:\s*false"; then
        log_message "Migration $filename is marked as NOT backward compatible - requires special review" "WARN"
    fi
    
    # Check for potentially breaking operations
    local breaking_patterns=("ALTER\s+COLUMN\s+.*NOT\s+NULL" "DROP\s+COLUMN" "RENAME\s+COLUMN")
    
    for pattern in "${breaking_patterns[@]}"; do
        if echo "$content" | grep -Pqi "$pattern"; then
            log_message "Potentially breaking operation detected in $filename: $pattern" "WARN"
        fi
    done
}

# Main execution
main() {
    log_message "Starting database migration policy validation"
    log_message "Migrations path: $MIGRATIONS_PATH"
    log_message "Policy file: $POLICY_PATH"
    log_message "Banned patterns: $BANNED_PATTERNS_PATH"
    
    # Check dependencies
    check_dependencies
    
    # Check if paths exist
    if [[ ! -d "$MIGRATIONS_PATH" ]]; then
        log_message "Migrations directory not found: $MIGRATIONS_PATH" "ERROR"
        exit 1
    fi
    
    if [[ ! -f "$POLICY_PATH" ]]; then
        log_message "Policy file not found: $POLICY_PATH" "ERROR"
        exit 1
    fi
    
    log_message "Policy file loaded successfully"
    
    # Get migration files
    local migration_files=()
    while IFS= read -r -d '' file; do
        migration_files+=("$file")
    done < <(find "$MIGRATIONS_PATH" -name "V*.sql" -print0 | sort -z)
    
    if [[ ${#migration_files[@]} -eq 0 ]]; then
        log_message "No migration files found in $MIGRATIONS_PATH" "WARN"
        exit 0
    fi
    
    log_message "Found ${#migration_files[@]} migration files to validate"
    
    # Validate each migration file
    for file in "${migration_files[@]}"; do
        local filename=$(basename "$file")
        log_message "Validating $filename" "INFO"
        
        local content=$(cat "$file")
        
        # Test filename convention
        test_filename_convention "$filename"
        
        # Test YAML header exists
        if test_yaml_header "$content" "$filename"; then
            local yaml_content=$(get_yaml_metadata "$content")
            
            if [[ -n "$yaml_content" ]]; then
                # Test required metadata fields
                test_required_fields "$yaml_content" "$filename"
                
                # Test backward compatibility
                test_backward_compatibility "$yaml_content" "$content" "$filename"
            fi
        fi
        
        # Test banned patterns
        test_banned_patterns "$content" "$filename" "$BANNED_PATTERNS_PATH"
        
        log_message "Completed validation for $filename"
    done
    
    # Summary
    echo ""
    log_message "Validation Summary:" "INFO"
    log_message "Total validations run: $VALIDATIONS_RUN" "INFO"
    
    if [[ $FAILURE_COUNT -eq 0 ]]; then
        log_message "Failures: $FAILURE_COUNT" "SUCCESS"
        log_message "Policy validation PASSED - all migrations comply with policy" "SUCCESS"
        exit 0
    else
        log_message "Failures: $FAILURE_COUNT" "ERROR"
        log_message "Policy validation FAILED with $FAILURE_COUNT errors" "ERROR"
        exit 1
    fi
}

# Run main function
main "$@"
