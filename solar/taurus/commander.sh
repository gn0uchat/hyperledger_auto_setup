#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
LOCAL_SOLAR_TOOLS=$( dirname $SDIR )/tools

. $SDIR/taurus_lib.sh
. $LOCAL_SOLAR_TOOLS/lib.sh

ADMIN_USER="admin"
REMOTE_USER="rmt_user"

GIT_REPO_ADDR=""
GIT_BRANCH="taurus_wip"
GIT_USER="moneysqtw"
GIT_SECRET_FILE="git.secret"

REMOTE_GIT_HOME="~/blockchain"
REMOTE_TAURUS_HOME="$REMOTE_GIT_HOME/solar/taurus"
REMOTE_SOLAR_TOOLS="$REMOTE_GIT_HOME/solar/tools"

INIT_NETWORK_JSON_FILE=$SDIR/json/network.json
ADD_NETWORK_JSON_FILE=$SDIR/json/new_org.json

INIT_NETWORK_JSON=$( cat $INIT_NETWORK_JSON_FILE | jq -c . )
ADD_NETWORK_JSON=$( cat $ADD_NETWORK_JSON_FILE | jq -c . )

ADDR_JSON=$( echo $NETWORK_JSON | jq -rc .address )
REMOTE_ADDRS=$( echo $ADDR_JSON | jq -r 'keys[]' )

function setup_remote_user {
	local REMOTE_ADDR=$( global_addr $1 )

	echo "sudo adduser $REMOTE_USER" | ssh $ADMIN_USER@$REMOTE_ADDR /bin/bash
}

function remote_repo_clone {
	REMOTE_ADDR=$1

	local GIT_REPO_HTTPS_URL="https://$GIT_USER@$GIT_REPO_ADDR"

	remote_git $REMOTE_ADDR "clone $GIT_REPO_HTTPS_URL"
	remote_git $REMOTE_ADDR "-C $REMOTE_GIT_HOME fetch $GIT_BRANCH"
	remote_git $REMOTE_ADDR "-C $REMOTE_GIT_HOME checkout $GIT_BRANCH"

	#remote_git $REMOTE_ADDR "clone --branch $GIT_BRANCH --single-branch $GIT_REPO_HTTPS_URL"
}

function init_remotes {
	log "initializing remotes"

	for REMOTE_ADDR in $REMOTE_ADDRS; do
		log "init remote: $REMOTE_ADDR"

		local GIT_HELPER_SH=git-askpass-helper.sh
		local SCRIPT_DIR=$REMOTE_TAURUS_HOME/scripts
		local SECRET=$( cat $SDIR/hkpc_ct.secret )

		setup_remote_user $REMOTE_ADDR

		scp $SDIR/scripts/$GIT_HELPER_SH $REMOTE_USER@$REMOTE_ADDR:~
		remote_command $REMOTE_ADDR "chmod u+x ~/$GIT_HELPER_SH"

		remote_repo_clone $REMOTE_ADDR

		remote_command $REMOTE_ADDR "export HKPC_CT_PW='$SECRET'; $SCRIPT_DIR/inst_hlf_prereq.sh"
		remote_command $REMOTE_ADDR "$REMOTE_TAURUS_HOME/scripts/download_binaries.sh"
		remote_command $REMOTE_ADDR "echo 'export PATH=\$PATH:\$HOME/bin' >> \$HOME/.bashrc"
	done
}

function remote_repo_reset {
	log "remoet repo reset"

	for REMOTE_ADDR in $REMOTE_ADDRS; do
		remote_git $REMOTE_ADDR "-C $REMOTE_GIT_HOME checkout master"
		remote_git $REMOTE_ADDR "-C $REMOTE_GIT_HOME branch -d $GIT_BRANCH"
		remote_git $REMOTE_ADDR "-C $REMOTE_GIT_HOME fetch origin $GIT_BRANCH"
		remote_git $REMOTE_ADDR "-C $REMOTE_GIT_HOME checkout $GIT_BRANCH"
	done
}

