#!/usr/bin/env bash
#

function _cryptPassword()
{
    local PYTHON_SCRIPT="
from passlib.context import CryptContext
passwd = CryptContext(schemes=['pbkdf2_sha512'])
print(passwd.encrypt('${1}'))
"
    echo "$(python -c "${PYTHON_SCRIPT}")"
}
function _executePSqlQuery()
{
    local QUERY="${1}"

    echo -e "\n${QUERY}"
    echo -e " └ \c"
    echo "${QUERY}" | psql ${@:2} -f -
}
function _odooReset()
{
    local PYTHON_SCRIPT="
import uuid
print(uuid.uuid4())
"
    local DATABASE_UUID="$(python -c "${PYTHON_SCRIPT}")"
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '${DATABASE_UUID}' WHERE key = 'database.uuid';" ${@}

    local DATABASE_SECRET="$(python -c "${PYTHON_SCRIPT}")"
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '${DATABASE_SECRET}' WHERE key = 'database.secret';" ${@}

    local MOBILE_UUID="$(python -c "${PYTHON_SCRIPT}")"
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '${MOBILE_UUID}' WHERE key = 'mobile.uuid';" ${@}

    _executePSqlQuery "UPDATE ir_config_parameter SET value = '2021-12-31 23:59:59' WHERE key = 'database.expiration_date';" ${@}
    _executePSqlQuery "UPDATE ir_config_parameter SET value = 'renewal' WHERE key = 'database.expiration_reason';" ${@}
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '' WHERE key = 'database.enterprise_code';" ${@}

    _executePSqlQuery "UPDATE ir_config_parameter SET value = '' WHERE key = 'website_slides.google_app_key';" ${@}
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '' WHERE key = 'google_calendar_client_id';" ${@}
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '' WHERE key = 'google_calendar_client_secret';" ${@}
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '' WHERE key = 'google_drive_client_id';" ${@}
    _executePSqlQuery "UPDATE ir_config_parameter SET value = '' WHERE key = 'google_drive_client_secret';" ${@}

    _executePSqlQuery "DELETE FROM fetchmail_server;" ${@}
    _executePSqlQuery "DELETE FROM ir_cron;" ${@}
    _executePSqlQuery "DELETE FROM ir_mail_server;" ${@}
}
function _randomPhrase()
{
    #
    # Print a random phrase when the terminal is
    #  opened and all scripts have been loaded
    #
    # Some other "cows" here: /usr/share/cowsay/cows
    #  -f <cow_name>
    #  -W <max_columns>
    #  -b / -d / -g / -p / -s / -t / -w / -y
    #
    local COW_PARAMS="-bdgpstwy"

    fortune -as | cowthink -n -${COW_PARAMS:$(shuf -i0-8 -n1):1}
}

function base64encode()
{
    echo -n "${1}" | base64
}
function base64decode()
{
    echo -n "${1}" | base64 --decode
}

function clean()
{
    clear

    _randomPhrase
}

function getIpAddresses()
{
    ifconfig | grep "inet " | awk '{ print $2 }'
}

function kubeDashboard()
{
    local ADMIN_NAMESPACE="kube-system"
    local ADMIN_NAME="admin-user"
    local DASHBOARD_NAMESPACE="kubernetes-dashboard"
    local DASHBOARD_SERVICE="kubernetes-dashboard"

    local SECRET_NAME="$(kubectl -n "${ADMIN_NAMESPACE}" get secret | grep "^${ADMIN_NAME}-token-" | awk '{print $1}')"
    local SECRET_TOKEN="$(kubectl -n "${ADMIN_NAMESPACE}" describe secret "${SECRET_NAME}" | grep "^token: " | awk '{print $2}')"

    echo -e "\nKubernetes dashboard is starting..."
    echo " │"
    echo -e " ├ URL: \e[4;36mhttp://localhost:8001/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:${DASHBOARD_SERVICE}:/proxy/\e[0m"
    echo " │"
    echo -e " └ Token: ${SECRET_TOKEN}\n"

    kubectl proxy
}

