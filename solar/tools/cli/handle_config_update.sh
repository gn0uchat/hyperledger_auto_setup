#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh


CLI_NAME=$1
ORG_NAME=$2
COMMAND=$3

log "handle config tx CLI_NAME => $CLI_NAME ORG_NAME => $ORG_NAME COMMAND => $COMMAND"
log "DATA_JSON => $DATA_JSON"

check_arg CLI_NAME
check_arg ORG_NAME
check_arg COMMAND

UPDATE_CONFIG_DIR=$SOLAR_TOOLS/consortium_artifact/data/$ORG_NAME
UPDATE_CONFIG_PB=update_config.pb

if_file_exist $UPDATE_CONFIG_DIR/$UPDATE_CONFIG_PB "udpate config block"

CLI_HOME=$SOLAR_TOOLS/cli/data/$CLI_NAME

function sign_config_tx {
	log "sign config tx"
	docker exec -i $CLI_NAME bash -c "peer channel signconfigtx -f '\$CLI_HOME/$UPDATE_CONFIG_PB' "

	cp $CLI_HOME/$UPDATE_CONFIG_PB $UPDATE_CONFIG_DIR/signed_$UPDATE_CONFIG_PB
}

function update_config_tx {
	log "update config tx ( $DATA_JSON )"
	check_arg DATA_JSON

	ORDERER_ADDR_PORT=$( echo $DATA_JSON | jq -rc .orderer_addr_port )
	CHANNEL_NAME=$( echo $DATA_JSON | jq -rc .channel_name )

	check_arg ORDERER_ADDR_PORT
	check_arg CHANNEL_NAME

	log "( $ORDERER_ADDR_PORT | $CHANNEL_NAME )"

	#ORDERER_PORT_ARGS="-o $ORDERER_ADDR:$ORDERER_PORT --tls --cafile $CA_CHAINFILE --clientauth"
	#ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
	local ORDERER_PORT_ARGS="-o $ORDERER_ADDR_PORT"
	local ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS"

	local DOCKER_COMMAND="peer channel update -f \$CLI_HOME/$UPDATE_CONFIG_PB -c $CHANNEL_NAME $ORDERER_CONN_ARGS"
	docker exec -i $CLI_NAME bash -c "$DOCKER_COMMAND"
}

function main {

	cp $UPDATE_CONFIG_DIR/$UPDATE_CONFIG_PB $CLI_HOME

	if   [ "sign_config_tx" = "$COMMAND" ]; then
		sign_config_tx
	elif [ "update_config_tx" = "$COMMAND" ]; then
		update_config_tx
	fi
}

main
