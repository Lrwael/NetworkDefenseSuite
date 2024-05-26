#!/bin/bash

UPDATE="false"
CHECK_HOSTS_LIST="false"

LOCAL_HOME_FOLDER="/home/honeypot"
ANSIBLE_FOLDER="$LOCAL_HOME_FOLDER/ansible"
STARTUP_LOG_FILE="$ANSIBLE_FOLDER/start-up.log"
CONFIGURE_ANSIBLE_SCRIPT="$ANSIBLE_FOLDER/scripts/configure-ansible.sh"

ETC_HOSTS="/etc/hosts"
ANSIBLE_USERNAME="honeypot"

CREDENTIALS_FOLDER="$ANSIBLE_FOLDER/credentials"
CREDENTIALS_YML_FILE="$CREDENTIALS_FOLDER/credentials.yml"
VAULT_GPG_PASSWORD="$CREDENTIALS_FOLDER/vault-password.gpg"
INVENTORY="$ANSIBLE_FOLDER/inventory"

declare -A HOSTS_LIST=(
    ["node-1"]="10.10.0.129:prod"
    ["node-2"]="10.10.0.131:prod"
    ["ntp-server"]="192.168.224.129:server"
    ["rsyslog-server"]="192.168.224.130:server"
    ["wazuh-siem"]="192.168.224.131:server"
)

#Colors
NOCOLOR='\033[0m'
RED='\033[0;31m'
ORANGE='\033[93m'
GREEN='\033[0;32m'

LOG_TO_FILE()
{
    echo "[$(date '+%d/%m/%Y %H:%M:%S.%3N')]: $1" >> $STARTUP_LOG_FILE
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

HONEYPOT_ICON()
{ 
    local YELLOW="\033[0;33m"
    local ORANGE="\033[38;5;208m"
    local BROWN="\033[38;5;94m"
    local RESET="\033[0m"

    sleep 0.1 && echo -e "                  ${ORANGE} __ __  ___  ____    ___ __ __ ____   ___  ______ ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|  |  |/   \|    \  /  _|  |  |    \ /   \|      |${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|  |  |     |  _  |/  [_|  |  |  o  |     |      |${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|  _  |  O  |  |  |    _|  ~  |   _/|  O  |_|  |_|${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|  |  |     |  |  |   [_|___, |  |  |     | |  |  ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|  |  |     |  |  |     |     |  |  |     | |  |  ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|__|__|\___/|__|__|_____|____/|__|__ \___/_ |__|  ${RESET}";
    echo ""
    sleep 0.1 && echo -e "                  ${YELLOW} ___ ___  ____ ___     ___      ____  __ __      ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|   |   |/    |   \   /  _]    |    \|  |  |     ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}| _   _ |  o  |    \ /  [_     |  o  |  |  |     ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|  \_/  |     |  D  |    _]    |     |  ~  |     ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|   |   |  _  |     |   [_     |  O  |___, |     ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|   |   |  |  |     |     |    |     |     |     ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|___|___|__|__|_____|_____|    |_____|____/      ${RESET}";
    echo ""
    sleep 0.1 && echo -e "                  ${BROWN} __    __  ____   ___ _"
    sleep 0.1 && echo -e "                  ${BROWN}|  |__|  |/    | /  _| |                          ${RESET}";
    sleep 0.1 && echo -e "                  ${BROWN}|  |  |  |  o  |/  [_| |                          ${RESET}";
    sleep 0.1 && echo -e "                  ${BROWN}|  |  |  |     |    _| |___                       ${RESET}";
    sleep 0.1 && echo -e "                  ${BROWN}|  \`  '  |  _  |   [_|     |                     ${RESET}";
    sleep 0.1 && echo -e "                  ${BROWN} \      /|  |  |     |     |                      ${RESET}";
    sleep 0.1 && echo -e "                  ${BROWN} _\_/\_/_|__|__|_____|_____|__                    ${RESET}";
    echo ""
    sleep 0.1 && echo -e "                  ${ORANGE} ____   ____  ___  __ __ _____                    ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|    \ /    |/   \|  |  |     |                   ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|  D  |  o  |     |  |  |   __|                   ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|    /|     |  O  |  |  |  |_                     ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|    \|  _  |     |  :  |   _]                    ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|  .  |  |  |     |     |  |                      ${RESET}";
    sleep 0.1 && echo -e "                  ${ORANGE}|__|\_|__|__|\___/_\__,_|__|                      ${RESET}";
    echo ""
    sleep 0.1 && echo -e "                  ${YELLOW}  ____ __ __ ___ ___   ___ ___                    ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW} /    |  |  |   |   | /  _|    \                  ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|  o  |  |  | _   _ |/  [_|  _  |                 ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|     |  ~  |  \_/  |    _|  |  |                 ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|  _  |___, |   |   |   [_|  |  |                 ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|  |  |     |   |   |     |  |  |                 ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}|__|__|____/|___|___|_____|__|__|                 ${RESET}";
    sleep 0.1 && echo -e "                  ${YELLOW}                                                  ${RESET}";

}

OPTIONS=$(getopt -o -u --longoptions help update-env check-hosts-list -- "$@" 2>&1 /dev/null)
RET_CODE=$?

if [ $RET_CODE -ne 0 ]; then
    LOG_ERROR "Unexpected option, quit"
    exit 1
fi

NB_ARGUMENTS=$#

if [ $NB_ARGUMENTS -eq 0 ]; then
    LOG_ERROR "You must provide at least one argument, use --hlep for assistance"
    exit 1
fi

while [ $# -gt 0 ]
do
    case $1 in
        --help)
            HONEYPOT_ICON
            echo "------------------------------------------------------------------------------------"
            echo "HELP:"
            echo "  --update-env            - This option check hosts lists and update the environment"
            echo "  --check-hosts-list      - List inventory information"
            echo "------------------------------------------------------------------------------------"
            exit 1
            ;;
        --update-env)
            UPDATE="true" ;;
        --check-hosts-list )
            CHECK_HOSTS_LIST="true" ;;
        --add-new-host)
            ADD_HOST="true" ;;
        *)
            ;;
    esac
    shift
