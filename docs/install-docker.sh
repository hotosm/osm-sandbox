#!/bin/bash

set -o pipefail

# Tested for Debian 11 Bookworm & Ubuntu 22.04 LTS

# Import helper utils
if [ -f "utils.sh" ]; then
    . ./utils.sh
else
    echo "Error: utils.sh not found."
    exit 1
fi

# Auto accept all apt prompts
export DEBIAN_FRONTEND=noninteractive

# Global Vars
TEMP_DIR=$(mktemp -d)
OS_NAME="debian"

check_user_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        heading_echo "WARNING" "yellow"

        yellow_echo "Current user is root."
        yellow_echo "This script must run as a non-privileged user account."
        echo

        if id "svchot" &>/dev/null; then
            yellow_echo "User 'svchot' found."
        else
            yellow_echo "Creating user 'svchot'."
            useradd -m -d /home/svchot -s /bin/bash svchot 2>/dev/null
        fi

        echo
        yellow_echo "Temporarily adding to sudoers list."
        echo "svchot ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/hot-sudoers >/dev/null

        echo
        yellow_echo "Rerunning this script as user 'svchot'."
        echo

        if ! command -v ps &>/dev/null; then
            apt-get update > /dev/null
            apt-get install -y procps --no-install-recommends > /dev/null
            echo
        fi

        if ! command -v machinectl &>/dev/null; then
            # Start the installation process in the background with spinner
            ( apt-get update > /dev/null
            wait  # Wait for 'apt-get update' to complete
            apt-get install -y systemd-container --no-install-recommends > /dev/null ) &
            install_progress $!
            echo
        fi

        # Check if input is direct bash script call (i.e. ends in .sh)
        ext="$(basename "$0")"
        if [ "${ext: -3}" = ".sh" ]; then
            # User called script directly, copy to temp dir
            root_script_path="$(readlink -f "$0")"
            temp_script_path="${TEMP_DIR}/$(basename "$0")"
            cp "$root_script_path" "$temp_script_path"
            chown svchot:svchot "$temp_script_path"
            chmod +x "$temp_script_path"

            machinectl --quiet shell \
                --setenv=RUN_AS_ROOT=true \
                --setenv=DOCKER_HOST="${DOCKER_HOST}" \
                svchot@ /bin/bash -c "$temp_script_path"
        else
            # User called script remotely, so do the same
            machinectl --quiet shell \
                --setenv=RUN_AS_ROOT=true \
                --setenv=DOCKER_HOST="${DOCKER_HOST}" \
                svchot@ /bin/bash -c "curl -fsSL https://get.sandbox.hotosm.dev | bash"
        fi

        exit 0
    fi
}

check_os() {
    heading_echo "Checking Current OS"

    if [ -e /etc/os-release ]; then
        source /etc/os-release
        case "$ID" in
        debian)
            export OS_NAME=${ID}
            echo "Current OS is ${PRETTY_NAME}."
            ;;
        ubuntu)
            export OS_NAME=${ID}
            echo "Current OS is ${PRETTY_NAME}."
            ;;
        *)
            echo "Current OS is not Debian or Ubuntu. Exiting."
            exit 1
            ;;
        esac
    else
        echo "Could not determine the operating system. Exiting."
        exit 1
    fi
}

remove_old_docker_installs() {
    heading_echo "Removing Old Versions of Docker"
    packages=(
        docker.io
        docker-doc
        docker-compose
        podman-docker
        containerd
        runc
    )
    for pkg in "${packages[@]}"; do
        sudo apt-get remove "$pkg"
    done
}

install_dependencies() {
    heading_echo "Installing Dependencies"
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        uidmap \
        dbus-user-session \
        slirp4netns

    if [ "$OS_NAME" = "debian" ]; then
        sudo apt-get install -y fuse-overlayfs
    fi
}

add_gpg_key() {
    heading_echo "Adding Docker GPG Key"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "Done"
}

add_to_apt() {
    heading_echo "Adding Docker to Apt Source"
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} \
        $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    echo "Done"
}

apt_install_docker() {
    heading_echo "Installing Docker"
    sudo apt-get update
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        docker-ce-rootless-extras
}

update_to_rootless() {
    heading_echo "Disabling Docker Service (If Running)"
    sudo systemctl disable --now docker.service docker.socket

    heading_echo "Install Rootless Docker"
    dockerd-rootless-setuptool.sh install
}

restart_docker_rootless() {
    heading_echo "Restarting Docker Service"
    echo "This is required as sometimes docker doesn't init correctly."
    systemctl --user daemon-reload
    systemctl --user restart docker
    echo
    echo "Done."
}

