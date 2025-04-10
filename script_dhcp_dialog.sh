#!/usr/bin/env bash
clear

#!/bin/bash
#Autor: Juan Carlos Fernandez, Iván Fornet, Álvaro Cuesta, Daniel Baco, Angel de la Vega, Alejandro Tejada
#Fecha de creación: 09/04/25
#Versión: 1.0
#-----------------------------------------------
#Zona de declaración de variables:

os=$(cat /etc/os-release | grep -E "^ID" | awk -F '=' '{print $2}')
DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0
export DIALOG_COLORS="black,blue"

#-----------------------------------------------
#Zona de declaración de funciones:

f_comprobar() {
    echo "Comprobando si el servidor está instalado..."
    if [[ $os -eq "debian" || $os -eq "ubuntu" ]]; then
        # Para Debian y Ubuntu
        if apt-cache policy isc-dhcp-server | grep -E 'ninguno|none' ; then
            echo "El servidor no está instalado."
            read -p "¿Quieres instalarlo? Sí (1), no (0): " instalar
            if [[ $instalar -eq 1 ]]; then
              if [[ $UID -eq 0 ]]; then
		apt update -y && apt install isc-dhcp-server -y
		echo "Servidor instalado correctamente."
		sleep 2
		return 0
              else
		echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
		sleep 2
		return 1
              fi
            elif [[ $instalar -eq 0 ]]; then
              echo  "El servidor no se instalará"
              sleep 2
	      return 0
            else
              echo "Se ha introducido un caracter incorrecto. Se volverá al menú..."
              sleep 2
	      return 1
	    fi
        else
            echo "El servidor está instalado."
            sleep 2
	    return 1
        fi
    elif [[ $os == "\"rocky\"" || $os == "fedora" ]]; then
        # Para Rocky y Fedora
        if dnf info isc-dhcp-server | grep -E 'ninguno|none'; then
            echo "El servidor no está instalado."
            read -p "¿Quieres instalarlo? Sí (1), no (0): " instalar
            if [[ $instalar -eq 1 ]]; then
              if [[ $UID -eq 0 ]]; then
		dnf update -y && dnf install isc-dhcp-server -y
		echo "Servidor instalado correctamente."
		sleep 2
		return 0
              else
		echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
		sleep 2
		return 1
              fi
            elif [[ $instalar -eq 0 ]]; then
              echo  "Volviendo al menú..."
              sleep 2
	      return 0
            else
              echo "Se ha introducido un caracter incorrecto. Se volverá al menú..."
              sleep 2
	      return 1
            fi
        else
            echo "El servidor está instalado."
	    return 1
        fi
    else
        echo "Tu distribución no está soportada para este script. Las distribuciones aceptadas son: Debian, Ubuntu, Rocky y Fedora."
        sleep 5
	return 1
    fi
}


f_activar(){
  if [[ $UID -eq 0 ]]; then
    read -p "¿Quieres activar o desactivar el servidor? Activar (1), desactivar (0): " activar
      if [[ $activar -eq 1 ]]; then
        systemctl start isc-dhcp-server && systemctl enable isc-dhcp-server
        echo "Servidor iniciado correctamente."
        sleep 2
	return 0
      elif [[ $activar -eq 0 ]]; then
        systemctl stop isc-dhcp-server && systemctl disable isc-dhcp-server
        echo "Servidor detenido correctamente."
        sleep 2
	return 0
      else
        echo "Se ha introducido un caracter incorrecto. Se volverá al menú..."
        sleep 2
        return 1
      fi
  else
      echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
      sleep 2
      return 1
  fi
}

f_agregar() {
  local int=$(ip -o link show | awk -F': ' '/state UP/ {print $2}')
  if [[ $UID -ne 0 ]]; then
    echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
    sleep 2
    return 1
  fi
  if [[ ! -f /etc/default/isc-dhcp-server ]]; then
    echo "No se ha encontrado el archivo de configuración del servicio DHCP."
    sleep 2
    return 1
  fi
  read -p "¿Qué configuración desea agregar? (subred/reserva): " conf
  echo -e "Deje las opciones en blanco si no desea añadir ciertos parámetros.\nTenga en cuenta que no agregar ciertos parámetros podría resultar en un error de configuración."
  case "$conf" in
    subred)
      read -p "- Subred: " subnet
      read -p "- Máscara de red: " netmask
      read -p "- Rango (Ej. 10.0.0.1 10.0.0.200): " rango
      read -p "- Máscara de subred: " subnet_mask
      read -p "- Dirección de broadcast: " broadcast
      read -p "- Gateway (interfaz de salida): " gateway
      read -p "- Servidor DNS: " dns
      read -p "- Nombre del dominio: " domain_name
      echo -e """

subnet $subnet netmask $netmask {
  range $rango;
  option subnet-mask $subnet_mask;
  option broadcast-address $broadcast;
  option routers $gateway;
  option domain-name-servers $dns;
  option domain-name "$domain_name";
}
""" >> /etc/dhcp/dhcpd.conf
      ;;
    reserva)
      read -p "- Nombre del host: " hostname
      read -p "- Dirección MAC: " mac
      read -p "- Dirección IP para asignar: " ip
      read -p "- Máscara de subred: " subnet_mask
      read -p "- Gateway (interfaz de salida): " gateway
      read -p "- Servidor DNS: " dns
      read -p "- Nombre del dominio: " domain_name
      echo -e """

host $hostname {
  hardware ethernet $mac;
  fixed-address $ip;
  option subnet-mask $subnet_mask;
  option routers $gateway;
  option domain-name-servers $dns;
  option domain-name "$domain_name";
}
""" >> /etc/dhcp/dhcpd.conf
      ;;
    *)
      echo "Opción inválida. Por favor, seleccione 'subred' o 'reserva'."
      return 1
      ;;
  esac
  systemctl restart isc-dhcp-server
  echo "Se ha añadido la configuración correctamente."
  sleep 2
  return 0
}


