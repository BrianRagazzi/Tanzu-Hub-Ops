


# Tanzu Hub issues and notes

## cannot start after stop



## Troubleshooting Hub from opsMgr
Add these to .bashrc on OM VM:

```
function bosh2hub() {
  bosh -d $(bosh deployments --column=Name | grep "hub-" | tr -d '\r') $*
}

function bosh2hubssh() {
  if [ $# -gt 1 ]; then
    bosh2hub ssh $(bosh2hub instances | tail -n+8 | awk '{print $1}' | sed -n "#1 p") "${@:2}"
  else
    bosh2hub ssh $(bosh2hub instances | tail -n+8 | awk '{print $1}' | sed -n "#1 p")
  fi
}

function bosh2hubfixantrea() {
  for i in {1..11}; do bosh2hubssh $i sudo /var/vcap/jobs/prepare-antrea-nodes/bin/pre-start ; done
  bosh2hubssh 14 sudo /var/vcap/jobs/prepare-antrea-nodes/bin/pre-start
}

function bosh2hubfixregistry() {
  bosh2hubssh 12 sudo /var/vcap/jobs/registry/bin/pre-start
  sleep 10
  bosh2hubssh 12 sudo monit restart registry
}

```

## need additional tools on registry

Add these to .bashrc on registry VM
```
alias k9sme='echo "sudo rm /tmp/* || true && curl -L https://github.com/derailed/k9s/releases/download/v0.50.6/k9s_Linux_amd64.tar.gz -o /tmp/k9s.tar.gz && cd /tmp && tar zxvf ./k9s.tar.gz && cp ./k9s ~/ && cd && ./k9s" | pbcopy'

alias kctrlme="echo 'mkdir local-bin && curl -L https://carvel.dev/install.sh | K14SIO_INSTALL_BIN_DIR=local-bin bash && export PATH=\$PWD/local-bin/:\$PATH && kctrl version' | pbcopy"

mkdir local-bin && curl -k -L https://carvel.dev/install.sh | K14SIO_INSTALL_BIN_DIR=local-bin bash
export PATH+=:$PWD/local-bin
```
original Path:
/var/vcap/jobs/bpm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/var/vcap/bosh/bin:/var/vcap/packages/kubectl/bin


Install things:
mkdir local-bin && curl -L https://carvel.dev/install.sh | K14SIO_INSTALL_BIN_DIR=local-bin bash && export PATH=$PWD/local-bin/:$PATH && kctrl version


curl -L https://github.com/derailed/k9s/releases/download/v0.50.6/k9s_Linux_amd64.tar.gz -o local-bin/k9s.tar.gz && cd local-bin && tar zxvf ./k9s.tar.gz && cp ./k9s ~/

## Bash Scripts

This repository contains several utility scripts for managing Tanzu Hub operations:

### [`adjust-deployment-probes.sh`](adjust-deployment-probes.sh)
A comprehensive script for adjusting Kubernetes deployment probe configurations (startup, readiness, and liveness probes).

**Features:**
- Configures failureThreshold, periodSeconds, and timeoutSeconds for all probe types
- Supports targeting specific containers or all containers in a deployment
- Includes dry-run mode for testing changes before applying
- Provides extensive command-line options for fine-tuning probe settings
- Validates input parameters and deployment existence

**Usage:** `./adjust-deployment-probes.sh <deployment-name> <namespace> [options]`

### [`apply-resource-requests-remover.sh`](apply-resource-requests-remover.sh)
Applies a resource requests removal overlay to Kubernetes PackageInstall objects using Carvel tools.

**Features:**
- Removes resource requests from containers in Deployments and StatefulSets
- Works with Carvel PackageInstall objects
- Validates prerequisites (kubectl, kctrl, ytt, jq)
- Automatically handles overlay configuration and application

**Usage:** `./apply-resource-requests-remover.sh <package-install-name> [namespace]`

### [`fixhub.sh`](fixhub.sh)
A Tanzu Hub stabilization script that restarts Antrea and Registry services on hub nodes after power-up events.

**Features:**
- Connects to Tanzu Hub deployment via BOSH
- Restarts Antrea on all non-registry, non-system nodes
- Restarts Registry service with proper timing
- Designed for post-power-up stabilization scenarios

**Usage:** `./fixhub.sh`

### [`k8s-node-monitor.sh`](k8s-node-monitor.sh)
A Kubernetes cluster monitoring script that provides detailed node resource information.

**Features:**
- Displays CPU and memory capacity, usage, and availability for all nodes
- Shows node taints and current kubectl context
- Converts units for easy reading (cores for CPU, GB for memory)
- Requires kubectl, jq, and bc tools

**Usage:** `./k8s-node-monitor.sh`

### [`reqfix/reqfix.sh`](reqfix/reqfix.sh)
A quick utility script for applying resource request fixes to Tanzu Service Mesh components.

**Features:**
- Deletes and recreates reqfix-related secrets in tanzusm namespace
- Patches the daedalus PackageInstall with overlay annotations
- Works in conjunction with [`reqfix.yaml`](reqfix/reqfix.yaml) overlay file

**Usage:** `./reqfix/reqfix.sh` (run from reqfix directory)
