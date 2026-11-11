#!/bin/bash
# Проверка готовности агента на ВМ. Запускать на проверяемой машине от root.
# Использование: ./check-agent.sh [openvpn]
DIR="$(cd "$(dirname "$0")" && pwd)"; . "$DIR/lib-check.sh"
[ "$(id -u)" = 0 ] || { echo "Запустите от root"; exit 2; }
ROLE="${1:-generic}"

section "1. node_exporter"
check "prometheus-node-exporter запущен" systemctl is-active --quiet prometheus-node-exporter
check "в автозагрузке" systemctl is-enabled --quiet prometheus-node-exporter
M=$(curl -fs http://127.0.0.1:9100/metrics 2>/dev/null)
[ -n "$M" ] && ok "порт 9100 отдаёт метрики" || fail "порт 9100 не отвечает"
for m in node_cpu_seconds_total node_memory_MemAvailable_bytes node_filesystem_avail_bytes node_load1 node_network_receive_bytes_total node_boot_time_seconds node_timex_offset_seconds; do
  echo "$M" | grep -q "^$m" && ok "метрика $m" || fail "нет метрики $m"
done
echo "$M" | grep -q '^node_systemd_unit_state' && ok "systemd-коллектор включён" || fail "нет node_systemd_unit_state (нужен --collector.systemd)"
echo "$M" | grep -q '^node_reboot_required' && ok "textfile: node_reboot_required" || fail "textfile-метрика node_reboot_required отсутствует"

section "2. Конфигурация агента"
[ -f /etc/monitoring-agent.conf ] && . /etc/monitoring-agent.conf
[ -n "$PROMETHEUS_IP" ] && ok "PROMETHEUS_IP = $PROMETHEUS_IP" || fail "PROMETHEUS_IP не задан в /etc/monitoring-agent.conf"
check "каталог textfile существует" test -d /var/lib/prometheus/node-exporter
check "задания cron установлены" test -f /etc/cron.d/monitoring-textfile

section "3. Фаервол (доступ только с Prometheus)"
check "цепочка MONITORING существует" iptables -nL MONITORING
iptables -S INPUT 2>/dev/null | grep -q -- '-j MONITORING' && ok "INPUT передаёт трафик в MONITORING" || fail "цепочка MONITORING не подключена к INPUT"
iptables -S MONITORING 2>/dev/null | grep -q -- '-i lo -j ACCEPT' && ok "loopback разрешён (локальные проверки работают)" || fail "нет правила ACCEPT для lo — порт 9100 недоступен даже локально (обновите monitoring-agent)"
iptables -S MONITORING 2>/dev/null | grep -q -- "-s $PROMETHEUS_IP/32.*-j ACCEPT" && ok "разрешён доступ с $PROMETHEUS_IP" || fail "нет правила ACCEPT для $PROMETHEUS_IP"
iptables -S MONITORING 2>/dev/null | grep -q -- '-j DROP' && ok "остальным адресам порты закрыты (DROP)" || fail "нет правила DROP для остальных"
check "monitoring-firewall.service включён (переживёт перезагрузку)" systemctl is-enabled --quiet monitoring-firewall
if [ -n "$PROMETHEUS_IP" ]; then
  FIRST=$(iptables -S INPUT | sed -n '2p'); echo "$FIRST" | grep -q MONITORING && ok "MONITORING стоит первым в INPUT" || warn "MONITORING не первое правило INPUT — другие правила могут перекрыть его"
fi

if [ "$ROLE" = openvpn ]; then
  section "4. OpenVPN"
  check "сервис openvpn активен" bash -c 'systemctl is-active --quiet "openvpn@server" || systemctl is-active --quiet openvpn-server@server || systemctl is-active --quiet openvpn'
  ip link show tun0 >/dev/null 2>&1 && ok "интерфейс tun0 существует" || fail "интерфейс tun0 не найден"
  S=/var/log/openvpn/openvpn-status.log
  if [ -f "$S" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$S") ))
    [ "$AGE" -le 60 ] && ok "status-файл свежий (${AGE} с)" || fail "status-файл не обновлялся ${AGE} с"
  else fail "нет $S (добавьте в server.conf: status /var/log/openvpn/openvpn-status.log 10 и status-version 2)"; fi
  curl -fs http://127.0.0.1:9100/metrics | grep -Eq '^openvpn_listening\{[^}]*\} 1$' && ok "OpenVPN слушает свой порт (openvpn_listening = 1)" || fail "openvpn_listening не равен 1"
  check "openvpn-exporter запущен" systemctl is-active --quiet openvpn-exporter
  O=$(curl -fs http://127.0.0.1:9176/metrics 2>/dev/null)
  echo "$O" | grep -Eq '^openvpn_up(\{[^}]*\})? 1$' && ok "openvpn_up = 1" || fail "openvpn_up не равен 1"
  echo "$O" | grep -q 'openvpn_server_connected_clients' && ok "метрика числа клиентов есть" || fail "нет openvpn_server_connected_clients"
  curl -fs http://127.0.0.1:9100/metrics | grep -q '^openvpn_cert_expiry_timestamp_seconds' && ok "метрика срока сертификата есть" || fail "нет openvpn_cert_expiry_timestamp_seconds (проверьте пути в openvpn-cert-expiry.sh)"
fi

echo
echo "Примечание: проверка видимости с Prometheus выполняется на сервере (check-server.sh, раздел 3: цели UP)."
summary