function odooChangePassword()
{
    echo ""
    read -s -p "New password: " NEW_PASSWD
    echo ""

    _executePSqlQuery "UPDATE res_users SET password_crypt = '$(_cryptPassword "${NEW_PASSWD}")' WHERE id = 1;" ${@}
}
function odoo12ChangePassword()
{
    echo ""
    read -s -p "New password: " NEW_PASSWD
    echo ""

    _executePSqlQuery "UPDATE res_users SET password = '$(_cryptPassword "${NEW_PASSWD}")' WHERE id = 2;" ${@}
}
function odooMakeDev()
{
    _odooReset ${@}

    odooChangePassword ${@}
}
function odoo12MakeDev()
{
    _odooReset ${@}

    odoo12ChangePassword ${@}
}
function odooRemoveAssets()
{
    _executePSqlQuery "DELETE FROM ir_attachment WHERE datas_fname SIMILAR TO '%.(css|js|less)';" ${@}
}

function removeDockerImages()
{
    local IMAGE=${1}
    local SKIP=${2}

    if [[ -z "${IMAGE}" ]]
    then
        echo "Usage: removeDockerImages <repository name> [<# of image to skip> | 1]"
    else
        if [[ -z "${SKIP}" ]]
        then
            SKIP=1
        fi

        docker images | awk -v IMAGE="${IMAGE}" '{ if (NR > 1 && $1 == IMAGE) print }' | awk -v SKIP=${SKIP} '{ if (NR > SKIP) print $3 }' | xargs docker image rm
    fi
}

function resetPermissions()
{
    local TARGET="${1}"

    if [[ -z "${TARGET}" ]]
    then
        TARGET="."
    fi

    local REALPATH="$(realpath "${TARGET}")"

    echo -e "\n \e[4;33mWARNING!\e[0m"
    echo -e "  \e[33m└\e[0m You are about to reset permissions on all files,"
    echo -e "     directories and subdirectories contained in: \"\e[36m${REALPATH}\e[0m\"\n"
    read -p "Are you sure to continue? [N]: " ANSWER

    if [[ "${ANSWER}" == "y" ]] || [[ "${ANSWER}" == "Y" ]]
    then
        echo -e " └ Please, wait... Resetting permissions... \c"

        find "${REALPATH}" -type d -exec chmod 755 {} \;
        find "${REALPATH}" -type f -exec chmod 644 {} \;

        echo -e "\e[32mOK!\e[0m"
    else
        echo -e " └ Ok, no problem! Permissions have been left untouched."
    fi
}

function sshTunnel()
{
    if [[ ${#} -lt 3 ]]
    then
        echo "Usage: sshTunnel <local port> [<ssh username>@]<ssh host>[:<ssh port> | 22] <remote port>"
    else
        local PARTS=($(echo ${2} | tr ':' ' '))
        local SSH_HOST="${PARTS[0]}"
        local SSH_PORT="${PARTS[1]}"

        if [[ -z "${SSH_PORT}" ]]
        then
            SSH_PORT=22
        fi

        echo -e "\nTunnelling \"localhost:${1}\" to \"${SSH_HOST}:${3}\"..."

        ssh -NL ${1}:localhost:${3} ${SSH_HOST} -p ${SSH_PORT}
    fi
}

function tarCompress()
{
    if [[ ${#} -lt 2 ]]
    then
        echo "Usage: tarCompress <archive name> <file or directory to compress>"
    else
        tar -czvf "${1}" "${2}"
    fi
}
function tarExtract()
{
    if [[ ${#} -lt 1 ]]
    then
        echo "Usage: tarExtract <archive name> [<directory where extract archive> | .]"
    else
        local EXTRACT_PATH="${2}"

        if [[ -z "${EXTRACT_PATH}" ]]
        then
            EXTRACT_PATH="."
        fi

        tar -xzvf "${1}" -C "${EXTRACT_PATH}"
    fi
}

#
# Useful functions (if you are in Bash under WSL)
#
function getWindowsFriendlyRealPath()
{
    local TARGET="${1}"

    if [[ -z "${TARGET}" ]]
    then
        TARGET="."
    fi

    local REALPATH="$(realpath "${TARGET}")"
    REALPATH="${REALPATH#/mnt}"

    echo "${REALPATH}"
}
