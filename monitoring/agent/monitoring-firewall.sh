#!/bin/sh
# Пропускает порты экспортёров только с IP Prometheus. Остальные правила хоста не трогает.
. /etc/monitoring-agent.conf
[ -n "$PROMETHEUS_IP" ] || { echo "PROMETHEUS_IP не задан в /etc/monitoring-agent.conf" >&2; exit 1; }
PORTS="9100,9176"
iptables -N MONITORING 2>/dev/null || iptables -F MONITORING
iptables -A MONITORING -i lo -j ACCEPT
iptables -A MONITORING -s "$PROMETHEUS_IP" -p tcp -m multiport --dports "$PORTS" -j ACCEPT
iptables -A MONITORING -p tcp -m multiport --dports "$PORTS" -j DROP
iptables -A MONITORING -j RETURN
iptables -C INPUT -j MONITORING 2>/dev/null || iptables -I INPUT 1 -j MONITORING
