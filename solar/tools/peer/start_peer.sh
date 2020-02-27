#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "start peer PEER_HOST => $PEER_HOST PEER_ORG => $PEER_ORG"

check_arg PEER_HOST
check_arg PEER_ORG

PEER_NAME=$( parse_host $PEER_HOST 0 )
PEER_ADDR=$( parse_host $PEER_HOST 1 )
PEER_PORT=$( parse_host $PEER_HOST 2 )

DB_ADDR=$PEER_ADDR
DB_PORT=$( parse_host $PEER_HOST 3 )

ORG_ADMIN_CERT=$SOLAR_TOOLS/org/data/${PEER_ORG}/msp/admincerts/${PEER_ORG}-admin-cert.pem

if_file_exist $ORG_ADMIN_CERT "org admin certificate"

SH=$SDIR/scripts
DATA=$SDIR/data
LOGS=$SDIR/logs
PEER_HOME=${DATA}/${PEER_NAME}

mkdir -p $SH; mkdir -p $DATA; mkdir -p $LOGS; mkdir -p $PEER_HOME;

function main {

    mkdir -p $PEER_HOME/msp/admincerts
    cp $ORG_ADMIN_CERT $PEER_HOME/msp/admincerts/
    
    { 
        writePeerDocker 
    } > $SDIR/docker-compose-${PEER_NAME}.yml
    
    docker-compose -f ${SDIR}/docker-compose-${PEER_NAME}.yml up -d
}

function writePeerDocker {
   MYHOME=/opt/gopath/src/github.com/hyperledger/fabric/peer
   MY_CA_CHAINFILE=$MYHOME/ca-cert.pem
   ORG_MSP_ID=${PEER_ORG}MSP

   PEER_PRODUCTION=$PEER_HOME/production
   PEER_RUN=$PEER_HOME/run
   PEER_DB_HOME=$PEER_HOME/db

   PEER_DB_NAME=couchdb.$PEER_NAME

   mkdir -p $PEER_PRODUCTION; mkdir -p $PEER_RUN; mkdir -p $PEER_DB_HOME;

   echo "version: '2'
services:

  $PEER_DB_NAME:
    container_name: $PEER_DB_NAME
    #image: hyperledger/fabric-couchdb:0.4.10 
    image: hyperledger/fabric-couchdb
    # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
    # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
    environment:
      - COUCHDB_USER=
      - COUCHDB_PASSWORD=
    # Comment/Uncomment the port mapping if you want to hide/expose the CouchDB service,
    # for example map it to utilize Fauxton User Interface in dev environments.
    ports:
       - \"$DB_PORT:5984\"
    volumes:
       - $PEER_DB_HOME:/opt/couchdb/data

  $PEER_NAME:
    container_name: $PEER_NAME
    image: hyperledger/fabric-peer
    environment:
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$DB_ADDR:$DB_PORT
      #- CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$DB_HOST
      # The CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME and CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD
      # provide the credentials for ledger to connect to CouchDB.  The username and password must
      # match the username and password set for the associated CouchDB.
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=
 
      - CORE_PEER_ID=$PEER_NAME
      - CORE_PEER_ADDRESS=0.0.0.0:7051
      - CORE_PEER_LOCALMSPID=$ORG_MSP_ID
      - CORE_PEER_MSPCONFIGPATH=$MYHOME/msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=host
      - CORE_LOGGING_LEVEL=DEBUG
      - CORE_CHAINCODE_LOGGING_LEVEL=DEBUG
      #- CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_ENABLED=false
      - CORE_PEER_TLS_CERT_FILE=$MYHOME/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=$MYHOME/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=$MY_CA_CHAINFILE
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:7051
      - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
      - CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
      - CORE_PEER_TLS_CLIENTROOTCAS_FILES=$MY_CA_CHAINFILE
      - CORE_PEER_TLS_CLIENTCERT_FILE=$MYHOME/tls/$PEER_NAME-client.crt
      - CORE_PEER_TLS_CLIENTKEY_FILE=$MYHOME/tls/$PEER_NAME-client.key"
   #if [ $NUM -gt 1 ]; then
   #   echo "      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:$PEER_PORT"
   #fi
   echo "    working_dir: $MYHOME
    command: /bin/bash -c '/scripts/boot_peer.sh'
    volumes:
      - $PEER_PRODUCTION:/var/hyperledger/production
      #- $PEER_RUN:/host/var/run
      - /var/run:/host/var/run
      - ${SH}:/scripts
      - ${DATA}:/data
      - ${LOGS}:/logs
      - ${PEER_HOME}:${MYHOME}
    ports:
       - \"$PEER_PORT:7051\"
    #network_mode: \"host\"
    depends_on:
      - $PEER_DB_NAME"
}

main
