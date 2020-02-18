#!/bin/bash
clear
opciones="Obtener_Credenciales_Admin Install_Controller_Node Install_Compute_Node Salir"


# Verificacion de instalacion correcta de servicios en el nodo de computo
# param $1 Directorio a verificar
# param $2 Archivo a verificar
# return int Retorna 0 si falla la verificacion y 1 si es un exito
function verifyServiceInstall {
	if [[ -d $1 ]]; then #Verifica si el directorio esta creado o existe
		if [[ -f $2 ]]; then #Verifica si el archivo existe
			return 1
		else
			return 0
		fi	
	else
		return 0
	fi
}

# Funcion que sirve para la validacion de cualquier contraseña
# param $1 Mensaje a mostrar al usuario
# return null
function enterPassword {
	# Lectura de contraseña de usuario OPENSTACK en RABBITMQ
	echo -e "$1"
	read -s password
	echo -e "\nVerifique la contraseña:"
	read -s verify_password
	while [[ $password != $verify_password ]]; do
		clear
		echo -e "\e[0;36m--- Nodo de Computo ---\e[0m\nInstacion de Nova Service\n"
		echo -e "--NO COINCIDIERON LAS CONTRASEÑAS--\nIngrese nuevamente la contraseña"
		read -s password
		echo -e "\nVerifique la contraseña:"
		read -s verify_password
	done
}

# Funcion para la modificacion de archivos para instalacion de NOVA en nodo de computo
# param $1 IP del nodo actual
# return null
function novaCompute {

	# SUSTITUIR CON RUTA DE nova.conf --> se usa ruta actual para pruebas
	novaConfDir=/etc/nova/nova.conf


	echo -e "\nIniciando cambios en nova.conf ..."
	sed -i "1 a enabled_apis=osapi_compute,metadata\ntransport_url = rabbit://openstack:$password@controller\nmy_ip = $2\nuse_neutron = true\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver" $novaConfDir
	

	#####[api]#####
	#Guardamos el resultado del comando grep que busca la cadena [api] y con la opcion n nos arroja el numero de linea
	#En el que se encuentra la unica coincidencia
	cadena=$(grep -n "\[api\]$" $novaConfDir)

	#Se extrae la subcadena que contiene el numero de linea de la coincidencia
	num_linea=${cadena/:\[api\]/}  #Se usa let para asegurarse que se convierta como numero

	#Se agrega bajo el numero de la linea indicada
	sed -i "$num_linea a auth_strategy = keystone" $novaConfDir

	#####[keystone_authtoken]#####
	cadena=$(grep -n "\[keystone_authtoken\]$" $novaConfDir)

	num_linea=${cadena/:\[keystone_authtoken\]/}

	enterPassword "\nIngrese la constraseña del usurio nova:"

	#Se agrega bajo el numero de la linea indicada
	sed -i "$num_linea a auth_url = http://controller:5000/v3\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = $password" $novaConfDir

	#####[vnc]#####
	cadena=$(grep -n "\[vnc\]$" $novaConfDir)
	num_linea=${cadena/:\[vnc\]/}

	#Se agrega bajo el numero de la linea indicada
	my_ip=\$my_ip
	sed -i "$num_linea a enabled = true\nserver_listen = 0.0.0.0\nserver_proxyclient_address = $my_ip\nnovncproxy_base_url = http://controller:6080/vnc_auto.html" $novaConfDir

	#####[glance]#####
	cadena=$(grep -n "\[glance\]$" $novaConfDir)
	num_linea=${cadena/:\[glance\]/}

	#Se agrega bajo el numero de la linea indicada
	sed -i "$num_linea a api_servers = http://controller:9292" $novaConfDir

	#####[oslo_concurrency]#####
	cadena=$(grep -n "\[oslo_concurrency\]$" $novaConfDir)
	num_linea=${cadena/:\[oslo_concurrency\]/}

	#Se agrega bajo el numero de la linea indicada
	sed -i "$num_linea a lock_path = /var/lib/nova/tmp" $novaConfDir

	#####placement#####
	cadena=$(grep -n "\[placement\]$" $novaConfDir)
	num_linea=${cadena/:\[placement\]/}

	enterPassword "\nIngrese la contraseña del usuario placement:"
	#Se agrega bajo el numero de la linea indicada
	sed -i "$num_linea a region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://controller:5000/v3\nusername = placement\npassword = $password" $novaConfDir

	num_cpus=$(egrep -c '(vmx|svm)' /proc/cpuinfo)	
	if [[ num_cpus = 0 ]]; then

		#####[libvirt]#####
		cadena=$(grep -n "\[libvirt\]$" $novaConfDir)
		num_linea=${cadena/:\[libvirt\]/}

		#Se agrega bajo el numero de la linea indicada
		sed -i "$num_linea a virt_type = qemu" $novaConfDir
	fi


	#Inicio de NOVA
	systemctl enable libvirtd.service openstack-nova-compute.service
    systemctl start libvirtd.service openstack-nova-compute.service

	echo "----------Finalizo la configuracion del servicio NOVA---------"
	sleep 2
	clear
}

