#!/bin/bash

#Autor: Enrique Menjívar

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function ctrl_c(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Saliendo...${endColour}"; sleep 1
	tput cnorm
	exit 0
}

function menu(){
	echo -e "\n 1. Enviroment"
	echo -e "\t- Networking Time Protocol (NTP)"
	echo -e "\t- OpenStack packeges"
	echo -e "\t- SQL Database (MariaDB)"
	echo -e "\t- Message queue (RabbitMQ)"
	echo -e "\t- Memcached"
	echo -e "\n 2. OpenStack services"
	echo -e "\t- Keystone"
	echo -e "\t- Glance"
	echo -e "\t- Placement"
	echo -e "\t- Nova"
	echo -e "\t- Neutron"
	echo -e "\t- Horizon"
	echo -e "\n 3. Generar credenciales Admin\n"
	echo -e "\n 4. Eliminar entorno de OpenStack\n"
}

verify_password(){
    echo -ne "\n\t\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña: ${endColour}" && read -s pass
    echo -ne "\n\t\t\t${yellowColour}[*]${endColour}${grayColour} Verificar contraseña: ${endColour}" && read -s verify_pass

    if [ $pass != $verify_pass ]; then
        echo -e "\n\t\t${redColour}[*] Las contraseñas no coinciden ${endColour}"
        verify_password
    fi
}

administrative_account(){
	echo -ne "\n\t${yellowColour}[*]${endColour}${grayColour} Configurando archivo admin-openrc con credenciales de administrador ${endColour}"
	verify_password
	admin_pass=$pass
	echo -e "export OS_PROJECT_DOMAIN_NAME=Default\
			\nexport OS_USER_DOMAIN_NAME=Default\
			\nexport OS_PROJECT_NAME=admin\
			\nexport OS_USERNAME=admin\
			\nexport OS_PASSWORD=${admin_pass}\
			\nexport OS_AUTH_URL=http://controller:5000/v3\
			\nexport OS_IDENTITY_API_VERSION=3\
			\nexport OS_IMAGE_API_VERSION=2" > admin-openrc
}

remove_enviroment(){
	clear
	echo -ne "\n\t${yellowColour}[*]${endColour}${grayColour} Eliminando NTP ${endColour}${yellowColour}...${endColour}"
	yum remove chrony -y > /dev/null 2>&1
	echo -ne "\n\t${yellowColour}[*]${endColour}${grayColour} Eliminando RabbitMQ ${endColour}${yellowColour}...${endColour}"
	yum remove rabbitmq-server -y > /dev/null 2>&1
	echo -ne "\n\t${yellowColour}[*]${endColour}${grayColour} Eliminando Memcached ${endColour}${yellowColour}...${endColour}"
	yum remove memcached python-memcached -y > /dev/null 2>&1
	echo -ne "\n\t${yellowColour}[*]${endColour}${grayColour} Eliminando ETCD ${endColour}${yellowColour}...${endColour}"	
	yum remove etcd -y > /dev/null 2>&1
}


#------------------------------------------------------------OPENSTACK_EVIROMENT-------------------------------------------------------------

function enviroment_ntp(){
	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando NTP ${endColour}${yellowColour}...${endColour}"
	yum install chrony -y > /dev/null 2>&1
	sleep 1

	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} ¿Desea configurar NTP (s/n)? ${endColour}" && read config_ntp
	if [ $config_ntp == "s" ]; then
		chrony_dir=/etc/chrony.conf
		echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese el servidor NTP (info: http://www.pool.ntp.org/join.html) ${endColour}" && read ntp_server
		sed -i "/server/d" $chrony_dir
		sed -i "3i server ${ntp_server} iburst" $chrony_dir

		echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la IP de la red (Ej. 10.0.0.0/24) ${endColour}" && read network_ip
		line_number=$(grep -n "allow" $chrony_dir | cut -d ':' -f '1')
		sed -i "${line_number}i allow ${network_ip}" $chrony_dir

		systemctl enable chronyd.service > /dev/null 2>&1
		systemctl start chronyd.service > /dev/null 2>&1
	fi

	echo	
}

function enviroment_openstack_packeges(){
	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando paquetes de OpenStack ${endColour}${yellowColour}...${endColour}"
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Instalando de OpenStack Stein ${endColour}${yellowColour}...${endColour}"
	yum install centos-release-openstack-stein -y > /dev/null 2>&1
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Actualizando repositorios ${endColour}${yellowColour}...${endColour}"
	yum upgrade	-y > /dev/null 2>&1
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Instalando openstack client ${endColour}${yellowColour}...${endColour}"
	yum install python-openstackclient -y > /dev/null 2>&1
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Instalando openstack-selinux ${endColour}${yellowColour}...${endColour}"
	yum install openstack-selinux -y > /dev/null 2>&1

	echo
}

