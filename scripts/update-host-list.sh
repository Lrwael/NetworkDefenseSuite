#!/bin/bash

LOCAL_HOME_FOLDER="/home/honeypot"
ANSIBLE_FOLDER="$LOCAL_HOME_FOLDER/ansible"
STARTUP_LOG_FILE="$ANSIBLE_FOLDER/start-up.log"
STRATUP_SCRIPT="$ANSIBLE_FOLDER/scripts/startup.sh"

HOSTNAME="$1"
IPADDRESS="$2"
TYPE="$3"

if [ -z "$HOSTNAME" ] || [ -z "$IPADDRESS" ] || [ -z "$TYPE" ] ; then
    echo "ERROR: You Must provide both hostname(1st arg) and ip address(2nd arg)"
fi

if [ ! -f $STRATUP_SCRIPT ]; then
    echo "Failed to locate $STRATUP_SCRIPT"
    exit 1
fi

LINE="$(grep -n "declare" "$STRATUP_SCRIPT" | cut -d ':' -f 1)"
NEW_HOST="[\"$HOSTNAME\"]=\"$IPADDRESS:$TYPE\""

CHECK_LINE_EXISTANCE="$(grep -q "$(echo "$NEW_HOST" | cut -d '=' -f 2)" $STRATUP_SCRIPT)"
RET_CODE=$?

if [ $RET_CODE -eq 0 ]; then
    echo "Host already exist in $STRATUP_SCRIPT"
    exit 0
fi

UPDATE_LINE="$(sed -i "${LINE}a\\   ${NEW_HOST}" $STRATUP_SCRIPT)"
RET_CODE=$?

exit $RET_CODE