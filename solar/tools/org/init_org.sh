#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )

. $SOLAR_TOOLS/lib.sh

log "init_org.sh ORG_NAME => $ORG_NAME CA_HOST => $CA_HOST"

check_arg ORG_NAME
check_arg CA_HOST

CA_NAME=$( parse_host $CA_HOST 0 )
CA_ADDR=$( parse_host $CA_HOST 1 )
CA_PORT=$( parse_host $CA_HOST 2 )

CA_CHAINFILE=$SOLAR_TOOLS/ca/data/$CA_NAME/ca-cert.pem

if_file_exist $CA_CHAINFILE "ca chaine file"

DATA=$SDIR/data
mkdir -p $DATA

ADMIN_NAME=${ORG_NAME}-admin

export ID_NAME=$ADMIN_NAME
export ID_TYPE=client
export CA_HOST=$CA_HOST
$SOLAR_TOOLS/account/new_account.sh "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

set -e

ORG_DIR=$DATA/${ORG_NAME}
ORG_MSP_DIR=$ORG_DIR/msp
ADMIN_DIR=$ORG_DIR/${ADMIN_NAME}

mkdir -p $ORG_DIR
mkdir -p $ORG_MSP_DIR
mkdir -p $ADMIN_DIR

export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
export FABRIC_CA_CLIENT_HOME=$ADMIN_DIR

fabric-ca-client getcacert -d -u https://$CA_ADDR:$CA_PORT -M $ORG_MSP_DIR

if [ ! -d ${ORG_MSP_DIR}/tlscacerts ]; then
    mkdir ${ORG_MSP_DIR}/tlscacerts
    cp ${ORG_MSP_DIR}/cacerts/* ${ORG_MSP_DIR}/tlscacerts
fi

SECRET_FILE=$SOLAR_TOOLS/account/secret/$CA_NAME/${ADMIN_NAME}
if_file_exist $SECRET_FILE "org admin secret file"

ADMIN_SECRET=$( cat $SECRET_FILE )
fabric-ca-client enroll -d -u https://$ADMIN_NAME:$ADMIN_SECRET@$CA_ADDR:$CA_PORT

mkdir -p ${ORG_MSP_DIR}/admincerts
cp ${ADMIN_DIR}/msp/signcerts/* ${ORG_MSP_DIR}/admincerts/${ADMIN_NAME}-cert.pem

mkdir -p ${ADMIN_DIR}/msp/admincerts
cp ${ADMIN_DIR}/msp/signcerts/* ${ADMIN_DIR}/msp/admincerts/${ADMIN_NAME}-cert.pem
