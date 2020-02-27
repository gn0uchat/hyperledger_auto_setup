#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_ROOT=$( dirname $SDIR )
SOLAR_TOOLS=$SOLAR_ROOT/tools

. ${SOLAR_TOOLS}/lib.sh
. ${SDIR}/env.sh

CA_CHAINFILE=$SOLAR_TOOLS/ca/data/${CA_NAME}/ca-cert.pem

function file_exist {
    FILE=$1
    FILE_MEANING=$2
    if [ ! -f $FILE ]; then
        echo "missing $FILE_MEANING. Please create $FILE"
	exit 1
    fi
}

function start_consensus {

    ZK_SERVERS=""; ZK_ID=1;
    for HOST in $ZK_HOSTS3p; do

        IFS=':;' read -ra PARTS <<< $HOST
	ADDR=${PARTS[0]}
	PORT1=${PARTS[1]}
	PORT2=${PARTS[2]}

        ZK_SERVERS=$( append "$ZK_SERVERS" "server.${ZK_ID}=${ADDR}:${PORT1}:${PORT2}" )

	CLI_PORT=$((CLI_PORT+1))
	ZK_ID=$((ZK_ID+1))
    done

    ZK_HOSTS=""; ZK_ID=1;
    for HOST in $ZK_HOSTS3p; do

        IFS=':;' read -ra PARTS <<< $HOST
	ADDR=${PARTS[0]}
	PORT1=${PARTS[1]}
	PORT2=${PARTS[2]}
	CLI_PORT=${PARTS[3]}

	ZK_NAME=zk$ZK_ID.$ORG_NAME
        $SOLAR_TOOLS/zookeeper/start_zookeeper.sh $ZK_NAME $ZK_ID "$ZK_SERVERS" $CLI_PORT $PORT1 $PORT2

	ZK_HOSTS=$( append "$ZK_HOSTS" "$ADDR:$CLI_PORT" )

	ZK_ID=$((ZK_ID+1))
    done

    echo "sleeping ..."; sleep 3;

    KAFKA_ID=0;
    for HOST in $KAFKA_HOSTS; do

        ADDR=$( split_colon $HOST 0 )
	PORT=$( split_colon $HOST 1 )

	KAFKA_NAME=kafka$KAFKA_ID.$ORG_NAME
	$SOLAR_TOOLS/kafka/init_kafka.sh  "$KAFKA_NAME" "$HOST" "$CA_CHAINFILE"
	$SOLAR_TOOLS/kafka/start_kafka.sh "$KAFKA_NAME" "$HOST" "$KAFKA_ID" "$ZK_HOSTS"

        KAFKA_ID=$((KAFKA_ID+1))
    done
}

function main {
    SH=$SDIR/scripts

    set -e

    $SOLAR_TOOLS/ca/start_ca.sh ${CA_NAME} ${CA_PORT}; echo 'sleeping ...'; sleep 3;

    send_pw
    broadcast_cacert

    start_consensus

    pause "before init_orderer.sh"

    COUNTER=0
    for ORDERER_HOST in $ORDERER_HOSTS; do

	ORDERER_NAME=orderer${COUNTER}-${ORG_NAME};
        $SOLAR_TOOLS/orderer/init_orderer.sh ${ORDERER_NAME} ${ORDERER_HOST} ${CA_HOST} ${CA_CHAINFILE};

	COUNTER=$((COUNTER+1));
    done

    pause "before init_peer.sh"
    $SOLAR_TOOLS/peer/init_peer.sh ${PEER_NAME} ${PEER_HOST} ${CA_HOST}

    pause "before init_org.sh"
    $SOLAR_TOOLS/org/init_org.sh ${ORG_NAME} ${CA_HOST}

    pause "before artifactgen.sh"
    #$SOLAR_TOOLS/consortium_artifact/artifactgen.sh ${CONSORTIUM_NAME} ${CHANNEL_NAME} ${ORG_NAME} ${ORG_NAME}
    $SOLAR_TOOLS/consortium_artifact/artifactgen.sh ${CONSORTIUM_NAME} \
	    ${CHANNEL_NAME} ${ORG_NAME} ${ORG_NAME} "${ORDERER_HOSTS}" "${KAFKA_HOSTS}"
    
    GENESIS_BLOCK_FILE=$SOLAR_TOOLS/consortium_artifact/data/${CONSORTIUM_NAME}/genesis.block
    CHANNEL_TX_FILE=$SOLAR_TOOLS/consortium_artifact/data/${CONSORTIUM_NAME}/${CHANNEL_NAME}/${CHANNEL_NAME}.tx
    ANCHOR_TX_FILE=$SOLAR_TOOLS/consortium_artifact/data/${CONSORTIUM_NAME}/${CHANNEL_NAME}/${ORG_NAME}-anchor.tx

    file_exist $GENESIS_BLOCK_FILE	"genesis block file"
    file_exist $CHANNEL_TX_FILE		"channel tx file "
    file_exist $ANCHOR_TX_FILE 		"anchor file for ${ORG_NAME}"
    
    #cp $GENESIS_BLOCK_FILE $SOLAR_TOOLS/orderer/data/${ORDERER_NAME}
    
    pause "before start_orderer.sh"


    COUNTER=0
    for ORDERER_HOST in $ORDERER_HOSTS; do

	ORDERER_NAME=orderer${COUNTER}-${ORG_NAME};

        echo "starting orderer: $ORDERER_NAME ..."

        $SOLAR_TOOLS/orderer/start_orderer.sh ${ORDERER_NAME} ${ORDERER_HOST} ${ORG_NAME} $GENESIS_BLOCK_FILE; 
        echo 'sleeping ...'; sleep 3;

	COUNTER=$((COUNTER+1));
    done

    pause "before start_peer.sh"
    $SOLAR_TOOLS/peer/start_peer.sh ${PEER_NAME} ${ORG_NAME} ${PEER_HOST} ${DB_HOST}; echo 'sleeping ...'; sleep 3;

    pause "start_peer_cli.sh"
    $SOLAR_TOOLS/cli/start_peer_cli.sh ${PEER_NAME} ${ORG_NAME}; echo 'sleeping ...'; sleep 3;

    CLI_HOME=$SOLAR_TOOLS/cli/data/${PEER_NAME}-cli

    cp $CHANNEL_TX_FILE		$CLI_HOME
    cp $ANCHOR_TX_FILE		$CLI_HOME
    cp $SH/run.sh $CLI_HOME/run.sh

    docker exec -i ${PEER_NAME}-cli bash ./run.sh
}

function send_pw {
    mkdir -p $SOLAR_TOOLS/account/secret/${CA_HOST}
    cp $SOLAR_TOOLS/ca/data/${CA_NAME}/ca-secret $SOLAR_TOOLS/account/secret/${CA_HOST}/boot
}

function broadcast_cacert {

    DIRS=( 
    	   #"$SOLAR_TOOLS/orderer/data/${ORDERER_NAME}"
	   "$SOLAR_TOOLS/peer/data/${PEER_NAME}"
	   "$SOLAR_TOOLS/account/data/${CA_HOST}"
	   "$SOLAR_TOOLS/org/data/${ORG_NAME}" )

    for DIR in ${DIRS[@]}; do
        echo "broadcast to $DIR"
        mkdir -p $DIR
        cp $SOLAR_TOOLS/ca/data/${CA_NAME}/ca-cert.pem $DIR
    done
}

main
#start_consensus
