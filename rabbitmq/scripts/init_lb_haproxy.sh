#!/bin/bash

set -eu

BALANCE_PORT=$1
FRONTEND_IP=$2
BACKEND_IPS_COMMA_SEPARATED=$3

TEMPLATES_DIR=/tmp/scripts/templates
# TEMPLATES_DIR=./templates

IFS=',' read -ra hosts <<< "$BACKEND_IPS_COMMA_SEPARATED"

# Add a port to each host
for i in "${!hosts[@]}"; do
    hosts[i]="server db${i} ${hosts[i]}:${BALANCE_PORT}"
done

BACKEND_HOSTS=${hosts[*]}

echo BACKEND_HOSTS=$BACKEND_HOSTS
echo BALANCE_PORT=$BALANCE_PORT

sudo mkdir -p /usr/local/etc/haproxy/
sudo cat <<EOF > /usr/local/etc/haproxy/haproxy.cfg

defaults
    mode tcp

frontend db
    bind :${BALANCE_PORT}
    default_backend service_backends

backend service_backends
EOF

for i in "${!hosts[@]}"; do
    echo -e "\t${hosts[i]}" >> /usr/local/etc/haproxy/haproxy.cfg
done

sudo docker run \
    -p $BALANCE_PORT:$BALANCE_PORT \
    -v /usr/local/etc/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg \
    --restart always \
    -d \
    haproxy:latest
