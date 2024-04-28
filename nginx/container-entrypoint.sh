#!/bin/bash

set -eo pipefail

echo
echo "Substituing env vars"
echo
bash /docker-entrypoint.d/20-envsubst-on-templates.sh

echo
echo "Starting NGINX in the background"
echo
nginx -g "daemon off;" > /dev/null 2>&1 &

# Wait for NGINX to start with a maximum timeout of 20 seconds
timeout=20
while [ $timeout -gt 0 ]; do
    if nc -z localhost 80; then
        break
    fi

    echo ""
    echo "Waiting for NGINX to be running..."
    sleep 2
    timeout=$((timeout - 2))
done

# Check if the timeout was reached
if [ $timeout -eq 0 ]; then
    echo "NGINX did not start within the timeout."
    exit 1
fi

# Check if DOMAIN is set
if [ -z "${DOMAIN}" ]; then
    echo "${DOMAIN} variable is not set. Exiting."
    exit 1
fi

# Run certbot with the constructed arguments
echo "Running command: certbot --non-interactive certonly ${certbot_args[*]}"
certbot --non-interactive certonly "${certbot_args[@]}"
echo "Certificate generated under: /etc/letsencrypt/live/${DOMAIN}/"

# Successful exit (stop container)
exit 0
