#!/bin/bash
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"; OUT="${OUT:-$R/dist}"; V=1.2
rm -rf "$OUT"; mkdir -p "$OUT"
B=$(mktemp -d)

# --- monitoring-server ---
S="$B/monitoring-server"
mkdir -p "$S/DEBIAN" "$S/usr/share/monitoring-server" "$S/usr/sbin"
cp -r "$R/server" "$S/usr/share/monitoring-server/"
cat > "$S/DEBIAN/control" <<EOC
Package: monitoring-server
Version: $V
Architecture: all
Maintainer: Ops <ops@example.com>
Depends: prometheus, prometheus-alertmanager, prometheus-blackbox-exporter, libcap2-bin
Description: Prometheus server with alert rules, Alertmanager e-mail and blackbox probes
EOC
cat > "$S/DEBIAN/postinst" <<'EOC'
#!/bin/sh
set -e
D=/usr/share/monitoring-server/server
install -d /etc/prometheus/rules /etc/prometheus/targets /etc/monitoring
cp $D/rules/*.yml /etc/prometheus/rules/
for f in $D/targets/*.yml; do [ -e /etc/prometheus/targets/$(basename $f) ] || cp $f /etc/prometheus/targets/; done
cp $D/prometheus.yml /etc/prometheus/prometheus.yml
[ -e /etc/prometheus/alertmanager.yml.dpkg-keep ] || cp $D/alertmanager.yml /etc/prometheus/alertmanager.yml
touch /etc/prometheus/alertmanager.yml.dpkg-keep
cp $D/blackbox.yml /etc/prometheus/blackbox.yml
[ -e /etc/monitoring/smtp_password ] || echo CHANGE_ME > /etc/monitoring/smtp_password
chgrp prometheus /etc/monitoring/smtp_password 2>/dev/null || true; chmod 0640 /etc/monitoring/smtp_password
sed -i '/^ARGS=/d' /etc/default/prometheus /etc/default/prometheus-alertmanager /etc/default/prometheus-blackbox-exporter 2>/dev/null || true
echo 'ARGS="--web.listen-address=127.0.0.1:9090 --storage.tsdb.retention.time=30d"' >> /etc/default/prometheus
echo 'ARGS="--config.file=/etc/prometheus/alertmanager.yml --web.listen-address=127.0.0.1:9093"' >> /etc/default/prometheus-alertmanager
echo 'ARGS="--config.file=/etc/prometheus/blackbox.yml --web.listen-address=127.0.0.1:9115"' >> /etc/default/prometheus-blackbox-exporter
setcap cap_net_raw+ep /usr/bin/prometheus-blackbox-exporter 2>/dev/null || true
if command -v systemctl >/dev/null && [ -d /run/systemd/system ]; then
  systemctl enable prometheus prometheus-alertmanager prometheus-blackbox-exporter || true
  systemctl restart prometheus prometheus-alertmanager prometheus-blackbox-exporter || true
fi
exit 0
EOC
chmod 755 "$S/DEBIAN/postinst"
mkdir -p "$S/usr/sbin" "$S/usr/lib/monitoring-server"
install -m644 "$R/scripts/lib-check.sh" "$S/usr/lib/monitoring-server/"
sed 's#^DIR=.*#. /usr/lib/monitoring-server/lib-check.sh#' "$R/scripts/check-server.sh" > "$S/usr/sbin/monitoring-check-server"
chmod 755 "$S/usr/sbin/monitoring-check-server"
dpkg-deb --build --root-owner-group "$S" "$OUT/monitoring-server_${V}_all.deb"

# --- monitoring-agent ---
A="$B/monitoring-agent"
mkdir -p "$A/DEBIAN" "$A/usr/lib/monitoring-agent" "$A/etc/cron.d" "$A/lib/systemd/system" "$A/etc"
install -m755 "$R"/agent/monitoring-firewall.sh "$R"/agent/openvpn-cert-expiry.sh "$R"/agent/reboot-required.sh "$R"/agent/openvpn-listen.sh "$A/usr/lib/monitoring-agent/"
install -m644 "$R/agent/monitoring-textfile.cron" "$A/etc/cron.d/monitoring-textfile"
install -m644 "$R/agent/monitoring-firewall.service" "$A/lib/systemd/system/"
install -m644 "$R/agent/openvpn-exporter.service" "$A/lib/systemd/system/"
mkdir -p "$A/lib/systemd/system/openvpn-server@.service.d"
install -m644 "$R/agent/openvpn-status-perms.conf" "$A/lib/systemd/system/openvpn-server@.service.d/status-perms.conf"
echo "PROMETHEUS_IP=" > "$A/etc/monitoring-agent.conf"
cat > "$A/DEBIAN/conffiles" <<EOC
/etc/monitoring-agent.conf
EOC
cat > "$A/DEBIAN/control" <<EOC
Package: monitoring-agent
Version: $V
Architecture: all
Maintainer: Ops <ops@example.com>
Depends: prometheus-node-exporter, iptables, openssl, cron
Recommends: systemd
Description: node_exporter configuration, textfile collectors and firewall for Prometheus scraping
 Set PROMETHEUS_IP in /etc/monitoring-agent.conf (or export it before installation).
EOC
cat > "$A/DEBIAN/postinst" <<'EOC'
#!/bin/sh
set -e
if [ -n "$PROMETHEUS_IP" ]; then sed -i "s/^PROMETHEUS_IP=.*/PROMETHEUS_IP=$PROMETHEUS_IP/" /etc/monitoring-agent.conf; fi
install -d /var/lib/prometheus/node-exporter
sed -i '/^ARGS=/d' /etc/default/prometheus-node-exporter 2>/dev/null || true
echo 'ARGS="--collector.systemd --collector.processes --collector.textfile.directory=/var/lib/prometheus/node-exporter"' >> /etc/default/prometheus-node-exporter
/usr/lib/monitoring-agent/reboot-required.sh || true
if command -v systemctl >/dev/null && [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  . /etc/monitoring-agent.conf
  if [ -n "$PROMETHEUS_IP" ]; then systemctl enable --now monitoring-firewall.service || true
  else echo "ВНИМАНИЕ: задайте PROMETHEUS_IP в /etc/monitoring-agent.conf и выполните: systemctl enable --now monitoring-firewall"; fi
  systemctl restart prometheus-node-exporter || true
fi
exit 0
EOC
cat > "$A/DEBIAN/prerm" <<'EOC'
#!/bin/sh
if [ "$1" = remove ] && command -v iptables >/dev/null; then
  iptables -D INPUT -j MONITORING 2>/dev/null || true; iptables -F MONITORING 2>/dev/null || true; iptables -X MONITORING 2>/dev/null || true
fi
exit 0
EOC
chmod 755 "$A/DEBIAN/postinst" "$A/DEBIAN/prerm"
mkdir -p "$A/usr/sbin"
install -m644 "$R/scripts/lib-check.sh" "$A/usr/lib/monitoring-agent/"
sed 's#^DIR=.*#. /usr/lib/monitoring-agent/lib-check.sh#' "$R/scripts/check-agent.sh" > "$A/usr/sbin/monitoring-check-agent"
chmod 755 "$A/usr/sbin/monitoring-check-agent"
dpkg-deb --build --root-owner-group "$A" "$OUT/monitoring-agent_${V}_all.deb"
rm -rf "$B"; ls -l "$OUT"
