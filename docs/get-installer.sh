#!/bin/sh

set -u

cleanup_and_exit() {
    # Cleanup temp dir if exists
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"

    # Check if $1 is unset or empty, then set it to "exit"
    if [ -z "${1+x}" ] || [ -z "$1" ]; then
        exit_code="exit"
    else
        exit_code="$1"
    fi

    if [ "$exit_code" = "exit" ]; then
        echo
        echo "Exiting..."
        exit 1
    fi
}

download_utils() {
    curl --proto '=https' --tlsv1.2 --silent --show-error --fail \
        --location https://get.sandbox.hotosm.org/utils.sh \
        --output utils.sh || { echo "Failed to download utils.sh"; cleanup_and_exit; }
    chmod +x utils.sh
}

install_docker() {
    curl --proto '=https' --tlsv1.2 --silent --show-error --fail \
        --location https://get.sandbox.hotosm.org/install-docker.sh \
        --output install-docker.sh || { echo "Failed to download install-docker.sh"; cleanup_and_exit; }
    chmod +x install-docker.sh
    bash install-docker.sh || { echo "Failed to install Docker"; cleanup_and_exit; }
}

install_sandbox() {
    curl --proto '=https' --tlsv1.2 --silent --show-error --fail \
        --location https://get.sandbox.hotosm.org/install-sandbox.sh \
        --output install-sandbox.sh || { echo "Failed to download install-sandbox.sh"; cleanup_and_exit; }
    chmod +x install-sandbox.sh
    bash install-sandbox.sh || { echo "Failed to install HOTOSM Sandbox"; cleanup_and_exit; }
}

trap 'cleanup_and_exit "exit"' EXIT

TEMP_DIR=$(mktemp -d) || { echo "Failed to create temporary directory"; cleanup_and_exit "exit"; }
cd "$TEMP_DIR" || { echo "Failed to change directory to temporary directory"; cleanup_and_exit "exit"; }
# Make temp dir available to child scripts
export TEMP_DIR

# Main execution
download_utils
install_docker
install_sandbox
cleanup_and_exit
