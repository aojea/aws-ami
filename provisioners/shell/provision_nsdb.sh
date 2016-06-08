#!/bin/sh
IP=10.1.2.10

cat >> /etc/resolv.conf <<EOF_MIDO
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF_MIDO

cat > /etc/apt/sources.list.d/datastax.list <<EOF_MIDO
# DataStax (Apache Cassandra)
deb http://debian.datastax.com/community stable main
EOF_MIDO

curl -L http://debian.datastax.com/debian/repo_key | apt-key add -

#
# Zookeper
#
apt-get update && apt-get -y upgrade
apt-get -y install crudini screen wget augeas-tools
apt-get -y install openjdk-7-jre-headless
apt-get -y install zookeeper zookeeperd 
echo "server.1=$IP:2888:3888" >> /etc/zookeeper/zoo.cfg
echo 1 > /var/lib/zookeeper/myid
service zookeeper restart

#
# Cassandra
#

apt-get -y install dsc20=2.0.10-1 cassandra=2.0.10
apt-mark hold dsc20 cassandra
service cassandra stop
sed -i -e "s/cluster_name:.*/cluster_name: 'midonet'/" /etc/cassandra/cassandra.yaml
sed -i -e "s/listen_address:.*/listen_address: $IP/" /etc/cassandra/cassandra.yaml
sed -i -e "s/seeds:.*/seeds: \"$IP\"/" /etc/cassandra/cassandra.yaml
sed -i -e "s/rpc_address:.*/rpc_address: $IP/" /etc/cassandra/cassandra.yaml
rm -rf /var/lib/cassandra/*
service cassandra start


