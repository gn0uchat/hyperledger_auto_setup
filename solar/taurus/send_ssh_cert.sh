#!/bin/bash
GIT_REPO_ADDR=""
GIT_BRANCH="solar_taurus"
GIT_USER="git_user"
GIT_SECRET_FILE="git_secret"

ADDRS=""
#USER="admin"

function remote_init_user {
	REMOTE_ADDR=$1
	USER="hkpc_ct"


	#cat $HOME/.ssh/id_rsa.pub | ssh $USER@$REMOTE_ADDR 'mkdir -p .ssh && cat >> .ssh/authorized_keys'
}

function init_user {
	USER="hkpc_ct"

	for ADDR in $ADDRS; do
		#echo "cat $HOME/.ssh/id_rsa.pub | ssh $USER@$ADDR 'cat >> .ssh/authorized_keys'"
	done
}
