#!/bin/bash

LOCAL_HOME_FOLDER="/home/honeypot"
ANSIBLE_FODER="$LOCAL_HOME_FOLDER/ansible"
INVENTORY="$ANSIBLE_FODER/inventory"

LOGS_FOLDER="$ANSIBLE_FODER/logs"
LOG_FILE="$LOGS_FOLDER/$(basename $0).log"

#Colors
NOCOLOR='\033[0m'
RED='\033[0;31m'
ORANGE='\033[93m'
GREEN='\033[0;32m'

LOG_TO_FILE()
{
    echo "[$(date '+%d/%m/%Y %H:%M:%S.%3N')]: $1" >> $LOG_FILE
}

LOG_INFO()
{
    logger -p info "$1"
    LOG_TO_FILE "$1"
    echo -e "${NOCOLOR}[$(date '+%d/%m/%Y %H:%M:%S.%3N')][INFO]: $1"
    sleep 1
}

LOG_ERROR()
{
    logger -p info "$1"
    LOG_TO_FILE "$1"
    echo -e "${RED}[$(date '+%d/%m/%Y %H:%M:%S.%3N')][ERROR]: $1 ${NOCOLOR}"
}

LOG_WARNING()
{
    logger -p info "$1"
    LOG_TO_FILE "$1"
    echo -e "${ORANGE}[$(date '+%d/%m/%Y %H:%M:%S.%3N')][WARNING]: $1 ${NOCOLOR}"
}

LOG_SUCCESS()
{
    logger -p info "$1"
    LOG_TO_FILE "$1"
    echo -e "${GREEN}[$(date '+%d/%m/%Y %H:%M:%S.%3N')][SUCCESS]: $1 ${NOCOLOR}"
}

OPTIONS=$(getopt -o -u --longoptions help add-new-host,ip-address,hostname,type: -- "$@" 2>&1 /dev/null)
RET_CODE=$?

if [ $RET_CODE -ne 0 ]; then
    LOG_ERROR "Unexpected option, quit"
    exit 1
fi

NB_ARGUMENTS=$#

while [ $# -gt 0 ]
do
    case $1 in
        --help)
            echo "* --send-logs-to         - Add remote host to be managed by $(hostname)"
            echo "  --ip-address            - Remote host ip address"
            echo "  --hostname              - Remote host hostname"
            echo "  --type                  - Specify the host type (server/dev...)"
            exit 1
            ;;
        --add-new-host)
            ADD_NEW_POST="true"
            ;;
        --ip-address)
            REMOTE_HOST_IP_ADDRESS="$2"
            ;;
        --hostname)
            REMOTE_HOSTNAME="$2"
            ;; 
        --type)
            HOST_TYPE="$2"
            ;;
        *)
            ;;
    esac
    shift
done
