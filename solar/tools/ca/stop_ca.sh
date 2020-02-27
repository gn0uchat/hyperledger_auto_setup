#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )

CA_NAME=$1

docker-compose -f ${SDIR}/docker-compose-${CA_NAME}.yml down
