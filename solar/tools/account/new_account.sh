#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "new_account.sh args: ID_NAME => $ID_NAME ID_TYPE => $ID_TYPE CA_HOST => $CA_HOST ATTR=> $1"

check_arg ID_NAME
check_arg ID_TYPE
check_arg CA_HOST

CA_NAME=$( parse_host $CA_HOST 0 )
CA_ADDR=$( parse_host $CA_HOST 1 )
CA_PORT=$( parse_host $CA_HOST 2 )

CA_CHAINFILE=$SOLAR_TOOLS/ca/data/$CA_NAME/ca-cert.pem
CA_SECRET_FILE=$SOLAR_TOOLS/ca/data/$CA_NAME/ca-secret

if_file_exist $CA_CHAINFILE	"ca chain file"
if_file_exist $CA_SECRET_FILE	"ca secret file"

ATTR=$1

#if [ $# -lt 3 ]; then
#    echo "Usage: new_account <ID_NAME> <ID_TYPE> <CA_HOST> [<ATTRIBUTE>]"
#    exit 1
#fi

#ID_NAME=$1
#ID_TYPE=$2
#CA_HOST=$3
#ATTR=$4
#
#CA_ADDR=$( split_host_addr $CA_HOST )
#CA_PORT=$( split_host_port $CA_HOST )

#CA_PORT="7054"

DATA=$SDIR/data
SECRET_DIR=$SDIR/secret/${CA_NAME}
#CA_CHAINFILE=$DATA/${CA_NAME}/ca-cert.pem

mkdir -p $DATA
mkdir -p $DATA/${CA_NAME}
mkdir -p $SECRET_DIR

set -e

mkdir -p $DATA/${CA_NAME}/fabric-ca-client

export FABRIC_CA_CLIENT_HOME=$DATA/${CA_NAME}/fabric-ca-client
export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE

#ADMIN_SECRET=$( cat $SECRET_DIR/$ADMIN )
ADMIN="boot"
ADMIN_SECRET=$( cat $CA_SECRET_FILE )

fabric-ca-client enroll -d -u https://${ADMIN}:${ADMIN_SECRET}@${CA_ADDR}:${CA_PORT}

gen_secret $SECRET_DIR/$ID_NAME

#if [ ! -f $SECRET_DIR/$ID_NAME ]; then
#    openssl rand -hex 16 > $SECRET_DIR/$ID_NAME
#    chmod 400 $SECRET_DIR/$ID_NAME
#fi

ID_SECRET=$( cat $SECRET_DIR/$ID_NAME )
if [ ! -z "$ATTR" ]; then
    ARG_ATTR="--id.attrs $ATTR"
fi

fabric-ca-client register -d --id.name $ID_NAME --id.secret $ID_SECRET --id.type $ID_TYPE $ARG_ATTR
