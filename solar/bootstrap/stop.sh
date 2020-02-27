#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_ROOT=$( dirname $SDIR )
SOLAR_TOOLS=$SOLAR_ROOT/tools
. $SDIR/env.sh

KAFKA_ID=0;
for HOST in $KAFKA_HOSTS; do

    KAFKA_NAME=kafka$KAFKA_ID.$ORG_NAME
    docker-compose -f $SOLAR_TOOLS/kafka/docker-compose-${KAFKA_NAME}.yml down

    KAFKA_ID=$((KAFKA_ID+1))
done

ZK_ID=1;
for HOST in $ZK_HOSTS3p; do

    ZK_NAME=zk$ZK_ID.$ORG_NAME
    docker-compose -f $SOLAR_TOOLS/zookeeper/docker-compose-${ZK_NAME}.yml down

    ZK_ID=$((ZK_ID+1))
done

COUNTER=0
for ORDERER_HOST in $ORDERER_HOSTS; do

    ORDERER_NAME=orderer${COUNTER}-${ORG_NAME};
    docker-compose -f $SOLAR_TOOLS/orderer/docker-compose-${ORDERER_NAME}.yml down

    COUNTER=$((COUNTER+1));
done


docker-compose -f $SOLAR_TOOLS/peer/docker-compose-${PEER_NAME}.yml down
docker-compose -f $SOLAR_TOOLS/ca/docker-compose-${CA_NAME}.yml down
docker-compose -f $SOLAR_TOOLS/cli/docker-compose-${PEER_NAME}-cli.yml down

sudo rm -r $SOLAR_TOOLS/*/data/
sudo rm -r $SOLAR_TOOLS/*/logs/
sudo rm -r $SOLAR_TOOLS/account/secret/
