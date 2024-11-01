#!/bin/bash

set -eu

BALANCE_PORT=$1
FRONTEND_IP=$2
BACKEND_IPS_COMMA_SEPARATED=$3

BACKEND_IPS_ARRAY=',' read -ra hosts <<< "$BACKEND_IPS_COMMA_SEPARATED"

# Add a port to each host
for i in "${!hosts[@]}"; do
    hosts[i]="${hosts[i]}:${BALANCE_PORT}"
done

# Join the modified array back into a string
BACKEND_HOSTS_COMMA_SEPARATED=$(IPS_ARRAY=','; echo "${hosts[*]}")

sudo docker run \
    --cap-add NET_ADMIN \
    --cap-add SYS_MODULE \
    --cap-add CAP_SYS_ADMIN \
    --network host --privileged \
    --restart always \
    -v /sys/fs/bpf:/sys/fs/bpf \
    -v /lib/modules \
    -v /var/run/cilium:/var/run/cilium/ \
    -d \
    --name l4lb \
    cilium/cilium:stable cilium-agent \
    --bpf-lb-algorithm=maglev \
    --devices=ens3 \
    --datapath-mode=lb-only \
    --enable-l7-proxy=false \
    --install-iptables-rules=false \
    --enable-bandwidth-manager=false \
    --enable-local-redirect-policy=false \
    --preallocate-bpf-maps=false \
    --disable-envoy-version-check=true \
    --auto-direct-node-routes=false \
    --enable-ipv4=true \
    --enable-ipv6=false

sleep 10

sudo docker exec l4lb cilium service update --id 1 --frontend "$FRONTEND_IP:$BALANCE_PORT" --backends "$BACKEND_HOSTS_COMMA_SEPARATED"

sudo ip addr add $FRONTEND_IP/32 dev lo label lo:v4-200

sudo sysctl -qw net.ipv4.vs.sloppy_tcp=1 # schedule non-SYN packets
sudo sysctl -qw net.ipv4.vs.pmtu_disc=0  # packets are silently fragmented
        # do NOT reschedule a connection when dest doesn't exist
        # anymore (needed to drain properly a LB7):
sudo sysctl -qw net.ipv4.vs.expire_nodest_conn=0
sudo sysctl -qw net.ipv4.vs.expire_quiescent_template=0