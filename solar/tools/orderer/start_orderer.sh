#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "start orderer ORDERER_HOST => $ORDERER_HOST ORDERER_ORG => $ORDERER_ORG CONSORTIUM_NAME => $CONSORTIUM_NAME"

check_arg ORDERER_HOST
check_arg ORDERER_ORG
check_arg CONSORTIUM_NAME

GENESIS_BLOCK_FILE=$SOLAR_TOOLS/consortium_artifact/data/${CONSORTIUM_NAME}/genesis.block
ORG_ADMIN_CERT=$SOLAR_TOOLS/org/data/${ORDERER_ORG}/msp/admincerts/${ORDERER_ORG}-admin-cert.pem

if_file_exist $GENESIS_BLOCK_FILE "genesis block file"
if_file_exist $ORG_ADMIN_CERT "org admin cert"

ORDERER_NAME=$( parse_host $ORDERER_HOST 0 )
ORDERER_ADDR=$( parse_host $ORDERER_HOST 1 )
ORDERER_PORT=$( parse_host $ORDERER_HOST 2 )

ORG_MSP_ID="${ORDERER_ORG}MSP"

set -e

SH=$SDIR/scripts
DATA=$SDIR/data
LOGS=$SDIR/logs
ORDERER_HOME=$DATA/$ORDERER_NAME

cp $GENESIS_BLOCK_FILE $ORDERER_HOME/genesis.block

mkdir -p $ORDERER_HOME/msp/admincerts
cp $ORG_ADMIN_CERT $ORDERER_HOME/msp/admincerts

MYHOME=/etc/hyperledger/orderer
MY_CA_CHAINFILE=$MYHOME/ca-cert.pem

echo "version: '2'
services:
  $ORDERER_NAME:
    container_name: $ORDERER_NAME
    image: hyperledger/fabric-orderer
    environment:
      - ORDERER_HOME=$MYHOME
      - ORDERER_HOST=$ORDERER_ADDR:$ORDERER_PORT
      - ORDERER_GENERAL_LISTENPORT=$ORDERER_PORT
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=$MYHOME/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
      - ORDERER_GENERAL_LOCALMSPDIR=$MYHOME/msp
      #- ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_ENABLED=false
      - ORDERER_GENERAL_TLS_PRIVATEKEY=$MYHOME/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=$MYHOME/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[$MY_CA_CHAINFILE]
      - ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true
      #- ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=false
      - ORDERER_GENERAL_TLS_CLIENTROOTCAS=[$MY_CA_CHAINFILE]
      - ORDERER_GENERAL_LOGLEVEL=debug
      - ORDERER_DEBUG_BROADCASTTRACEDIR=/logs

      #- ORDERER_KAFKA_VERBOSE=true
      #- ORDERER_KAFKA_TLS_ENABLED=true
      #- ORDERER_KAFKA_TLS_PRIVATEKEY_FILE=$MYHOME/tls/server.key
      #- ORDERER_KAFKA_TLS_CERTIFICATE_FILE=$MYHOME/tls/server.crt
      #- ORDERER_KAFKA_TLS_ROOTCAS_FILE=$MY_CA_CHAINFILE
    ports:
       - \"$ORDERER_PORT:$ORDERER_PORT\"
    command: /bin/bash -c '/scripts/boot_orderer.sh'
    volumes:
      - $SH:/scripts
      - $DATA:/data
      - $LOGS:/logs
      - $ORDERER_HOME:$MYHOME
      #- $SDIR/yaml/orderer-base.yaml:/etc/hyperledger/fabric/orderer.yaml

    network_mode: \"host\"" > ${SDIR}/docker-compose-${ORDERER_NAME}.yml

docker-compose -f ${SDIR}/docker-compose-${ORDERER_NAME}.yml up -d
