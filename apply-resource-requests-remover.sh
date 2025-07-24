#!/bin/bash

# Script to apply resource requests removal overlay to a PackageInstall
# Prerequisites: carvel tools (kapp, kctrl, ytt), kubectl, and jq must be installed

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <package-install-name> [namespace]"
    echo ""
    echo "Arguments:"
    echo "  package-install-name   Name of the PackageInstall object"
    echo "  namespace             Namespace of the PackageInstall (optional, defaults to current context namespace)"
    echo ""
    echo "Examples:"
    echo "  $0 my-package-install"
    echo "  $0 my-package-install my-namespace"
    echo ""
    echo "This script will:"
    echo "1. Extract the current PackageInstall configuration"
    echo "2. Apply the resource requests removal overlay using ytt"
    echo "3. Update the PackageInstall with the modified configuration"
    exit 1
}

# Check if required tools are available
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v kctrl &> /dev/null; then
        missing_tools+=("kctrl")
    fi
    
    if ! command -v ytt &> /dev/null; then
        missing_tools+=("ytt")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: The following required tools are not installed or not in PATH:"
        printf '  %s\n' "${missing_tools[@]}"
        echo ""
        echo "Please install the missing tools and try again."
        exit 1
    fi
}

# Validate kubectl context
check_kubectl_context() {
    if ! kubectl cluster-info &> /dev/null; then
        echo "Error: No valid kubectl context found"
        echo "Please configure kubectl to connect to your cluster"
        exit 1
    fi
    
    local context=$(kubectl config current-context)
    echo "Using kubectl context: $context"
}

# Main function
main() {
    # Check arguments
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        usage
    fi
    
    local package_install_name="$1"
    local namespace="${2:-}"
    
    # Set namespace flag for kubectl commands
    local namespace_flag=""
    if [ -n "$namespace" ]; then
        namespace_flag="-n $namespace"
        echo "Using namespace: $namespace"
    else
        local current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
        echo "Using current context namespace: $current_namespace"
    fi
    
    # Check prerequisites
    echo "Checking prerequisites..."
    check_prerequisites
    check_kubectl_context
    echo ""
    
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local overlay_file="$script_dir/remove-resource-requests-overlay.yaml"
    
    # Check if overlay file exists
    if [ ! -f "$overlay_file" ]; then
        echo "Error: Overlay file not found at $overlay_file"
        echo "Please ensure remove-resource-requests-overlay.yaml is in the same directory as this script"
        exit 1
    fi
    
    echo "Found overlay file: $overlay_file"
    
    # Check if PackageInstall exists
    echo "Checking if PackageInstall '$package_install_name' exists..."
    if ! kubectl get packageinstall "$package_install_name" $namespace_flag &> /dev/null; then
        echo "Error: PackageInstall '$package_install_name' not found"
        if [ -n "$namespace" ]; then
            echo "Please verify the name and namespace are correct"
        else
            echo "Please verify the name is correct or specify the correct namespace"
        fi
        exit 1
    fi
    
    echo "PackageInstall '$package_install_name' found"
    echo ""
    
    # Create temporary directory for processing
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    echo "Processing PackageInstall..."
    
    # Get current PackageInstall spec
    local current_spec_file="$temp_dir/current-spec.yaml"
    kubectl get packageinstall "$package_install_name" $namespace_flag -o yaml > "$current_spec_file"
    
    # Extract the values from the PackageInstall if they exist
    local values_file="$temp_dir/values.yaml"
    kubectl get packageinstall "$package_install_name" $namespace_flag -o jsonpath='{.spec.values}' > "$values_file" 2>/dev/null || echo "{}" > "$values_file"
    
    # Get the package reference to understand what we're working with
    local package_ref=$(kubectl get packageinstall "$package_install_name" $namespace_flag -o jsonpath='{.spec.packageRef.refName}')
    echo "Package reference: $package_ref"
    
    # Create overlay configuration for the PackageInstall
    local overlay_config_file="$temp_dir/overlay-config.yaml"
    cat > "$overlay_config_file" << EOF
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: $package_install_name
spec:
  packageRef:
    refName: $package_ref
  values:
$(cat "$values_file" | sed 's/^/    /')
  overlays:
  - name: remove-resource-requests
    overlay: |
$(cat "$overlay_file" | sed 's/^/      /')
EOF
    
    echo "Applying overlay to remove resource requests..."
    
    # Apply the updated PackageInstall with overlay
    kubectl apply -f "$overlay_config_file" $namespace_flag
    
    echo ""
    echo "Successfully applied resource requests removal overlay to PackageInstall '$package_install_name'"
    echo ""
    echo "The overlay will:"
    echo "- Remove resource.requests from all containers in Deployments"
    echo "- Remove resource.requests from all containers in StatefulSets"
    echo "- Remove resource.requests from all initContainers in Deployments and StatefulSets"
    echo ""
    echo "You can monitor the PackageInstall status with:"
    echo "  kubectl get packageinstall $package_install_name $namespace_flag -o yaml"
}

# Run main function with all arguments
main "$@"