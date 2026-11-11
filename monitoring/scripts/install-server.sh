#!/bin/bash
# Установка Prometheus + Alertmanager + blackbox_exporter на Debian/Ubuntu.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Запустите от root"; exit 1; }
D="$(cd "$(dirname "$0")/.." && pwd)/server"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y prometheus prometheus-alertmanager prometheus-blackbox-exporter prometheus-node-exporter

install -d /etc/prometheus/rules /etc/prometheus/targets /etc/monitoring
cp "$D"/rules/*.yml /etc/prometheus/rules/
[ -e /etc/prometheus/targets/node.yml ] || cp "$D"/targets/*.yml /etc/prometheus/targets/
cp "$D/prometheus.yml" /etc/prometheus/prometheus.yml
cp "$D/alertmanager.yml" /etc/prometheus/alertmanager.yml
cp "$D/blackbox.yml" /etc/prometheus/blackbox.yml
[ -e /etc/monitoring/smtp_password ] || { echo "CHANGE_ME" > /etc/monitoring/smtp_password; }
chown root:prometheus /etc/monitoring/smtp_password; chmod 0640 /etc/monitoring/smtp_password

# Слушаем только localhost, хранение 30 дней
sed -i '/^ARGS=/d' /etc/default/prometheus
echo 'ARGS="--web.listen-address=127.0.0.1:9090 --storage.tsdb.retention.time=30d"' >> /etc/default/prometheus
sed -i '/^ARGS=/d' /etc/default/prometheus-alertmanager
echo 'ARGS="--config.file=/etc/prometheus/alertmanager.yml --web.listen-address=127.0.0.1:9093"' >> /etc/default/prometheus-alertmanager
sed -i '/^ARGS=/d' /etc/default/prometheus-blackbox-exporter
echo 'ARGS="--config.file=/etc/prometheus/blackbox.yml --web.listen-address=127.0.0.1:9115"' >> /etc/default/prometheus-blackbox-exporter
# icmp без root
setcap cap_net_raw+ep /usr/bin/prometheus-blackbox-exporter 2>/dev/null || true

promtool check config /etc/prometheus/prometheus.yml
amtool check-config /etc/prometheus/alertmanager.yml

systemctl enable --now prometheus prometheus-alertmanager prometheus-blackbox-exporter
systemctl restart prometheus prometheus-alertmanager prometheus-blackbox-exporter
echo "Готово. Отредактируйте /etc/prometheus/targets/*.yml, alertmanager.yml и /etc/monitoring/smtp_password"
echo "Веб-интерфейс: ssh -L 9090:127.0.0.1:9090 user@<server>  ->  http://localhost:9090"
