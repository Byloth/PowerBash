#!/usr/bin/env bash
#

function sshTunnel()
{
    if [ $# -lt 3 ]
    then
        echo "Usage: $0 <local port> [<username>@]<remote host> <remote port>"
    else
        echo -e "\nTunnelling \"localhost:${1}\" to \"${2}:${3}\"..."

        ssh -NL ${1}:localhost:${3} ${2}
    fi
}

# Useful functions (if you are in Bash under WSL)
#
function getWindowsFriendlyRealPath()
{
    local TARGET="${1}"

    if [ -z "${TARGET}" ]
        TARGET="."
    fi

    local REALPATH="$(realpath ${TARGET})"
    REALPATH="${REALPATH#/mnt}"

    echo ${REALPATH}
}
