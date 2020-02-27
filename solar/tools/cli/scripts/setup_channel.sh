#ORDERER_HOST
#ORG_NAME
#CHANNEL_NAME
#COMMAND

#ORDERER_PORT_ARGS="-o ${ORDERER_HOST} --tls --cafile $CA_CHAINFILE --clientauth"
#ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
ORDERER_CONN_ARGS="-o $ORDERER_HOST"

CHANNEL_TX_FILE=${CLI_HOME}/${CHANNEL_NAME}.tx
ANCHOR_TX_FILE=${CLI_HOME}/${ORG_NAME}-anchor.tx
CHANNEL_BLOCK_FILE=${CLI_HOME}/${CHANNEL_NAME}.block

function main {

    set -e

    if [ "setup_channel" = "$COMMAND" ]; then
    	setup_channel
    elif [ "create_channel" = "$COMMAND" ]; then
    	create_channel
    elif [ "join_channel" = "$COMMAND" ]; then
    	join_channel
    else
    	setup_channel
    fi

    #setup_chaincode
}

function join_channel {

    peer channel fetch 0 $CHANNEL_BLOCK_FILE $ORDERER_CONN_ARGS -c $CHANNEL_NAME
    peer channel join -b $CHANNEL_BLOCK_FILE

    if [ -f $ANCHOR_TX_FILE ]; then
        peer channel update -c $CHANNEL_NAME -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
    fi
}

function create_channel {
    peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS \
          --outputBlock $CHANNEL_BLOCK_FILE
}

function setup_channel {
    create_channel
    join_channel
}

function setup_chaincode {

    CC_CHAIN_TAG_DIR=
    CC_CHAIN_TAG_NAME=

    CC_CHAIN_PRODUCT_DIR=
    CC_CHAIN_PRODUCT_NAME=

    #CC_ARGS=\'{\"Args\":[\"init\"]}\'
    peer chaincode install -n $CC_CHAIN_TAG_NAME -v 1.0 -p $CC_CHAIN_TAG_DIR
    peer chaincode instantiate -C $CHANNEL_NAME -n $CC_CHAIN_TAG_NAME -v 1.0 -c '{"Args":["init"]}' $ORDERER_CONN_ARGS

    #CC_ARGS=\'{\"Args\":[\"init\"]}\'
    peer chaincode install -n $CC_CHAIN_PRODUCT_NAME -v 1.0 -p $CC_CHAIN_PRODUCT_DIR
    peer chaincode instantiate -C $CHANNEL_NAME -n $CC_CHAIN_PRODUCT_NAME -v 1.0 -c '{"Args":["init"]}' $ORDERER_CONN_ARGS

}

main
