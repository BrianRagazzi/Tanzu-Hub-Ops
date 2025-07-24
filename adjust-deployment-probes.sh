#!/bin/bash

# Script to adjust failureThreshold, periodSeconds, and timeoutSeconds values
# in startupProbe, readinessProbe, and livenessProbe sections of deployment containers
# 
# Usage: ./adjust-deployment-probes.sh <deployment-name> <namespace> [options]
#
# Author: Platform Automation Team
# Date: $(date +%Y-%m-%d)

set -euo pipefail

# Default values
DEFAULT_FAILURE_THRESHOLD=30
DEFAULT_PERIOD_SECONDS=30 #10
DEFAULT_TIMEOUT_SECONDS=30 #5

# Default values for liveness probe (may be different from startup/readiness)
DEFAULT_LIVENESS_FAILURE_THRESHOLD=10 #2
DEFAULT_LIVENESS_PERIOD_SECONDS=30
DEFAULT_LIVENESS_TIMEOUT_SECONDS=30 #5

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <deployment-name> <namespace> [options]

Required Arguments:
  deployment-name    Name of the Kubernetes deployment
  namespace         Namespace where the deployment exists

Optional Arguments:
  --startup-failure-threshold <value>     Set startupProbe failureThreshold (default: $DEFAULT_FAILURE_THRESHOLD)
  --startup-period-seconds <value>        Set startupProbe periodSeconds (default: $DEFAULT_PERIOD_SECONDS)
  --startup-timeout-seconds <value>       Set startupProbe timeoutSeconds (default: $DEFAULT_TIMEOUT_SECONDS)
  --readiness-failure-threshold <value>   Set readinessProbe failureThreshold (default: $DEFAULT_FAILURE_THRESHOLD)
  --readiness-period-seconds <value>      Set readinessProbe periodSeconds (default: $DEFAULT_PERIOD_SECONDS)
  --readiness-timeout-seconds <value>     Set readinessProbe timeoutSeconds (default: $DEFAULT_TIMEOUT_SECONDS)
  --liveness-failure-threshold <value>    Set livenessProbe failureThreshold (default: $DEFAULT_LIVENESS_FAILURE_THRESHOLD)
  --liveness-period-seconds <value>       Set livenessProbe periodSeconds (default: $DEFAULT_LIVENESS_PERIOD_SECONDS)
  --liveness-timeout-seconds <value>      Set livenessProbe timeoutSeconds (default: $DEFAULT_LIVENESS_TIMEOUT_SECONDS)
  --container-name <name>                 Target specific container (optional, applies to all containers if not specified)
  --dry-run                              Show what would be changed without applying
  --help                                 Display this help message

Examples:
  # Adjust all probe values for all containers in deployment
  $0 my-app default --startup-failure-threshold 5 --readiness-period-seconds 15 --liveness-timeout-seconds 10

  # Adjust only startup probe for specific container
  $0 my-app default --container-name web --startup-timeout-seconds 30

  # Adjust liveness probe settings
  $0 my-app default --liveness-failure-threshold 3 --liveness-period-seconds 30

  # Dry run to see changes without applying
  $0 my-app default --startup-failure-threshold 10 --liveness-period-seconds 20 --dry-run

EOF
}

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to validate numeric input
validate_number() {
    local value=$1
    local param_name=$2
    
    if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -le 0 ]; then
        log "ERROR: $param_name must be a positive integer, got: $value"
        exit 1
    fi
}

# Function to check if deployment exists
check_deployment_exists() {
    local deployment=$1
    local namespace=$2
    
    if ! kubectl get deployment "$deployment" -n "$namespace" &>/dev/null; then
        log "ERROR: Deployment '$deployment' not found in namespace '$namespace'"
        exit 1
    fi
}

# Function to get container names from deployment
get_container_names() {
    local deployment=$1
    local namespace=$2
    
    kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[*].name}'
}

