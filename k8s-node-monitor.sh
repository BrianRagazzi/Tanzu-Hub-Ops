#!/bin/bash

# Kubernetes Node Resource Monitor Script
# Prerequisites: kubectl and jq must be installed and kubectl context must be set

set -e

echo "Kubernetes Node Resource Summary"
echo "================================"
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed or not in PATH"
    exit 1
fi

# Check if bc is available (for calculations)
if ! command -v bc &> /dev/null; then
    echo "Error: bc is not installed or not in PATH"
    exit 1
fi

# Check if kubectl context is set
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: No valid kubectl context found"
    exit 1
fi

# Get current context
CONTEXT=$(kubectl config current-context)
echo "Current Context: $CONTEXT"
echo

# Function to convert memory from Ki to GB
convert_memory() {
    local memory_ki=$1
    if [[ $memory_ki =~ ^[0-9]+Ki$ ]]; then
        local value=${memory_ki%Ki}
        echo "scale=2; $value / 1048576" | bc
    else
        echo "0"
    fi
}

# Function to convert CPU from millicores to cores
convert_cpu() {
    local cpu_m=$1
    if [[ $cpu_m =~ ^[0-9]+m$ ]]; then
        local value=${cpu_m%m}
        echo "scale=3; $value / 1000" | bc
    elif [[ $cpu_m =~ ^[0-9]+$ ]]; then
        echo "$cpu_m"
    else
        echo "0"
    fi
}

# Print table header
printf "%-20s %-12s %-12s %-12s %-12s %-12s %-12s %-30s\n" \
    "NODE" "CPU_CAP" "MEM_CAP_GB" "CPU_USED" "MEM_USED_GB" "CPU_AVAIL" "MEM_AVAIL_GB" "TAINTS"
printf "%-20s %-12s %-12s %-12s %-12s %-12s %-12s %-30s\n" \
    "----" "-------" "----------" "--------" "-----------" "---------" "------------" "------"

# Get node information
kubectl get nodes -o json | jq -r '.items[] |
    {
        name: .metadata.name,
        cpu_capacity: .status.capacity.cpu,
        memory_capacity: .status.capacity.memory,
        cpu_allocatable: .status.allocatable.cpu,
        memory_allocatable: .status.allocatable.memory,
        taints: (.spec.taints // [] | map(.key + ":" + (.value // "")) | join(","))
    } |
    [.name, .cpu_capacity, .memory_capacity, .cpu_allocatable, .memory_allocatable, .taints] |
    @tsv' | while IFS=$'\t' read -r node cpu_cap mem_cap cpu_alloc mem_alloc taints; do

    # Get resource usage for this node
    usage_data=$(kubectl top node "$node" --no-headers 2>/dev/null || echo "$node 0m 0% 0Mi 0%")
    cpu_used=$(echo "$usage_data" | awk '{print $2}')
    mem_used=$(echo "$usage_data" | awk '{print $4}')

    # Convert memory capacity from Ki to GB
    mem_cap_gb=$(convert_memory "$mem_cap")
    mem_alloc_gb=$(convert_memory "$mem_alloc")

    # Convert CPU values
    cpu_cap_cores="$cpu_cap"
    cpu_alloc_cores="$cpu_alloc"
    cpu_used_cores=$(convert_cpu "$cpu_used")

    # Convert memory used from Mi to GB
    if [[ $mem_used =~ ^[0-9]+Mi$ ]]; then
        mem_used_value=${mem_used%Mi}
        mem_used_gb=$(echo "scale=2; $mem_used_value / 1024" | bc)
    else
        mem_used_gb="0"
    fi

    # Calculate available resources
    cpu_available=$(echo "scale=3; $cpu_alloc_cores - $cpu_used_cores" | bc)
    mem_available_gb=$(echo "scale=2; $mem_alloc_gb - $mem_used_gb" | bc)

    # Handle empty taints
    if [[ -z "$taints" ]]; then
        taints="none"
    fi

    # Print the row
    printf "%-20s %-12s %-12s %-12s %-12s %-12s %-12s %-30s\n" \
        "$node" "$cpu_cap_cores" "$mem_cap_gb" "$cpu_used_cores" "$mem_used_gb" "$cpu_available" "$mem_available_gb" "$taints"
done

echo
echo "Notes:"
echo "- CPU values are in cores"
echo "- Memory values are in GB"
echo "- Available = Allocatable - Used"
echo "- Taints format: key:value"
echo "- If 'kubectl top' metrics are unavailable, usage will show as 0"
