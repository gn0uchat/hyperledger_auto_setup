ORDERER_HOST="127.0.0.1:7050"
ORG_NAME="solar"

CHANNEL_NAME="solar_channel"

function main {

    set -e

    ORDERER_PORT_ARGS="-o ${ORDERER_HOST} --tls --cafile $CA_CHAINFILE --clientauth"
    ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"

    setup_channel
    #setup_chaincode
}

function setup_channel {

    CHANNEL_TX_FILE=${CLI_HOME}/${CHANNEL_NAME}.tx
    ANCHOR_TX_FILE=${CLI_HOME}/${ORG_NAME}-anchor.tx

    CHANNEL_BLOCK_FILE=${CLI_HOME}/${CHANNEL_NAME}.block
    peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS \
          --outputBlock $CHANNEL_BLOCK_FILE

    peer channel join -b $CHANNEL_BLOCK_FILE

    peer channel update -c $CHANNEL_NAME -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
}

function setup_chaincode {

    CC_CHAIN_TAG_DIR=
    CC_CHAIN_TAG_NAME=

    CC_CHAIN_PRODUCT_DIR=
    CC_CHAIN_PRODUCT_NAM=

    #CC_ARGS=\'{\"Args\":[\"init\"]}\'
    peer chaincode install -n $CC_CHAIN_TAG_NAME -v 1.0 -p $CC_CHAIN_TAG_DIR
    peer chaincode instantiate -C $CHANNEL_NAME -n $CC_CHAIN_TAG_NAME -v 1.0 -c '{"Args":["init"]}' $ORDERER_CONN_ARGS

    #CC_ARGS=\'{\"Args\":[\"init\"]}\'
    peer chaincode install -n $CC_CHAIN_PRODUCT_NAME -v 1.0 -p $CC_CHAIN_PRODUCT_DIR
    peer chaincode instantiate -C $CHANNEL_NAME -n $CC_CHAIN_PRODUCT_NAME -v 1.0 -c '{"Args":["init"]}' $ORDERER_CONN_ARGS

}

main