f_modificar(){
  local original_file output_file tempfile
  local opcion parametros_actuales nuevo_valor

  read -p "Introduce el archivo de configuración actual: " archivo_original
  read -p "Introduce el nombre que desee establecer al archivo modificado: " archivo_modificado

  tempfile=$(mktemp)
  cp "$archivo_original" "$tempfile"

  while true; do
    exec 3>&1
    selection=$(dialog \
      --backtitle "Servidor DHCP" \
      --title "=== Menú de Modificación DHCP ===" \
      --clear \
      --cancel-label "Exit" \
      --menu "Por favor, seleccione una opción:" $HEIGHT $WIDTH 8 \
      "1" "Modificar rango de IPs" \
      "2" "Modificar nombre de dominio" \
      "3" "Modificar servidores DNS" \
      "4" "Modificar puerta de enlace" \
      "5" "Modificar tiempo de concesión" \
      "6" "Modificar tiempo máximo" \
      "7" "Guardar y salir" \
      2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case $exit_status in
      $DIALOG_CANCEL)
        clear
        echo "Programa cerrado correctamente."
        sleep 2
        exit 0
        ;;
      $DIALOG_ESC)
        clear
        echo "Programa cancelado." >&2
        sleep 2
        exit 1
        ;;
    esac
    case $selection in
    1)
      parametros_actuales=$(awk '/subnet /,/}/{ if ($1 == "range") print $2, $3 }' "$tempfile" | tr -d ';')
      echo "Rango actual: $parametros_actuales"
      read -p "Nuevo rango (inicio fin): " nuevo_valor
      sed -i "/subnet /,/}/ {s/^\(\s*range\s*\).*/\1${nuevo_valor};/}" "$tempfile"
      ;;
    2)
      parametros_actuales=$(awk -F'"' '/domain-name/ {print $2}' "$tempfile")
      echo "Dominio actual: $parametros_actuales"
      read -p "Nuevo dominio: " nuevo_valor
      sed -i "s/\(domain-name\s*\"\).*\(\"\)/\1${nuevo_valor}\2/" "$tempfile"
      ;;
    3)
      parametros_actuales=$(awk -F'[ ;]' '/domain-name-servers/ {print $3}' "$tempfile")
      echo "DNS actuales: $parametros_actuales"
      read -p "Nuevos DNS (separados por coma): " nuevo_valor
      sed -i "s/\(domain-name-servers\s*\).*;/\1${nuevo_valor};/" "$tempfile"
      ;;
    4)
      parametros_actuales=$(awk '/routers/ {print $3}' "$tempfile" | tr -d ';')
      echo "Gateway actual: $parametros_actuales"
      read -p "Nuevo gateway: " nuevo_valor
      sed -i "s/\(routers\s*\).*;/\1${nuevo_valor};/" "$tempfile"
      ;;
    5)
      parametros_actuales=$(awk '/default-lease-time/ {print $2}' "$tempfile" | tr -d ';')
      echo "Tiempo actual: $parametros_actuales"
      read -p "Nuevo tiempo (seg): " nuevo_valor
      sed -i "s/\(default-lease-time\s*\).*;/\1${nuevo_valor};/" "$tempfile"
      ;;
    6)
      parametros_actuales=$(awk '/max-lease-time/ {print $2}' "$tempfile" | tr -d ';')
      echo "Tiempo máximo actual: $parametros_actuales"
      read -p "Nuevo máximo (seg): " nuevo_valor
      sed -i "s/\(max-lease-time\s*\).*;/\1${nuevo_valor};/" "$tempfile"
      ;;
    7)
      cp "$tempfile" "$archivo_modificado"
      rm "$tempfile"
      echo "Configuración guardada en: $output_file"
      sleep 2
      return 0
      ;;
    esac
  done
}

