#!/bin/bash -ex

cat > /etc/apt/sources.list.d/openjdk8.list <<EOF_MIDO
# OpenJDK 8
deb http://ppa.launchpad.net/openjdk-r/ppa/ubuntu trusty main
EOF_MIDO

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x86F44E2A

apt-get -y install openjdk-8-jre
