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
}

function menu(){
	clear
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
	echo -e "\n 3. Generar credenciales Admin"
	echo -e "\n 4. Eliminar entorno de OpenStack"
	echo -e "\n 5. Abrir puertos de OpenStack"
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

verify_password(){
    echo -ne "\n\t\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña: ${endColour}" && read -s pass
    echo -ne "\n\t\t\t${yellowColour}[*]${endColour}${grayColour} Verificar contraseña: ${endColour}" && read -s verify_pass

    if [ $pass != $verify_pass ]; then
        echo -e "\n\t\t${redColour}[*] Las contraseñas no coinciden ${endColour}"
        verify_password
    fi
}

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

users_account(){
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

	echo -ne "\n\t${yellowColour}[*]${endColour}${grayColour} Configurando archivo demo-openrc con credenciales de administrador ${endColour}"
	verify_password
	demo_pass=$pass
	echo -e "export OS_PROJECT_DOMAIN_NAME=Default\
			\nexport OS_USER_DOMAIN_NAME=Default\
			\nexport OS_PROJECT_NAME=myproject\
			\nexport OS_USERNAME=myuser\
			\nexport OS_PASSWORD=${demo_pass}\
			\nexport OS_AUTH_URL=http://controller:5000/v3\
			\nexport OS_IDENTITY_API_VERSION=3\
			\nexport OS_IMAGE_API_VERSION=2" > admin-openrc
}

function verify_credentials(){
	echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese el usuario de Mariadb: ${endColour}" && read mariadb_user
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña de superusuario: ${endColour}" && read -s mariadb_user_pass
	mysql -u ${mariadb_user} -p${mariadb_user_pass} -e "show databases" > /dev/null 2>&1

	if [ "$(echo $?)" != "0" ]; then
		echo -e "\n\t\t${redColour}[*] Credenciales no válidas ${endColour}"
		verify_credentials
	fi
}

#param1: nombre de base de datos
#param2: usuario del a base de datos
#param3: en caso que se cree más de una base de datos se usa este paramentro para que no pida la contraseña cada vez
function oss_create_database(){
	if [ "$(echo $3)" != "1" ]; then
		verify_credentials
		echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando Base de datos ${1}${endColour}${yellowColour}...${endColour}"
		verify_password
	else
		echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando Base de datos ${1}${endColour}${yellowColour}...${endColour}"
	fi

	mysql -u ${mariadb_user} -p${mariadb_user_pass} -e "CREATE DATABASE ${1}";
	mysql -u ${mariadb_user} -p${mariadb_user_pass} -e "GRANT ALL PRIVILEGES ON ${1}.* TO '${2}'@'localhost' IDENTIFIED BY '${pass}'";
	mysql -u ${mariadb_user} -p${mariadb_user_pass} -e "GRANT ALL PRIVILEGES ON ${1}.* TO '${2}'@'%' IDENTIFIED BY '${pass}'";
}


#param1: dirección del archivo donde se desean buscar las secciones
#param@: array con las sección a buscar
function verify_sections(){
	dir=${1} && shift
	sections=("$@")

	for section in "${sections[@]}"; do
		egrep "^\[${section}\]$" ${dir} > /dev/null

		if [ "$(echo $?)" != "0" ]; then
			echo -e "[${section}]\n" >> ${dir}
		fi
	done
}

function oss_keystone(){
	keystone_dir=/etc/keystone/keystone.conf

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Keystone ${endColour}${yellowColour}...${endColour}"	
	oss_create_database keystone keystone
	db_pass=$pass
	
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Descargando e instalando paquetes ${endColour}${yellowColour}...${endColour}"
	yum install openstack-keystone httpd mod_wsgi -y > /dev/null 2>&1

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando archivos del servicio${endColour}${yellowColour}...${endColour}"; sleep 1
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

	users_account
}

oss_glance(){
	glance_api_dir=/etc/glance/glance-api.conf
	glance_api_registry=/etc/glance/glance-registry.conf

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Glance ${endColour}${yellowColour}...${endColour}"
	oss_create_database glance glance
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

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando archivos del servicio${endColour}${yellowColour}...${endColour}"; sleep 1
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
	oss_create_database placement placement
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

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando archivos del servicio${endColour}${yellowColour}...${endColour}"; sleep 1
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
	oss_create_database nova_api nova
	db_pass_nova_api=$pass
	
	echo
	oss_create_database nova nova 1
	db_pass_nova=$pass
	
	echo
	oss_create_database nova_cell0 nova 1
	db_pass_nova_cell=$pass

	source admin-openrc
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Creando credenciales del servicio ${endColour}${yellowColour}...${endColour}"
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

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Descargando e instalando paquetes de nova ${endColour}${yellowColour}...${endColour}"
	yum install openstack-nova-api openstack-nova-conductor openstack-nova-novncproxy openstack-nova-scheduler -y > /dev/null 2>&1

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando archivos del servicio${endColour}${yellowColour}...${endColour}"
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario openstack agregado a RabbitMQ: ${endColour}" && read -s pass_openstack_user
	echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la IP del controlador (management IP): ${endColour}" && read manag_ip
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
						\nserver_listen = \$my_ip\
						\nserver_proxyclient_address = \$my_ip" $nova_dir
	sed -i "/^\[glance\]$/a api_servers = http://controller:9292" $nova_dir
	sed -i "/^\[oslo_concurrency\]$/a lock_path = /var/lib/nova/tmp" $nova_dir
	echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario placement: ${endColour}" && read -s placement_pass
	sed -i "/^\[placement\]$/a region_name = RegionOne\
								\nproject_domain_name = Default\
								\nproject_name = service\
								\nauth_type = password\
								\nuser_domain_name = Default\
								\nauth_url = http://controller:5000/v3\
								\nusername = placement\
								\npassword = ${placement_pass}" $nova_dir

	echo "<Directory /usr/bin>\
		   \n<IfVersion >= 2.4>\
		    \n  Require all granted\
		   \n</IfVersion>\
		   \n<IfVersion < 2.4>\
		    \n  Order allow,deny\
		    \n  Allow from all\
		   \n</IfVersion>\
		\n</Directory>" >> /etc/httpd/conf.d/00-placement-api.conf
	
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos nova-api ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage api_db sync" nova > /dev/null 2>&1
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Registrado base de datos cell0 ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova > /dev/null 2>&1
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Creando celda cell1 ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova > /dev/null 2>&1
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos nova ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage db sync" nova > /dev/null 2>&1
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Verificando registro de cell0 y cell1 ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de nova ${endColour}${yellowColour}...${endColour}"
	systemctl enable openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service > /dev/null 2>&1
	systemctl start openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service > /dev/null 2>&1

	echo -e "\n\t${redColour}[*]${endColour}${yellowColour} Asegurese de haber instalado nova en el nodo computo, presione enter para continuar ${endColour}${yellowColour}...${endColour}" && read -n 1 one_key
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Agregando nodo de computo a la base de datos cell ${endColour}${yellowColour}...${endColour}"
	source admin-openrc
	openstack compute service list --service nova-compute
	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Buscando nodos de computo ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
	sed -i "/^\[scheduler\]$/a discover_hosts_in_cells_interval = 300" $nova_dir
}

oss_neutron(){
	neutron_dir=/etc/neutron/neutron.conf
	nova_dir=/etc/nova/nova.conf
	ml2_dir=/etc/neutron/plugins/ml2/ml2_conf.ini
	linux_bridge_dir=/etc/neutron/plugins/ml2/linuxbridge_agent.ini
	l3_agent_dir=/etc/neutron/l3_agent.ini
	dhcp_agent_dir=/etc/neutron/dhcp_agent.ini
	metadata_agent_dir=/etc/neutron/metadata_agent.ini

	neutron_sections=(database DEFAULT keystone_authtoken nova oslo_concurrency)
	nova_sections=(neutron)
	ml2_sections=(ml2 ml2_type_flat ml2_type_vxlan securitygroup)
	linux_bridge_sections=(linux_bridge vxlan securitygroup)
	l3_agent_sections=(DEFAULT)
	dhcp_agent_sections=(DEFAULT)
	metadata_agent_sections=(DEFAULT)

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Neutron ${endColour}${yellowColour}...${endColour}"
	oss_create_database neutron neutron
	db_pass=$pass

	source admin-openrc
	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour} Creando credenciales del servicio ${endColour}${yellowColour}...${endColour}"
	echo -e "\t\t\t${yellowColour}[*]${endColour}${grayColour} Creando usuario neutron ${endColour}${yellowColour}...${endColour}"
	openstack user create --domain default --password-prompt neutron
	echo -e "\t\t\t${yellowColour}[*]${endColour}${grayColour} Agregando rol admin al usuario neutron ${endColour}${yellowColour}...${endColour}"
	openstack role add --project service --user neutron admin
	echo -e "\t\t\t${yellowColour}[*]${endColour}${grayColour} Creando el servicio de entidad neutron ${endColour}${yellowColour}...${endColour}"
	openstack service create --name neutron --description "OpenStack Networking" network

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Creando endpoints del servicio API Networking ${endColour}${yellowColour}...${endColour}"
	openstack endpoint create --region RegionOne network public http://controller:9696
	openstack endpoint create --region RegionOne network internal http://controller:9696
	openstack endpoint create --region RegionOne network admin http://controller:9696

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Networking opción 2: Self-service - Descargando e instalando paquetes${endColour}${yellowColour}...${endColour}"
	yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables -y > /dev/null 2>&1

	verify_sections ${neutron_dir} ${neutron_sections[@]}
	verify_sections ${nova_dir} ${nova_sections[@]}
	verify_sections ${ml2_dir} ${ml2_sections[@]}
	verify_sections ${linux_bridge_dir} ${linux_bridge_sections[@]}
	verify_sections ${l3_agent_dir} ${l3_agent_sections[@]}
	verify_sections ${dhcp_agent_dir} ${dhcp_agent_sections[@]}
	verify_sections ${metadata_agent_dir} ${metadata_agent_sections[@]}

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando componentes del servicio${endColour}${yellowColour}...${endColour}"
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario openstack agregado a RabbitMQ: ${endColour}" && read -s pass_openstack_user
	sed -i "/^\[database\]$/a connection = mysql+pymysql://neutron:${db_pass}@controller/neutron" $neutron_dir
	sed -i "/^\[DEFAULT\]$/a core_plugin = ml2\
							\nservice_plugins = router\
							\nallow_overlapping_ips = true\
							\ntransport_url = rabbit://openstack:${pass_openstack_user}@controller\
							\nauth_strategy = keystone\
							\nnotify_nova_on_port_status_changes = true\
							\nnotify_nova_on_port_data_changes = true" $neutron_dir

	echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario neutron: ${endColour}" && read -s neutron_pass
	sed -i "/^\[keystone_authtoken\]$/a www_authenticate_uri = http://controller:5000\
										\nauth_url = http://controller:5000\
										\nmemcached_servers = controller:11211\
										\nauth_type = password\
										\nproject_domain_name = default\
										\nuser_domain_name = default\
										\nproject_name = service\
										\nusername = neutron\
										\npassword = ${neutron_pass}" $neutron_dir

	echo -ne "\n\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la contraseña del usuario nova: ${endColour}" && read -s nova_pass
	sed -i "/^\[nova\]$/a auth_url = http://controller:5000\
							\nauth_type = password\
							\nproject_domain_name = default\
							\nuser_domain_name = default\
							\nregion_name = RegionOne\
							\nproject_name = service\
							\nusername = nova\
							\npassword = ${nova_pass}" $neutron_dir
	sed -i "/^\[oslo_concurrency\]$/a lock_path = /var/lib/neutron/tmp" $neutron_dir

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour}Configurando módulo de capa 2 ${endColour}${yellowColour}...${endColour}"; sleep 1
	sed -i "/^\[ml2\]$/a type_drivers = flat,vlan,vxlan\
						\ntenant_network_types = vxlan\
						\nmechanism_drivers = linuxbridge,l2population\
						\nextension_drivers = port_security" $ml2_dir
	sed -i "/^\[ml2_type_flat\]$/a flat_networks = provider" $ml2_dir
	sed -i "/^\[ml2_type_vxlan\]$/a vni_ranges = 1:1000" $ml2_dir
	sed -i "/^\[securitygroup\]$/a enable_ipset = true" $ml2_dir

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour}Configurando el linux bridge agent ${endColour}${yellowColour}...${endColour}"
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese el nombre de la interfaz de red provider: ${endColour}" && read provider_interface
	sed -i "/^\[linux_bridge\]$/a physical_interface_mappings = provider:${provider_interface}" $linux_bridge_dir
	echo -ne "\t\t${yellowColour}[*]${endColour}${grayColour} Ingrese la IP del controlador (management IP): ${endColour}" && read manag_ip
	sed -i "/^\[vxlan\]$/a enable_vxlan = true\
							\nlocal_ip = ${manag_ip}\
							\nl2_population = true" $linux_bridge_dir
	sed -i "/^\[securitygroup\]$/a enable_security_group = true\
									\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" $linux_bridge_dir
	modprobe br_netfilter

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour}Configurando agente de capa 3 ${endColour}${yellowColour}...${endColour}"; sleep 1
	sed -i "/^\[DEFAULT\]$/a interface_driver = linuxbridge" $l3_agent_dir

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour}Configurando agente DHCP ${endColour}${yellowColour}...${endColour}"; sleep 1
	sed -i "/^\[DEFAULT\]$/a interface_driver = linuxbridge\
							\ndhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\
							\nenable_isolated_metadata = true" $dhcp_agent_dir

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour}Configurando agente de metadata ${endColour}${yellowColour}...${endColour}"; sleep 1
	verify_password
	metadata_pass=$pass
	sed -i "/^\[DEFAULT\]$/a nova_metadata_host = controller\
							\nmetadata_proxy_shared_secret = ${metadata_pass}" $metadata_agent_dir

	echo -e "\n\t\t${yellowColour}[*]${endColour}${grayColour}Configurando servicio de computo para usar el servicio de red ${endColour}${yellowColour}...${endColour}"; sleep 1
	sed -i "/^\[neutron\]$/a url = http://controller:9696\
							\nauth_url = http://controller:5000\
							\nauth_type = password\
							\nproject_domain_name = default\
							\nuser_domain_name = default\
							\nregion_name = RegionOne\
							\nproject_name = service\
							\nusername = neutron\
							\npassword = ${neutron_pass}\
							\nservice_metadata_proxy = true\
							\nmetadata_proxy_shared_secret = ${metadata_pass}" $nova_dir
	
	ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Llenando Base de datos neutron ${endColour}${yellowColour}...${endColour}"
	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron > /dev/null 2>&1

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Iniciando servicios de neutron ${endColour}${yellowColour}...${endColour}"
	systemctl restart openstack-nova-api.service > /dev/null 2>&1
	systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service > /dev/null 2>&1
	systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service > /dev/null 2>&1
	systemctl enable neutron-l3-agent.service > /dev/null 2>&1
	systemctl start neutron-l3-agent.service > /dev/null 2>&1

}

