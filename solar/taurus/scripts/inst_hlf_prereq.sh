#!/bin/bash

function inst_docker {

   echo $HKPC_CT_PW | sudo -S apt-get update

   echo $HKPC_CT_PW | sudo -S apt-get install -y \
       apt-transport-https \
       ca-certificates \
       curl \
       software-properties-common

   log "download gpg"

   #curl -fsSL https://download.docker.com/linux/ubuntu/gpg | ( echo $HKPC_CT_PW | sudo -S apt-key add - )
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg > ./docker.gpg
   echo $HKPC_CT_PW | sudo -S apt-key add ./docker.gpg

   log "user: $USER apt-get install"

   echo $HKPC_CT_PW | sudo -S add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

   echo $HKPC_CT_PW | sudo -S apt-get update

   echo $HKPC_CT_PW | sudo -S apt-get install -y docker-ce

   echo $HKPC_CT_PW | sudo -S usermod -G docker $USER
}

function inst_docker-compose {
   echo $HKPC_CT_PW | sudo -S curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" \
   -o /usr/local/bin/docker-compose

   echo $HKPC_CT_PW | sudo -S chmod +x /usr/local/bin/docker-compose

   echo $HKPC_CT_PW | sudo -S curl -L https://raw.githubusercontent.com/docker/compose/1.22.0/contrib/completion/bash/docker-compose \
   -o /etc/bash_completion.d/docker-compose

}

function inst_golang {
   wget https://dl.google.com/go/go1.11.linux-amd64.tar.gz

   echo $HKPC_CT_PW | sudo -S tar -C /usr/local -xzf  go1.11.linux-amd64.tar.gz

   echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc

   echo "export GOPATH=\$HOME/go" >> ~/.bashrc

   echo "export PATH=\$PATH:\$GOPATH/bin" >> ~/.bashrc

   rm go1.11.linux-amd64.tar.gz
}

function inst_nodejs {
   curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -

   sudo apt-get install -y nodejs

   sudo apt-get install -y build-essential
}

function inst_python {

   echo $HKPC_CT_PW | sudo -S apt-get install -y python
}

function inst_prereq {
   set -e

   log "install docker"
   inst_docker
   log "install docker-compose"
   inst_docker-compose
   log "install golang"
   inst_golang
   #inst_nodejs
   log "install python"
   inst_python
   inst_jq
}

function inst_jq {
    echo $HKPC_CT_PW | sudo -S apt-get install -y jq
}

function inst_fabric_sample {
   inst_prereq
   curl -sSL http://bit.ly/2ysbOFE | bash -s 1.2.0 && \
   echo "export PATH=\$PATH:$PWD/fabric-samples/bin" >> ~/.bashrc
}

function log {
	MSG=$1
	echo "[log] $MSG"
}

mkdir -p hlf_prereq_tmp
cd hlf_prereq_tmp

#inst_prereq && \
inst_jq && \
source ~/.bashrc

cd ..
rm -r hlf_prereq_tmp

#echo $HKPC_CT_PW
#echo $HKPC_CT_PW | sudo -S ls .
