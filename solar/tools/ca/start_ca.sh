#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
source $SOLAR_TOOLS/lib.sh

#if [ $# -ne 2 ]; then
#    echo "Usage: start_ca <CA_NAME> <CA_PORT>:$*"
#    exit 1
#fi

log "start_ca.sh args: CA_HOST => $CA_HOST"

check_arg CA_HOST

CA_NAME=$( parse_host $CA_HOST 0 )
CA_ADDR=$( parse_host $CA_HOST 1 )
CA_PORT=$( parse_host $CA_HOST 2 )

#CA_NAME=$1
#CA_PORT=$2
#CA_HOST=$LOCAL_HOST
#CA_HOST="127.0.0.1"
#CA_PORT="7054"

function main {

    SH=${SDIR}/scripts
    DATA=${SDIR}/data
    CA_DIR=$DATA/${CA_NAME}

    mkdir -p $SH; mkdir -p $DATA; mkdir -p $CA_DIR;

    CA_SECRET=$CA_DIR/ca-secret
    if [ ! -f ${CA_SECRET} ]; then
        openssl rand -hex 16 > ${CA_SECRET}
        chmod 400 ${CA_SECRET}
    fi

    makeCADocker ${SDIR}/docker-compose-${CA_NAME}.yml

    docker-compose -f ${SDIR}/docker-compose-${CA_NAME}.yml up -d
}

function makeCADocker {
    FILE=$1
    CA_LOGFILE=/logs/${CA_NAME}.log

    echo \
"version: '2'
services:

  $CA_NAME:
    container_name: $CA_NAME
    image: hyperledger/fabric-ca
    command: /bin/bash -c '/scripts/boot-ca.sh'
    environment:
      - FABRIC_CA_SERVER_PORT=$CA_PORT
      - FABRIC_CA_SERVER_CA_NAME=$CA_NAME
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_CN=$CA_NAME
      - FABRIC_CA_SERVER_CSR_HOSTS=$CA_ADDR
      - FABRIC_CA_SERVER_DEBUG=true
    volumes:
      - ${SH}:/scripts
      - ${DATA}:/data
      - ${CA_DIR}:/etc/hyperledger/fabric-ca
      - ${SDIR}/logs:/logs
    network_mode: \"host\"
    ports:
       - \"${CA_PORT}:${CA_PORT}\" " >  $FILE
}

main
