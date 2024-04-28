#!/bin/bash

heading_echo() {
    local message="$1"
    local color="${2:-blue}"
    local separator="--------------------------------------------------------"
    local sep_length=${#separator}
    local pad_length
    pad_length=$(( (sep_length - ${#message}) / 2 ))
    local pad=""

    case "$color" in
        "black") color_code="\e[0;30m" ;;
        "red") color_code="\e[0;31m" ;;
        "green") color_code="\e[0;32m" ;;
        "yellow") color_code="\e[0;33m" ;;
        "blue") color_code="\e[0;34m" ;;
        "purple") color_code="\e[0;35m" ;;
        "cyan") color_code="\e[0;36m" ;;
        "white") color_code="\e[0;37m" ;;
        *) color_code="\e[0m" ;;  # Default: reset color
    esac

    for ((i=0; i<pad_length; i++)); do
        pad="$pad "
    done

    echo ""
    echo -e "${color_code}$separator\e[0m"
    echo -e "${color_code}$pad$message$pad\e[0m"
    echo -e "${color_code}$separator\e[0m"
    echo ""
}

yellow_echo() {
    local text="$1"
    echo -e "\e[0;33m${text}\e[0m"
}

red_echo() {
    local text="$1"
    echo -e "\e[0;33m${text}\e[0m"
}

install_progress() {
    local pid=$1
    local delay=0.5
    local spin[0]="-"
    local spin[1]="\\"
    local spin[2]="|"
    local spin[3]="/"

    while [ "$(ps a | awk '{print $1}' | grep "$pid")" ]; do
        local temp=${spin[0]}
        spin[0]=${spin[1]}
        spin[1]=${spin[2]}
        spin[2]=${spin[3]}
        spin[3]=$temp
        echo -ne "${spin[0]} Installing machinectl requirement...\r"
        sleep $delay
    done
    yellow_echo "${spin[0]} Installing machinectl requirement... Done"
}