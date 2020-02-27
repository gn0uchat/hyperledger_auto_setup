#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

if [ $# -ne 5 ]; then
    echo "Usage: new_account <PEER_NAME> <PEER_HOST> <CA_HOST> <CA_CHAINFILE> <SECRET_FILE>: $*"
    exit 1
fi

PEER_NAME=$1
PEER_HOST=$2
CA_HOST=$3
CA_CHAINFILE=$4
SECRET_FILE=$5

CA_PORT="7054"

function gen_tls_keys {
    KEY_FILE=$1
    CRT_FILE=$2

    fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $PEER_HOME/tmp --csr.hosts $PEER_HOST
    
    cp $PEER_HOME/tmp/keystore/* $KEY_FILE 
    cp $PEER_HOME/tmp/signcerts/* $CRT_FILE
    
    rm -rf $PEER_HOME/tmp
}

set -e

DATA=$SDIR/data
mkdir -p $DATA

PEER_HOME=$DATA/$PEER_NAME
mkdir -p $PEER_HOME

if_file_exist $SECRET_FILE
PEER_SECRET=$( cat $SECRET_FILE )

ENROLLMENT_URL=https://${PEER_NAME}:${PEER_SECRET}@${CA_HOST}:${CA_PORT}

if_file_exist $CA_CHAINFILE

export FABRIC_CA_CLIENT_HOME=$DATA/fabric-ca-client
export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

TLSDIR=$PEER_HOME/tls
if [ ! -d $TLSDIR ]; then
mkdir $TLSDIR
fi

gen_tls_keys $TLSDIR/server.key $TLSDIR/server.crt

gen_tls_keys $TLSDIR/${PEER_NAME}-client.key $TLSDIR/${PEER_NAME}-client.crt

PEER_MSP=$PEER_HOME/msp
if [ ! -d $PEER_MSP ]; then
    mkdir $PEER_MSP
fi

fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $PEER_MSP

if [ ! -d $PEER_MSP/tlscacerts ]; then
    mkdir $PEER_MSP/tlscacerts
    cp $PEER_MSP/cacerts/* $PEER_MSP/tlscacerts
fi
