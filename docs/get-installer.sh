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
    . utils.sh
}

check_docker() {
    heading_echo "Docker Install"

    if command -v docker &> /dev/null; then
        echo "Docker already installed: $(which docker)"
        echo "Skipping."
        return 0
    fi

    echo "Docker must be installed for this tool to work."
    echo
    echo "Do you want to install Docker? (y/n)"
    echo
    read -rp "Enter 'y' to install, anything else to continue: " install_docker

    if [[ "$install_docker" = "y" ||  "$install_docker" = "yes" ]]; then
        curl --proto '=https' --tlsv1.2 --silent --show-error --fail \
            --location https://get.sandbox.hotosm.dev/install-docker.sh \
            --output install-docker.sh 2>&1
        chmod +x install-docker.sh
        bash install-docker.sh
    else
        echo
        red_echo "Docker is required. Aborting."
        echo
        exit 1
    fi
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
check_docker
install_sandbox
