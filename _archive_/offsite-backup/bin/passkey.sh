#!/bin/bash

set -e

NET_DEV=$(ip link sh | egrep -o '(eth|ens|enx)([0-9a-f]+):' | tr -d ':' | head -1)
DISK_SN=$(udevadm info --query=property --name=/dev/sda | egrep '^ID_SERIAL=' | cut -d'=' -f 2)

[ -z "${NET_DEV}" ] && {
  echo "No network device"
  exit 1
}

[ -z "${DISK_SN}" ] && {
  echo "No disk serial"
  exit 1
}

MAC_ADDR=$(ip link sh dev ${NET_DEV} | egrep -o '([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2})' | head -1)

[ -z "${MAC_ADDR}" ] && {
  echo "No mac address"
  exit 1
}

server_key=$(cat /etc/machine-id)

if [ -f /etc/server_key ]; then
  # for generate: openssl rand -base64 32 > /etc/server_key
  server_key=$(cat /etc/server_key)
fi

if [ -f /tmp/server_key ]; then
  server_key=$(cat /tmp/server_key)
fi

echo "${DISK_SN}|${MAC_ADDR}|${server_key}" | openssl dgst -sha256 -binary | openssl enc -base64 | tr -d '+=/\\'
