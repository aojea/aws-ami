#!/usr/bin/env bash

# default version
MARIADB_VERSION='10.0'

# Import repo key
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
# Add repo for MariaDB
add-apt-repository -y "deb http://mirrors.syringanetworks.net/mariadb/repo/10.0/ubuntu trusty main"
# Update
apt-get update

# Install MariaDB without password prompt
echo "Set username to 'root' and password to 'openstack'"
sudo debconf-set-selections <<< "maria-db-$MARIADB_VERSION mysql-server/root_password password openstack"
sudo debconf-set-selections <<< "maria-db-$MARIADB_VERSION mysql-server/root_password_again password openstack"
echo "Success!"
# Install MariaDB
# -qq implies -y --force-yes
sudo apt-get install -qq mariadb-server

# enable remote access
# setting the mysql bind-address to allow connections from everywhere
sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

# adding grant privileges to mysql root user from everywhere
# thx to http://stackoverflow.com/questions/7528967/how-to-grant-mysql-privileges-in-a-bash-script for this
MYSQL=`which mysql`

Q1="GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY 'openstack' WITH GRANT OPTION;"
Q2="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}"
$MYSQL -uroot -p$1 -e "$SQL"

sed -i 's/max_connections/\#max_connections/g' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a max_connections = 1500' /etc/mysql/my.cnf

service mysql restart
