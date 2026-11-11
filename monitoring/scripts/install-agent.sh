#!/bin/bash
# Установка node_exporter и защита портов. Использование: PROMETHEUS_IP=10.0.0.5 ./install-agent.sh [openvpn]
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Запустите от root"; exit 1; }
: "${PROMETHEUS_IP:?Укажите PROMETHEUS_IP}"
ROLE="${1:-generic}"
A="$(cd "$(dirname "$0")/.." && pwd)/agent"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y prometheus-node-exporter iptables openssl

echo "PROMETHEUS_IP=$PROMETHEUS_IP" > /etc/monitoring-agent.conf
install -d /usr/lib/monitoring-agent /var/lib/prometheus/node-exporter
install -m755 "$A"/monitoring-firewall.sh "$A"/openvpn-cert-expiry.sh "$A"/reboot-required.sh "$A"/openvpn-listen.sh /usr/lib/monitoring-agent/
install -m644 "$A/monitoring-textfile.cron" /etc/cron.d/monitoring-textfile
install -m644 "$A/monitoring-firewall.service" /etc/systemd/system/

# node_exporter: systemd-коллектор + textfile, слушаем все интерфейсы (доступ ограничен iptables)
sed -i '/^ARGS=/d' /etc/default/prometheus-node-exporter
echo 'ARGS="--collector.systemd --collector.processes --collector.textfile.directory=/var/lib/prometheus/node-exporter"' >> /etc/default/prometheus-node-exporter

systemctl daemon-reload
systemctl enable --now monitoring-firewall.service
systemctl enable prometheus-node-exporter && systemctl restart prometheus-node-exporter
/usr/lib/monitoring-agent/reboot-required.sh

if [ "$ROLE" = openvpn ]; then
  "$(dirname "$0")/install-openvpn-exporter.sh"
  /usr/lib/monitoring-agent/openvpn-cert-expiry.sh
fi
echo "Агент установлен. Порты 9100/9176 доступны только с $PROMETHEUS_IP"
