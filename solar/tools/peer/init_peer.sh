#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "init_peer.sh args: PEER_HOST => $PEER_HOST CA_HOST => $CA_HOST"

check_arg PEER_HOST
check_arg CA_HOST

PEER_NAME=$( parse_host $PEER_HOST 0 )
PEER_ADDR=$( parse_host $PPER_HOST 1 )
PEER_PORT=$( parse_host $PEER_HOST 2 )

CA_NAME=$( parse_host $CA_HOST 0 )
CA_ADDR=$( parse_host $CA_HOST 1 )
CA_PORT=$( parse_host $CA_HOST 2 )

DATA=$SDIR/data
PEER_HOME=$DATA/$PEER_NAME
PEER_SECRET_FILE=$SOLAR_TOOLS/account/secret/${CA_NAME}/${PEER_NAME}
CA_CHAINFILE=$SOLAR_TOOLS/ca/data/$CA_NAME/ca-cert.pem

set -e

if_file_exist $PEER_SECRET_FILE "peer secret file"
if_file_exist $CA_CHAINFILE     "ca chain file"

mkdir -p $DATA
mkdir -p $PEER_HOME

#$SOLAR_TOOLS/account/new_account.sh $PEER_NAME peer $CA_ADDR:$CA_PORT
cp $CA_CHAINFILE $PEER_HOME/ca-cert.pem

PEER_SECRET=$( cat $PEER_SECRET_FILE )
ENROLLMENT_URL=https://${PEER_NAME}:${PEER_SECRET}@$CA_ADDR:$CA_PORT

export FABRIC_CA_CLIENT_HOME=$DATA/fabric-ca-client
export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

TLSDIR=$PEER_HOME/tls
PEER_MSP=$PEER_HOME/msp
TMP_DIR=$PEER_HOME/tmp

mkdir -p $TLSDIR
mkdir -p $PEER_MSP

gen_tls_keys $TLSDIR/server.key $TLSDIR/server.crt $PEER_ADDR $TMP_DIR
gen_tls_keys $TLSDIR/${PEER_NAME}-client.key $TLSDIR/${PEER_NAME}-client.crt $PEER_ADDR $TMP_DIR

fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $PEER_MSP

if [ ! -d $PEER_MSP/tlscacerts ]; then
    mkdir $PEER_MSP/tlscacerts
    cp $PEER_MSP/cacerts/* $PEER_MSP/tlscacerts
fi
