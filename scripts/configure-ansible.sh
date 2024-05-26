#!/bin/bash

ADMIN_PUB_KEY="651699715E95047E50A936372D37DEBE3DAAD361"

PULIC_KEYS_FOLDER="/home/honeypot/.ssh/"
PUBLIC_KEY="$PULIC_KEYS_FOLDER/id_rsa"

ETC_HOSTS="/etc/hosts"
ADD_NEW_POST="false"
ANSIBLE_USERNAME="honeypot"

LOCAL_HOME_FOLDER="/home/honeypot"
ANSIBLE_FOLDER="$LOCAL_HOME_FOLDER/ansible"
CREDENTIALS_FOLDER="$ANSIBLE_FOLDER/credentials"
CREDENTIALS_YML_FILE="$CREDENTIALS_FOLDER/credentials.yml"
VAULT_GPG_PASSWORD="$CREDENTIALS_FOLDER/vault-password.gpg"
INVENTORY="$ANSIBLE_FOLDER/inventory"
VAULT_PASSWORD_FILE="/tmp/vault-password"

CONFIGURE_ANSIBLE_LOG_FOLDER="$ANSIBLE_FOLDER/logs"
CONFIGURE_ANSIBLE_LOG_FILE="$CONFIGURE_ANSIBLE_LOG_FOLDER/configure-ansible.logs"

GROUP=""
HOST_TYPE=""
KNOWN_HOSTS_FILE="$LOCAL_HOME_FOLDER/.ssh/known_hosts"

RSYSLOG_SERVER="rsyslog-server"
RSYSLOG_SERVICE="rsyslog"
RSYSLOG_CONFIGURATION_FILE="/etc/rsyslog.conf"

NTP_SERVER="ntp-server"
NTP_SERVICE="chrony"
NTP_CONFIGURATION_FILE="/etc/chrony.conf"

LISTENING_PORT="514"
PROTOCOLS_LIST=( "tcp" "udp" )

#Colors
NOCOLOR='\033[0m'
RED='\033[0;31m'
ORANGE='\033[93m'
GREEN='\033[0;32m'

