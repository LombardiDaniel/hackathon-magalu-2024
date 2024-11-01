#!/bin/bash

BALANCE_PORT=$1
FRONTNED_IP=$2
BACKEND_IPS_COMMA_SEPARATED=$3

BACKEND_IPS_ARRAY=',' read -ra hosts <<< "$BACKEND_IPS_COMMA_SEPARATED"

# Add a port to each host
for i in "${!hosts[@]}"; do
    hosts[i]="${hosts[i]}:27017"
done

# Join the modified array back into a string
BACKEND_HOSTS_COMMA_SEPARATED=$(IPS_ARRAY=','; echo "${hosts[*]}")

sudo docker run \
    --cap-add NET_ADMIN \
    --cap-add SYS_MODULE \
    --cap-add CAP_SYS_ADMIN \
    --network host --privileged \
    -v /sys/fs/bpf:/sys/fs/bpf \
    -v /lib/modules \
    -v /var/run/cilium:/var/run/cilium/ \
    --name l4lb cilium/cilium:stable cilium-agent \
    --bpf-lb-algorithm=maglev \
    --bpf-lb-mode=dsr \
    --bpf-lb-acceleration=native \
    --bpf-lb-dsr-dispatch=ipip \
    --devices=enp1s0 \
    --datapath-mode=lb-only \
    --enable-l7-proxy=false \
    --tunnel=disabled \
    --install-iptables-rules=false \
    --enable-bandwidth-manager=false \
    --enable-local-redirect-policy=false \
    --enable-hubble=false \
    --enable-l7-proxy=false \
    --preallocate-bpf-maps=false \
    --disable-envoy-version-check=true \
    --auto-direct-node-routes=false \
    --enable-ipv4=true \
    --enable-ipv6=true

sudo docker exe l4lb cilium service update --id 1 --frontend "$FRONTEND_IP:$BALANCE_IP" --backends "$BACKEND_HOSTS_COMMA_SEPARATED"