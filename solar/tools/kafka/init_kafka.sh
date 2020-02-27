#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

#if [ $# -ne 1 ]; then
#  log "Usage: start_kafka <KAFKA_HOST>: $*"
#  exit 1
#fi

log "init_kafka.sh args: ZK_HOST => $KAFKA_HOST"

check_arg KAFKA_HOST

KAFKA_NAME=$( parse_host $KAFKA_HOST 0 )
KAFKA_ID=$(   parse_host $KAFKA_HOST 1 )
KAFKA_ADDR=$( parse_host $KAFKA_HOST 2 )
KAFKA_PORT=$( parse_host $KAFKA_HOST 3 )

DATA=$SDIR/data
KAFKA_HOME=$DATA/$KAFKA_NAME

#CA_CERT_FILE=$KAFKA_HOME/ca-cert
#CA_KEY_FILE=$KAFKA_HOME/ca-key
CA_CERT_FILE=$DATA/ca-cert
CA_KEY_FILE=$DATA/ca-key

KEYSTORE_FILE=$KAFKA_HOME/keystore.jks
TRUSTSTORE_FILE=$KAFKA_HOME/truststore.jks
KEYSTORE_SECRET_FILE=$KAFKA_HOME/secret

function gen_tls_ca {

  SECRET_FILE=$SDIR/secret/${CA_HOST}/$KAFKA_NAME
  SECRET=$( cat $SECRET_FILE )

  $SOLAR_TOOLS/account/new_account.sh "$KAFKA_NAME" "kafka" "$CA_HOST"

  ENROLLMENT_URL=https://${KAFKA_NAME}:${SECRET}@${CA_HOST}

  fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M $KAFKA_HOME/tmp --csr.hosts $KAFKA_ADDR
    
  cp $KAFKA_HOME/tmp/keystore/*  $KEY_FILE 
  cp $KAFKA_HOME/tmp/signcerts/* $CRT_FILE

  rm -r $KAFKA_HOME/tmp

}

function main {
  mkdir -p $DATA
  mkdir -p $KAFKA_HOME

  gen_secret $KEYSTORE_SECRET_FILE

  #ALIAS=$KAFKA_NAME-tls
  ALIAS=localhost
  DNAME="CN=$KAFKA_ADDR"
  SECRET=$( cat "$KEYSTORE_SECRET_FILE" )

  #CA_ALIAS=$KAFKA_NAME-ca
  CA_ALIAS=CARoot
  KAFKA_TLS_CERT=$KAFKA_HOME/$ALIAS-cert
  KAFKA_TLS_SIGN_CERT=$KAFKA_HOME/$ALIAS-signed_cert
  VALID_DAYS=365

  if [ ! -f "$KEYSTORE_FILE" ];then

    keytool -genkey -keyalg RSA -noprompt -alias $ALIAS  -dname $DNAME -validity $VALID_DAYS -keystore $KEYSTORE_FILE \
  	    -storepass $SECRET -keypass $SECRET -ext SAN=ip:$KAFKA_ADDR
    #keytool -genkey -noprompt -alias $ALIAS  -dname $DNAME -validity $VALID_DAYS -keystore $KEYSTORE_FILE \
    #	    -storepass $SECRET -keypass $SECRET
  fi

  gen_ca

  keytool -keystore $TRUSTSTORE_FILE -alias $CA_ALIAS -import -noprompt -trustcacerts -file $CA_CERT_FILE \
  	-storepass $SECRET

  keytool -keystore $KEYSTORE_FILE -alias $ALIAS -certreq -file $KAFKA_TLS_CERT -storepass $SECRET -keypass $SECRET

  #ca_sign_tls

  openssl x509 -req -CA $CA_CERT_FILE -CAkey $CA_KEY_FILE -in $KAFKA_TLS_CERT -out  $KAFKA_TLS_SIGN_CERT \
  	-days $VALID_DAYS -CAcreateserial -passin pass:"$SECRET"

  keytool -keystore $KEYSTORE_FILE -alias $CA_ALIAS -import -trustcacerts -file $CA_CERT_FILE \
  	-storepass $SECRET -keypass $SECRET -noprompt

  keytool -keystore $KEYSTORE_FILE -alias $ALIAS -import -trustcacerts -file $KAFKA_TLS_SIGN_CERT \
  	-storepass $SECRET -keypass $SECRET -noprompt

  #keytool -keystore $TRUSTSTORE_FILE -alias "orderer_ca" -import -trustcacerts -file $ORDERER_CA_CERT \
  #	-storepass $SECRET -keypass $SECRET -noprompt

}

function ca_sign_tls {

  SAN_CNF_FILE=$KAFKA_HOME/openssl.cnf

  echo "subjectAltName = IP:$KAFKA_ADDR" > $SAN_CNF_FILE

  openssl x509 -req -CA $CA_CERT_FILE -CAkey $CA_KEY_FILE -in $KAFKA_TLS_CERT -out  $KAFKA_TLS_SIGN_CERT \
  	-extfile $SAN_CNF_FILE -extensions v3_ca -days $VALID_DAYS -CAcreateserial -passin pass:"$SECRET"

}

function gen_ca {
  if [ ! -f "$CA_CERT_FILE" ]; then

    DNAME="/CN=$KAFKA_ADDR"

    openssl req -new -x509 -keyout $CA_KEY_FILE -out $CA_CERT_FILE -days 365 -passout pass:"$SECRET" \
    	-subj "$DNAME" -nodes

    chmod 400 $CA_KEY_FILE
  fi

}

#main
