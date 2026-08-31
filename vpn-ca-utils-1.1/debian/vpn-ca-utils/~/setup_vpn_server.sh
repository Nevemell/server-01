#!/usr/bin/env bash
set -euo pipefail

# --- НАСТРОЙКИ ---
VPN_SERVER_IP="111.88.145.208"
PKI_DIR="$HOME/easy-rsa"
OUTPUT_DIR="/etc/openvpn/server"
CLIENT_DIR="$HOME/clients"
PORT=1194
PROTO=udp
TA_KEY_FILE="$OUTPUT_DIR/ta.key"
IPTABLES_RULES="/etc/iptables/rules.v4"

# Проверка: sudo доступен?
if ! sudo -v 2>/dev/null; then
  echo "ОШИБКА: sudo недоступен. Запросите права у администратора." >&2
  exit 1
fi

echo "Пароль sudo запрошен один раз в начале — дальше кэшируется."

# --- УСТАНОВКА ПАКЕТОВ ---
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y openvpn easy-rsa iptables-persistent curl

# --- IP FORWARD ---
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-ipforward.conf
sudo sysctl --system

# --- IPTABLES ---
sudo mkdir -p "$(dirname "$IPTABLES_RULES")"

# Определяем основной сетевой интерфейс
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$IFACE" ]; then
  echo "Не удалось определить основной интерфейс." >&2
  exit 1
fi

sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

sudo iptables -F
sudo iptables -t nat -F

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT

sudo iptables -A FORWARD -i tun0 -j ACCEPT
sudo iptables -A FORWARD -o tun0 -j ACCEPT

sudo iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE

sudo iptables-save | sudo tee "$IPTABLES_RULES" > /dev/null

# --- PKI (от обычного пользователя, в домашней папке) ---
mkdir -p "$PKI_DIR"
ln -s /usr/share/easy-rsa/* "$PKI_DIR/" 2>/dev/null || true
chmod 700 "$PKI_DIR"
cd "$PKI_DIR"

if [ ! -f vars ]; then
  cat > vars <<'EOF'
set_var EASYRSA_REQ_COUNTRY "RUS"
set_var EASYRSA_REQ_PROVINCE "Moscow"
set_var EASYRSA_REQ_CITY "Moscow City"
set_var EASYRSA_REQ_ORG "ClearView UX"
set_var EASYRSA_REQ_EMAIL "sysadmin@company.ru"
set_var EASYRSA_REQ_OU "DevOps"
set_var EASYRSA_ALGO "ec"
set_var EASYRSA_DIGEST "sha512"
EOF
  chmod 600 vars
fi

if [ ! -d pki ]; then
  ./easyrsa init-pki
fi

if [ ! -f pki/reqs/server.req ]; then
  ./easyrsa gen-req server nopass
fi

if [ ! -f ta.key ]; then
  openvpn --genkey --secret ta.key
fi

# --- ПОДГОТОВКА СЕРВЕРНОЙ ДИРЕКТОРИИ ---
sudo mkdir -p "$OUTPUT_DIR"

# server.conf (генерируется от пользователя, копируется через sudo)
if [ ! -f server.conf ]; then
  echo "ОШИБКА: server.conf не найден в $(pwd). Поместите его туда и запустите скрипт снова." >&2
  exit 1
fi
sudo cp server.conf "$OUTPUT_DIR/"

# Копируем ключи в системную директорию
sudo cp "$PKI_DIR/pki/private/server.key" "$OUTPUT_DIR/"
sudo cp "$PKI_DIR/ta.key" "$TA_KEY_FILE"

# Права
sudo chown root:root "$OUTPUT_DIR/server.conf"
sudo chown nobody:nogroup "$OUTPUT_DIR/server.key" "$TA_KEY_FILE"
sudo chmod 600 "$OUTPUT_DIR/server.key"
sudo chmod 600 "$TA_KEY_FILE"
sudo chmod 644 "$OUTPUT_DIR/server.conf"

# Логи
sudo mkdir -p /var/log/openvpn
sudo chown nobody:nogroup /var/log/openvpn

# --- ИНСТРУКЦИЯ ---
echo ""
echo "========================================"
echo "  VPN-сервер подготовлен"
echo "========================================"
echo ""
echo "Файлы на этом сервере:"
echo "  Запрос:         $PKI_DIR/pki/reqs/server.req"
echo "  Приватный ключ:   $OUTPUT_DIR/server.key"
echo "  tls-crypt:        $TA_KEY_FILE"
echo "  Конфиг:          $OUTPUT_DIR/server.conf"
echo ""
echo "Ожидает от CA-сервера:"
echo "  ca.crt   → $OUTPUT_DIR/ca.crt"
echo "  server.crt → $OUTPUT_DIR/server.crt"
echo ""
echo "--- ДАЛЬНЕЙШИЕ ШАГИ ---"
echo ""
echo "1) Перенесите server.req на CA-сервер:"
echo "   scp $PKI_DIR/pki/reqs/server.req user@CA_IP:/tmp/"
echo ""
echo "2) На CA-сервере:"
echo "   cd ~/easy-rsa"
echo "   ./easyrsa import-req /tmp/server.req server"
echo "   ./easyrsa sign-req server server"
echo ""
echo "3) Перенесите подписанные файлы обратно:"
echo "   scp user@CA_IP:~/easy-rsa/pki/ca.crt          /tmp/ca.crt"
echo "   scp user@CA_IP:~/easy-rsa/pki/issued/server.crt /tmp/server.crt"
echo "   sudo cp /tmp/ca.crt /tmp/server.crt $OUTPUT_DIR/"
echo "   sudo chown nobody:nogroup $OUTPUT_DIR/ca.crt $OUTPUT_DIR/server.crt"
echo "   sudo chmod 644 $OUTPUT_DIR/ca.crt $OUTPUT_DIR/server.crt"
echo ""
echo "4) Запустите OpenVPN:"
echo "   sudo systemctl enable openvpn-server@server.service"
echo "   sudo systemctl start openvpn-server@server.service"
echo "   sudo systemctl status openvpn-server@server.service"
echo ""

