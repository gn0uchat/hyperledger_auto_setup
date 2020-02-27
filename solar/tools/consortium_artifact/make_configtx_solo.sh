#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )

if [ $# -ne 3 ]; then
    log "Usage: make_configtx_solo <ORDERER_ORGS> <PEER_ORGS> <ORDERER_HOST>: $*"
    exit 1
fi

ORDERER_ORGS=$1
PEER_ORGS=$2
ORDERER_HOST=$3

DATA=${SDIR}/data

function printOrdererOrg {
   ORG=$1
   MSP_DIR="${SOLAR_TOOLS}/org/data/${ORG}/msp"

   echo "
  - &ORD${ORG}

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

   echo "
  - &PEER${ORG}

    Name: ${ORG}

    # ID to load the MSP definition as
    ID: ${ORG}MSP

    # MSPDir is the filesystem path which contains the MSP configuration
    MSPDir: ${MSP_DIR}
    AnchorPeers:
       # AnchorPeers defines the location of peers which can be used
       # for cross org gossip communication.  Note, this value is only
       # encoded in the genesis block in the Application section context
       - Host: $PEER_HOST
         Port: 7051"
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

   for ORG in $PEER_ORGS; do
      printPeerOrg $ORG 127.0.0.1
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
      OrdererType: solo
      Addresses:
        - $ORDERER_HOST

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
        # NOTE: Use IP:port notation
        Brokers:
          - 127.0.0.1:9092

      # Organizations is the list of orgs which are defined as participants on
      # the orderer side of the network
      Organizations:"

   for ORG in $ORDERER_ORGS; do
      echo "        - *ORD${ORG}"
   done

   echo "
    Consortiums:

      SampleConsortium:

        Organizations:"

   for ORG in $PEER_ORGS; do
      echo "          - *PEER${ORG}"
   done

   echo "
  OrgsChannel:
    Consortium: SampleConsortium
    Application:
      <<: *ApplicationDefaults
      Organizations:"

   for ORG in $PEER_ORGS; do
      echo "        - *PEER${ORG}"
   done

   }
   
}
main
