#!/bin/sh
# Метрика openvpn_listening: слушает ли OpenVPN свой порт (UDP/TCP берётся из server.conf).
# На машинах без OpenVPN метрика не создаётся.
CONF=/etc/openvpn/server/server.conf
OUT=/var/lib/prometheus/node-exporter/openvpn_listen.prom
[ -f "$CONF" ] || { rm -f "$OUT"; exit 0; }
PORT=$(awk '$1=="port"{print $2}' "$CONF" | head -1); PORT=${PORT:-1194}
PROTO=$(awk '$1=="proto"{print $2}' "$CONF" | head -1); PROTO=${PROTO:-udp}
case "$PROTO" in tcp*) OPT=-tlnH ;; *) OPT=-ulnH ;; esac
if ss $OPT | awk '{print $4}' | grep -q ":$PORT\$"; then v=1; else v=0; fi
echo "openvpn_listening{port=\"$PORT\",proto=\"$PROTO\"} $v" > "$OUT.$$" && mv "$OUT.$$" "$OUT"