allow_priv_port_access() {
    heading_echo "Allowing Privileged Port Usage"
    sudo tee -a /etc/sysctl.conf <<EOF > /dev/null 2>&1
net.ipv4.ip_unprivileged_port_start=0
EOF
    sudo sysctl -p
    echo "Done"
}

update_docker_ps_format() {
    heading_echo "Updating docker ps Formatting"

    # Root user
    if [ "$RUN_AS_ROOT" = true ]; then
        sudo mkdir -p /root/.docker
        sudo touch /root/.docker/config.json
        sudo tee /root/.docker/config.json <<EOF > /dev/null 2>&1
{
    "psFormat": "table {{.ID}}\\t{{.Image}}\\t{{.Status}}\\t{{.Names}}"
}
EOF
    fi

    # svchot user
    mkdir -p ~/.docker
    touch ~/.docker/config.json
    tee ~/.docker/config.json <<EOF > /dev/null 2>&1
{
    "psFormat": "table {{.ID}}\\t{{.Image}}\\t{{.Status}}\\t{{.Names}}"
}
EOF

echo "Done"
}


add_vars_to_bashrc() {
    # DOCKER_HOST must be added to the top of bashrc, as running non-interactively
    # Most distros exit .bashrc execution is non-interactive

    heading_echo "Adding DOCKER_HOST and 'dc' alias to bashrc"

    user_id=$(id -u)
    docker_host_var="export DOCKER_HOST=unix:///run/user/$user_id/docker.sock"
    dc_alias_cmd="alias dc='docker compose'"

    # Create temporary files for root and user bashrc
    tmpfile_root=$(mktemp)
    tmpfile_user=$(mktemp)

    if [ "$RUN_AS_ROOT" = true ]; then
        # Check if DOCKER_HOST is already defined in /root/.bashrc
        if ! sudo grep -q "$docker_host_var" /root/.bashrc; then
            echo "Adding DOCKER_HOST var to /root/.bashrc."
            echo "$docker_host_var" | sudo tee -a "$tmpfile_root" > /dev/null
            echo
        fi

        # Check if the 'dc' alias already exists in /root/.bashrc
        if ! sudo grep -q "$dc_alias_cmd" /root/.bashrc; then
            echo "Adding 'dc' alias to /root/.bashrc."
            echo "$dc_alias_cmd" | sudo tee -a "$tmpfile_root" > /dev/null
            echo
        fi
    fi

    # Check if DOCKER_HOST is already defined in ~/.bashrc
    if ! grep -q "$docker_host_var" ~/.bashrc; then
        echo "Adding DOCKER_HOST var to ~/.bashrc."
        echo "$docker_host_var" | tee -a "$tmpfile_user" > /dev/null
        echo
    fi

    # Check if the 'dc' alias already exists in ~/.bashrc
    if ! grep -q "$dc_alias_cmd" ~/.bashrc; then
        echo "Adding 'dc' alias to ~/.bashrc."
        echo "$dc_alias_cmd" | tee -a "$tmpfile_user" > /dev/null
        echo
    fi

    # Append the rest of the original .bashrc to the temporary file
    if [ -e ~/.bashrc ]; then
        grep -v -e "$docker_host_var" -e "$dc_alias_cmd" ~/.bashrc >> "$tmpfile_user"
    fi
    # Replace the original .bashrc with the modified file
    mv "$tmpfile_user" ~/.bashrc

    # If RUN_AS_ROOT is true, replace /root/.bashrc with the modified file
    if [ "$RUN_AS_ROOT" = true ]; then
        # Append the rest of the original /root/.bashrc to the temporary file
        if [ -e /root/.bashrc ]; then
            grep -v -e "$docker_host_var" -e "$dc_alias_cmd" /root/.bashrc >> "$tmpfile_root"
        fi

        # Replace the original /root/.bashrc with the modified file
        sudo mv "$tmpfile_root" /root/.bashrc
    fi

    echo "Setting DOCKER_HOST for the current session."
    DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
    export DOCKER_HOST

    echo
    echo "Done"
}

install_docker() {
    check_user_not_root

    check_os
    remove_old_docker_installs
    install_dependencies
    add_gpg_key
    add_to_apt
    apt_install_docker
    update_to_rootless
    allow_priv_port_access
    restart_docker_rootless
    update_docker_ps_format
    add_vars_to_bashrc

    if [[ "$RUN_AS_ROOT" = true ]]; then
        # Remove from sudoers
        sudo rm /etc/sudoers.d/hot-sudoers
    fi

    # Enable docker daemon to remain after ssh disconnect
    echo
    yellow_echo "Enable login linger for user $(whoami) (docker daemon on ssh disconnect)."
    loginctl enable-linger "$(whoami)"
}
