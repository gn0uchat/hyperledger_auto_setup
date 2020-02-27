#!/bin/bash
DEBUG=0
LOCAL_HOST="127.0.0.1"

function if_dir_exist {
    FILE=$1
    FILE_MEANING=$2
    if [ ! -d $FILE ]; then
        echo "missing $FILE_MEANING. Please create $FILE"
        exit 1
    fi
}

function if_file_exist {
    FILE=$1
    FILE_MEANING=$2
    if [ ! -f $FILE ]; then
        echo "missing $FILE_MEANING. Please create $FILE"
        exit 1
    fi
}

function gen_tls_keys {
    local KEY_FILE=$1
    local CRT_FILE=$2
    local ADDR=$3
    local TMP_DIR=$4

    mkdir -p $TMP_DIR

    #fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $PEER_HOME/tmp --csr.hosts $PEER_HOST
    #fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $TMP_DIR --csr.hosts $ADDR --csr.cn $ADDR
    fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $TMP_DIR --csr.hosts $ADDR
    
    cp $TMP_DIR/keystore/* $KEY_FILE 
    cp $TMP_DIR/signcerts/* $CRT_FILE
    
    rm -rf $TMP_DIR
}

function gen_secret {

  local SECRET_FILE=$1
  
  if [ ! -f "$SECRET_FILE" ]; then
      openssl rand -hex 16 > $SECRET_FILE
      chmod 400 $SECRET_FILE
  fi

}

function pause {
  if [ "$DEBUG" = "1" ];then
    MSG=$1
    read -rsp "[pause] $MSG ..."
  fi
}

function append {
    local HEAD="$1"
    local TAIL="$2"
    local DELI="$3"

    if [ -z "$DELI" ]; then
        DELI=" "
    fi

    if [ -z "$HEAD" ]; then
        local HEAD=$TAIL
    else
        local HEAD="${HEAD}${DELI}${TAIL}"
    fi

    echo "$HEAD"
}

function split_colon {
    STR=$1
    IDX=$2
    IFS=':' read -ra PARTS <<< $STR
    echo ${PARTS[$IDX]}
}

function parse_host {

    local STR=$1
    local IDX=$2
    local END_IDX=$3


    IFS=':;' read -ra PARTS <<< $STR
    #echo ${PARTS[$IDX]}

    if [ "$END_IDX" = "" ]; then
    	local OUTPUT=${PARTS[$IDX]}
    else
    	local OUTPUT=""
    	while [ "$IDX" -le "$END_IDX" ]; do
		local OUTPUT=$( append "$OUTPUT" "${PARTS[$IDX]}" ":" )
		IDX=$((IDX + 1))
	done
    fi

    echo $OUTPUT
}

function parse {
    STR=$1
    IDX=$2
    DEL=$3

    if [ "$DEL" = "" ]; then
    	DEL=":;"
    fi
    IFS=$DEL read -ra PARTS <<< $STR

    echo ${PARTS[$IDX]}
}

function parse_addr {
    STR=$1
    IDX=$2
    IFS=':;' read -ra PARTS <<< $STR
    echo ${PARTS[$IDX]}
}

function split_host_port {
    HOST=$1
    IFS=':' read -ra PARTS <<< $HOST
    echo ${PARTS[1]}
}

function split_host_addr {
    HOST=$1
    IFS=':' read -ra PARTS <<< $HOST
    echo ${PARTS[0]}
}

function log {
    echo "[log] $@" 1>&2;
}

function send_message {
	ADDR=$1
	PORT=$2
	MSG=$3

	log "sending message to $ADDR on port $PORT"

	SEND_SUCC=0

	while [ "SEND_SUCC" = "1" ]; do
		( echo "$MSG" | nc $ADDR $PORT ) && SEND_SUCC=1
		sleep 3;
	done

	log "sending message to $ADDR on port $PORT complete"
}

function wait_message {
	PORT=$1

	log "wait message on port $PORT"

	nc -l $PORT
	
	log "message received, no longer waiting"
}

function encode_list {
	LIST=$1
	ENCODE_LIST=""

	for ITEM in $LIST; do
		ENCODE_LIST=$( append "$ENCODE_LIST" "$ITEM" "?" )
	done

	echo $ENCODE_LIST
}

function decode_list {
	ENCODE_LIST=$1
	LIST=$( echo $ENCODE_LIST | sed -e 's/\?/ /g' )

	echo $LIST
}

function check_arg {
	VAR_NAME=$1
	VAR_VAL=${!VAR_NAME}

	if [ "$VAR_VAL" = "" ]; then
		echo "environment variable $VAR_NAME unset"
		exit 1
	fi
}

function host_name {
	local TYPE=$1
	local HOST=$2
	local NAME=""

	NAME=$( parse_host $HOST 0 )

	echo $NAME
}

function host_addr {
	local TYPE=$1
	local HOST=$2
	local ADDR=""

	if [ "$TYPE" = "kafka" ]; then
		ADDR=$( parse_host $HOST 2 )
	elif [ "$TYPE" = "zookeeper" ]; then
		ADDR=$( parse_host $HOST 2 )
	else
		ADDR=$( parse_host $HOST 1 )
	fi

	echo $ADDR
}

function host_port {
	local TYPE=$1
	local HOST=$2
	echo $( parse_host $HOST 2 )
}
