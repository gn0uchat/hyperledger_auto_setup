#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "artifactgen NETWORK_JSON => $NETWORK_JSON"

check_arg NETWORK_JSON

CONSORTIUM_NAME=$( echo $NETWORK_JSON | jq -r '.consortium.name' )
CHANNEL_NAME=$( echo $NETWORK_JSON | jq -r '.channel.name' )

check_arg CONSORTIUM_NAME
check_arg CHANNEL_NAME

ORG_JSON_LIST=$( echo $NETWORK_JSON | jq -c .organization[] )
PEER_ORGS=""
for ORG_JSON in $ORG_JSON_LIST; do
	ORG_NAME=$( echo $ORG_JSON | jq -r .name )
	PEER_ELEM=$( echo $ORG_JSON | jq -c .peer )

	if [ "$PEER_ELEM" != "null" ]; then
		PEER_ORGS=$( append $PEER_ORGS $ORG_NAME )
	fi
done

DATA=${SDIR}/data
CONSORTIUM_DIR=${DATA}/${CONSORTIUM_NAME}
CHANNEL_DIR=${CONSORTIUM_DIR}/${CHANNEL_NAME}

mkdir -p $CONSORTIUM_DIR; mkdir -p $CHANNEL_DIR

export NETWORK_JSON=$NETWORK_JSON
$SDIR/make_configtx_kafka.sh > ${CONSORTIUM_DIR}/configtx.yaml

configtxgen -configPath ${CONSORTIUM_DIR} -profile OrgsOrdererGenesis -outputBlock ${CONSORTIUM_DIR}/genesis.block

configtxgen -configPath ${CONSORTIUM_DIR} -profile OrgsChannel -outputCreateChannelTx ${CHANNEL_DIR}/${CHANNEL_NAME}.tx \
    -channelID $CHANNEL_NAME

for ORG in $PEER_ORGS; do
   ANCHOR_TX_FILE=${CHANNEL_DIR}/${ORG}-anchor.tx
   configtxgen -configPath ${CONSORTIUM_DIR} -profile OrgsChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
       -channelID $CHANNEL_NAME -asOrg $ORG
done
