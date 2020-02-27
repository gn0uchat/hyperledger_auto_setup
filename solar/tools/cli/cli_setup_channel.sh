#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

CLI_NAME=$1
ORG_NAME=$2
COMMAND=$3

log "cli setup channel ( $CLI_NAME | $ORG_NAME | $COMMAND )"

check_arg CHANNEL_JSON


CHANNEL_NAME=$( echo $CHANNEL_JSON | jq -rc .name )
CONSORTIUM_NAME=$( echo $CHANNEL_JSON | jq -rc .consortium )
ORDERER_HOST=$( echo $CHANNEL_JSON | jq -rc .delegate.orderer[0] )

check_arg CONSORTIUM_NAME
check_arg CHANNEL_NAME
check_arg ORDERER_HOST

SH=$SDIR/scripts
DATA=$SDIR/data
LOGS=$SDIR/logs
CLI_HOME=$DATA/${CLI_NAME}

CHANNEL_TX_FILE=$SOLAR_TOOLS/consortium_artifact/data/${CONSORTIUM_NAME}/${CHANNEL_NAME}/${CHANNEL_NAME}.tx
ANCHOR_TX_FILE=$SOLAR_TOOLS/consortium_artifact/data/${CONSORTIUM_NAME}/${CHANNEL_NAME}/${ORG_NAME}-anchor.tx

if_file_exist $CHANNEL_TX_FILE
#if_file_exist $ANCHOR_TX_FILE

ORDERER_ADDR_PORT=$( host_addr orderer $ORDERER_HOST ):$( host_port orderer $ORDERER_HOST )

cp $CHANNEL_TX_FILE $CLI_HOME

if [ -f $ANCHOR_TX_FILE ]; then
	cp $ANCHOR_TX_FILE $CLI_HOME
fi

COMMAND_PATH=cli_cmd_setup_channel.sh
COMMAND_FILE=$CLI_HOME/$COMMAND_PATH

echo -n "" > $COMMAND_FILE
echo "COMMAND=$COMMAND" >> $COMMAND_FILE
echo "ORDERER_HOST=$ORDERER_ADDR_PORT" >> $COMMAND_FILE
echo "ORG_NAME=$ORG_NAME" >> $COMMAND_FILE
echo "CHANNEL_NAME=$CHANNEL_NAME" >> $COMMAND_FILE

cat $SH/setup_channel.sh >> $COMMAND_FILE

chmod u+x $COMMAND_FILE

docker exec -i $CLI_NAME bash ./$COMMAND_PATH