function oss_horizon(){
	horizon_dir=/etc/openstack-dashboard/local_settings
	horizon_httpd_dir=/etc/httpd/conf.d/openstack-dashboard.conf

	echo -e "\t${yellowColour}[*]${endColour}${blueColour} Instalando Horizon ${endColour}${yellowColour}...${endColour}"

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Descargando e instalando paquetes de Horizon${endColour}${yellowColour}...${endColour}"
	yum install openstack-dashboard -y > /dev/null 2>&1

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Configurando archivos del servicio${endColour}${yellowColour}...${endColour}"; sleep 1
	sed -i "/OPENSTACK_HOST =/c\OPENSTACK_HOST = \"controller\"" $horizon_dir
	sed -i "/ALLOWED_HOSTS =/c\ALLOWED_HOSTS = ['*']" $horizon_dir
	sed -i "/SESSION_ENGINE =/a SESSION_ENGINE = 'django.contrib.sessions.backends.cache'\
\
								\n\nCACHES = {\
								\n    'default': {\
								\n         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',\
								\n         'LOCATION': 'controller:11211',\
								\n    }\
								\n}" $horizon_dir
	sed -i "/OPENSTACK_KEYSTONE_URL =/c\OPENSTACK_KEYSTONE_URL = \"http://%s:5000/v3\" % OPENSTACK_HOST" $horizon_dir
	sed -i "/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT =/a OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" $horizon_dir
	sed -i "/OPENSTACK_API_VERSIONS =/a OPENSTACK_API_VERSIONS = {\
										\n    \"identity\": 3,\
										\n    \"image\": 2,\
										\n    \"volume\": 3,\
										\n}" $horizon_dir
	sed -i "/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN =/a OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"Default\"" $horizon_dir
	sed -i "/OPENSTACK_KEYSTONE_DEFAULT_ROLE =/c\OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"" $horizon_dir
	sed -i "/TIME_ZONE =/c\TIME_ZONE = \"UTC\"" $horizon_dir
	sed -i "4i WSGIApplicationGroup %{GLOBAL}" $horizon_httpd_dir

	echo -e "\t\t${yellowColour}[*]${endColour}${grayColour} Reiniciando servicios ${endColour}${yellowColour}...${endColour}"
	systemctl restart httpd.service memcached.service > /dev/null 2>&1
}

