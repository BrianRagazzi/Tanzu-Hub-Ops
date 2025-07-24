#!/usr/bin/env bash
## fixhub.sh
## Restarts Antrea and Registry on Tanzu Hub nodes to stabilize
## following non-install power-up

set -o errexit -o nounset -o pipefail

function bosh2hub() {
  bosh -d $(bosh deployments --column=Name | grep "hub-" | grep -v "hub-tas-collector-" | tr -d '\r') $*
}


function bosh2hubfixantreaskipreg() {
  for node in $(bosh2hub instances | tail -n+1 | awk '{print $1}');
    do
      if [[ "$node" == *"registry"* ]]; then
        echo "registry... skipping"
      elif [[ "$node" == *"system"* ]]; then
        echo "system... skipping"
      else
        echo $node
        bosh2hub ssh $node sudo /var/vcap/jobs/prepare-antrea-nodes/bin/pre-start
      fi
    done
}


function bosh2hubfixonlyreg() {
  for node in $(bosh2hub instances | tail -n+1 | awk '{print $1}');
    do
      if [[ "$node" == *"registry"* ]]; then
        echo "registry... restarting registry"
        bosh2hub ssh $node sudo /var/vcap/jobs/registry/bin/pre-start
        echo "pausing 10 seconds..."
        sleep 10
        bosh2hub ssh $node sudo monit restart registry
      fi
    done
}


echo "Connecting to each Tanzu Hub node to restart antrea"
bosh2hubfixantreaskipreg
echo "restarting registry"
bosh2hubfixonlyreg
echo "Should be working..."
