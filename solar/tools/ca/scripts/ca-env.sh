#!/bin/bash
SDIR=$( pwd $BASH_SOURCE )

ROOT_SH=${SDIR}/../../scripts

source $ROOT_SH/env.sh

CA_NAME=${ORG_NAME}-ca
CA_HOST=${LOCAL_HOST_IP}
