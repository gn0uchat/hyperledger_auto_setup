#!/bin/bash
SDIR=$( dirname $( readlink -f $BASH_SOURCE ) )
SOLAR_TOOLS=$( dirname $SDIR )
. $SOLAR_TOOLS/lib.sh

CLI_NAME=$1
SH_NAME=$2
check_arg ENV_CMD

log "exec script CLI_NAME => $CLI_NAME SH_NAME=> $SH_NAME ENV_CMD => $ENV_CMD"

SH_DIR=$SDIR/scripts
DATA=$SDIR/data
CLI_HOME=$DATA/$CLI_NAME

function main {
	
	local COMMAND_PATH=cli_exec_sh_$SH_NAME
	local COMMAND_FILE=$CLI_HOME/$COMMAND_PATH

	echo "$ENV_CMD" > $COMMAND_FILE
	cat $SH_DIR/$SH_NAME >> $COMMAND_FILE
	
	chmod u+x $COMMAND_FILE

	docker exec -i $CLI_NAME bash ./$COMMAND_PATH
}
main
