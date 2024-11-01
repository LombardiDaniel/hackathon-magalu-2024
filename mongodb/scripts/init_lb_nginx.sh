#!/bin/bash

set -eu

BALANCE_PORT=$1
FRONTEND_IP=$2
BACKEND_IPS_COMMA_SEPARATED=$3

# TEMPLATES_DIR=/tmp/scripts/templates/
TEMPLATES_DIR=./templates

BACKEND_IPS_ARRAY=',' read -ra hosts <<< "$BACKEND_IPS_COMMA_SEPARATED"

# Add a port to each host
for i in "${!hosts[@]}"; do
    hosts[i]="server ${hosts[i]}:${BALANCE_PORT};"
done

# Join the modified array back into a string
BACKEND_HOSTS=$(IPS_ARRAY='\n'; echo "${hosts[*]}")

echo $BACKEND_HOSTS
echo $BALANCE_PORT

awk -v MATCH_FOR_AWK_BACKEND="$BACKEND_HOSTS" '{gsub("MATCH_FOR_AWK_BACKEND", MATCH_FOR_AWK_BACKEND)}1' $TEMPLATES_DIR/nginx.conf > $TEMPLATES_DIR/nginx-b.conf
awk -v MATCH_FOR_AWK_PORT="$BALANCE_PORT" '{gsub("MATCH_FOR_AWK_PORT", MATCH_FOR_AWK_PORT)}1' $TEMPLATES_DIR/nginx-b.conf > $TEMPLATES_DIR/nginx-bf.conf

# sudo cp $TEMPLATES_DIR/nginx-bf.conf /etc/nginx/conf.d/default.conf
sudo cp $TEMPLATES_DIR/nginx-bf.conf /etc/nginx/conf.d/default.conf

sudo docker run \
    -p $BALANCE_PORT:$BALANCE_PORT \
    -v /etc/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf \
    --restart latest
    nginx:latest



# ./init_lb_nginx.sh 27017 0.0.0.0 172.18.0.92:27017