function enviroment_mariadb(){
	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando MariaDB ${endColour}${yellowColour}...${endColour}"
	yum install mariadb mariadb-server python2-PyMySQL -y > /dev/null 2>&1

	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la IP del controlador (management IP) ${endColour}" && read mar_manag_ip
	echo -e "[mysqld] \
			\nbind-address=${mar_manag_ip} \
			\n\ndefault-storage-engine = innodb \
			\ninnodb_file_per_table = on \
			\nmax_connections = 4096 \
			\ncollation-server = utf8_general_ci \
			\ncharacter-set-server = utf8" > /etc/my.cnf.d/openstack.cnf

	systemctl enable mariadb.service > /dev/null 2>&1
	systemctl start mariadb.service > /dev/null 2>&1

	mysql_secure_installation

	echo
}

function enviroment_message_queue(){
	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando RabbitMQ ${endColour}${yellowColour}...${endColour}"
	yum install rabbitmq-server -y > /dev/null 2>&1

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de RabbitMQ ${endColour}${yellowColour}...${endColour}"
	systemctl enable rabbitmq-server.service > /dev/null 2>&1
	systemctl start rabbitmq-server.service > /dev/null 2>&1

	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Contraseña para el usuario openstack ${endColour}"
	verify_password
	pass_rabbitmq_user=$pass
	rabbitmqctl add_user openstack $pass_rabbitmq_user > /dev/null 2>&1
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando usuario openstack ${endColour}${yellowColour}...${endColour}"
	rabbitmqctl set_permissions openstack ".*" ".*" ".*" > /dev/null 2>&1

	echo
}

function enviroment_memcached(){
	memcached_dir=/etc/sysconfig/memcached
	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Memcached ${endColour}${yellowColour}...${endColour}"
	yum install memcached python-memcached -y > /dev/null 2>&1

	sed -i "/OPTIONS/d" $memcached_dir
	echo -e "OPTIONS=\"-l 127.0.0.1,::1,controller\"" >> $memcached_dir

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de Memcached ${endColour}${yellowColour}...${endColour}"
	systemctl enable memcached.service > /dev/null 2>&1
	systemctl start memcached.service > /dev/null 2>&1

	echo
}

function enviroemnte_etcd(){
	etcd_dir=/etc/etcd/etcd.conf
	
	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Etcd ${endColour}${yellowColour}...${endColour}"	
	yum install etcd -y > /dev/null 2>&1

	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la IP del controlador (management IP) ${endColour}" && read controller_ip

	sed -i "/ETCD_LISTEN_PEER_URLS=/c\ETCD_LISTEN_PEER_URLS=\"http://${controller_ip}:2380\"" $etcd_dir
	sed -i "/ETCD_LISTEN_CLIENT_URLS=/c\ETCD_LISTEN_CLIENT_URLS=\"http://${controller_ip}:2379\"" $etcd_dir
	sed -i "/ETCD_NAME=/c\ETCD_NAME=\"controller\"" $etcd_dir

	sed -i "/ETCD_INITIAL_ADVERTISE_PEER_URLS=/c\ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://${controller_ip}:2380\"" $etcd_dir
	sed -i "/ETCD_ADVERTISE_CLIENT_URLS=/c\ETCD_ADVERTISE_CLIENT_URLS=\"http://${controller_ip}:2379\"" $etcd_dir
	sed -i "/ETCD_INITIAL_CLUSTER=/c\ETCD_INITIAL_CLUSTER=\"controller=http://${controller_ip}:2380\"" $etcd_dir
	sed -i "/ETCD_INITIAL_CLUSTER_TOKEN=/c\ETCD_INITIAL_CLUSTER_TOKEN=\"etcd-cluster-01\"" $etcd_dir
	sed -i "/ETCD_INITIAL_CLUSTER_STATE=/c\ETCD_INITIAL_CLUSTER_STATE=\"new\"" $etcd_dir

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de ETCD ${endColour}${yellowColour}...${endColour}"
	systemctl enable etcd > /dev/null 2>&1
	systemctl start etcd > /dev/null 2>&1

	echo
}


#------------------------------------------------------------OPENSTACK_SERVICE-------------------------------------------------------------