LOG_TO_FILE()
{
    echo "[$(date '+%d/%m/%Y %H:%M:%S.%3N')]: $1" >> $CONFIGURE_ANSIBLE_LOG_FILE
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

    REMOVE_VAULT_PASSWORD
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

REMOVE_VAULT_PASSWORD()
{
    LOG_INFO "Removing $VAULT_PASSWORD_FILE"
    
    if [ -f $VAULT_PASSWORD_FILE ]; then
        REMOVE_FILE="$(rm -f $VAULT_PASSWORD_FILE)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to remove $VAULT_PASSWORD_FILE"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully removed $VAULT_PASSWORD_FILE"
        fi
    else
        LOG_WARNING "Nothing to do, $VAULT_PASSWORD_FILE already removed"
    fi

    exit $RET_CODE
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
            echo "* --add-new-host          - Add remote host to be managed by $(hostname)"
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

CHECK_IP() {
    IP_ADDRESS=$1
    PATTERN='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'

    LOG_INFO "Check if target host:($REMOTE_HOSTNAME) is reachable"

    if [[ $IP_ADDRESS =~ $PATTERN ]]; then
        PING_REMOTE_HOST="$(ping -c 1 $IP_ADDRESS 2>&1)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Target host:($REMOTE_HOSTNAME) is not reachable"
            exit 1
        else
            LOG_SUCCESS "Localhost:($(hostname)) can reach the target host:($REMOTE_HOSTNAME)"
        fi
    else
        LOG_ERROR "$IP_ADDRESS is not a valid IP address."
        exit 1
    fi
}

if [ $ADD_NEW_POST == "false" ]; then
    LOG_ERROR "--add-new-host is mandatory"
    exit 1
fi

if [ "$ADD_NEW_POST" == "true" ]; then
    if [ $NB_ARGUMENTS -lt 3 ]; then
        LOG_ERROR "You must provide both remote host ip address and hostname, use --ip-address:<ip_address> and --hostname:<hostname> or --help) for assistance"
        exit 1
    fi

    if [ "$REMOTE_HOST_IP_ADDRESS" == "" ]; then
        LOG_ERROR "You must provide remote host ip address, use --ip-address:<ip_address> or --help) for assistance"
        exit 1
    fi

    if [ "$REMOTE_HOSTNAME" == "" ]; then
        LOG_ERROR "You must provide remote host hostname, use --hostname:<hostname> or --help) for assistance"
        exit 1
    fi

    CHECK_IP "$REMOTE_HOST_IP_ADDRESS"

    LOG_INFO "Adding target host ($REMOTE_HOSTNAME) with ip address:$REMOTE_HOST_IP_ADDRESS to $ETC_HOSTS"

    CHECK_HOST="$(grep -qE "$REMOTE_HOSTNAME|$REMOTE_HOST_IP_ADDRESS" $ETC_HOSTS)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        ADD_TO_ETC_HOSTS="$(echo "$REMOTE_HOST_IP_ADDRESS   $REMOTE_HOSTNAME    ${REMOTE_HOSTNAME}.honeypot.tn" | sudo tee -a $ETC_HOSTS 2>&1)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to add target host ($REMOTE_HOSTNAME) with ip address:$REMOTE_HOST_IP_ADDRESS to $ETC_HOSTS - return code: $RET_CODE"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully added target host ($REMOTE_HOSTNAME) with ip address:$REMOTE_HOST_IP_ADDRESS to $ETC_HOSTS"
        fi
    else
        LOG_WARNING "Nothing to do, target host ($REMOTE_HOSTNAME) with ip address:$REMOTE_HOST_IP_ADDRESS already exists in $ETC_HOSTS"
    fi

    LOG_INFO "Adding target host ($REMOTE_HOSTNAME) to the inventory"

    CHECK_PRESENCE="$(grep -q "$REMOTE_HOSTNAME" $INVENTORY)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        if [ -z "$REMOTE_HOSTNAME" ]; then
            LOG_ERROR "Remote hostname is mandatory"
            exit 1
        fi

        if [ ! -f $INVENTORY ]; then
            LOG_ERROR "Ansible inventory file not found: $INVENTORY"
            exit 1
        fi

        case $HOST_TYPE in
            "server")
                GROUP="/\[servers\]/a"
                ;;
            "prod")
                GROUP="/\[prod\]/a"
                ;;
            "dev")
                GROUP="/\[dev\]/a"
                ;;
            *)
                GROUP="1i"
                ;;
        esac

        ADDING_HOST_TO_INVENTORY="$(sed -i "$GROUP $REMOTE_HOSTNAME" $INVENTORY)"
        RET_CODE=$?

        if [ $RET_CODE -eq 0 ]; then
            if [ -z "$HOST_TYPE" ]; then
                LOG_SUCCESS "Succefully added $REMOTE_HOSTNAME to Ansible inventory without group"
            else      
                LOG_SUCCESS "Succefully added $REMOTE_HOSTNAME to Ansible inventory as $HOST_TYPE"
            fi
        else
            LOG_ERROR "Failed to add $REMOTE_HOSTNAME to Ansible inventory"
        fi
    else
        LOG_WARNING "Nothing to do, target host $REMOTE_HOSTNAME already in the inventory"
    fi

    LOG_INFO "Adding SSH key fingerprint to $KNOWN_HOSTS_FILE"

    SSH_FINGERPRINT=$(ssh-keygen -F $REMOTE_HOSTNAME 2> /dev/null)

    if [ -n "$SSH_FINGERPRINT" ]; then
        LOG_WARNING "Nothing to do, The SSH key fingerprint of the remote host $REMOTE_HOSTNAME is already in known_hosts."
    else
        SSH_KEY=$(ssh-keyscan -H $REMOTE_HOSTNAME 2> /dev/null)
        
        if [ -z "$SSH_KEY" ]; then
            LOG_ERROR "Failed to retrieve SSH public key for the remote host $REMOTE_HOSTNAME"
            exit 1
        fi

        ADD_KEY="$(echo "$SSH_KEY" | tee -a $KNOWN_HOSTS_FILE 2>&1)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to add SSH public key to rmote host $REMOTE_HOSTNAME"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully added the SSH public key of the remote host $REMOTE_HOSTNAME to known_hosts"
        fi
    fi

    LOG_INFO "Generating local $ANSIBLE_USERNAME user public key"

    if [ ! -f "$PUBLIC_KEY" ]; then
        GENERATE_KEY="$(ssh-keygen -t rsa -N "" -f $PUBLIC_KEY > /dev/null)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to generate local $ANSIBLE_USERNAME user public key"
            exit $RET_CODE
        else
            LOG_SUCCESS "Succefully generated local $ANSIBLE_USERNAME user public key"
        fi
    else
        LOG_WARNING "Nothing to do, local $ANSIBLE_USERNAME user public key already generated"
    fi

    LOG_INFO "Decrypting $VAULT_GPG_PASSWORD"

    CHECK_KEY="$(gpg --list-keys "$ADMIN_PUB_KEY" 2> /dev/null > /dev/null)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        LOG_ERROR "Decrypting key is missing from your host:$(hostname)"
        exit $RET_CODE
    fi
    
    DECRYPT_FILE="$(gpg --decrypt -o /tmp/vault-password $VAULT_GPG_PASSWORD 2> /dev/null > /dev/null)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        LOG_ERROR "Failed to decrypt $VAULT_GPG_PASSWORD"
        exit $RET_CODE
    else
        LOG_SUCCESS "Successfully decrypted $VAULT_GPG_PASSWORD"
    fi
   
    LOG_INFO "Creating remote $ANSIBLE_USERNAME user for target host: $REMOTE_HOSTNAME"
    
    CREATE_USER="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m user -a "name='$ANSIBLE_USERNAME' shell='/bin/bash' uid='1050' password={{  ANSIBLE_USER_PASSWORD  | password_hash('sha512') }}" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE 2> /dev/null)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        LOG_ERROR "Failed to create remote $ANSIBLE_USERNAME user for target host: $REMOTE_HOSTNAME - return code : $RET_CODE"
        exit $RET_CODE
    else
        LOG_SUCCESS "Successfully creating remote $ANSIBLE_USERNAME user for target host: $REMOTE_HOSTNAME"
    fi
    
    LOG_INFO "Adding remote $ANSIBLE_USERNAME user to sudoers"

    ADD_TO_SUDOERS="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m copy -a "content='$ANSIBLE_USERNAME ALL=(ALL) NOPASSWD:ALL' dest=/etc/sudoers.d/$ANSIBLE_USERNAME" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE > /dev/null)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        LOG_ERROR "Failed to add remote $ANSIBLE_USERNAME to sudoers"
        exit $RET_CODE
    else
        LOG_SUCCESS "Successfully adding remote $ANSIBLE_USERNAME to sudoers"
    fi

    LOG_INFO "Copying local $ANSIBLE_USERNAME user public key to the remote $ANSIBLE_USERNAME user"
    
    COPY_KEY="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m authorized_key -a "user=honeypot state=present key={{ lookup('file', '/home/honeypot/.ssh/id_rsa.pub') }}" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE > /dev/null)"
    RET_CODE=$?

    if [ $RET_CODE -ne 0 ]; then
        LOG_ERROR "Failed to copy local $ANSIBLE_USERNAME user public key to the remote $ANSIBLE_USERNAME user"
        exit $RET_CODE
    else
        LOG_SUCCESS "Successfully copied local $ANSIBLE_USERNAME user public key to the remote $ANSIBLE_USERNAME user"
    fi

    if [ "$REMOTE_HOSTNAME" != "rsyslog-server" ]; then
        LOG_INFO "Download ${RSYSLOG_SERVICE}.service for target host: $REMOTE_HOSTNAME"

        CHECK_PACKAGE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -a "rpm -qi $RSYSLOG_SERVICE" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE > /dev/null)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            DOWNLOAD_SERVICE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m dnf -a "name='$RSYSLOG_SERVICE' state='latest'" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE > /dev/null)"
            RET_CODE=$?

            if [ $RET_CODE -ne 0 ]; then
                LOG_ERROR "Failed to ${RSYSLOG_SERVICE}.service for target host: $REMOTE_HOSTNAME"
                exit $RET_CODE
            else
                LOG_SUCCESS "Succefully downloaded ${RSYSLOG_SERVICE}.service for target host: $REMOTE_HOSTNAME"
            fi

            for PROTOCOL in ${PROTOCOLS_LIST[@]}; do
                LOG_INFO "Allowing $REMOTE_HOSTNAME to send/receive $PROTOCOL data on port $LISTENING_PORT"

                ALLOW_FIREWALL="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m firewalld -a "port='$LISTENING_PORT/$PROTOCOL' permanent='true' immediate='true' state='enabled'" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
                RET_CODE=$?

                if [ $RET_CODE -ne 0 ]; then
                    LOG_ERROR "Failed to allow $REMOTE_HOSTNAME to send/receive $PROTOCOL data on port $PLISTENING_PORTORT"
                    exit $RET_CODE
                else
                    LOG_SUCCESS "Successfully allowed $REMOTE_HOSTNAME to send/receive $PROTOCOL data on port $POLISTENING_PORTRT"
                fi 
            done
        else
            LOG_WARNING "Nothing to do, ${RSYSLOG_SERVICE}.service already installed in target host: $REMOTE_HOSTNAME"
        fi

        LOG_INFO "Setting $REMOTE_HOSTNAME as an Rsyslog client for $RSYSLOG_SERVER"

        CONFIGURE_RSYSLOG_CLIENT="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m lineinfile -a "path='$RSYSLOG_CONFIGURATION_FILE' line='*.* @$RSYSLOG_SERVER:514' insertafter='EOF'" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to set $REMOTE_HOSTNAME as an Rsyslog client for $RSYSLOG_SERVER"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully setting $REMOTE_HOSTNAME as an Rsyslog client for $RSYSLOG_SERVER"
        fi

        LOG_INFO "Restarting ${RSYSLOG_SERVICE}.service for target host: $REMOTE_HOSTNAME"

        RESTART_SERVICE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -a "systemctl restart ${RSYSLOG_SERVICE}.service" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to restart ${RSYSLOG_SERVICE}.service for target host: $REMOTE_HOSTNAME"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully restarting ${RSYSLOG_SERVICE}.service for target host: $REMOTE_HOSTNAME"
        fi

        LOG_INFO "Restarting ${RSYSLOG_SERVICE}.service for rsyslog-server"

        RESTART_SERVICE="$(ansible -i $INVENTORY rsyslog-server -a "systemctl restart ${RSYSLOG_SERVICE}.service" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to restart ${RSYSLOG_SERVICE}.service for rsyslog-server"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully restarting ${RSYSLOG_SERVICE}.service for rsyslog-server"
        fi
    fi

    if [ "$REMOTE_HOSTNAME" != "ntp-server" ]; then
        LOG_INFO "Downloading ${NTP_SERVICE}d.service for target host: $REMOTE_HOSTNAME"
        
        CHECK_PACKAGE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -a "rpm -qi $NTP_SERVICE" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE > /dev/null)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            DOWNLOAD_NTP_SERVICE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m dnf -a "name='$NTP_SERVICE' state='latest'" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
            RET_CODE=$?

            if [ $RET_CODE -ne 0 ]; then
                LOG_ERROR "Failed to download ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME"
                exit $RET_CODE
            else
                LOG_SUCCESS "Successfully downloaded ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME"
            fi
        else
            LOG_WARNING "Nothing to do, ${NTP_SERVICE}.service already downloaded for target host: $REMOTE_HOSTNAME"
        fi

        LOG_INFO "Start ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME at boot"

        START_NTP_SERVICE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m service -a "name='${NTP_SERVICE}d' state='started' enabled='yes'" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to start ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME at boot"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully started ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME at boot"
        fi

        LOG_INFO "Setting $REMOTE_HOSTNAME as an NTP client for $NTP_SERVER"
        
        UPDATE_CONFIG_FILE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -m lineinfile -a "path='$NTP_CONFIGURATION_FILE' regexp='^pool' line='server ntp-server iburst'" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to set $REMOTE_HOSTNAME as an NTP client for $NTP_SERVER"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully set $REMOTE_HOSTNAME as an NTP client for $NTP_SERVER"
        fi

        LOG_INFO "Restarting ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME"

        RESTART_SERVICE="$(ansible -i $INVENTORY $REMOTE_HOSTNAME -a "systemctl restart ${NTP_SERVICE}d" -u root --extra-vars "@${CREDENTIALS_YML_FILE}" --extra-vars "ansible_ssh_pass={{ ROOT_PASSWORD }}" --vault-password-file $VAULT_PASSWORD_FILE)"
        RET_CODE=$?

        if [ $RET_CODE -ne 0 ]; then
            LOG_ERROR "Failed to restart ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME - return code: $RET_CODE"
            exit $RET_CODE
        else
            LOG_SUCCESS "Successfully restarted ${NTP_SERVICE}.service for target host: $REMOTE_HOSTNAME"
        fi
    fi
fi

REMOVE_VAULT_PASSWORD