# Function to create YAML patch file for a specific container
create_patch_file() {
    local container_index=$1
    local deployment_name=$2
    local container_name=$3
    local patch_file="/tmp/${deployment_name}-${container_name}-probe-patch.yaml"
    
    # Start building the YAML patch
    cat > "$patch_file" << EOF
spec:
  template:
    spec:
      containers:
      - name: $container_name
EOF

    # Add startup probe patches (always include since we have defaults)
    echo "        startupProbe:" >> "$patch_file"
    echo "          failureThreshold: $STARTUP_FAILURE_THRESHOLD" >> "$patch_file"
    echo "          periodSeconds: $STARTUP_PERIOD_SECONDS" >> "$patch_file"
    echo "          timeoutSeconds: $STARTUP_TIMEOUT_SECONDS" >> "$patch_file"
    
    # Add readiness probe patches (always include since we have defaults)
    echo "        readinessProbe:" >> "$patch_file"
    echo "          failureThreshold: $READINESS_FAILURE_THRESHOLD" >> "$patch_file"
    echo "          periodSeconds: $READINESS_PERIOD_SECONDS" >> "$patch_file"
    echo "          timeoutSeconds: $READINESS_TIMEOUT_SECONDS" >> "$patch_file"
    
    # Add liveness probe patches (always include since we have defaults)
    echo "        livenessProbe:" >> "$patch_file"
    echo "          failureThreshold: $LIVENESS_FAILURE_THRESHOLD" >> "$patch_file"
    echo "          periodSeconds: $LIVENESS_PERIOD_SECONDS" >> "$patch_file"
    echo "          timeoutSeconds: $LIVENESS_TIMEOUT_SECONDS" >> "$patch_file"
    
    echo "$patch_file"
}

# Function to cleanup temporary patch files
cleanup_patch_files() {
    local deployment_name=$1
    rm -f /tmp/${deployment_name}-*-probe-patch.yaml
}

# Function to apply patches to deployment using patch files
apply_patches() {
    local deployment=$1
    local namespace=$2
    local container_names=($3)
    local target_container=$4
    local dry_run=$5
    
    local dry_run_flag=""
    if [ "$dry_run" = "true" ]; then
        dry_run_flag="--dry-run=client"
        log "DRY RUN MODE - No changes will be applied"
    fi
    
    local patch_files_created=()
    
    # If target container is specified, find its index
    if [ -n "$target_container" ]; then
        local container_index=-1
        for i in "${!container_names[@]}"; do
            if [ "${container_names[$i]}" = "$target_container" ]; then
                container_index=$i
                break
            fi
        done
        
        if [ $container_index -eq -1 ]; then
            log "ERROR: Container '$target_container' not found in deployment '$deployment'"
            log "Available containers: ${container_names[*]}"
            exit 1
        fi
        
        local patch_file=$(create_patch_file $container_index "$deployment" "$target_container")
        if [ -n "$patch_file" ]; then
            patch_files_created+=("$patch_file")
            log "Created patch file: $patch_file"
            log "Applying patch to container '$target_container' (index $container_index)..."
            
            if [ "$dry_run" = "true" ]; then
                log "Would apply patch file: $patch_file"
                log "Patch file contents:"
                cat "$patch_file" | sed 's/^/  /'
            else
                kubectl patch deployment "$deployment" -n "$namespace" --type='strategic' --patch-file="$patch_file"
                log "Successfully patched container '$target_container'"
            fi
        else
            log "No changes specified for container '$target_container'"
        fi
    else
        # Apply to all containers
        for i in "${!container_names[@]}"; do
            local patch_file=$(create_patch_file $i "$deployment" "${container_names[$i]}")
            if [ -n "$patch_file" ]; then
                patch_files_created+=("$patch_file")
                log "Created patch file: $patch_file"
                log "Applying patch to container '${container_names[$i]}' (index $i)..."
                
                if [ "$dry_run" = "true" ]; then
                    log "Would apply patch file: $patch_file"
                    log "Patch file contents:"
                    cat "$patch_file" | sed 's/^/  /'
                else
                    kubectl patch deployment "$deployment" -n "$namespace" --type='strategic' --patch-file="$patch_file"
                    log "Successfully patched container '${container_names[$i]}'"
                fi
            fi
        done
    fi
    
    # Clean up patch files after use (unless dry run for inspection)
    if [ "$dry_run" = "false" ]; then
        for patch_file in "${patch_files_created[@]}"; do
            rm -f "$patch_file"
            log "Cleaned up patch file: $patch_file"
        done
    else
        log "Patch files preserved for inspection (dry run mode):"
        for patch_file in "${patch_files_created[@]}"; do
            log "  $patch_file"
        done
    fi
}

