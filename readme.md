


# Tanzu Hub v1.0.0 issues and notes

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


curl -L https://github.com/derailed/k9s/releases/download/v0.50.6/k9s_Linux_amd64.tar.gz -o /tmp/k9s.tar.gz && cd /tmp && tar zxvf ./k9s.tar.gz && cp ./k9s ~/
