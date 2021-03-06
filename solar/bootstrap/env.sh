#!/bin/bash
LOCAL_IP="127.0.0.1"

ORG_NAME="solar"
CA_NAME="${ORG_NAME}-ca"
PEER_NAME="earth-solar"
ORDERER_NAME="orderer-solar"
CONSORTIUM_NAME="sun"
CHANNEL_NAME="solar_channel"

CA_PORT="7054"
CA_ADDR="$LOCAL_IP"

PEER_PORT=7051
PEER_ADDR="$LOCAL_IP"

DB_PORT=5984
DB_ADDR="$LOCAL_IP"

CA_HOST="${CA_ADDR}:${CA_PORT}"
PEER_HOST="${PEER_ADDR}:${PEER_PORT}"
DB_HOST="$DB_ADDR:$DB_PORT"

ORDERER_HOSTS="$LOCAL_IP:7050 $LOCAL_IP:7049"
#ORDERER_HOSTS="$LOCAL_IP:7050"

KAFKA_HOSTS="$LOCAL_IP:9092 $LOCAL_IP:9093 $LOCAL_IP:9094"
#KAFKA_HOSTS="$LOCAL_IP:9092"

ZK_HOSTS3p="$LOCAL_IP:2888:3888;2181 $LOCAL_IP:2889:3889;2182 $LOCAL_IP:2890:3890;2183"