f_recuperar(){
  if [[ $UID -eq 0 ]]; then
    read -p "¿Quieres recuperar la configuración inicial o la anterior a la actual? Inicial (1), anterior (0): " recuperar
    if [[ $recuperar -eq 1 ]]; then
      if [[ -f /etc/dhcp/dhcpd.conf.default ]]; then
        cp /etc/dhcp/dhcpd.conf.default /etc/dhcp/dhcpd.conf
        echo "Reiniciando el servicio..."
        systemctl restart isc-dhcp-server
        echo "Configuración restaurada correctamente."
        sleep 2
        return 0
      else
        echo "No se ha encontrado la copia de seguridad."
        sleep 2
        return 1
      fi
    elif [[ $recuperar -eq 0 ]]; then
      if [[ -f /etc/dhcp/dhcpd.conf.old ]]; then
        cp /etc/dhcp/dhcpd.conf.old /etc/dhcp/dhcpd.conf
        echo "Reiniciando el servicio..."
        systemctl restart isc-dhcp-server
        echo "Configuración restaurada correctamente."
        sleep 2
        return 0
      else
        echo "No se ha encontrado la copia de seguridad."
        sleep 2
        return 1
      fi
    fi
  else
      echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
      sleep 2
      return 1
  fi
}


f_borrar(){
  if [[ $UID -eq 0 ]]; then
    if [[ -f /etc/dhcp/dhcpd.conf ]]; then
	rm -r /etc/dhcp/dhcpd.conf
	echo "La configuración del servidor se ha borrado correctamente."
	sleep 2
	return 0
    else
	echo "La configuración del servidor ya está borrada."
	sleep 2
    fi
  else
      echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
      sleep 2
      return 1
  fi
}


f_desinstalar(){
  echo "Comprobando si el servidor está instalado..."
  if [[ $os == "debian" || $os == "ubuntu" ]]; then
    # Para Debian y Ubuntu
    if apt-cache policy isc-dhcp-server | grep -E 'ninguno|none' ; then
      echo "El servidor no está instalado."
      sleep 2
      return 1
    else
      if [[ $UID -eq 0 ]]; then
        apt remove isc-dhcp-server -y && apt purge isc-dhcp-server -y
	echo "Servidor desinstalado correctamente."
	sleep 2
	return 0
      else
        echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
        sleep 2
        return 1
      fi
    fi
  elif [[ $os == "\"rocky\"" || $os == "fedora" ]]; then
        # Para Rocky y Fedora
        if dnf info isc-dhcp-server | grep -E 'ninguno|none'; then
          echo "El servidor no está instalado."
          sleep 2
          return 1
        else
          if [[ $UID -eq 0 ]]; then
            dnf remove isc-dhcp-server -y
	    echo "Servidor desinstalado correctamente."
	    sleep 2
	    return 0
	  else
            echo "Esta acción no se puede llevar a cabo porque no tienes permisos de Administrador."
            sleep 2
            return 1
          fi
        fi
  else
    echo "Tu distribución no está soportada para este script. Las distribuciones aceptadas son: Debian, Ubuntu, Rocky y Fedora."
    sleep 5
    return 1
  fi
}

display_result() {
  dialog --title "$1" \
    --no-collapse \
    --msgbox "$result" 0 0
}

#Ejecución de funciones
#-------------------------------------------------------
echo "Es necesario tener instalado el paquete 'dialog' para el correcto funcionamiento del script. Pulse Ctrl + C para salir."
while true; do
  exec 3>&1
  selection=$(dialog \
    --backtitle "Servidor DHCP" \
    --title "--- Menu ---" \
    --clear \
    --cancel-label "Exit" \
    --menu "Por favor, seleccione una opción:" $HEIGHT $WIDTH 8 \
    "1" "Comprobar si está instalado el servicio e instalarlo" \
    "2" "Activar o desactivar el servidor" \
    "3" "Agregar una configuración al servidor" \
    "4" "Modificar la configuración" \
    "5" "Recuperar la configuración (subopción 1 Inicial, 2 Anterior)" \
    "6" "Borrar configuración" \
    "7" "Desinstalar y borrar la configuración" \
    2>&1 1>&3)
  exit_status=$?
  exec 3>&-
  case $exit_status in
    $DIALOG_CANCEL)
      clear
      echo "Programa cerrado correctamente."
      sleep 2
      clear
      exit
      ;;
    $DIALOG_ESC)
      clear
      echo "Programa cancelado." >&2
      sleep 2
      clear
      exit 1
      ;;
  esac
  case $selection in
  1)
    f_comprobar
    ;;
  2)
    f_activar
    ;;
  3)
    f_agregar
    ;;
  4)
    f_modificar
    ;;
  5)
    f_recuperar
    ;;
  6)
    f_borrar
    ;;
  7)
    f_desinstalar
    ;;
  esac
done
