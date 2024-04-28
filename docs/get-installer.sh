#!/bin/sh

set -u

cleanup_and_exit() {
    echo
    echo "CTRL+C received, exiting..."

    # Cleanup files
    rm -rf "${TEMP_DIR}"

    exit 1
}

download_utils() {
    curl --proto '=https' --tlsv1.2 --silent --show-error --fail \
        --location https://get.sandbox.hotosm.dev/utils.sh \
        --output utils.sh 2>&1
    chmod +x utils.sh
}

install_docker() {
    curl --proto '=https' --tlsv1.2 --silent --show-error --fail \
        --location https://get.sandbox.hotosm.dev/install-docker.sh \
        --output install-docker.sh 2>&1
    chmod +x install-docker.sh
    bash install-docker.sh
}

install_sandbox() {
    curl --proto '=https' --tlsv1.2 --silent --show-error --fail \
        --location https://get.sandbox.hotosm.dev/install-sandbox.sh \
        --output install-sandbox.sh 2>&1
    chmod +x install-sandbox.sh
    bash install-sandbox.sh
}

trap cleanup_and_exit INT
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}" || exit 1

download_utils
install_docker
install_sandbox
