#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

COMMAND=$1
check_arg CLI_NAME

log "cli setup channel CLI_NAME=> $CLI_NAME COMMAND => $COMMAND"

docker exec -i $CLI_NAME bash -c "$COMMAND"
