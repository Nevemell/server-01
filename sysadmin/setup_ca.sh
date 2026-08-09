#!/usr/bin/env bash
set -euo pipefail

CA_DIR=$HOME/easy-rsa

sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get -y install easy-rsa vim

mkdir "$CA_DIR"
ln -s /usr/share/easy-rsa/* "$CA_DIR/"
cd "$CA_DIR"

# vars можно сгенерировать или взять готовый шаблон
if [[ ! -f vars ]]; then
  cp vars.example vars

  echo 'set_var EASYRSA_REQ_COUNTRY "RUS"' >>vars
  echo 'set_var EASYRSA_REQ_PROVINCE "Moscow"' >>vars
  echo 'set_var EASYRSA_REQ_CITY "Moscow City"' >>vars
  echo 'set_var EASYRSA_REQ_ORG "ClearView UX"' >>vars
  echo 'set_var EASYRSA_REQ_EMAIL "sysadmin@company.ru"' >>vars
  echo 'set_var EASYRSA_REQ_OU "DevOps"' >>vars
  echo 'set_var EASYRSA_ALGO "ec"' >>vars
  echo 'set_var EASYRSA_DIGEST "sha512"' >>vars
fi
./easyrsa init-pki
./easyrsa build-ca nopass

# Настройка iptables 
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT


echo "CA created in $CA_DIR, keys in pki/"

