#!/bin/bash

REMOTE_HOST_SSH_PORT=22
REMOTE_HOST_SSH_USER=sshtunnel
REMOTE_HOST=sshtunnel.vitalvas.com

# Ignore early failed connections at boot
export AUTOSSH_GATETIME=0

if [ ! -f '/etc/ssh/ssh_host_ecdsa_key' ]; then
  ssh-keygen -A
fi

[ "$(which autossh)" ] || {
  apt install -qy autossh
}

SSH_PORT=$(shuf -i 48210-65530 -n 1)
PORT_STR="-R 0.0.0.0:${SSH_PORT}:localhost:22"

autossh -4 -M 0 -N -T -f \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i /etc/ssh/ssh_host_ecdsa_key \
  ${PORT_STR} \
  -p${REMOTE_HOST_SSH_PORT} ${REMOTE_HOST_SSH_USER}@${REMOTE_HOST}

echo "SSH port: ${SSH_PORT}"