function remote_repo_update {
	log "remote repo update"

	for REMOTE_ADDR in $REMOTE_ADDRS; do
		remote_git $REMOTE_ADDR "-C $REMOTE_GIT_HOME pull origin $GIT_BRANCH"
	done

}

function remote_init_organization {
	local ORG_JSON=$1

	local ORG_NAME=$( echo $ORG_JSON | jq -rc .name )
	local CA_HOST=$( echo $ORG_JSON | jq -rc .ca )
	local PEER_HOSTS=$( echo $ORG_JSON | jq -rc .peer[] )
	local ORDERER_HOSTS=$(echo $ORG_JSON | jq -rc .orderer[] )

	local MSP_PATH=org/data/$ORG_NAME/msp
	local ORG_PATH=org/data/$ORG_NAME

	log "remote initialize organization ( $ORG_NAME | $CA_HOST | $PEER_HOSTS | $ORDERER_HOSTS )"
	
	remote_start_ca "$CA_HOST"

	sleep 5;

	remote_init_org "$ORG_NAME" "$CA_HOST"
	
	broadcast_ca_chainfile "$CA_HOST" "$PEER_HOSTS $ORDERER_HOSTS"
	
	if [ "$ORDERER_HOSTS" = "null" ]; then local ORDERER_HOSTS=""; fi
	for ORDERER_HOST in $ORDERER_HOSTS; do
		local ADDR=$( host_addr orderer $ORDERER_HOST )
		remote_send_folder $ADDR $REMOTE_SOLAR_TOOLS/org/data $LOCAL_SOLAR_TOOLS/$ORG_PATH
		remote_init_orderer "$ORDERER_HOST" "$CA_HOST"
	done

	if [ "$PEER_HOSTS" = "null" ]; then local PEER_HOSTS=""; fi
	for PEER_HOST in $PEER_HOSTS; do
		local ADDR=$( host_addr peer $PEER_HOST )
		remote_send_folder $ADDR $REMOTE_SOLAR_TOOLS/org/data $LOCAL_SOLAR_TOOLS/$ORG_PATH

		remote_init_peer "$PEER_HOST" "$CA_HOST"
	done
	
}

function pick_orderer {
	local ORDERER_LIST=$1
	local PICKED=""
	for ORDERER_HOST in $ORDERER_LIST; do
		if [ "$DELEGATE_ORDERER" = "" ]; then
			PICKED=$ORDERER_HOST
			break
		fi
	done

	echo $PICKED
}

