#!/bin/sh
#IP of the controller
IP=10.1.2.10

cat >> /etc/resolv.conf <<EOF_MIDO
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF_MIDO

cat > /etc/apt/sources.list.d/openjdk8.list <<EOF_MIDO
# OpenJDK 8
deb http://ppa.launchpad.net/openjdk-r/ppa/ubuntu trusty main
EOF_MIDO

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x86F44E2A


# Add midonet repositories
cat > /etc/apt/sources.list.d/midonet.list <<EOF_MIDO
# MidoNet
deb http://builds.midonet.org/midonet-5 testing main

# MidoNet OpenStack Integration
deb http://builds.midonet.org/openstack-kilo stable main

# MidoNet 3rd Party Tools and Libraries
deb http://builds.midonet.org/misc stable main
EOF_MIDO

curl -L http://builds.midonet.org/midorepo.key | apt-key add - 

apt-get update && apt-get -y upgrade

apt-get -y install midolman
sudo sed -i  's/zookeeper_hosts = 127.0.0.1:2181/zookeeper_hosts = 10.1.2.10:2181/' /etc/midolman/midolman.conf
service midolman restart

echo <<EOF_MIDO | mn-conf set -t default
zookeeper {
zookeeper_hosts = $IP:2181 }
cassandra {
servers = $IP
}
EOF_MIDO