# Main function
main() {
    # Set up cleanup trap
    trap 'cleanup_patch_files "${deployment_name:-unknown}" 2>/dev/null || true' EXIT
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log "ERROR: kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check for help flag first
    if [[ "$*" == *"--help"* ]]; then
        usage
        exit 0
    fi
    
    # Check if we have at least 2 arguments
    if [ $# -lt 2 ]; then
        log "ERROR: Missing required arguments"
        usage
        exit 1
    fi
    
    local deployment_name=$1
    local namespace=$2
    shift 2
    
    # Initialize variables with default values for all probe types
    local STARTUP_FAILURE_THRESHOLD="$DEFAULT_FAILURE_THRESHOLD"
    local STARTUP_PERIOD_SECONDS="$DEFAULT_PERIOD_SECONDS"
    local STARTUP_TIMEOUT_SECONDS="$DEFAULT_TIMEOUT_SECONDS"
    local READINESS_FAILURE_THRESHOLD="$DEFAULT_FAILURE_THRESHOLD"
    local READINESS_PERIOD_SECONDS="$DEFAULT_PERIOD_SECONDS"
    local READINESS_TIMEOUT_SECONDS="$DEFAULT_TIMEOUT_SECONDS"
    local LIVENESS_FAILURE_THRESHOLD="$DEFAULT_LIVENESS_FAILURE_THRESHOLD"
    local LIVENESS_PERIOD_SECONDS="$DEFAULT_LIVENESS_PERIOD_SECONDS"
    local LIVENESS_TIMEOUT_SECONDS="$DEFAULT_LIVENESS_TIMEOUT_SECONDS"
    local TARGET_CONTAINER=""
    local DRY_RUN="false"
    
    # Parse optional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --startup-failure-threshold)
                STARTUP_FAILURE_THRESHOLD="$2"
                validate_number "$STARTUP_FAILURE_THRESHOLD" "startup-failure-threshold"
                shift 2
                ;;
            --startup-period-seconds)
                STARTUP_PERIOD_SECONDS="$2"
                validate_number "$STARTUP_PERIOD_SECONDS" "startup-period-seconds"
                shift 2
                ;;
            --startup-timeout-seconds)
                STARTUP_TIMEOUT_SECONDS="$2"
                validate_number "$STARTUP_TIMEOUT_SECONDS" "startup-timeout-seconds"
                shift 2
                ;;
            --readiness-failure-threshold)
                READINESS_FAILURE_THRESHOLD="$2"
                validate_number "$READINESS_FAILURE_THRESHOLD" "readiness-failure-threshold"
                shift 2
                ;;
            --readiness-period-seconds)
                READINESS_PERIOD_SECONDS="$2"
                validate_number "$READINESS_PERIOD_SECONDS" "readiness-period-seconds"
                shift 2
                ;;
            --readiness-timeout-seconds)
                READINESS_TIMEOUT_SECONDS="$2"
                validate_number "$READINESS_TIMEOUT_SECONDS" "readiness-timeout-seconds"
                shift 2
                ;;
            --liveness-failure-threshold)
                LIVENESS_FAILURE_THRESHOLD="$2"
                validate_number "$LIVENESS_FAILURE_THRESHOLD" "liveness-failure-threshold"
                shift 2
                ;;
            --liveness-period-seconds)
                LIVENESS_PERIOD_SECONDS="$2"
                validate_number "$LIVENESS_PERIOD_SECONDS" "liveness-period-seconds"
                shift 2
                ;;
            --liveness-timeout-seconds)
                LIVENESS_TIMEOUT_SECONDS="$2"
                validate_number "$LIVENESS_TIMEOUT_SECONDS" "liveness-timeout-seconds"
                shift 2
                ;;
            --container-name)
                TARGET_CONTAINER="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log "ERROR: Unknown option $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # All probe types now have default values, so validation is always satisfied
    log "INFO: Applying probe configurations - startup, readiness, and liveness probes will be configured"
    
    log "Starting probe adjustment for deployment '$deployment_name' in namespace '$namespace'"
    
    # Check if deployment exists
    check_deployment_exists "$deployment_name" "$namespace"
    
    # Get container names
    local container_names_str=$(get_container_names "$deployment_name" "$namespace")
    local container_names=($container_names_str)
    
    if [ ${#container_names[@]} -eq 0 ]; then
        log "ERROR: No containers found in deployment '$deployment_name'"
        exit 1
    fi
    
    log "Found containers: ${container_names[*]}"
    
    # Apply patches
    apply_patches "$deployment_name" "$namespace" "$container_names_str" "$TARGET_CONTAINER" "$DRY_RUN"
    
    if [ "$DRY_RUN" = "false" ]; then
        log "Probe adjustment completed successfully for deployment '$deployment_name'"
        log "You can check the deployment status with: kubectl get deployment $deployment_name -n $namespace"
    else
        log "Dry run completed - no changes were applied"
    fi
}

# Run main function with all arguments
main "$@"