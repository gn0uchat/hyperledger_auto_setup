#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "new org ORG_JSON => $ORG_JSON ORG_CONFIGTX_JSON => $ORG_CONFIGTX_JSON"

check_arg ORG_JSON
check_arg ORG_CONFIGTX_JSON

ORG_NAME=$( echo $ORG_JSON | jq -rc .name )
CA_HOST=$( echo $ORG_JSON | jq -rc .ca )
PEER_LIST=$( echo $ORG_JSON | jq -rc .peer[] )
ANCHOR_HOST=$( echo $ORG_JSON | jq -rc .anchor )

DATA=$SDIR/data
ORG_DATA=$DATA/$ORG_NAME

mkdir -p $ORG_DATA

function createConfigUpdate() {

  #createConfigUpdate ${CHANNEL_NAME} config.json modified_config.json org3_update_in_envelope.pb
	CHANNEL=$1
	ORIGINAL=$2
	MODIFIED=$3
	OUTPUT=$4

	log "createConfigUpdate parameters: $CHANNEL $ORIGINAL $MODIFIED $OUTPUT"

	configtxlator proto_encode --input "${ORIGINAL}" --type common.Config > original_config.pb

	configtxlator proto_encode --input "${MODIFIED}" --type common.Config > modified_config.pb

	configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb \
		--updated modified_config.pb > config_update.pb

	configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate >config_update.json

	echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json

	configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope >"${OUTPUT}"
}

function remote_add_org {
	local ORG_JSON=$1
	local NETWORK_JSON=$2

	configtxgen -printOrg ${ORG_MSP} > /data/${ORG_NAME}-configtx.json

	#fetchChannelConfig config.json
	peer channel fetch config config_block.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS

	configtxlator proto_decode --input config_block.pb --type common.Block | \
	   jq .data.data[0].payload.data.config > config.json

	#log "Modify the configuration to append the new org"

	jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'${ORG_MSP}'":.[1]}}}}}' \
	   config.json /data/${ORG_NAME}-configtx.json > modified_config.json

	createConfigUpdate ${CHANNEL_NAME} config.json modified_config.json ${ORG_NAME}_update_in_envelope.pb

	log "going to sign"

	#signConfigtxAsPeerOrg org1 1 mars_update_in_envelope.pb
	#signConfigtxAsPeerOrg org2 1 org3_update_in_envelope.pb
	if [ ! -f /${DATA}/member-orgs ]; then
	   touch /${DATA}/member-orgs
	fi

	MEM_ORGS=( $(cat /${DATA}/member-orgs) )

	for MEM_ORG in "${MEM_ORGS[@]}" ; do
	   log "sign configtx as ${MEM_ORG} anchor"
	   signConfigtxAsPeerOrg ${MEM_ORG} anchor ${ORG_NAME}_update_in_envelope.pb
	done

	log "going to udpate"

	#updateConfigBlock mars_update_in_envelope.pb

	initPeerVars ${PORGS[0]} 1
	switchToAdminIdentity
	peer channel update -f  ${ORG_NAME}_update_in_envelope.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS


}
