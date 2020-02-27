#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "init_orderer.sh args: ORDERER_HOST=> $ORDERER_HOST  CA_HOST => $CA_HOST"

check_arg ORDERER_HOST
check_arg CA_HOST

ORDERER_NAME=$( parse_host $ORDERER_HOST 0 )
ORDERER_ADDR=$( parse_host $ORDERER_HOST 1 )
ORDERER_PORT=$( parse_host $ORDERER_HOST 2 )

CA_NAME=$( parse_host $CA_HOST 0 )
CA_ADDR=$( parse_host $CA_HOST 1 )
CA_PORT=$( parse_host $CA_HOST 2 )

ORDERER_SECRET_FILE=$SOLAR_TOOLS/account/secret/${CA_NAME}/${ORDERER_NAME}
CA_CHAINFILE=$SOLAR_TOOLS/ca/data/${CA_NAME}/ca-cert.pem

if_file_exist $ORDERER_SECRET_FILE	"orderer secret file"
if_file_exist $CA_CHAINFILE		"ca chainfile"

#function add_kafka_tlsca {
#  cp $SOLAR_TOOLS/kafka/data/ca-cert $ORDERER_MSP/tlscacerts/kafka-tls-ca
#}


DATA=$SDIR/data
ORDERER_HOME=$DATA/$ORDERER_NAME

set -e

mkdir -p $DATA
mkdir -p $ORDERER_HOME

cp $CA_CHAINFILE $ORDERER_HOME/ca-cert.pem

#$SOLAR_TOOLS/account/new_account.sh $ORDERER_NAME orderer $CA_HOST

ORDERER_SECRET=$( cat $ORDERER_SECRET_FILE )
ENROLLMENT_URL=https://${ORDERER_NAME}:${ORDERER_SECRET}@${CA_ADDR}:${CA_PORT}

#export FABRIC_CA_CLIENT_HOME=$DATA/fabric-ca-client
#export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

export FABRIC_CA_CLIENT_HOME=$ORDERER_HOME/fabric-ca-client
export FABRIC_CA_CLIENT_TLS_CERTFILES=$ORDERER_HOME/ca-cert.pem

mkdir -p $FABRIC_CA_CLIENT_HOME

#fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $ORDERER_HOME/tmp \
#	--csr.hosts $ORDERER_ADDR --csr.cn $ORDERER_ADDR
fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $ORDERER_HOME/tmp \
	--csr.hosts $ORDERER_ADDR

#ORDERER_ADDR_PORT=$ORDERER_ADDR:$ORDERER_PORT
#fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $ORDERER_HOME/tmp \
#	--csr.hosts $ORDERER_ADDR_PORT  --csr.cn $ORDERER_ADDR_PORT

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

#add_kafka_tlsca