function update_org_configtx {
	local ORG_JSON=$1
	local CHANNEL_JSON=$2

	log "update config tx ( $ORG_JSON | $CHANNEL_JSON )"

	local DELEGATE_PEER=$( echo $CHANNEL_JSON | jq -rc .delegate.peer[0] )
	local DELEGATE_ORDERER=$( echo $CHANNEL_JSON | jq -rc .delegate.orderer[0] )
	local CHANNEL_NAME=$( echo $CHANNEL_JSON | jq -rc .name )

	log "( $DELEGATE_PEER | $DELEGATE_ORDERER | $CHANNEL_NAME )"

	local ORG_NAME=$( echo $ORG_JSON | jq -rc .name )
	local CA_HOST=$( echo $ORG_JSON | jq -rc .ca )

	local CA_ADDR=$( host_addr ca $CA_HOST )

	local DELEGATE_PEER_NAME=$( host_name peer $DELEGATE_PEER )
	local DELEGATE_PEER_ADDR=$( host_addr peer $DELEGATE_PEER )
	local DELEGATE_ORDERER_ADDR=$( host_addr orderer $DELEGATE_ORDERER )
	local DELEGATE_ORDERER_PORT=$( host_port orderer $DELEGATE_ORDERER )

	local CLI_NAME=$DELEGATE_PEER_NAME-cli
	local CLI_ADDR=$DELEGATE_PEER_ADDR

	log "remote fetch config block"

	local ENV_CMD="ORDERER_ADDR=$DELEGATE_ORDERER_ADDR; ORDERER_PORT=$DELEGATE_ORDERER_PORT"
	local ENV_CMD="$ENV_CMD; CHANNEL_NAME=$CHANNEL_NAME"
	local EXEC_SH="$REMOTE_SOLAR_TOOLS/cli/cli_exec_sh.sh"

	remote_command $CLI_ADDR "export ENV_CMD=\"$ENV_CMD\"; $EXEC_SH $CLI_NAME fetch_config.sh"

	local CONFIG_BLOCK_PATH=cli/data/$CLI_NAME/config_block.pb
	local ORIGIN_CONFIG_PB=$LOCAL_SOLAR_TOOLS/consortium_artifact/data/$ORG_NAME/origin_config.pb

	local UPDATE_CONFIG_PATH=consortium_artifact/data/$ORG_NAME/update_config.pb

	remote_get_file $CLI_ADDR $REMOTE_SOLAR_TOOLS/$CONFIG_BLOCK_PATH $ORIGIN_CONFIG_PB
	
	export ORG_JSON=$ORG_JSON
	export CHANNEL_NAME=$CHANNEL_NAME
	$LOCAL_SOLAR_TOOLS/consortium_artifact/new_org_artifact.sh

	remote_send_file $CLI_ADDR $REMOTE_SOLAR_TOOLS/$UPDATE_CONFIG_PATH $LOCAL_SOLAR_TOOLS/$UPDATE_CONFIG_PATH
	
	local ADDR_PORT=$DELEGATE_ORDERER_ADDR:$DELEGATE_ORDERER_PORT
	local DATA_JSON="{\"orderer_addr_port\":\"$ADDR_PORT\", \"channel_name\" : \"$CHANNEL_NAME\"}"
	local SET_ENV="export DATA_JSON='$DATA_JSON'"
	local HANDLE_CONFIG_UPDATE="$REMOTE_SOLAR_TOOLS/cli/handle_config_update.sh"
	remote_command $CLI_ADDR "$SET_ENV; $HANDLE_CONFIG_UPDATE $CLI_NAME $ORG_NAME update_config_tx"
}

function remote_add_organization {
	local ORG_JSON=$( echo $1 | jq -rc . )
	local CHANNEL_JSON=$( echo $2 | jq -rc . )

	log "remote add organization ( $ORG_JSON | $CHANNEL_JSON )"

	local DELEGATE_PEER=$( echo $CHANNEL_JSON | jq -rc .delegate.peer[0] )
	local DELEGATE_ORDERER=$( echo $CHANNEL_JSON | jq -rc .delegate.orderer[0] )
	local CONSORTIUM_NAME=$( echo $CHANNEL_JSON | jq -rc .consortium )

	remote_init_organization $ORG_JSON

	update_org_configtx $ORG_JSON $CHANNEL_JSON

	remote_start_organization $ORG_JSON $CONSORTIUM_NAME
	remote_setup_channel $CHANNEL_JSON true
}

