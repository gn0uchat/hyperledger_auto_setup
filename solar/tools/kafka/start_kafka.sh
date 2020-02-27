#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

MIN_ISR=1

#if [ $# -ne 4 ]; then
#  log "Usage: start_kafka <KAFKE_NAME> <KAFKA_HOST> <KAFKA_ID> <ZOOKEEPER_HOSTS>: $*"
#  exit 1
#fi

log "start_kafka.sh args: KAFKA_HOST => $KAFKA_HOST ZOOKEEPER_HOSTS => $ZOOKEEPER_HOSTS"

check_arg KAFKA_HOST
check_arg ZOOKEEPER_HOSTS

KAFKA_NAME=$( parse_host $KAFKA_HOST 0 )
KAFKA_ID=$(   parse_host $KAFKA_HOST 1 )
KAFKA_ADDR=$( parse_host $KAFKA_HOST 2 )
KAFKA_PORT=$( parse_host $KAFKA_HOST 3 )

DATA=$SDIR/data
KAFKA_HOME=$DATA/$KAFKA_NAME

KEYSTORE_FILE=$KAFKA_HOME/keystore.jks
TRUSTSTORE_FILE=$KAFKA_HOME/truststore.jks
KEYSTORE_SECRET_FILE=$KAFKA_HOME/secret

function main {
  
  DOCKER_FILE=$SDIR/docker-compose-${KAFKA_NAME}.yml

  print_kafka_yaml > $DOCKER_FILE; chmod 600 $DOCKER_FILE;

  docker-compose -f $DOCKER_FILE up -d
}

function print_kafka_yaml {
  PROTO=PLAINTEXT

{
echo "version: '2'
services:
  $KAFKA_NAME:
    container_name: $KAFKA_NAME
    extends:
      file: $SDIR/yaml/orderer-kafka-base.yaml
      service: kafka
    environment:
      # ========================================================================
      #     Reference: https://kafka.apache.org/documentation/#configuration
      # ========================================================================
      #
      # broker.id
      - KAFKA_BROKER_ID=${KAFKA_ID}
      #
      # min.insync.replicas
      # Let the value of this setting be M. Data is considered committed when
      # it is written to at least M replicas (which are then considered in-sync
      # and belong to the in-sync replica set, or ISR). In any other case, the
      # write operation returns an error. Then:
      # 1. If up to M-N replicas -- out of the N (see default.replication.factor
      # below) that the channel data is written to -- become unavailable,
      # operations proceed normally.
      # 2. If more replicas become unavailable, Kafka cannot maintain an ISR set
      # of M, so it stops accepting writes. Reads work without issues. The
      # channel becomes writeable again when M replicas get in-sync.
      - KAFKA_MIN_INSYNC_REPLICAS=$MIN_ISR
      #
      # default.replication.factor
      # Let the value of this setting be N. A replication factor of N means that
      # each channel will have its data replicated to N brokers. These are the
      # candidates for the ISR set of a channel. As we noted in the
      # min.insync.replicas section above, not all of these brokers have to be
      # available all the time. In this sample configuration we choose a
      # default.replication.factor of K-1 (where K is the total number of brokers in
      # our Kafka cluster) so as to have the largest possible candidate set for
      # a channel's ISR. We explicitly avoid setting N equal to K because
      # channel creations cannot go forward if less than N brokers are up. If N
      # were set equal to K, a single broker going down would mean that we would
      # not be able to create new channels, i.e. the crash fault tolerance of
      # the ordering service would be non-existent.
      - KAFKA_DEFAULT_REPLICATION_FACTOR=1
      #
      # zookeper.connect
      # Point to the set of Zookeeper nodes comprising a ZK ensemble."

      ZOOKEEPER_LIST=""
      for ZOOKEEPER_HOST in $ZOOKEEPER_HOSTS; do
	if [ -z "$ZOOKEEPER_LIST" ];then
	  ZOOKEEPER_LIST="$ZOOKEEPER_HOST"
	else
	  ZOOKEEPER_LIST="$ZOOKEEPER_LIST,$ZOOKEEPER_HOST"
        fi
      done

      echo "
      - KAFKA_ZOOKEEPER_CONNECT=$ZOOKEEPER_LIST
      # zookeeper.connection.timeout.ms
      # The max time that the client waits to establish a connection to
      # Zookeeper. If not set, the value in zookeeper.session.timeout.ms (below)
      # is used.
      #- KAFKA_ZOOKEEPER_CONNECTION_TIMEOUT_MS = 6000
      #
      # zookeeper.session.timeout.ms
      #- KAFKA_ZOOKEEPER_SESSION_TIMEOUT_MS = 6000

      - KAFKA_PORT=${KAFKA_PORT}

      - KAFKA_LISTENERS=${PROTO}://${KAFKA_ADDR}:${KAFKA_PORT}"

  #VM_KEYSTORE_FILE=/data/keystore.jks
  #VM_TRUSTSTORE_FILE=/data/truststore.jks
  #SECRET=$( cat $KEYSTORE_SECRET_FILE )

  if [ "$PROTO" = "SSL" ]; then
    echo"
      - KAFKA_SECURITY_INTER_BROKER_PROTOCOL=SSL

      - KAFKA_SSL_KEYSTORE_LOCATION=$VM_KEYSTORE_FILE
      - KAFKA_SSL_KEYSTORE_PASSWORD=$SECRET
      - KAFKA_SSL_KEY_PASSWORD=$SECRET
      - KAFKA_SSL_CLIENT_AUTH=none
      - KAFKA_SSL_ENABLED_PROTOCOLS=TLSv1.2,TLSv1.1,TLSv1
      - KAFKA_SSL_KEYSTORE_TYPE=JKS
      - KAFKA_SSL_TRUSTSTORE_TYPE=JKS
      - KAFKA_SSL_TRUSTSTORE_LOCATION=$VM_TRUSTSTORE_FILE
      - KAFKA_SSL_TRUSTSTORE_PASSWORD=$SECRET"
  fi

  echo "
    ports:
      - $KAFKA_PORT:$KAFKA_PORT
    #volumes:
    #  - $KEYSTORE_FILE:$VM_KEYSTORE_FILE
    #  - $TRUSTSTORE_FILE:$VM_TRUSTSTORE_FILE

    network_mode: \"host\" "
}
}

main
