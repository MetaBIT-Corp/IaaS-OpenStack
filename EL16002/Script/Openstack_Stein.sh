#!/bin/bash
clear
opciones="Obtener_Credenciales_Admin Install_Controller_Node Install_Compute_Node Salir"


#Verificacion de instalacion correcta de servicio nova en el nodo de computo
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

#Modificacion de archivos para instalacion de nova en nodo de computo
function novaCompute {

	# SUSTITUIR CON RUTA DE nova.conf --> se usa ruta actual para pruebas
	novaConfDir=/home/ricardoe/Escritorio/prueba.conf

	#Validacion de que si los archivos existen
	echo -e "\nIniciando cambios en nova.conf ..."
	sed -i "1 a enabled_apis=osapi_compute,metadata\ntransport_url = rabbit://openstack:$1@controller\nmy_ip = $2\nuse_neutron = true\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver" $novaConfDir
	

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

	enterPassword "\nIngrese la constraseña del usurio nova."

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

	enterPassword "\nIngrese la contraseña del usuario placement"
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

	#systemctl enable libvirtd.service openstack-nova-compute.service
    #systemctl start libvirtd.service openstack-nova-compute.service

	echo "----------Finalizo la configuracion del archvio nova.conf---------"
	sleep 2
	clear

	menu
}

#Para mostrar el menu despues de que finalice alguna ejecucion
function messageUES {
	echo -e "
	\e[0;31m __    __     ________     ________
	|  |  |  |   |   _____|   |  ______|		    
	|  |  |  |   |  |_____    |  |_____ 
	|  |  |  |   |   _____|   |______  |
	|  |__|  |   |  |_____     _____|  |
	|________|   |________|   |________|\e[0m\n"
}

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
			echo -e "\e[0;36m--- Nodo de Computo ---\e[0m\nInstacion de Nova Service\n"
			#Instalacion del servicio, verifica si ya esta instalado
			verify= verifyServiceInstall /etc/nova/ /etc/nova/nova.conf 
			if [[ verify =  0 ]]; then
				#yum install openstack-nova-compute -y
				echo lol
			fi

			#Llamada a funcion ingreso de contraseña
			enterPassword "Ingrese la contraseña del usuario openstack para RabbitMQ:"

			echo -e "\nIngrese la direccion IP del nodo de computo actual:"
			read ip_node

			#Llamada a llenado de archivos del servicio nova NODO COMPUTO
			novaCompute $password $ip_node #Prueba

			#Llamada a funcion novaCompute si la verificacion es valida
			echo -e "\nVerificando si la instalacion se realizo correctamente ..."
			if [[ verify = 1 ]]; then
				novaCompute $password $ip_node
			else
				clear
				echo -e "WARNING: No existe este archivo /etc/nova/nova.conf , algo salio mal en la instalacion. Verifique\n"
				# menu
			fi 


			###### NEUTRON ######
			clear
			echo -e "\e[0;29m--- Nodo de Computo ---\e[0m\nInstacion de Neutron Service\n"
			verify= verifyServiceInstall /etc/neutron/ /etc/neutron/neutron.conf 
			if [[ verify =  0 ]]; then
				#yum install openstack-neutron-linuxbridge ebtables ipset
				echo lol
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