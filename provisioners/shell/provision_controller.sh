#!/bin/sh

admin_token=openstack

#Install Openstack client
apt-get -qq install python-openstackclient

#Install RabbitMQ
apt-get -qq install rabbitmq-server
rabbitmqctl add_user openstack openstack
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

#Install Keystone

echo "<<<<<Creating databases>>>>>"
mysql -uroot -popenstack <<EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost'  IDENTIFIED BY 'openstack';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%'  IDENTIFIED BY 'openstack';
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'openstack';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'openstack';
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'openstack';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'openstack';
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'openstack';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'openstack';
CREATE DATABASE heat;
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' IDENTIFIED BY 'openstack';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY 'openstack';
exit
EOF
echo "Success!"
#Disable the keystone service from starting automatically after installation:
echo "manual" > /etc/init/keystone.override

apt-get -y --force-yes install keystone apache2 libapache2-mod-wsgi  memcached python-memcache

#Keystone.conf file is preconfigured and stored in a mounted shared folder - See Vagrant file
mv /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
cp /tmp/keystone.conf /etc/keystone/keystone.conf

su -s /bin/sh -c "keystone-manage db_sync" keystone

#Configure the Apache HTTP server
echo "ServerName controller" >> /etc/apache2/apache2.conf
cat >> /etc/apache2/sites-available/wsgi-keystone.conf <<RE_CONF
Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>
RE_CONF

ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled

#Finalize the installation
#Restart the Apache HTTP server:
service apache2 restart
rm -f /var/lib/keystone/keystone.db

#Create the service entity and API endpoints
OS_TOKEN=$admin_token
OS_URL=http://controller:35357/v3
OS_IDENTITY_API_VERSION=3


#Create the service entity and API endpoints
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION service create --name keystone --description "OpenStack Identity" identity
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION endpoint create --region RegionOne identity public http://controller:5000/v2.0
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION endpoint create --region RegionOne identity internal http://controller:5000/v2.0
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION endpoint create --region RegionOne identity admin http://controller:35357/v2.0

#Create projects, users, and roles
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION project create --domain default --description "Admin Project" admin
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION user create --domain default --project admin --password openstack admin
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION role create admin
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION role add --project admin --user admin admin
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION project create --domain default --description "Service Project" service

#Create the demo project:
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION project create --domain default --description "Demo Project" demo
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION user create --domain default --password openstack demo
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION role create user
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION role add --project demo --user demo user

#Create MidoNet API Service
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION service create --name midonet --description "MidoNet API Service" midonet
 
#Create MidoNet Administrative User
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION user create --domain default --password openstack midonet
openstack --os-url $OS_URL --os-token $OS_TOKEN --os-identity-api-version $OS_IDENTITY_API_VERSION role add --project service --user midonet admin

#As the admin user, request an authentication token:
#openstack --os-auth-url http://controller:35357/v3 \
#--os-project-domain-id default --os-user-domain-id default \
#--os-project-name admin --os-username admin --os-auth-type password openstack \
#token issue
#RECHECK password prompt
#Disable the temporary authentication token mechanism, modifications are already done in the keystone-paste.ini file
#cp /etc/keystone/keystone-paste.ini /etc/keystone/keystone-paste.ini.bak
#mv /tmp/contr_files/keystone-paste.ini /etc/keystone/keystone-paste.ini
#chown keystone:keystone /etc/keystone/keystone-paste.ini
unset OS_TOKEN OS_URL

cat >> /root/admin-openrc.sh <<RE_CONF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
RE_CONF

#for demo user demo-openrc.sh 
cat >> /root/demo-openrc.sh <<RE_CONF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=demo
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
RE_CONF


#source admin-openrc.sh
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
openstack token issue

#Install and configure controller node for Neutron
#Database creation is done at the beginning of the script

openstack user create --domain default --password openstack neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696

apt-get -qq install python-midonetclient neutron-server python-networking-midonet python-neutronclient
apt-get -qq purge neutron-plugin-ml2

mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
cp /tmp/neutron.conf /etc/neutron/neutron.conf

mkdir /etc/neutron/plugins/midonet

cat >> /etc/neutron/plugins/midonet/midonet.ini <<RE_CONF
[MIDONET]
# MidoNet API URL
midonet_uri = http://controller:8181/midonet-api
# MidoNet administrative user in Keystone
username = midonet
password = openstack
# MidoNet administrative user's tenant
project_id = service
RE_CONF

cp /etc/default/neutron-server /etc/default/neutron-server.bak
echo "NEUTRON_PLUGIN_CONFIG=\"/etc/neutron/plugins/midonet/midonet.ini\"" > /etc/default/neutron-server

apt-get -qq install python-neutron-lbaas
apt-get -qq install python-neutron-fwaas
apt-get -qq install python-neutron-vpnaas

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/midonet/midonet.ini upgrade head" neutron
su -s /bin/sh -c "neutron-db-manage --subproject networking-midonet upgrade head" neutron

service neutron-server restart

#Horizon Installation
apt-get -qq install openstack-dashboard
mv /etc/openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py.bak
cp /tmp/local_settings.py /etc/openstack-dashboard/local_settings.py


service apache2 reload

#MidoNet Cluster Installation
apt-get -qq install midonet-tools midonet-cluster

mv /etc/midonet/midonet.conf /etc/midonet/midonet.conf.bak
cp /tmp/midonet.conf /etc/midonet/midonet.conf

 
cat << EOF | mn-conf set -t default
zookeeper {
zookeeper_hosts = "nsdb1:2181,nsdb2:2181,nsdb3:2181"
}
cassandra {
servers = "nsdb1,nsdb2,nsdb3"
}
EOF

echo "cassandra.replication_factor : 3" | mn-conf set -t default

cat << EOF | mn-conf set -t default
cluster.auth {
provider_class = "org.midonet.cluster.auth.keystone.KeystoneService"
admin_role = "admin"
keystone.tenant_name = "admin"
keystone.admin_token = "openstack"
keystone.host = controller
keystone.port = 35357
}
EOF

service midonet-cluster start

cat >> /root/.midonetrc <<RE_CONF
[cli]
api_url = http://controller:8181/midonet-api
username = admin
password = openstack
project_id = admin
RE_CONF

#Midonet Analytics
#apt-get -qy install midonet-cluster-mem
#service midonet-cluster restart
