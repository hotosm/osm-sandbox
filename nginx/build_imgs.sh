#!/bin/bash

NGINX_TAG="${NGINX_TAG:-1.25.3}"

# Certs init
echo "Building proxy:certs-init"
docker build nginx \
    --tag "ghcr.io/hotosm/osm-sandbox/proxy:certs-init" \
    --target certs-init \
    --build-arg NGINX_TAG="${NGINX_TAG}"

if [[ -n "$PUSH_IMGS" ]]; then
    docker push "ghcr.io/hotosm/osm-sandbox/proxy:certs-init"
fi

# Main proxy
echo "Building proxy"
docker build nginx \
    --tag "ghcr.io/hotosm/osm-sandbox/proxy:latest" \
    --build-arg NGINX_TAG="${NGINX_TAG}"

if [[ -n "$PUSH_IMGS" ]]; then
    docker push "ghcr.io/hotosm/osm-sandbox/proxy:latest"
fi
