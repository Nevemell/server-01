#!/bin/bash
# Установка kumina/openvpn_exporter. Бинарник нужно собрать (go build) либо скачать и положить в /usr/local/bin.
set -euo pipefail
if [ ! -x /usr/local/bin/openvpn_exporter ]; then
  command -v go >/dev/null || apt-get install -y golang-go git
  GOBIN=/usr/local/bin go install github.com/kumina/openvpn_exporter@latest
fi
install -m644 "$(cd "$(dirname "$0")/.." && pwd)/agent/openvpn-exporter.service" /etc/systemd/system/
install -d /etc/systemd/system/openvpn-server@.service.d
install -m644 "$(cd "$(dirname "$0")/.." && pwd)/agent/openvpn-status-perms.conf" /etc/systemd/system/openvpn-server@.service.d/status-perms.conf
systemctl daemon-reload
systemctl enable --now openvpn-exporter
echo "Убедитесь, что в server.conf есть: status /var/log/openvpn/openvpn-status.log 10 и status-version 2"