function oss_create_database(){
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña de superusuario: ${endColour}" && read -s root_pass
	echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando Base de datos ${1}${endColour}${yellowColour}...${endColour}"
	verify_password

	mysql -u root -p${root_pass} -e "CREATE DATABASE ${1}";
	mysql -u root -p${root_pass} -e "GRANT ALL PRIVILEGES ON ${1}.* TO '${1}'@'localhost' IDENTIFIED BY '${pass}'";
	mysql -u root -p${root_pass} -e "GRANT ALL PRIVILEGES ON ${1}.* TO '${1}'@'%' IDENTIFIED BY '${pass}'";
}

function oss_keystone(){
	keystone_dir=/etc/keystone/keystone.conf

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Keystone ${endColour}${yellowColour}...${endColour}"	
	oss_create_database keystone
	db_pass=$pass
	
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Descargando e instalando paquetes ${endColour}${yellowColour}...${endColour}"
	yum install openstack-keystone httpd mod_wsgi -y > /dev/null 2>&1

	sed -i "/^\[database\]$/a connection = mysql+pymysql://keystone:${db_pass}@controller/keystone" $keystone_dir
	sed -i "/^\[token\]$/a provider = fernet" $keystone_dir

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos Keystone ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "keystone-manage db_sync" keystone

	keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
	keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando contraseña para el administrador de keystone ${endColour}${yellowColour}...${endColour}"
	verify_password
	keystone_pass=$pass

	keystone-manage bootstrap --bootstrap-password $keystone_pass \
	  --bootstrap-admin-url http://controller:5000/v3/ \
	  --bootstrap-internal-url http://controller:5000/v3/ \
	  --bootstrap-public-url http://controller:5000/v3/ \
	  --bootstrap-region-id RegionOne

	line_number=$(grep -n "ServerName" /etc/httpd/conf/httpd.conf | cut -d ':' -f '1' | tr '\n' ' ' | cut -d ' ' -f '2')
	sed -i "${line_number}i ServerName controller" /etc/httpd/conf/httpd.conf
	#sed -i "/#ServerName/a ServerName controller" /etc/httpd/conf/httpd.conf

	ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de keystone ${endColour}${yellowColour}...${endColour}"
	systemctl enable httpd.service > /dev/null 2>&1
	systemctl start httpd.service > /dev/null 2>&1

	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando credenciales de administrador ${endColour}"
	echo -e "export OS_USERNAME=admin\
				\nexport OS_PASSWORD=${keystone_pass}\
				\nexport OS_PROJECT_NAME=admin\
				\nexport OS_USER_DOMAIN_NAME=Default\
				\nexport OS_PROJECT_DOMAIN_NAME=Default\
				\nexport OS_AUTH_URL=http://controller:5000/v3\
				\nexport OS_IDENTITY_API_VERSION=3" > admin-openrc
	source admin-openrc

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando dominio, usuarios y roles ${endColour}${yellowColour}...${endColour}"
	openstack domain create --description "An Example Domain" example
	openstack project create --domain default --description "Service Project" service
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando proyecto myproject ${endColour}${yellowColour}...${endColour}"
	openstack project create --domain default --description "Demo Project" myproject
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando usuario myuser ${endColour}${yellowColour}...${endColour}"
	openstack user create --domain default --password-prompt myuser
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando rol myrole ${endColour}${yellowColour}...${endColour}"
	openstack role create myrole
	openstack role add --project myproject --user myuser myrole

	administrative_account
}