function remote_start_organization {
	local ORG_JSON=$1
	local CONSORTIUM_NAME=$2

	log "remote start organization ( $ORG_JSON | $CONSORTIUM_NAME )"

	local ORG_NAME=$( echo $ORG_JSON | jq -rc .name )
	local CA_HOST=$( echo $ORG_JSON | jq -rc .ca )
	local PEER_HOST_LIST=$( echo $ORG_JSON | jq -rc .peer[] )
	local ORDERER_HOST_LIST=$(echo $ORG_JSON | jq -rc .orderer[] )

	local GENBLK_PATH=consortium_artifact/data/${CONSORTIUM_NAME}/genesis.block
	#local CHANTX_PATH=consortium_artifact/data/${CONSORTIUM_NAME}/${CHANNEL_NAME}/${CHANNEL_NAME}.tx

	if [ "$ORDERER_HOST_LIST" = "null" ]; then local ORDERER_HOST_LIST=""; fi
	for ORDERER_HOST in $ORDERER_HOST_LIST; do
		
		local ADDR=$( parse_host $ORDERER_HOST 1 )

		remote_send_file $ADDR $REMOTE_SOLAR_TOOLS/$GENBLK_PATH $LOCAL_SOLAR_TOOLS/$GENBLK_PATH
		#remote_send_file $ADDR $REMOTE_SOLAR_TOOLS/$CHANTX_PATH $LOCAL_SOLAR_TOOLS/$CHANTX_PATH

		SET_ENV="export ORDERER_HOST=$ORDERER_HOST; export ORDERER_ORG=$ORG_NAME"
		SET_ENV="$SET_ENV; export CONSORTIUM_NAME=$CONSORTIUM_NAME"
		START_ORDERER="$REMOTE_SOLAR_TOOLS/orderer/start_orderer.sh"
		remote_command $ADDR "$SET_ENV; $START_ORDERER"
	done

	if [ "$PEER_HOST_LIST" = "null" ]; then local PEER_HOST_LIST=""; fi
	for PEER_HOST in $PEER_HOST_LIST; do
		local ADDR=$( parse_host $PEER_HOST 1 )

		local SET_ENV="export PEER_HOST=$PEER_HOST; export PEER_ORG=$ORG_NAME"
		local START_PEER="$REMOTE_SOLAR_TOOLS/peer/start_peer.sh"
		remote_command $ADDR "$SET_ENV; $START_PEER"

		sleep 5;

		local CLI_NAME=$( host_name peer $PEER_HOST )-cli
		remote_start_cli $PEER_HOST $ORG_NAME $NETWORK_JSON
	done
}

function remote_peer_init_channel {
	local PEER_HOST=$1
	local PEER_ORG=$2
	local CHANNEL_JSON=$3
	local CHANNEL_EXIST=$4

	log "remote peer init channel: ( $PEER_HOST | $PEER_ORG | $CHANNEL_JSON | $CHANNEL_EXIST )"

	local PEER_NAME=$( parse_host $PEER_HOST 0 )
	local PEER_ADDR=$( parse_host $PEER_HOST 1 )
	local CLI_NAME=$PEER_NAME-cli

	local SET_ENV="export CHANNEL_JSON='$CHANNEL_JSON'"
	local CLI_SETUP_CHANN="$REMOTE_SOLAR_TOOLS/cli/cli_setup_channel.sh"
	if [ "$CHANNEL_EXIST" = "false" ]; then
		local CMD="setup_channel"
		local CHANNEL_EXIST=true
	else
		local CMD="join_channel"
	fi

	remote_command $PEER_ADDR "$SET_ENV; $CLI_SETUP_CHANN $CLI_NAME $PEER_ORG $CMD"
}

function remote_setup_channel {
	local CHANNEL_JSON=$( echo $1 | jq -c . )
	local CHANNEL_EXIST=$2

	log "remote setup channel ( $CHANNEL_JSON | $CHANNEL_EXIST )"

	PEER_ORG_LIST=$( echo $CHANNEL_JSON | jq -rc .peer_org[] )

	for PEER_HOST_ORG in $PEER_ORG_LIST; do
		local PEER_HOST=$( parse_host $PEER_HOST_ORG 0 2 )
		local PEER_ORG=$( parse_host $PEER_HOST_ORG 3 )

		remote_peer_init_channel $PEER_HOST $PEER_ORG "$CHANNEL_JSON" $CHANNEL_EXIST

		if [ "$CHANNEL_EXIST" = "false" ]; then
			local CHANNEL_EXIST=true
		fi
	done
}