#------------------------------------------------------------OTHER_FUNCTIONS-------------------------------------------------------------
of_open_openstack_ports(){
	echo -e "${yellowColour}[*]${endColour}${blueColour} Abriendo puertos de OpenStack ${endColour}${yellowColour}...${endColour}"
	firewall-cmd --permanent --add-port={2380/tcp,5672/tcp,5000/tcp,8778/tcp,9292/tcp,6080/tcp,11211/tcp,9696/tcp,80/tcp} > /dev/null 2>&1
	firewall-cmd --reload > /dev/null 2>&1

	echo -e "\t${yellowColour}[*]${endColour}${grayColour}Información del firewall: ${endColour}\n"
	firewall-cmd --list-all
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
			oss_keystone
			oss_glance
			oss_placement
			oss_nova
			oss_neutron
			oss_horizon
			;;

		3) users_account ;;

		4) remove_enviroment ;;

		5) of_open_openstack_ports ;;

		*) echo -e "\n${redColour}[*] Opción no válida${endColour}" ;;
	esac
	echo
else
	echo -e "\n${redColour}[*] No eres usuario root${endColour}\n"
fi

: '
Por hacer
1. Verificar mensajes donde pide ip y pass
2. Validar existencia de secciones
3. Validar que br_netfilter sea 1
4. Verificar dependencias'