oss_glance(){
	glance_api_dir=/etc/glance/glance-api.conf
	glance_api_registry=/etc/glance/glance-registry.conf

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Glance ${endColour}${yellowColour}...${endColour}"
	oss_create_database glance
	db_pass=$pass

	source admin-openrc
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando credenciales del servicio ${endColour}${yellowColour}...${endColour}"
	echo -e "\t\t\t${yellowColour}[*]${endColour}${grayColour} Creando usuario glance ${endColour}${yellowColour}...${endColour}"
	openstack user create --domain default --password-prompt glance
	openstack role add --project service --user glance admin
	openstack service create --name glance --description "OpenStack Image" image

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Creando endpoints del servicio ${endColour}${yellowColour}...${endColour}"
	openstack endpoint create --region RegionOne image public http://controller:9292
	openstack endpoint create --region RegionOne image internal http://controller:9292
	openstack endpoint create --region RegionOne image admin http://controller:9292

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Descargando e instalando paquetes ${endColour}${yellowColour}...${endColour}"
	yum install openstack-glance -y > /dev/null 2>&1

	sed -i "/^\[database\]$/a connection = mysql+pymysql://glance:${db_pass}@controller/glance" $glance_api_dir
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario glance: ${endColour}" && read -s glance_pass
	sed -i "/^\[keystone_authtoken\]$/a www_authenticate_uri  = http://controller:5000\
										\nauth_url = http://controller:5000\
										\nmemcached_servers = controller:11211\
										\nauth_type = password\
										\nproject_domain_name = Default\
										\nuser_domain_name = Default\
										\nproject_name = service\
										\nusername = glance\
										\npassword = ${glance_pass}" $glance_api_dir
	sed -i "/^\[paste_deploy\]$/a flavor = keystone" $glance_api_dir
	sed -i "/^\[glance_store\]$/a stores = file,http\
								\ndefault_store = file\
								\nfilesystem_store_datadir = /var/lib/glance/images/" $glance_api_dir

	sed -i "/^\[database\]$/a connection = mysql+pymysql://glance:${db_pass}@controller/glance" $glance_api_registry
	sed -i "/^\[keystone_authtoken\]$/a www_authenticate_uri = http://controller:5000\
										\nauth_url = http://controller:5000\
										\nmemcached_servers = controller:11211\
										\nauth_type = password\
										\nproject_domain_name = Default\
										\nuser_domain_name = Default\
										\nproject_name = service\
										\nusername = glance\
										\npassword = ${glance_pass}" $glance_api_registry
	sed -i "/^\[paste_deploy\]$/a flavor = keystone" $glance_api_registry

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos glance ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "glance-manage db_sync" glance > /dev/null 2>&1

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de glance ${endColour}${yellowColour}...${endColour}"
	systemctl enable openstack-glance-api.service openstack-glance-registry.service > /dev/null 2>&1
	systemctl start openstack-glance-api.service openstack-glance-registry.service > /dev/null 2>&1

	
}

oss_placement(){
	placement_dir=/etc/placement/placement.conf

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Placement ${endColour}${yellowColour}...${endColour}"
	oss_create_database placement
	db_pass=$pass

	source admin-openrc
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando usuario de servicio placement ${endColour}${yellowColour}...${endColour}"
	openstack user create --domain default --password-prompt placement
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Agregando usuario placement al proyecto de servicio ${endColour}${yellowColour}...${endColour}"
	openstack role add --project service --user placement admin
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Creando API de placement ${endColour}${yellowColour}...${endColour}"
	openstack service create --name placement --description "Placement API" placement
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando endpoints del servicio API de placement ${endColour}${yellowColour}...${endColour}"
	openstack endpoint create --region RegionOne placement public http://controller:8778
	openstack endpoint create --region RegionOne placement internal http://controller:8778
	openstack endpoint create --region RegionOne placement admin http://controller:8778

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Descargando e instalando paquetes de placement ${endColour}${yellowColour}...${endColour}"
	yum install openstack-placement-api -y > /dev/null 2>&1

	sed -i "/^\[placement_database\]$/a connection = mysql+pymysql://placement:${db_pass}@controller/placement" $placement_dir
	sed -i "/^\[api\]$/a auth_strategy = keystone" $placement_dir
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario placement: ${endColour}" && read -s placement_pass
	sed -i "/^\[keystone_authtoken\]$/a auth_url = http://controller:5000/v3\
										\nmemcached_servers = controller:11211\
										\nauth_type = password\
										\nproject_domain_name = Default\
										\nuser_domain_name = Default\
										\nproject_name = service\
										\nusername = placement\
										\npassword = ${placement_pass}" $placement_dir

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos placement ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "placement-manage db sync" placement > /dev/null 2>&1

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Reiniciando servicios ${endColour}${yellowColour}...${endColour}"
	systemctl restart httpd > /dev/null 2>&1

}

