#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh


if [ $# -ne 5 ]; then
    echo "Usage: setup_orderer <ORDERER_NAME> <ORDERER_HOST> <CA_HOST> <CA_CHAINFILE> <SECRET_FILE>: $*"
    exit 1
fi

ORDERER_NAME=$1
ORDERER_HOST=$2
CA_HOST=$3
CA_CHAINFILE=$4
SECRET_FILE=$5

CA_PORT="7054"

set -e

DATA=$SDIR/data
mkdir -p $DATA

ORDERER_HOME=$DATA/$ORDERER_NAME
if [ ! -d $ORDERER_HOME ]; then
    mkdir $ORDERER_HOME
fi

if_file_exist $SECRET_FILE
ORDERER_SECRET=$( cat $SECRET_FILE )

ENROLLMENT_URL=https://${ORDERER_NAME}:${ORDERER_SECRET}@${CA_HOST}:${CA_PORT}

if_file_exist $CA_CHAINFILE

export FABRIC_CA_CLIENT_HOME=$DATA/fabric-ca-client
export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $ORDERER_HOME/tmp --csr.hosts $ORDERER_HOST

TLSDIR=$ORDERER_HOME/tls
if [ ! -d $TLSDIR ]; then
    mkdir $TLSDIR
fi

cp $ORDERER_HOME/tmp/keystore/* $TLSDIR/server.key
cp $ORDERER_HOME/tmp/signcerts/* $TLSDIR/server.crt

rm -rf $ORDERER_HOME/tmp

ORDERER_MSP=$ORDERER_HOME/msp
if [ ! -d $ORDERER_MSP ]; then
    mkdir $ORDERER_MSP
fi

fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_MSP

if [ ! -d $ORDERER_MSP/tlscacerts ]; then
    mkdir $ORDERER_MSP/tlscacerts
    cp $ORDERER_MSP/cacerts/* $ORDERER_MSP/tlscacerts
fi
