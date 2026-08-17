#!/usr/bin/env bash
set -euo pipefail

# --- НАСТРОЙКИ ---
VPN_SERVER_IP="111.88.145.208"  # приватный IP сервера
PKI_DIR="/etc/openvpn/easy-rsa"
IPTABLES_RULES="/etc/iptables/rules.v4"

# --- ОБНОВЛЕНИЕ И УСТАНОВКА ---
apt-get update
apt-get upgrade -y
apt-get install -y openvpn easy-rsa iptables-persistent

# --- ФАЕРВОЛ (iptables) ---
mkdir -p "$(dirname "$IPTABLES_RULES")"

# Политики по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешить loopback
iptables -A INPUT -i lo -j ACCEPT

# Разрешить уже установленные соединения
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH (TCP 22)
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# OpenVPN (UDP 1194)
iptables -A INPUT -p udp --dport 1194 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# NAT для клиентов OpenVPN (чтобы они имели выход в интернет)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE   

# Сохранение правил (iptables-persistent будет подгружать их при загрузке)
iptables-save | sudo tee "$IPTABLES_RULES" > /dev/null

# --- PKI (Easy-RSA) ---
mkdir -p "$PKI_DIR"
cp -r /usr/share/easy-rsa/* "$PKI_DIR/"
cd "$PKI_DIR"
# Заполнение vars
if [ ! -f vars ]; then
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

# Генерируем запрос на сертификат сервера (без подписи на этом этапе)
./easyrsa gen-req server nopass

# Cозданиt публичного tls-crypt-ключа
openvpn --genkey --secret ta.key

# --- КОНФИГУРАЦИЯ OPENVPN ---
cp server.conf /etc/openvpn/server
mv "$PKI_DIR/pki/private/server.key" /etc/openvpn/server
sysctl -w net.ipv4.ip_forward=1
sysctl -p
systemctl -f enable openvpn-server@server.service
systemctl stop openvpn@server.service
systemctl disable openvpn@server.service
systemctl daemon-reload
systemctl start openvpn-server@server.service
systemctl status openvpn-server@server.service

echo "Готово: запрос server.req создан в $PKI_DIR/pki/reqs/"
echo "Правила iptables сохранены в $IPTABLES_RULES"
