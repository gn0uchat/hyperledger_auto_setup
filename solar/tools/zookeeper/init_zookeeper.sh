#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

YAML_DIR=$SDIR/yaml

if [ $# -ne 5 ]; then
  echo "Usage: init_zookeeper <ZK_NAME> <ZK_PORT1> <ZK_PORT2> <ZK_ID> <ZK_HOSTS>: $*"
  exit 1
fi

ZK_NAME=$1
ZK_PORT1=$2
ZK_PORT2=$3
ZK_ID=$4
ZK_HOSTS=$5

function main {

  CNT=1; ZK_SERVERS=""

  for HOST in $ZK_HOSTS; do

    ZK_SERV="server.${CNT}=$HOST"

    if [ -z "$ZK_SERVERS" ]; then
      ZK_SERVERS=$ZK_SERV
    else
      ZK_SERVERS="$ZK_SERVERS $ZK_SERV"
    fi

    CNT=$((CNT+1))
  done

  DOCKER_FILE=$SDIR/docker-compose-${ZK_NAME}.yaml

  print_zookeeper_yaml > $DOCKER_FILE
#  docker-compose -f $DOCKER_FILE up -d
}

function print_zookeeper_yaml {
echo "version: '2'

network_mode: "host"

services:
  ${ZK_NAME}:
    container_name: ${ZK_NAME}
    extends:
      file: orderer-kafka-base.yaml
      service: zookeeper
    environment:
      # ========================================================================
      #     Reference: https://zookeeper.apache.org/doc/r3.4.9/zookeeperAdmin.html#sc_configuration
      # ========================================================================
      #
      # myid
      # The ID must be unique within the ensemble and should have a value
      # between 1 and 255.
      - ZOO_MY_ID=${ZK_ID}
      #
      # server.x=[hostname]:nnnnn[:nnnnn]
      # The list of servers that make up the ZK ensemble. The list that is used
      # by the clients must match the list of ZooKeeper servers that each ZK
      # server has. There are two port numbers 'nnnnn'. The first is what
      # followers use to connect to the leader, while the second is for leader
      # election.
      - ZOO_SERVERS=\"${ZK_SERVERS}\"
    ports:
      - ${ZK_PORT1}:${ZK_PORT1}
      - ${ZK_PORT2}:${ZK_PORT2}"
}

main