function gen_artifact {
	local NETWORK_JSON=$1

	log "generate artifacts ( $NETWORK_JSON )"
	export NETWORK_JSON=$NETWORK_JSON
	$LOCAL_SOLAR_TOOLS/consortium_artifact/artifactgen.sh
}

function init_network {
	local NETWORK_JSON=$( echo $1 | jq -c . )

	local ORG_JSON_LIST=$( echo $NETWORK_JSON | jq -rc .organization[] )
	local CHANNEL_JSON=$( echo $NETWORK_JSON | jq -rc .channel )
	local CONSORTIUM_NAME=$( echo $NETWORK_JSON | jq -rc .consortium.name )
	local CONS_JSON=$( echo $NETWORK_JSON | jq -rc .consensus )
	
	start_consensus "$CONS_JSON"

	for ORG_JSON in $ORG_JSON_LIST; do
		log "init organization JSON => $ORG_JSON"
		remote_init_organization "$ORG_JSON"
	done

	gen_artifact "$NETWORK_JSON"

	for ORG_JSON in $ORG_JSON_LIST; do
		log "start organization JSON => $ORG_JSON"
		remote_start_organization "$ORG_JSON" $CONSORTIUM_NAME
	done

	remote_setup_channel $CHANNEL_JSON false
}

function remote_sudo_command {
	local REMOTE_ADDR=$( global_addr $1 )
	local COMMAND=$2

	local HKPC_CT_PW=$( cat $SDIR/hkpc_ct.secret )

	log "remote sudo command FROM $REMOTE_USER@$REMOTE_ADDR DO $COMMAND"

	SET_ENV="export PATH=\$PATH:\$HOME/bin"

	echo "PW='$HKPC_CT_PW'; echo \$PW | sudo -S $COMMAND" | ssh $REMOTE_USER@$REMOTE_ADDR /bin/bash
}

function tear_down_unit {
	TYPE=$1
	HOST=$2

	log "tear down unit ( $TYPE | $HOST )"

	local NAME=$( host_name $TYPE $HOST )
	local ADDR=$( host_addr $TYPE $HOST )
	local YML_FILE=$REMOTE_SOLAR_TOOLS/$TYPE/docker-compose-$NAME.yml
	local DATA=$REMOTE_SOLAR_TOOLS/$TYPE/data/$NAME


	set +e
	remote_command $ADDR "docker-compose -f $YML_FILE down"
	remote_sudo_command $ADDR "rm -rf $DATA"
	set -e
}

