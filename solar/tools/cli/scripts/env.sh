export ORDERER_HOST="127.0.0.1"
export ORDERER_PORT="7050"
export ORG_NAME="solar"
export CHANNEL_NAME="solar_channel"
export CC_NAME="mars_cc"
export ORDERER_PORT_ARGS="-o ${ORDERER_HOST}:${ORDERER_PORT} --tls --cafile $CA_CHAINFILE --clientauth"
export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
#peer chaincode invoke -C $CHANNEL_NAME -n $CC_NAME -c '{"Args":["prayToken","bob"]}' $ORDERER_CONN_ARGS

