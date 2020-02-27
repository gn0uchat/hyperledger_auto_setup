#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh


#if [ $# -ne 6 ]; then
#  echo "Usage: start_zookeeper <ZOOKEEPER_NAME> <ZOO_MY_ID> <ZOO_SERVERS> <CLI_PORT> <PORT1> <PORT2>: $*"
#  exit 1
#fi

#if [ $# -ne 2 ]; then
#  #ZK_HOST=<NAME>:<ID>:<ADDR>:<PORT>:<PORT>;<PORT>
#  echo "Usage: start_zookeeper <ZK_HOST> <ZOO_SERVERS>: $*"
#  echo "ZK_HOST=<NAME>:<ID>:<ADDR>:<PORT>:<PORT>;<PORT>"
#  exit 1
#fi

log "ZK_HOST => $ZK_HOST"
log "ZOO_SERVERS => $ZOO_SERVERS"

check_arg ZK_HOST
check_arg ZOO_SERVERS

ZOOKEEPER_NAME=$( parse_host $ZK_HOST 0 )
ZOO_MY_ID=$( parse_host $ZK_HOST 1 )
ZOO_ADDR=$( parse_host $ZK_HOST 2 )
PORT1=$( parse_host $ZK_HOST 3 )
PORT2=$( parse_host $ZK_HOST 4 )
CLI_PORT=$( parse_host $ZK_HOST 5 )

log "$ZOOKEEPER_NAME $ZOO_MY_ID $ZOO_ADDR $PORT1 $PORT2 $CLI_PORT"

YAML_DIR=$SDIR/yaml
DATA=$SDIR/data
ZK_DATA=$DATA/$ZOOKEEPER_NAME

mkdir -p $DATA
mkdir -p $ZK_DATA

function main {

  DOCKER_FILE=$SDIR/docker-compose-${ZOOKEEPER_NAME}.yml
  ZOOKEEPER_CFG=$ZK_DATA/${ZOOKEEPER_NAME}.cfg

  print_zk_cfg > $ZOOKEEPER_CFG
  print_zookeeper_yaml > $DOCKER_FILE
  docker-compose -f $DOCKER_FILE up -d
}

function print_zk_cfg {
  {
  echo "clientPort=${CLI_PORT}"
  echo "dataDir=/data"
  echo "dataLogDir=/datalog"
  echo "tickTime=2000"
  echo "initLimit=5"
  echo "syncLimit=2"
  #echo "autopurge.snapRetainCount=3"
  #echo "autopurge.purgeInterval=1"
  for SERVER in $ZOO_SERVERS; do
      echo $SERVER
  done
 }
}

function print_zookeeper_yaml {

ZK_BASE_FILE=$SDIR/yaml/orderer-kafka-base.yaml

echo "version: '2'
services:
  ${ZOOKEEPER_NAME}:
    container_name: ${ZOOKEEPER_NAME}
    extends:
      file: ${ZK_BASE_FILE}
      service: zookeeper
    environment:
      # ========================================================================
      #     Reference: https://zookeeper.apache.org/doc/r3.4.9/zookeeperAdmin.html#sc_configuration
      # ========================================================================
      #
      # myid
      # The ID must be unique within the ensemble and should have a value
      # between 1 and 255.
      - ZOO_MY_ID=${ZOO_MY_ID}
      #
      # server.x=[hostname]:nnnnn[:nnnnn]
      # The list of servers that make up the ZK ensemble. The list that is used
      # by the clients must match the list of ZooKeeper servers that each ZK
      # server has. There are two port numbers 'nnnnn'. The first is what
      # followers use to connect to the leader, while the second is for leader
      # election.
      - ZOO_SERVERS=${ZOO_SERVERS}
    volumes:
      - ${ZOOKEEPER_CFG}:/conf/zoo.cfg
    ports:
      - ${PORT1}:${PORT1}
      - ${PORT2}:${PORT2}
    network_mode: \"host\" "
}

main
