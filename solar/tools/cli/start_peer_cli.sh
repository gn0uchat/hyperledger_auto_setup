#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
SOLAR_ROOT=$( dirname $SOLAR_TOOLS )
. $SOLAR_TOOLS/lib.sh

log "start peer client PEER_HOST => $PEER_HOST PEER_ORG => $PEER_ORG"

check_arg PEER_HOST
check_arg PEER_ORG

PEER_NAME=$( host_name peer $PEER_HOST )
PEER_ADDR=$( host_addr peer $PEER_HOST )
PEER_PORT=$( host_port peer $PEER_HOST )

CLI_NAME=${PEER_NAME}-cli

CHAINCODE_DIR=${SOLAR_ROOT}/chaincode
SH=$SDIR/scripts
DATA=$SDIR/data
LOGS=$SDIR/logs
CLI_HOME=$DATA/${CLI_NAME}

PEER_HOME=$SOLAR_TOOLS/peer/data/${PEER_NAME}
ORG_ADMIN_HOME=${SOLAR_TOOLS}/org/data/${PEER_ORG}/${PEER_ORG}-admin

function main {

    if_dir_exist $PEER_HOME 		"peer home dir"
    if_dir_exist $ORG_ADMIN_HOME	"admin dir of ${PEER_ORG}"

    set -e

    mkdir -p $SH; mkdir -p $DATA; mkdir -p $LOGS; mkdir -p $CLI_HOME;
    
    cp $PEER_HOME/ca-cert.pem $CLI_HOME

    { 
        writePeerDocker 
    } > $SDIR/docker-compose-${CLI_NAME}.yml
    
    docker-compose -f ${SDIR}/docker-compose-${CLI_NAME}.yml up -d
}

function writePeerDocker {
   MYHOME=/opt/gopath/src/github.com/hyperledger/fabric/peer
   CCHOME=/opt/gopath/src/
   MY_CA_CHAINFILE=$MYHOME/ca-cert.pem
   ORG_MSP_ID=${PEER_ORG}MSP

   FABRIC_DIR=${GOPATH}/src/github.com/hyperledger/fabric

   echo "version: '2'
services:
  ${CLI_NAME}:
    container_name: $CLI_NAME
    image: hyperledger/fabric-tools:1.2.0
    #image: hyperledger/fabric-ca-tools
    tty: true
    environment:
      - CLI_PEER_ORG=$PEER_ORG
      - CLI_HOME=$MYHOME
      - CA_CHAINFILE=${MY_CA_CHAINFILE}
      - CORE_PEER_ID=$PEER_NAME
      - CORE_PEER_ADDRESS=$PEER_ADDR:$PEER_PORT
      - CORE_PEER_LOCALMSPID=$ORG_MSP_ID
      - CORE_PEER_MSPCONFIGPATH=$MYHOME/org_admin_msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=host
      - CORE_LOGGING_LEVEL=DEBUG
      #- CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_ENABLED=false
      - CORE_PEER_TLS_ROOTCERT_FILE=$MY_CA_CHAINFILE
      - CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
      - CORE_PEER_TLS_CLIENTROOTCAS_FILES=$MY_CA_CHAINFILE
      - CORE_PEER_TLS_CLIENTCERT_FILE=$MYHOME/tls/$PEER_NAME-client.crt
      - CORE_PEER_TLS_CLIENTKEY_FILE=$MYHOME/tls/$PEER_NAME-client.key
    working_dir: $MYHOME
    volumes:"

  for cc_dir in $CHAINCODE_DIR/*/; do  
    cc_dir_name=$( basename $cc_dir )
    echo -n "
      - ${cc_dir}:${CCHOME}/$cc_dir_name" 
  done  

    echo "
      - ${SH}:/scripts
      - ${DATA}:/data
      - ${LOGS}:/logs
      - ${CLI_HOME}:${MYHOME}
      - ${ORG_ADMIN_HOME}/msp:${MYHOME}/org_admin_msp
      - ${PEER_HOME}/tls:${MYHOME}/tls
      - ${FABRIC_DIR}:/opt/gopath/src/github.com/hyperledger/fabric
      - /var/run:/host/var/run
    network_mode: \"host\"" 
}

main