done

HONEYPOT_ICON

if [ "$CHECK_HOSTS_LIST" == "true" ]; then
    echo "--------------------------------------------------"
    for HOST in "${!HOSTS_LIST[@]}"; do 
        HOSTNAME="$HOST"
        IP_ADDRESS="$(echo ${HOSTS_LIST[$HOST]} | cut -d ':' -f 1)"
        DEPARTEMENT="$(echo ${HOSTS_LIST[$HOST]} | cut -d ':' -f 2)"

        if [ -z "$DEPARTEMENT" ]; then
            DEPARTEMENT="N/A"
        fi

        echo "HOST: $HOSTNAME"
        echo "IP-ADDRESS: $IP_ADDRESS"
        echo "DEPARTEMENT: $DEPARTEMENT"
        echo "--------------------------------------------------"
    done
fi

if [ "$UPDATE" == "true" ]; then
    if [ ! -f "$CONFIGURE_ANSIBLE_SCRIPT" ]; then
        LOG_ERROR "Failed to locate $CONFIGURE_ANSIBLE_SCRIPT"
        exit 1
    fi
    echo "----------------------------------------------------------------------------------------------------"
    for HOST in "${!HOSTS_LIST[@]}"; do 
        HOSTNAME="$HOST"
        IP_ADDRESS="$(echo ${HOSTS_LIST[$HOST]} | cut -d ':' -f 1)"
        DEPARTEMENT="$(echo ${HOSTS_LIST[$HOST]} | cut -d ':' -f 2)"

        bash $CONFIGURE_ANSIBLE_SCRIPT --add-new-host --hostname $HOSTNAME --ip-address $IP_ADDRESS --type $DEPARTEMENT
        echo "----------------------------------------------------------------------------------------------------"
    done

    LOG_INFO "Updating /etc/hosts for all hosts"
    
    UPDATE_ETC_HOSTS="$(ansible-playbook -i $INVENTORY $ANSIBLE_FOLDER/generate_hosts.yml)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        LOG_ERROR "Failed to update /etc/hosts for all hosts"
        exit 1
    else
        LOG_SUCCESS "Successfully updared /etc/hosts for all hosts"
    fi
fi