# Funcion para la modificacion de archivos para instalacion de NEUTRON en nodo de computo
# param $1 Constraseña de RABBITMQ
# param $2 IP del nodo actual
function neutronCompute {
	# SUSTITUIR CON RUTA DE neutron.conf
	neutronConfDir=/etc/neutron/neutron.conf
	neutronLinuxBrDir=/etc/neutron/plugins/ml2/linuxbridge_agent.ini

	# SUSTITUIR CON RUTA DE nova.conf --> se usa ruta actual para pruebas
	novaConfDir=/etc/nova/nova.conf


	echo -e "\nIniciando cambios en neutron.conf ..."
	sed -i "1 a transport_url = rabbit://openstack:$1@controller\nauth_strategy = keystone" $neutronConfDir

	#####[keystone_authtoken]#####
	cadena=$(grep -n "\[keystone_authtoken\]$" $neutronConfDir)
	num_linea=${cadena/:\[keystone_authtoken\]/}
	enterPassword "\nIngrese la constraseña del usurio neutron:"
	sed -i "$num_linea a www_authenticate_uri = http://controller:5000\nauth_url = http://controller:5000\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = $password" $neutronConfDir

	#####[oslo_concurrency]#####
	cadena=$(grep -n "\[oslo_concurrency\]$" $neutronConfDir)
	num_linea=${cadena/:\[oslo_concurrency\]/}
	sed -i "$num_linea a lock_path = /var/lib/neutron/tmp" $neutronConfDir

	######Configuracion de LINUX BRIDGE AGENT######
	echo -e "\nConfiguracion SELF-SERVICE NETWORK\nIniciando cambios en linuxbridge_agent.ini ..."

	echo -e "\nIngrese el nombre de la interfaz que tiene acceso a internet:"
	read intName
	sed -i "1 a [linux_bridge]\nphysical_interface_mappings = provider:$intName\n\n[vxlan]\nenable_vxlan = true\nlocal_ip = $2\nl2_population = true\n\n[securitygroup]\nenable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" $neutronLinuxBrDir


	# FALTA VERIFICAR SI EL MODULO ESTA CARGADO BR_NET_FILTER
	########################################################

	######Configuracion nova.conf con neutron######
	#####[neutron]#####
	echo -e "\nConfiguracion de neutron en NOVA Service\nIniciando cambios en nova.conf ..."
	cadena=$(grep -n "^\[neutron\]$" $novaConfDir)
	num_linea=${cadena/:\[neutron\]/}
	sed -i "$num_linea a url = http://controller:9696\nauth_url = http://controller:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = $password" $novaConfDir


	#Reinicio de NOVA
	systemctl restart openstack-nova-compute.service

	#INICIO DE NEUTRON
	systemctl enable neutron-linuxbridge-agent.service
	systemctl start neutron-linuxbridge-agent.service

	echo "----------Finalizo la configuracion del servicio NEUTRON---------"
	sleep 2
	clear

	menu
}

# Funcion para mostrar mensaje de la UES
function messageUES {
	echo -e "
	\e[0;31m __    __     ________     ________
	|  |  |  |   |   _____|   |  ______|		    
	|  |  |  |   |  |_____    |  |_____ 
	|  |  |  |   |   _____|   |______  |
	|  |__|  |   |  |_____     _____|  |
	|________|   |________|   |________|\e[0m\n"
}

# Funcion encargada de controlar las opciones del menu y ejecutar respectivamente la accion correspondiente
function menu {
	echo -e "\e[0;31mUniversidad de El Salvador, Ingeniera de Sistemas Informaticos\e[0m
\e[0;31mAutor: Ricardo Estupinian\e[0m"

	echo -e "\n\e[0;32mBienvenido a la instalacion de OpenStack Version Stein. CENTOS 7\e[0m\n"
	echo --- Selecciona una opcion del menu de instalacion. ---
	select opcion in $opciones ; 
	do 
		if [[ $opcion = "Obtener_Credenciales_Admin" ]]; then

			echo "Credenciales para usuario admin"


		elif [[ $opcion = "Install_Controller_Node" ]]; then

			echo "--- Nodo Controlador ---"

		elif [[ $opcion = "Install_Compute_Node" ]]; then
			###### NOVA ######
			clear
			echo -e "\e[0;36m--- Nodo de Computo ---\e[0m\nInstalacion de NOVA Service\n"

			#Instalacion del servicio, verifica si ya esta instalado
			verify= verifyServiceInstall /etc/nova/ /etc/nova/nova.conf 
			if [[ verify =  0 ]]; then
				yum install openstack-nova-compute -y
			fi

			#Llamada a funcion ingreso de contraseña
			enterPassword "Ingrese la contraseña del usuario openstack para RabbitMQ:"

			echo -e "\nIngrese la direccion IP del nodo de computo actual:"
			read ip_node
			passRabbit=$password

			#Llamada a funcion novaCompute si la verificacion es valida
			echo -e "\nVerificando si la instalacion se realizo correctamente ..."
			if [[ verify = 1 ]]; then
				novaCompute $ip_node
			else
				clear
				echo -e "WARNING: No existe este archivo /etc/nova/nova.conf , algo salio mal en la instalacion. Verifique\n"
				sleep 3
				menu
			fi 


			###### NEUTRON ######
			clear
			echo -e "\e[0;36m--- Nodo de Computo ---\e[0m\nInstalacion de NEUTRON Service\n"
			verify= verifyServiceInstall /etc/neutron/ /etc/neutron/neutron.conf 
			if [[ verify =  0 ]]; then
				yum install openstack-neutron-linuxbridge ebtables ipset
			fi

			#Llamada a funcion neutronCompute si la verificacion es valida
			echo -e "\nVerificando si la instalacion se realizo correctamente ..."
			if [[ verify = 1 ]]; then
				neutronCompute $passRabbit $ip_node
			else
				clear
				echo -e "WARNING: No existe este archivo /etc/neutron/neutron.conf, algo salio mal en la instalacion. Verifique\n"
				sleep 3
				menu
			fi 
			

		elif [[ $opcion = "Salir" ]]; then

			clear
			echo -e "Esperamos haya sido util este script!!! Bye!"
			messageUES
			exit
		fi
	done
}

#Mostramos el Menu
menu