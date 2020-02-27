#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )

if [ $# -ne 5 ]; then
    echo "Usage: setup_org <ORG_NAME> <CA_HOST> <ADMIN_ID> <CA_CHAINFILE> <SECRET_FILE>"
    exit 1
fi

ORG_NAME=$1
CA_HOST=$2
ADMIN_ID=$3
CA_CHAINFILE=$4
SECRET_FILE=$5

CA_PORT="7054"


DATA=$SDIR/data
mkdir -p $DATA


set -e
#CA_CHAINFILE=$DATA/${ORG_NAME}/ca-cert.pem
if [ ! -f $CA_CHAINFILE ]; then
    echo "missing ca chainfile. please create $CA_CHAINFILE"
    exit 1
fi

ORG_DIR=$DATA/${ORG_NAME}
ORG_MSP_DIR=$ORG_DIR/msp
ADMIN_DIR=$ORG_DIR/${ADMIN_ID}

mkdir -p $ORG_DIR
mkdir -p $ORG_MSP_DIR
mkdir -p $ADMIN_DIR

export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR

fabric-ca-client getcacert -d -u https://${CA_HOST}:${CA_PORT} -M $ORG_MSP_DIR

if [ ! -d ${ORG_MSP_DIR}/tlscacerts ]; then
    mkdir ${ORG_MSP_DIR}/tlscacerts
    cp ${ORG_MSP_DIR}/cacerts/* ${ORG_MSP_DIR}/tlscacerts
fi

#SECRET_FILE=$SOLAR_TOOLS/account/secret/${CA_HOST}/${ADMIN_ID}
if [ ! -f $SECRET_FILE ]; then
    echo "mising secret file. Please create $SECRET_FILE"
    exit 1
fi

ADMIN_SECRET=$( cat $SECRET_FILE )
fabric-ca-client enroll -d -u https://$ADMIN_ID:$ADMIN_SECRET@${CA_HOST}:${CA_PORT}

mkdir -p ${ORG_MSP_DIR}/admincerts
cp ${ADMIN_DIR}/msp/signcerts/* ${ORG_MSP_DIR}/admincerts/${ADMIN_ID}-cert.pem

mkdir -p ${ADMIN_DIR}/msp/admincerts
cp ${ADMIN_DIR}/msp/signcerts/* ${ADMIN_DIR}/msp/admincerts/${ADMIN_ID}-cert.pem
