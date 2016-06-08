#!/bin/bash

set -e

# Do software and security update
sudo apt-get update && sudo apt-get upgrade -y

DEPS="
    apt-show-versions
    ntp
    unzip
    htop
    ifstat
    realpath
    tree
    software-properties-common
    git
    netperf
    nmap
    "

# Install basic packages
for dep in $DEPS; do
    if ! dpkg -s $dep > /dev/null 2>&1; then
    echo "Attempting installation of missing package: $dep"
    set -x
    sudo apt-get install -y $dep
    set +x
    fi
done
