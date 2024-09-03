#!/bin/bash

# --------------------------------------------------------------------------- LOGS

function warn(){
        echo -e "\033[0;33m""$1""\033[0m"
}

function error(){
        echo -e "\033[0;31m""$1""\033[0m" 1>&2
}

function success(){
        echo -e "\033[0;32m""$1""\033[0m"
}

function info(){
        echo -e "\033[1;37m""$1""\033[0m"
}

# --------------------------------------------------------------------------- CHECKS

function check_is_root() {
  if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root."
    exit 1
  fi
}