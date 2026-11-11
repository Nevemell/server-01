#!/bin/sh
# Пишет срок действия сертификатов OpenVPN в textfile-коллектор node_exporter.
OUT=/var/lib/prometheus/node-exporter/openvpn_cert.prom
TMP="$OUT.$$"
: > "$TMP"
for f in /etc/openvpn/server/server.crt /etc/openvpn/server.crt /etc/openvpn/server/ca.crt /etc/openvpn/ca.crt; do
  [ -f "$f" ] || continue
  d=$(openssl x509 -enddate -noout -in "$f" | cut -d= -f2)
  ts=$(date -d "$d" +%s)
  echo "openvpn_cert_expiry_timestamp_seconds{file=\"$f\"} $ts" >> "$TMP"
done
mv "$TMP" "$OUT"
