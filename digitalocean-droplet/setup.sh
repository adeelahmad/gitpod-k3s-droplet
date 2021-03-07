#!/usr/bin/env bash

set -exuo pipefail

doctl account get

DROPLET_NAME=gitpod-k3s
DOMAIN_NAME=ludmann.name
GITPOD_SUBDOMAIN=gitpod.x
LEGO_VOLUME_ID=a705e73d-7d8f-11eb-84cd-0a58ac14d02e

#DROPLET_SIZE=s-1vcpu-1gb
DROPLET_SIZE=s-2vcpu-4gb

doctl compute droplet create "$DROPLET_NAME" \
    --image ubuntu-20-04-x64 \
    --region fra1 \
    --size "$DROPLET_SIZE" \
    --ssh-keys "$DIGITALOCEAN_SSH_KEY_FINGERPRINT" \
    --volumes "$LEGO_VOLUME_ID" \
    --wait

IP=$(doctl compute droplet get "$DROPLET_NAME" --format PublicIPv4 --no-header)
doctl compute domain records create "$DOMAIN_NAME" --record-type A --record-name "$GITPOD_SUBDOMAIN" --record-data "$IP" --record-ttl 30
doctl compute domain records create "$DOMAIN_NAME" --record-type A --record-name "*.$GITPOD_SUBDOMAIN" --record-data "$IP" --record-ttl 30
doctl compute domain records create "$DOMAIN_NAME" --record-type A --record-name "*.ws.$GITPOD_SUBDOMAIN" --record-data "$IP" --record-ttl 30

sleep 30

scp -r gitpod-install "root@$IP:"
ssh "root@$IP" ./gitpod-install/install.sh \
    "$GITPOD_SUBDOMAIN.$DOMAIN_NAME" \
    "letsencrypt@cornelius-ludmann.de" \
    "$DIGITALOCEAN_ACCESS_TOKEN" \
    "$GITPOD_GITHUB_CLIENT_SECRET" \
    "true"

mkdir -p ~/.kube
scp "root@$IP:/etc/rancher/k3s/k3s.yaml" ~/.kube/config
sed -i "s+127.0.0.1+$IP+g" ~/.kube/config

echo "done"

watch kubectl get pods
