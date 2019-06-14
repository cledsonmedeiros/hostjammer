#!/bin/bash

function CHECK_DEPENDECIAS {
  NETTOOLS=`sudo dpkg-query -l | grep net-tools | wc -l`
  NETDISCOVER=`sudo dpkg-query -l | grep netdiscover | wc -l`
  HPING3=`sudo dpkg-query -l | grep hping3 | wc -l`
  if [[ $NETTOOLS -eq 0 ]]; then
    echo -e "Instalando net-tools\n"
    sudo apt install net-tools
    echo
  fi
  if [[ $NETDISCOVER -eq 0 ]]; then
    echo -e "Instalando netdiscover\n"
    sudo apt install netdiscover
    echo
  fi
  if [[ $HPING3 -eq 0 ]]; then
    echo -e "Instalando hping3\n"
    sudo apt install hping3
    echo
  fi
}

function CHECK_ROOT {
  if [[ ! $USER = "root" ]]; then
    echo "Execute como root."
    exit
  fi
}

function GET_INTERFACES {
  INTERFACES=( $(sudo ifconfig | grep "<UP,BROADCAST,RUNNING,MULTICAST>" | awk -F ": " '{print $1}') )
  LEN_INTERFACES=${#INTERFACES[@]}

  if [[ $LEN_INTERFACES = 1 ]]; then
    INTERFACE=${INTERFACES[0]}
    echo "Única interface disponível: $INTERFACE"
  else
    echo "Escolha a interface:"
    echo

    for (( i = 0; i < $LEN_INTERFACES; i++ )); do
      echo "$i - ${INTERFACES[$i]}"
    done

    echo
    echo -n "Escolha: "
    read N_INTERFACE

    if [[ $N_INTERFACE -ge $LEN_INTERFACES ]] || [[ $N_INTERFACE -lt 0 ]]; then
      echo "Opção inválida."
      exit
    fi
    echo
    INTERFACE=${INTERFACES[$N_INTERFACE]}
    echo "Você escolheu $INTERFACE"

  fi
}

function GET_ESCOPO {
  ESCOPO=$(sudo ip route | grep "$INTERFACE" | grep "kernel scope link src" | awk -F " " '{print $1}')
  IP=$(echo "$ESCOPO" | awk -F "/" '{print $1}')
  MASK=$(echo "$ESCOPO" | awk -F "/" '{print $2}')
  echo "Escopo da rede: $ESCOPO"


  POT=$((32 - $MASK))
  IP_NUMBER=$(((2 ** $POT) - 1 ))
  echo "Número de IP's possíveis: $IP_NUMBER"
}

CHECK_ROOT
CHECK_DEPENDECIAS
GET_INTERFACES
GET_ESCOPO
