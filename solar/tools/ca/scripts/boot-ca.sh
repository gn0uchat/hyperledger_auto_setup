#!/bin/bash

set -e

SECRET=$( cat $FABRIC_CA_SERVER_HOME/ca-secret )

fabric-ca-server init -b boot:$SECRET

#cp $FABRIC_CA_SERVER_HOME/ca-cert.pem /data

fabric-ca-server start
