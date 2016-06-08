#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y adduser libfontconfig curl screen vim 

cat > ~/.screenrc <<EOF
hardstatus on
hardstatus alwayslastline
hardstatus string "%w"
EOF

# Install vim

cat > ~/.vimrc <<EOF
" Tabs to spaces.
set expandtab
set shiftwidth=2
set softtabstop=2
set smarttab
set smartindent
set tabstop=2
EOF


# Install ansible
sudo apt-get -y install software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update
sudo apt-get -y install ansible curl

# Install influxdb
wget https://s3.amazonaws.com/influxdb/influxdb_0.9.6.1_amd64.deb
dpkg -i influxdb_0.9.6.1_amd64.deb
sed -i '/^\[\[graphite\]\]$/,/^\[/ s/enabled = false/enabled = true/' /etc/influxdb/influxdb.conf
sed -i '/^\[\[graphite\]\]$/,/^\[/ s/\# database.*/database = \"data\"/' /etc/influxdb/influxdb.conf
service influxdb start

# Install grafana
wget https://grafanarel.s3.amazonaws.com/builds/grafana_2.6.0_amd64.deb
dpkg -i grafana_2.6.0_amd64.deb
service grafana-server start

# Install jmxtrans
apt-get install -qy openjdk-7-jre curl --no-install-recommends
wget http://central.maven.org/maven2/org/jmxtrans/jmxtrans/253/jmxtrans-253.deb
dpkg -i jmxtrans-253.deb
sed -i 's/JMXTRANS_USER=.*/JMXTRANS_USER=root/' /etc/init.d/jmxtrans
service jmxtrans start

# Install telegraf
wget http://get.influxdb.org/telegraf/telegraf_0.10.1-1_amd64.deb
dpkg -i telegraf_0.10.1-1_amd64.deb

# Configure grafana and influxdb
influx -execute 'CREATE DATABASE "data"'
curl 'http://admin:admin@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"localInflux","type":"influxdb","url":"http://127.0.0.1:8086","access":"proxy","isDefault":true,"database":"data"}'

