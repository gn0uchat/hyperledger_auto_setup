#!/bin/bash
function global_addr {
	local sub_addr=$1

	#log "global addr ( $sub_addr )"

	local GLOBAL_ADDR=$( echo $ADDR_JSON | jq -r .\"$sub_addr\" )

	echo $GLOBAL_ADDR
}

function remote_command {
	local REMOTE_ADDR=$( global_addr $1 )
	local COMMAND=$2

	log "remote command FROM $REMOTE_USER@$REMOTE_ADDR DO $COMMAND"

	SET_ENV="export PATH=\$PATH:\$HOME/bin"

	#echo "echo \"$COMMAND\" | ssh $REMOTE_USER@$REMOTE_ADDR /bin/bash"
	echo "$SET_ENV; $COMMAND" | ssh $REMOTE_USER@$REMOTE_ADDR /bin/bash
}

function remote_git {
	local REMOTE_ADDR=$1 
	local GIT_COMMAND=$2

	log "remote_git @ $REMOTE_ADDR with command [$GIT_COMMAND]"

	GIT_SECRET=$( cat $GIT_SECRET_FILE )
	SET_ENV="export GIT_ASKPASS=~/git-askpass-helper.sh; export GIT_PASSWORD='$GIT_SECRET'"

	remote_command $REMOTE_ADDR "$SET_ENV; git $GIT_COMMAND"
}

function remote_get_file {
	local REMOTE_ADDR=$1
	local REMOTE_FILE=$2
	local DEST_FILE=$3
	local ARG="$4"

	log "remote get file from $REMOTE_USER@$REMOTE_ADDR:$REMOTE_FILE => $DEST_FILE ($ARG)"

	local FOLDER=$( dirname $DEST_FILE )
	mkdir -p $FOLDER

	scp $ARG $REMOTE_USER@$( global_addr $REMOTE_ADDR ):$REMOTE_FILE $DEST_FILE
}

function remote_get_folder {
	local REMOTE_ADDR=$1
	local REMOTE_FOLDER=$2
	local LOCAL_FOLDER=$3

	log "remote get folder $REMOTE_USER@$REMOTE_ADDR:$REMOTE_FOLDER/ => $LOCAL_FOLDER/"

	scp -rp $REMOTE_USER@$( global_addr $REMOTE_ADDR ):$REMOTE_FOLDER $LOCAL_FOLDER
}

function remote_send_folder {
	local REMOTE_ADDR=$1
	local REMOTE_FOLDER=$2
	local LOCAL_FOLDER=$3

	log "remote get folder $LOCAL_FOLDER/ => $REMOTE_USER@$REMOTE_ADDR:$REMOTE_FOLDER/"

	scp -rp $LOCAL_FOLDER $REMOTE_USER@$( global_addr $REMOTE_ADDR ):$REMOTE_FOLDER
}

function remote_send_file {
	local REMOTE_ADDR=$1
	local REMOTE_FILE=$2
	local SRC_FILE=$3
	local ARG="$4"

	log "remote send file from $SRC_FILE => $REMOTE_USER@$REMOTE_ADDR:$REMOTE_FILE"

	local FOLDER=$( dirname $REMOTE_FILE )

	remote_command $REMOTE_ADDR "mkdir -p $FOLDER"

	scp $ARG $SRC_FILE $REMOTE_USER@$( global_addr $REMOTE_ADDR ):$REMOTE_FILE
}

function remote_transfer_file {
	local FROM_ADDR=$1
	local FROM_FILE=$2
	local TO_ADDR=$3
	local TO_FILE=$4

	local TMP_FILE=$SDIR/scp.tmp

	log "remote transfer file $REMOTE_USER@$FROM_ADDR:$FROM_FILE => $REMOTE_USER@$TO_ADDR:$TO_FILE"

	remote_get_file $FROM_ADDR $FROM_FILE $TMP_FILE
	chmod u+rw $TMP_FILE
	remote_send_file $TO_ADDR $TO_FILE $TMP_FILE

	rm $TMP_FILE
}

function collect_zk_host {
	local ZOOKEEPER_HOSTS=$1
	local ZK_HOSTS=""

	for HOST in $ZOOKEEPER_HOSTS; do
		local ADDR=$( parse_host $HOST 2 )
		local CLI_PORT=$( parse_host $HOST 5)

		local ZK_HOSTS=$( append "$ZK_HOSTS" "$ADDR:$CLI_PORT" )
	done

	echo $ZK_HOSTS
}

function collect_zk_server {

	local ZK_HOSTS=$1

	local ZK_SERVERS=""
	for HOST in $ZK_HOSTS; do

		local ZK_ID=$( parse_host $HOST 1 )
		local ADDR=$(  parse_host $HOST 2 )
		local PORT1=$( parse_host $HOST 3 )
		local PORT2=$( parse_host $HOST 4 )

		local ZK_SERVERS=$( append "$ZK_SERVERS" "server.${ZK_ID}=${ADDR}:${PORT1}:${PORT2}" )
	done

	echo $ZK_SERVERS
}

function remote_start_cli {
	local PEER_HOST=$1
	local PEER_ORG=$2

	local PEER_NAME=$( parse_host $PEER_HOST 0 )
	local PEER_ADDR=$( parse_host $PEER_HOST 1 )

	log "remote start cli : ( $PEER_HOST | $PEER_ORG )"

	#local CHANTX_PATH=consortium_artifact/data/${CONSORTIUM_NAME}/${CHANNEL_NAME}/${CHANNEL_NAME}.tx
	#local ANCHOR_PATH=consortium_artifact/data/${CONSORTIUM_NAME}/${CHANNEL_NAME}/${ORG_NAME}-anchor.tx

	#remote_send_file $PEER_ADDR $REMOTE_SOLAR_TOOLS/$CHANTX_PATH $LOCAL_SOLAR_TOOLS/$CHANTX_PATH
	#if [ -f $LOCAL_SOLAR_TOOLS/$ANCHOR_PATH ]; then
	#	remote_send_file $PEER_ADDR $REMOTE_SOLAR_TOOLS/$ANCHOR_PATH $LOCAL_SOLAR_TOOLS/$ANCHOR_PATH
	#fi

	local SET_ENV="export PEER_HOST=$PEER_HOST; export PEER_ORG=$PEER_ORG"
	local START_PEER_CLI="$REMOTE_SOLAR_TOOLS/cli/start_peer_cli.sh"
	remote_command $PEER_ADDR "$SET_ENV; $START_PEER_CLI"

}

function start_consensus {
	local CONS_JSON=$( echo $1 | jq -c . )

	log "start consensus ( $CONS_JSON )"

	local ZOOKEEPER_HOST_LIST=$( echo $CONS_JSON | jq -rc .zookeeper[] )
	local KAFKA_HOST_LIST=$( echo $CONS_JSON | jq -rc .kafka[] )

	local ZK_HOSTS=$( collect_zk_host "$ZOOKEEPER_HOST_LIST" )
	local ZK_SERVERS=$( collect_zk_server "$ZOOKEEPER_HOST_LIST" )

	log "start zookeepers"

	for ZK_HOST in $ZOOKEEPER_HOST_LIST; do
		log "starting zookeeper: $ZK_HOST"

		local ADDR=$( parse_host $ZK_HOST 2 )

		local SET_ENV="export ZK_HOST=$ZK_HOST; export ZOO_SERVERS=\"$ZK_SERVERS\""
		local START_ZOOKEEPER="$REMOTE_SOLAR_TOOLS/zookeeper/start_zookeeper.sh"
		remote_command $ADDR "$SET_ENV; $START_ZOOKEEPER;"
	done

	log "zookeepers started"

	log "sleeping ..."; sleep 5;

	for KAFKA_HOST in $KAFKA_HOST_LIST; do
		log "starting kafka: $KAFKA_HOST"

		local ADDR=$( parse_host $KAFKA_HOST 2 )

		local SET_ENV="export KAFKA_HOST=$KAFKA_HOST; export ZOOKEEPER_HOSTS=\"$ZK_HOSTS\""
		local INIT_KAFKA="$REMOTE_SOLAR_TOOLS/kafka/init_kafka.sh"
		local START_KAFKA="$REMOTE_SOLAR_TOOLS/kafka/start_kafka.sh"

		remote_command $ADDR "$SET_ENV; $INIT_KAFKA && $START_KAFKA;"
	done

	log "consensus started"
}

function remote_setup_user {

	local ADDR=$1
	local USER_ID=$2
	local USER_TYPE=$3
	local CA_HOST=$4

	log "remote setup user ( $ADDR | $USER_ID | $USER_TYPE | $CA_HOST )"

	local CA_NAME=$( parse_host $CA_HOST 0 )
	local CA_ADDR=$( parse_host $CA_HOST 1 )
	local CA_PORT=$( parse_host $CA_HOST 2 )

	local SET_ENV="export ID_NAME=$USER_ID; export ID_TYPE=$USER_TYPE; export CA_HOST=$CA_HOST"
	local NEW_ACCOUNT="$REMOTE_SOLAR_TOOLS/account/new_account.sh"

	remote_command $CA_ADDR "$SET_ENV; $NEW_ACCOUNT;"

	local SECRET_PATH=$REMOTE_SOLAR_TOOLS/account/secret/$CA_NAME/$USER_ID

	if [ "$CA_ADDR" != "$ADDR" ]; then
		remote_transfer_file $CA_ADDR $SECRET_PATH $ADDR $SECRET_PATH
	fi
}

function remote_init_orderer {
	local ORDERER_HOST=$1
	local CA_HOST=$2
	
	local NAME=$( parse_host $ORDERER_HOST 0 )
	local ADDR=$( parse_host $ORDERER_HOST 1 )
	local PORT=$( parse_host $ORDERER_HOST 2 )

	log "remote init orderer ( $NAME | $ADDR | $PORT )"

	remote_setup_user $ADDR $NAME orderer $CA_HOST

	local SET_ENV="export ORDERER_HOST=$ORDERER_HOST; export CA_HOST=$CA_HOST"
	local INIT_ORDERER="$REMOTE_SOLAR_TOOLS/orderer/init_orderer.sh"
	remote_command $ADDR "$SET_ENV; $INIT_ORDERER"
}

function remote_start_ca {
	local CA_HOST=$1

	local NAME=$( parse_host $CA_HOST 0 )
	local ADDR=$( parse_host $CA_HOST 1 )
	local PORT=$( parse_host $CA_HOST 2 )

	log "remote start ca ( $NAME | $ADDR | $PORT )"
	
	local START_CA="$REMOTE_SOLAR_TOOLS/ca/start_ca.sh"
	local SET_ENV="export CA_HOST=$CA_HOST"

	remote_command $ADDR "$SET_ENV; $START_CA;"

	local SECRET_PATH=/ca/data/$NAME/ca-secret
	local CACERT_PATH=/ca/data/$NAME/ca-cert.pem

	mkdir -p $LOCAL_SOLAR_TOOLS/ca/data/$NAME

	remote_get_file $ADDR $REMOTE_SOLAR_TOOLS/$SECRET_PATH $LOCAL_SOLAR_TOOLS/$SECRET_PATH
	remote_get_file $ADDR $REMOTE_SOLAR_TOOLS/$CACERT_PATH $LOCAL_SOLAR_TOOLS/$CACERT_PATH
}

function remote_init_peer {
	local PEER_HOST=$1
	local CA_HOST=$2

	local NAME=$( parse_host $PEER_HOST 0 )
	local ADDR=$( parse_host $PEER_HOST 1 )
	local PORT=$( parse_host $PEER_HOST 2 )

	log "remote init peer ( $NAME | $ADDR | $PORT )"

	remote_setup_user $ADDR $NAME peer $CA_HOST

	local SET_ENV="export PEER_HOST=$PEER_HOST; export CA_HOST=$CA_HOST"
	local INIT_PEER="$REMOTE_SOLAR_TOOLS/peer/init_peer.sh"

	remote_command $ADDR "$SET_ENV; $INIT_PEER"
}

function broadcast_ca_chainfile {
	local CA_HOST=$1
	local HOSTS=$2

	local CA_NAME=$( host_name ca $CA_HOST )
	local CA_ADDR=$( host_addr ca $CA_HOST )

	local CACHAINFILE_PATH=ca/data/$CA_NAME/ca-cert.pem

	log "broadcast ca chainfile ( $CA_HOST | $HOSTS )"

	for HOST in $HOSTS; do
		log "broadcast ca cert to $HOST"

		local ADDR=$( parse_host $HOST 1 )
		if [ "$ADDR" != "$CA_ADDR" ]; then
			remote_send_file $ADDR $REMOTE_SOLAR_TOOLS/$CACHAINFILE_PATH $LOCAL_SOLAR_TOOLS/$CACHAINFILE_PATH
		fi
	done
}

function remote_init_org {
	local ORG_NAME=$1
	local CA_HOST=$2

	local CA_ADDR=$( parse_host $CA_HOST 1 )
	local REMOTE_ADDR=$CA_ADDR

	log "remote init org ( $ORG_NAME | $CA_HOST )"

	local SET_ENV="export ORG_NAME=$ORG_NAME; export CA_HOST=$CA_HOST"
	local INIT_ORG="$REMOTE_SOLAR_TOOLS/org/init_org.sh"

	remote_command $REMOTE_ADDR "$SET_ENV; $INIT_ORG"

	local MSP_PATH=org/data/$ORG_NAME/msp
	local ORG_PATH=org/data/$ORG_NAME
	remote_get_folder $REMOTE_ADDR $REMOTE_SOLAR_TOOLS/$ORG_PATH $LOCAL_SOLAR_TOOLS/org/data
}
