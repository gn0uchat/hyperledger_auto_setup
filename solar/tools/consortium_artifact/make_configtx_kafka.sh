#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

log "make configtx kafka $NETWORK_JSON"

check_arg NETWORK_JSON

ORG_JSON_LIST=$( echo $NETWORK_JSON | jq -c .organization[] )

ORDERER_ORGS=""
PEER_ORGS=""
ORDERER_HOSTS=""

PEER_ORGJSON=""

for ORG_JSON in $ORG_JSON_LIST; do
	ORG_NAME=$( echo $ORG_JSON | jq -r .name )
	ORDERER_ELEM=$(echo $ORG_JSON | jq -c .orderer)
	PEER_ELEM=$( echo $ORG_JSON | jq -c .peer )

	if [ "$ORDERER_ELEM" != "null" ]; then
		ORDERER_HOST=$( echo $ORDERER_ELEM | jq -r .[] )

		ORDERER_ORGS=$( append $ORDERER_ORGS $ORG_NAME )
		ORDERER_HOSTS=$( append $ORDERER_HOSTS $ORDERER_HOST )
	fi

	if [ "$PEER_ELEM" != "null" ]; then
		PEER_ORGS=$( append $PEER_ORGS $ORG_NAME )
		PEER_ORGJSON=$( append $PEER_ORGJSON $ORG_JSON )
	fi
done

BROKER_HOSTS=$( echo $NETWORK_JSON | jq -rc ".consensus | .kafka[]")

DATA=${SDIR}/data

function printOrdererOrg {
   ORG=$1
   MSP_DIR="${SOLAR_TOOLS}/org/data/${ORG}/msp"

   echo "
  - &ORD$( echo $ORG | sed -e 's/\./\_/g' )

    Name: ${ORG}

    # ID to load the MSP definition as
    ID: ${ORG}MSP

    # MSPDir is the filesystem path which contains the MSP configuration
    MSPDir: ${MSP_DIR}"
}

function printPeerOrg {
   ORG=$1
   PEER_HOST=$2
   MSP_DIR=$SOLAR_TOOLS/org/data/${ORG}/msp

   PEER_ADDR=$( parse_host $PEER_HOST 1 )
   PEER_PORT=$( parse_host $PEER_HOST 2 )

   echo "
  - &PEER$( echo $ORG | sed -e 's/\./\_/g' )

    Name: ${ORG}

    # ID to load the MSP definition as
    ID: ${ORG}MSP

    # MSPDir is the filesystem path which contains the MSP configuration
    MSPDir: ${MSP_DIR}
    AnchorPeers:
       # AnchorPeers defines the location of peers which can be used
       # for cross org gossip communication.  Note, this value is only
       # encoded in the genesis block in the Application section context
       - Host: $PEER_ADDR
         Port: $PEER_PORT"
}

function main {

{
echo "
################################################################################
#
#   Section: Organizations
#
#   - This section defines the different organizational identities which will
#   be referenced later in the configuration.
#
################################################################################
Organizations:"

   for ORG in $ORDERER_ORGS; do
      printOrdererOrg $ORG
   done

   for ORGJSON in $PEER_ORGJSON; do
      NAME=$( echo $ORGJSON | jq -r ".name" )
      ANCHOR_HOST=$( echo $ORGJSON | jq -r ".anchor" )

      printPeerOrg $NAME $ANCHOR_HOST
   done

   echo "
################################################################################
#
#   SECTION: Application
#
#   This section defines the values to encode into a config transaction or
#   genesis block for application related parameters
#
################################################################################
Application: &ApplicationDefaults

    # Organizations is the list of orgs which are defined as participants on
    # the application side of the network
    Organizations:
"
   echo "
################################################################################
#
#   Profile
#
#   - Different configuration profiles may be encoded here to be specified
#   as parameters to the configtxgen tool
#
################################################################################
Profiles:

  OrgsOrdererGenesis:
    Orderer:
      # Orderer Type: The orderer implementation to start
      # Available types are \"solo\" and \"kafka\"
      #OrdererType: solo
      OrdererType: kafka
      Addresses:"

   for HOST in $ORDERER_HOSTS; do
      ADDR=$( parse_host $HOST 1 )
      PORT=$( parse_host $HOST 2 )
      echo "        - $ADDR:$PORT"
   done

   echo "
      # Batch Timeout: The amount of time to wait before creating a batch
      BatchTimeout: 2s

      # Batch Size: Controls the number of messages batched into a block
      BatchSize:

        # Max Message Count: The maximum number of messages to permit in a batch
        MaxMessageCount: 10

        # Absolute Max Bytes: The absolute maximum number of bytes allowed for
        # the serialized messages in a batch.
        AbsoluteMaxBytes: 99 MB

        # Preferred Max Bytes: The preferred maximum number of bytes allowed for
        # the serialized messages in a batch. A message larger than the preferred
        # max bytes will result in a batch larger than preferred max bytes.
        PreferredMaxBytes: 512 KB

      Kafka:
        # Brokers: A list of Kafka brokers to which the orderer connects
        # NOTE: Use IP:port notation"
    echo -n "
        Brokers:"

    for BROKER_HOST in $BROKER_HOSTS; do
      ADDR=$( parse_host $BROKER_HOST 2 )
      PORT=$( parse_host $BROKER_HOST 3 )
      echo -n "
          - $ADDR:$PORT"
    done

    echo "
      # Organizations is the list of orgs which are defined as participants on
      # the orderer side of the network
      Organizations:"

   for ORG in $ORDERER_ORGS; do
      echo "        - *ORD$( echo $ORG | sed -e 's/\./\_/g' )"
   done

   echo "
    Consortiums:

      SampleConsortium:

        Organizations:"

   for ORG in $PEER_ORGS; do
      echo "          - *PEER$( echo $ORG | sed -e 's/\./\_/g' )"
   done

   echo "
  OrgsChannel:
    Consortium: SampleConsortium
    Application:
      <<: *ApplicationDefaults
      Organizations:"

   for ORG in $PEER_ORGS; do
      echo "        - *PEER$( echo $ORG | sed -e 's/\./\_/g')"
   done

   }
   
}
main
