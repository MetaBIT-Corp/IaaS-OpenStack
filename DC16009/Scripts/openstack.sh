#!/bin/bash

before_reboot(){
    yum install centos-release-openstack-queens -y
    yum upgrade -y
}

after_reboot(){
    yum install python-openstackclient openstack-selinux -y
#Instalar servicio de BD MariaDB [¿Solo nodo controlador?]
    yum install mariadb mariadb-server python2-PyMySQL
    touch /etc/my.cnf.d/openstack.cnf
    "[mysqld]" >> /etc/my.cnf.d/openstack.cnf
#Direccion IP de nodo controlador en donde esta la BD SQL
    "bind-address = 10.0.0.11" >> /etc/my.cnf.d/openstack.cnf
    "default-storage-engine = innodb" >> /etc/my.cnf.d/openstack.cnf
    "innodb_file_per_table = on" >> /etc/my.cnf.d/openstack.cnf
    "max_connections = 4096" >> /etc/my.cnf.d/openstack.cnf
    "collation-server = utf8_general_ci" >> /etc/my.cnf.d/openstack.cnf
    "character-set-server = utf8" >> /etc/my.cnf.d/openstack.cnf
#Finalizando instalacion de mariadb
    systemctl enable mariadb.service
    systemctl start mariadb.service
#Secure the db service
    mysql_secure_installation
#Message queue
    yum install rabbitmq-server -y
    systemctl enable rabbitmq-server.service
    systemctl start rabbitmq-server.service
#Add the openstack user
    rabbitmqctl add_user openstack RABBIT_PASS
#Config permisos para usuario openstack
    rabbitmqctl set_permissions openstack ".*" ".*" ".*"
#Memcached
    yum install memcached python-memcached
#Edit conf file
    sed -i 's/::1/::1,controller/g' /etc/sysconfig/memcached
    systemctl enable memcached.service
    systemctl start memcached.service
#Etcd
    yum install etcd -y
#Editando archivo de config
    sed -i 's/localhost/10.0.0.11/g' /etc/etcd/etcd.conf
    sed -i 's/default/controller/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_DATA_DIR/ETCD_DATA_DIR/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_LISTEN_PEER_URLS/ETCD_LISTEN_PEER_URLS/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_LISTEN_CLIENT_URLS/ETCD_LISTEN_CLIENT_URLS/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_NAME/ETCD_NAME/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_INITIAL_ADVERTISE_PEER_URLS/ETCD_INITIAL_ADVERTISE_PEER_URLS/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_ADVERTISE_CLIENT_URLS/ETCD_ADVERTISE_CLIENT_URLS/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_INITIAL_CLUSTER/ETCD_INITIAL_CLUSTER/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_INITIAL_CLUSTER_TOKEN/ETCD_INITIAL_CLUSTER_TOKEN/g' /etc/etcd/etcd.conf
    sed -i 's/#ETCD_INITIAL_CLUSTER_STATE/ETCD_INITIAL_CLUSTER_STATE/g' /etc/etcd/etcd.conf
    systemctl enable etcd
    systemctl start etcd
}

if[ -f /var/run/rebooting_for_updates ]; then
    after_reboot
    rm /var/run/rebooting_for_updates
    update-rc.d myupdate remove
else
    before_reboot
    touch /var/run/rebooting_for_updates
    update-rc.d myupdate defaults
    sudo reboot
fi