oss_nova(){
	nova_dir=/etc/nova/nova.conf

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Nova ${endColour}${yellowColour}...${endColour}"
	oss_create_database nova_api
	db_pass_nova_api=$pass
	
	oss_create_database nova
	db_pass_nova=$pass
	
	oss_create_database nova_cell0
	db_pass_nova_cell=$pass

	source admin-openrc
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando credenciales del servicio ${endColour}${yellowColour}...${endColour}"
	echo -e "\t\t\t${yellowColour}[*]${endColour}${grayColour} Creando usuario nova ${endColour}${yellowColour}...${endColour}"
	openstack user create --domain default --password-prompt nova
	echo -e "\t\t\t${yellowColour}[*]${endColour}${grayColour} Agregando rol admin al usuario nova ${endColour}${yellowColour}...${endColour}"
	openstack role add --project service --user nova admin
	echo -e "\t\t\t${yellowColour}[*]${endColour}${grayColour} Creando el servicio de entidad nova ${endColour}${yellowColour}...${endColour}"
	openstack service create --name nova --description "OpenStack Compute" compute

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Creando endpoints del servicio API de compute ${endColour}${yellowColour}...${endColour}"
	openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
	openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
	openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Descargando e instalando paquetes de nova ${endColour}${yellowColour}...${endColour}"
	yum install openstack-nova-api openstack-nova-conductor openstack-nova-novncproxy openstack-nova-scheduler -y > /dev/null 2>&1

	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario openstack agregado a RabbitMQ: ${endColour}" && read -s pass_openstack_user
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la IP del controlador (management IP) ${endColour}" && read manag_ip
	sed -i "/^\[DEFAULT\]$/a enabled_apis = osapi_compute,metadata\
							\ntransport_url = rabbit://openstack:${pass_openstack_user}@controller:5672/\
							\nmy_ip = ${manag_ip}\
							\nuse_neutron = true\
							\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver" $nova_dir
	sed -i "/^\[api_database\]$/a connection = mysql+pymysql://nova:${db_pass_nova_api}@controller/nova_api" $nova_dir
	sed -i "/^\[database\]$/a connection = mysql+pymysql://nova:${db_pass_nova}@controller/nova" $nova_dir
	sed -i "/^\[api\]$/a auth_strategy = keystone" $nova_dir

	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario nova: ${endColour}" && read -s nova_pass
	sed -i "/^\[keystone_authtoken\]$/a www_authenticate_uri = http://controller:5000/\
										\nauth_url = http://controller:5000/\
										\nmemcached_servers = controller:11211\
										\nauth_type = password\
										\nproject_domain_name = Default\
										\nuser_domain_name = Default\
										\nproject_name = service\
										\nusername = nova\
										\npassword = ${nova_pass}" $nova_dir
	sed -i "/^\[vnc\]$/a enabled = true\
						\nserver_listen = $my_ip\
						\nserver_proxyclient_address = $my_ip" $nova_dir
	sed -i "/^\[glance\]$/a api_servers = http://controller:9292" $nova_dir
	sed -i "/^\[oslo_concurrency\]$/a lock_path = /var/lib/nova/tmp" $nova_dir
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario placement: ${endColour}" && read -s placement_pass
	sed -i "/^\[placement\]$/a region_name = RegionOne\
								project_domain_name = Default\
								project_name = service\
								auth_type = password\
								user_domain_name = Default\
								auth_url = http://controller:5000/v3\
								username = placement\
								password = ${placement_pass}" $nova_dir

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos nova-api ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage api_db sync" nova > /dev/null 2>&1
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Registrado base de datos cell0 ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova > /dev/null 2>&1
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando celda cell1 ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova > /dev/null 2>&1
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos nova ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage db sync" nova > /dev/null 2>&1
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Verificando registro de cell0 y cell1 ${endColour}${yellowColour}...${endColour}"

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de nova ${endColour}${yellowColour}...${endColour}"
	systemctl enable openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service > /dev/null 2>&1
	systemctl start openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service > /dev/null 2>&1

}

# Main Function

if [ "$(id -u)" == "0" ]; then
	
	menu
	echo -ne "Ingrese una opción: " && read option

	clear
	case $option in
		1) echo -e " ${yellowColour}[*]${endColour}${grayColour} Preparando entorno de OpenStack ${endColour}${yellowColour}...${endColour}"
			enviroment_ntp
			enviroment_openstack_packeges
			enviroment_mariadb
			enviroment_message_queue 
			enviroment_memcached
			enviroemnte_etcd 
			;;
		
		2) echo -e " ${yellowColour}[*]${endColour}${grayColour} Instalando servicios de OpenStack ${endColour}${yellowColour}...${endColour}"
			#oss_keystone
			#oss_glance
			#oss_placement
			oss_nova
			;;

		3) administrative_account ;;

		4) remove_enviroment ;;

		*) echo -e "\n${redColour}[*] Opción no válida${endColour}" ;;
	esac
	echo
else
	echo -e "\n${redColour}[*] No eres usuario root${endColour}\n"
fi

: '
Por hacer
1. Validar ingreso de usuario root
2. Verificar estandar de mensajes en cada servicio'