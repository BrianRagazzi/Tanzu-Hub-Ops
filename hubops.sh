#!/usr/bin/env bash


set -o errexit -o nounset -o pipefail

function bosh2hub() {
  bosh -d $(bosh deployments --column=Name | grep "hub-" | grep -v "hub-tas-collector-" | tr -d '\r') $*
}


function bosh2hubboshcmd() {
  for node in $(bosh2hub instances | tail -n+1 | awk '{print $1}');
    do
        if [[ "$node" == *"registry"* ]]; then
            echo "registry... skipping"
        elif [[ "$node" == *"system"* ]]; then
            echo "system... skipping"
        else
            echo "working on $node"
            bosh2hub $1 $node -n
        fi
    done
}

# Check for operation argument
if [[ $# -ne 1 ]] || [[ ! "$1" =~ ^(stop|start|restart)$ ]]; then
  echo "Usage: $0 {stop|start|restart}"
  exit 1
fi

operation="$1"

case "$operation" in
  stop)
    echo "Stopping Tanzu Hub nodes via bosh (soft, skip drain)..."
    bosh2hubboshcmd "stop --soft --skip-drain --no-converge"
    ;;
  start)
    echo "Starting Tanzu Hub nodes via bosh..."
    bosh2hubboshcmd "start --no-converge"
    ;;
  restart)
    echo "Restarting Tanzu Hub nodes via bosh..."
    bosh2hubboshcmd "restart --no-converge"
    ;;
  *)
    echo "Usage: $0 {stop|start|restart}"
    exit 1
    ;;
esac