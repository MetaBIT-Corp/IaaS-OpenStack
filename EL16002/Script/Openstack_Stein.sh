#!/bin/bash
clear
echo -e "\e[0;31mUniversidad de El Salvador, Ingeniera de Sistemas Informaticos\e[0m
\e[0;31mAutor: Ricardo Estupinian\e[0m"

echo -e "\n\e[0;32mBienvenido a la instalacion de OpenStack Version Stein.\e[0m\n"
echo --- Selecciona una opcion del menu de instalacion. ---
opciones="Obtener_Credenciales_Admin Install_Controller_Node Install_Compute_Node Salir"

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
	select opcion in $opciones ; 
	do 
		if [[ $opcion = "" ]]; then

			echo "Credenciales para usuario admin"

		elif [[ $opcion = "" ]]; then

			echo "--- Nodo Controlador---"

		elif [[ $opcion = "" ]]; then

			echo "--- Nodo de Computo---"

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