#!/bin/bash
set -eo pipefail


function ensure_root() {
    if [[ ${UID} != 0 ]]; then
        echo 'Must be run with sudo!'
        exit 1
    fi
}

function load_nbd_module() {
    modprobe nbd
}

function connect_device() {
    echo "Connecting ${image} to /dev/${nbd}"
    qemu-nbd -c /dev/${nbd} --read-only "${image}"
}

function disconnect_device() {
    echo "Disconnecting /dev/${nbd}"
    qemu-nbd -d "/dev/${nbd}"
}

function main() {
    ensure_root

    echo ${argv}
    if [[ ! ${1} || ! ${2} ]]; then
        echo 'Need an action (connect disconnect), nbd path, and QEMU image path (only if connecting)!'
        exit 1
    else
        action=${1}
        nbd=${2}
        image=${3}
        load_nbd_module

        if [[ ${action} == 'connect' ]]; then
            if [[ ! ${image} ]]; then
                echo 'Need a QEMU image to mount!'
                exit 1
            fi

            connect_device
        elif [[ ${action} == 'disconnect' ]]; then
            disconnect_device
        fi
    fi
}

main ${@}
