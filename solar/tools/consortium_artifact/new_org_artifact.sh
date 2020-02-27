#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "new org artifact ORG_JSON => $ORG_JSON CHANNEL_NAME => $CHANNEL_NAME"

check_arg ORG_JSON
check_arg CHANNEL_NAME

ORG_NAME=$( echo $ORG_JSON | jq -rc .name )
ANCHOR_HOST=$( echo $ORG_JSON | jq -rc .anchor )

if_file_exist $ORIGIN_CONFIG_FILE
if_dir_exist $MSP_DIR

DATA=$SDIR/data
ORG_DATA=$DATA/$ORG_NAME
mkdir -p $ORG_DATA

OLD_CONFIG_PB=$ORG_DATA/origin_config.pb
MSP_DIR=$SOLAR_TOOLS/org/data/$ORG_NAME/msp

ORG_MSP_ID=${ORG_NAME}MSP

function createConfigUpdate() {

	local CHANNEL=$1
	local ORIGINAL=$2
	local MODIFIED=$3
	local OUTPUT=$4

	log "create config update ( $CHANNEL | $ORIGINAL | $MODIFIED | $OUTPUT )"

	local ORIGIN_CONFIG_PB=$ORG_DATA/original_config.pb
	local MODIFIED_CONFIG_PB=$ORG_DATA/modified_config.pb
	local CONFIG_UPDATE_PB=$ORG_DATA/config_update.pb
	local CONFIG_UPDATE_JSON=$ORG_DATA/config_update.json
	local CONFIG_UPDATE_ENV_JSON=$ORG_DATA/config_update_in_envelope.json

	log "createConfigUpdate parameters: $CHANNEL $ORIGINAL $MODIFIED $OUTPUT"

	configtxlator proto_encode --input "${ORIGINAL}" --type common.Config > $ORIGIN_CONFIG_PB

	configtxlator proto_encode --input "${MODIFIED}" --type common.Config > $MODIFIED_CONFIG_PB

	configtxlator compute_update --channel_id "${CHANNEL}" --original $ORIGIN_CONFIG_PB \
		--updated $MODIFIED_CONFIG_PB > $CONFIG_UPDATE_PB

	configtxlator proto_decode --input $CONFIG_UPDATE_PB --type common.ConfigUpdate > $CONFIG_UPDATE_JSON

	local CONFIG_UPDATE=$( cat $CONFIG_UPDATE_JSON )
	echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$CONFIG_UPDATE'}}}' | jq . > $CONFIG_UPDATE_ENV_JSON

	configtxlator proto_encode --input $CONFIG_UPDATE_ENV_JSON --type common.Envelope >"${OUTPUT}"
}

function new_org_configtx() {
	local ANCHOR_ADDR=$( parse_host $ANCHOR_HOST 1 )
	local ANCHOR_PORT=$( parse_host $ANCHOR_HOST 2 )

	log "new org config tx ( $ANCHOR_ADDR | $ANCHOR_PORT )"

	local PROFILE_ID=PEER$( echo $ORG_NAME | sed -e 's/\./\_/g' )

	echo "---
#   Section: Organizations
Organizations:
    - &$PROFILE_ID
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: $ORG_NAME

        # ID to load the MSP definition as
        ID: $ORG_MSP_ID

        MSPDir: $MSP_DIR

        AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
            - Host: $ANCHOR_ADDR
              Port: $ANCHOR_PORT"
}

function main {
	local CONFIG_TX_FILE=$ORG_DATA/configtx.yaml
	local CONFIG_TX_JSON=$ORG_DATA/config_tx.json
	local ORIGIN_CONFIG_JSON=$ORG_DATA/config.json
	local MODIFIED_CONFIG_JSON=$ORG_DATA/modified_config.json
	local UPDATE_CONFIG_PB=$ORG_DATA/update_config.pb
	
	set -e

	new_org_configtx > $CONFIG_TX_FILE

	log "new organization config => json"
	#export FABRIC_CFG_PATH=$ORG_DATA
	#configtxgen  -channelID $CHANNEL_NAME -printOrg $ORG_MSP_ID > $CONFIG_TX_JSON
	#configtxgen -channelID $CHANNEL_NAME -configPath $ORG_DATA -printOrg $ORG_MSP_ID > $CONFIG_TX_JSON
	configtxgen -channelID $CHANNEL_NAME -configPath $ORG_DATA -printOrg $ORG_NAME > $CONFIG_TX_JSON

	log "original config tx => json"
	configtxlator proto_decode --input $OLD_CONFIG_PB --type common.Block | \
	   jq .data.data[0].payload.data.config > $ORIGIN_CONFIG_JSON

	log "modified config json"
	jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'${ORG_MSP_ID}'":.[1]}}}}}' \
	   $ORIGIN_CONFIG_JSON $CONFIG_TX_JSON > $MODIFIED_CONFIG_JSON

	createConfigUpdate $CHANNEL_NAME $ORIGIN_CONFIG_JSON $MODIFIED_CONFIG_JSON $UPDATE_CONFIG_PB
}

main