function tear_down_organization {
	local ORG_JSON=$1

	log "tear down organization ( $ORG_JSON )"

	local ORG_NAME=$( echo $ORG_JSON | jq -rc .name )
	local CA_HOST=$( echo $ORG_JSON | jq -rc .ca )
	local ORDERER_LIST=$( echo $ORG_JSON | jq -rc .orderer[] )
	local PEER_LIST=$( echo $ORG_JSON | jq -rc .peer[] )

	local CA_NAME=$( host_name ca $CA_HOST )

	log "[ $ORG_NAME | $CA_HOST | $ORDERER_LIST | $PEER_LIST | $CA_NAME ]"

	if [ "$PEER_LIST" = "null" ]; then local PEER_LIST=""; fi
	for PEER_HOST in $PEER_LIST; do
		local PEER_NAME=$( host_name peer $PEER_HOST )
		local PEER_ADDR=$( host_addr peer $PEER_HOST )
		local CLI_NAME=$PEER_NAME-cli

		tear_down_unit cli $CLI_NAME:$PEER_ADDR
		tear_down_unit peer $PEER_HOST

		set +e
		remote_sudo_command $PEER_ADDR "rm -r $REMOTE_SOLAR_TOOLS/account/secret/$CA_NAME"
		remote_command $PEER_ADDR "rm -r $REMOTE_SOLAR_TOOLS/org/data/$ORG_NAME"
		set -e
	done

	if [ "$ORDERER_LIST" = "null" ]; then local ORDERER_LIST=""; fi
	for ORDERER_HOST in $ORDERER_LIST; do
		local ORDERER_ADDR=$( host_addr orderer $ORDERER_HOST )
		tear_down_unit orderer $ORDERER_HOST

		set +e
		remote_sudo_command $ORDERER_ADDR "rm -r $REMOTE_SOLAR_TOOLS/account/secret/$CA_NAME"
		remote_command $ORDERER_ADDR "rm -r $REMOTE_SOLAR_TOOLS/org/data/$ORG_NAME"
		set -e
	done

	local CA_NAME=$( host_name ca $CA_HOST )
	local CA_ADDR=$( host_addr ca $CA_HOST )

	tear_down_unit ca $CA_HOST

	set +e
	remote_sudo_command $CA_ADDR "rm -r $REMOTE_SOLAR_TOOLS/account/data/$CA_NAME"
	remote_sudo_command $CA_ADDR "rm -r $REMOTE_SOLAR_TOOLS/account/secret/$CA_NAME"
	set -e

	set +e
	sudo rm -r $LOCAL_SOLAR_TOOLS/consortium_artifact/data/$ORG_NAME
	sudo rm -r $LOCAL_SOLAR_TOOLS/ca/data/$CA_NAME
	sudo rm -r $LOCAL_SOLAR_TOOLS/account/data/$CA_NAME
	sudo rm -r $LOCAL_SOLAR_TOOLS/account/secret/$CA_NAME

	sudo rm -r $LOCAL_SOLAR_TOOLS/org/data/$ORG_NAME
	set -e
}

function tear_down_consensus {
	local CONS_JSON=$1

	local ZOOKEEPER_HOST_LIST=$( echo $CONS_JSON | jq -rc .zookeeper[] )
	local KAFKA_HOST_LIST=$( echo $CONS_JSON | jq -rc .kafka[] )

	for KAFKA_HOST in $KAFKA_HOST_LIST; do
		tear_down_unit kafka $KAFKA_HOST
	done

	for ZK_HOST in $ZOOKEEPER_HOST_LIST; do
		tear_down_unit zookeeper $ZK_HOST
	done
}

function tear_down_network {
	local NETWORK_JSON=$( echo $1 | jq -c . )

	local ORG_JSON_LIST=$( echo $NETWORK_JSON | jq -rc .organization[] )
	local CHANNEL_JSON=$( echo $NETWORK_JSON | jq -rc .channel )
	local CONSORTIUM_NAME=$( echo $NETWORK_JSON | jq -rc .consortium.name )

	for ORG_JSON in $ORG_JSON_LIST; do
		tear_down_organization $ORG_JSON
	done

	local CONS_JSON=$( echo $NETWORK_JSON | jq -rc .consensus )
	if [ "$CONS_JSON" != "null" ]; then
		tear_down_consensus $CONS_JSON
	fi

	set +e
	sudo rm -r $LOCAL_SOLAR_TOOLS/consortium_artifact/data/$CONSORTIUM_NAME
	set -e

}

function main {
	local SUB_COMMAND=$1
	log "command => $SUB_COMMAND"

	set -e

	remote_repo_update

	log "start command"

	if   [ "tear_down" = "$SUB_COMMAND" ];then

		tear_down_network $INIT_NETWORK_JSON
		tear_down_network $ADD_NETWORK_JSON

	elif [  "init" = "$SUB_COMMAND" ];then

		init_network $INIT_NETWORK_JSON

	elif [ "new_org" = "$SUB_COMMAND" ];then

		local ORG_JSON=$( echo $ADD_NETWORK_JSON | jq -rc .organization[0] )
		local CHANNEL_JSON=$( echo $ADD_NETWORK_JSON | jq -rc .channel )

		remote_add_organization $ORG_JSON $CHANNEL_JSON

	elif [ "repo_reset" = "$SUB_COMMAND" ]; then

		remote_repo_reset

	fi
}

main $1
