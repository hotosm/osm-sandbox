#!/bin/bash

set -o pipefail

# Tested for Debian 11 Bookworm & Ubuntu 22.04 LTS

# Auto accept all apt prompts
export DEBIAN_FRONTEND=noninteractive

# Global Vars
TEMP_DIR=$(mktemp -d)
DOTENV_NAME=.env

get_repo() {
    heading_echo "Getting Necessary Files"

    current_dir="${PWD}"

    if ! command -v git &>/dev/null; then
        yellow_echo "Downloading GIT."
        echo
        sudo apt-get update
        sudo apt-get install -y git --no-install-recommends
        echo
    fi

    # Files in a random temp dir
    cd "${TEMP_DIR}" || exit 1

    repo_url="https://github.com/hotosm/osm-sandbox.git"

    echo "Cloning repo $repo_url to dir: ${TEMP_DIR}"
    echo
    git clone --branch --depth 1 "$repo_url"
}

check_existing_dotenv() {
    if [ -f "${DOTENV_NAME}" ]; then
        echo "WARNING: ${DOTENV_NAME} file already exists."
        echo "This script will overwrite the content of this file."
        echo
        printf "Do you want to overwrite file \'%s\'? y/n" "${DOTENV_NAME}"
        echo
        while true; do
            read -erp "Enter 'y' to overwrite, anything else to continue: " overwrite

            if [[ "$overwrite" = "y" || "$overwrite" = "yes" ]]; then
                return 1
            else
                echo "Continuing with existing .env file."
                return 0
            fi
        done
    fi

    return 1
}

prompt_user_gen_dotenv() {
    heading_echo "Generate dotenv config for FMTM"

    # Exit if user does not overwrite existing dotenv
    if check_existing_dotenv; then
        return
    fi

    heading_echo "Domain Name"

    echo "To run OSM Sandbox you must own a domain name."
    while true; do
        read -erp "Enter a valid domain name you wish to use: " domain

        if [ "$domain" = "" ]; then
            echo "Invalid input!"
        else
            export DOMAIN="${domain}"
            break
        fi
    done

    heading_echo "Admin Credentials"

    while true; do
        read -erp "Enter the admin email address: " email

        if [ "$email" = "" ]; then
            echo "Invalid input!"
        else
            export ADMIN_EMAIL="${email}"
            break
        fi
    done

    while true; do
        read -erp "Enter the admin password: " password

        if [ "$password" = "" ]; then
            echo "Invalid input!"
        else
            export ADMIN_PASS="${password}"
            break
        fi
    done

    heading_echo "Generating Dotenv File"

    echo "DOMAIN=$DOMAIN" > .env
    echo "ADMIN_EMAIL=$ADMIN_EMAIL" > .env
    echo "ADMIN_PASS=$ADMIN_PASS" > .env
    echo "CERT_EMAIL=$ADMIN_EMAIL" > .env

    heading_echo "Completed Dotenv File Generation." "green"
    echo "File ${DOTENV_NAME} content:"
    echo
    cat ${DOTENV_NAME}
    echo
}

run_compose_stack() {
    # Workaround if DOCKER_HOST is missed (i.e. docker just installed)
    if [ -z "$DOCKER_HOST" ]; then
        DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
        export DOCKER_HOST
    fi

    heading_echo "Pulling Required Images"
    docker compose pull

    heading_echo "Starting HOTOSM Sandbox"
    docker compose up \
        --detach --remove-orphans --force-recreate
}

final_output() {
    # Source env vars
    # shellcheck source=/dev/null
    . "${DOTENV_NAME}"

    proto="https"
    heading_echo "Sandbox Setup Complete" "green"
    echo "Access on:     ${proto}://${DOMAIN}"
    echo
}

install_sandbox() {
    get_repo
    # Work in generated temp dir
    local repo_dir="${TEMP_DIR}/osm-sandbox"
    cd "${repo_dir}" || exit 1

    prompt_user_gen_dotenv
    run_compose_stack
    final_output

    # Cleanup files
    rm -rf "${TEMP_DIR}"
}

install_sandbox
