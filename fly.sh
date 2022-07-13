#!/bin/bash


red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'


function set_vps_swap() {
    # Set swap size as two times of RAM size automatically
    if [ $(free | grep Swap | awk '{print $2}') -gt 0 ]; then
        echo -e "${green}Swap already enabled${plain}"
        cat /proc/swaps
        free -h
        return 0
    else
        echo -e "${green}Swapfile not created. creating it${plain}"
        mem_num=$(awk '($1 == "MemTotal:"){print $2/1024}' /proc/meminfo | sed "s/\..*//g" | awk '{print $1*2}')
        fallocate -l ${mem_num}M /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap defaults 0 0' >>/etc/fstab
        echo -e "${green}swapfile created.${plain}"
        cat /proc/swaps
        free -h
    fi
}

function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --email)
            email="$2"
            shift
            shift
            ;;
        --token)
            token="$2"
            shift
            shift
            ;;
        --version)
            version="$2"
            shift
            shift
            ;;
        --proxy)
            use_proxy="$2"
            shift
            shift
            ;;
        --debug-output)
            set -x
            shift
            ;;
        *)
            error "Unknown argument: $1"
            display_help
            exit 1
            ;;
        esac
    done
}

function display_help() {
    echo "Usage: $0 [--email <email>] [--token <token>]"
    echo "  --email <email>    Email address to login"
    echo "  --token <token>  traffmonetizer token"
    echo "  --debug-output     Enable debug output"
    echo "Example: $0 --email a952135763@gmail.com --token 34gI/+HiEmJs/SFXgA4OmtJEv53hCRiPL6TtbiD1naY="
}

function check_root_user() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${red}Error: root user is needed${plain}"
        exit 1
    fi
}

function check_os() {
    # os distro release
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    else
        echo -e "${red}ERROR: Only support Centos8, Debian 10+ or Ubuntu16+${plain}\n" && exit 1
    fi

    # os arch
    arch=$(arch)
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="amd64"
    else
        echo -e "${red}ERROR: ${plain}Unsupported architecture: $arch\n" && exit 1
    fi

    # os version
    os_version=""
    if [[ -f /etc/os-release ]]; then
        os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
    fi
    if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
        os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
    fi

    if [[ x"${release}" == x"centos" ]]; then
        if [[ ${os_version} -le 7 ]]; then
            echo -e "${red}Please use CentOS 8 or higher version.${plain}\n" && exit 1
        fi
    elif [[ x"${release}" == x"ubuntu" ]]; then
        if [[ ${os_version} -lt 16 ]]; then
            echo -e "${red}Please use Ubuntu 16 or higher version.${plain}\n" && exit 1
        fi
    elif [[ x"${release}" == x"debian" ]]; then
        if [[ ${os_version} -lt 10 ]]; then
            echo -e "${red}Please Debian 10 or higher version.${plain}\n" && exit 1
        fi
    fi
}

function install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget sudo curl -y &>/dev/null
    else
        apt update &>/dev/null && apt install wget sudo curl -y &>/dev/null
    fi
}

function install_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo -e "${green}docker already installed, skip${plain}"
    else
        echo -e "${green}Installing docker${plain}"
        curl -fsSL https://get.docker.com | sudo bash
        systemctl restart docker || service docker restart
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${red}docker installation failed, please check your environment${plain}"
        exit 1
    fi
}


function set_peer2profit_email() {
    if [ -z "$email" ]; then
        read -rp "Input your email: " email
    fi
    if [ -n "$email" ]; then
        echo -e "${green}Your email is: $email ${plain}"
        export email
        eval "docker run -d --restart=always -e P2P_EMAIL=$email peer2profit/peer2profit_linux:latest"
    else
        echo -e "${red}Please input your email${plain}"
        exit 1
    fi
}

function set_traffmonetizer_token() {
    if [ -z "$token" ]; then
        read -rp "Input your token: " token
    fi
    if [ -n "$token" ]; then
        echo -e "${green}Your token is: $token ${plain}"
        export token
        eval "docker run -d --restart=always traffmonetizer/cli start accept --token $token"
    else
        echo -e "${red}Please input your token${plain}"
        exit 1
    fi
}





function start_containers() {
    export COMPOSE_HTTP_TIMEOUT=500
    echo "Clean cache"
    docker system prune -f &>/dev/null
    docker stats --no-stream
}

function fly() {
    parse_args "$@"
    check_root_user
    set_vps_swap
    check_os
    install_base
    install_docker
    set_peer2profit_email
    set_traffmonetizer_token
    start_containers
}

fly "$@"
