#!/bin/bash
# Проверка готовности сервера мониторинга. Запускать на сервере Prometheus от root.
DIR="$(cd "$(dirname "$0")" && pwd)"; . "$DIR/lib-check.sh"
[ "$(id -u)" = 0 ] || { echo "Запустите от root"; exit 2; }
PROM=http://127.0.0.1:9090; AM=http://127.0.0.1:9093

section "1. Сервисы"
for s in prometheus prometheus-alertmanager prometheus-blackbox-exporter prometheus-node-exporter; do
  check "$s запущен" systemctl is-active --quiet "$s"
  check "$s в автозагрузке" systemctl is-enabled --quiet "$s"
done

section "2. Конфигурация"
check "promtool: prometheus.yml корректен" promtool check config /etc/prometheus/prometheus.yml
check "promtool: правила корректны" promtool check rules /etc/prometheus/rules/*.yml
check "amtool: alertmanager.yml корректен" amtool check-config /etc/prometheus/alertmanager.yml
for f in node openvpn icmp openvpn-port; do check "файл целей targets/$f.yml существует" test -s /etc/prometheus/targets/$f.yml; done
grep -q '10\.0\.0\.' /etc/prometheus/targets/*.yml 2>/dev/null && warn "в targets остались примерные адреса 10.0.0.x — замените на реальные"

section "3. Prometheus: цели и данные"
if curl -fs "$PROM/-/ready" >/dev/null; then ok "Prometheus отвечает (ready)"; else fail "Prometheus не отвечает на $PROM"; fi
T=$(curl -fs "$PROM/api/v1/targets" 2>/dev/null)
if [ -n "$T" ]; then
  DOWN=$(echo "$T" | python3 -c 'import sys,json
d=json.load(sys.stdin)["data"]["activeTargets"]
bad=[f"{t["labels"].get("job")} {t["scrapeUrl"]}" for t in d if t["health"]!="up"]
print("\n".join(bad))')
  TOTAL=$(echo "$T" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["data"]["activeTargets"]))')
  [ -z "$DOWN" ] && ok "все цели ($TOTAL) в состоянии UP" || { fail "цели не в UP:"; echo "$DOWN" | sed 's/^/           /'; }
fi
R=$(curl -fs "$PROM/api/v1/rules" 2>/dev/null | python3 -c 'import sys,json
g=json.load(sys.stdin)["data"]["groups"];print(sum(len(x["rules"]) for x in g))' 2>/dev/null)
[ "${R:-0}" -ge 30 ] && ok "загружено правил алертов: $R" || fail "загружено правил: ${R:-0} (ожидается ≥30)"
N=$(curl -fs "$PROM/api/v1/query" --data-urlencode 'query=count(up{job="node"}==1)' 2>/dev/null | python3 -c 'import sys,json;r=json.load(sys.stdin)["data"]["result"];print(r[0]["value"][1] if r else 0)' 2>/dev/null)
[ "${N:-0}" -ge 1 ] && ok "метрики node_exporter поступают (машин: $N)" || fail "нет данных node_exporter"
curl -fs "$PROM/api/v1/query" --data-urlencode 'query=count(probe_success)' 2>/dev/null | grep -q '"result":\[{' && ok "blackbox-проверки выполняются" || fail "нет метрик blackbox (probe_success)"
RET=$(ps -o args= -C prometheus 2>/dev/null | grep -o 'retention.time=[0-9a-z]*')
[ -n "$RET" ] && ok "хранение: $RET" || warn "retention не задан (по умолчанию 15d)"

section "4. Alertmanager и почта"
curl -fs "$AM/-/ready" >/dev/null && ok "Alertmanager отвечает (ready)" || fail "Alertmanager не отвечает на $AM"
curl -fs "$PROM/api/v1/alertmanagers" | grep -q '"activeAlertmanagers":\[{' && ok "Prometheus видит Alertmanager" || fail "Prometheus не подключён к Alertmanager"
grep -q 'smtp.example.com\|ops@example.com' /etc/prometheus/alertmanager.yml && fail "в alertmanager.yml остались шаблонные SMTP-адреса" || ok "SMTP-параметры заменены"
[ "$(cat /etc/monitoring/smtp_password 2>/dev/null)" = "CHANGE_ME" ] && fail "пароль SMTP не задан" || ok "пароль SMTP задан"
P=$(stat -c %a /etc/monitoring/smtp_password 2>/dev/null); { [ "$P" = 640 ] || [ "$P" = 600 ]; } && ok "права на smtp_password: $P" || fail "права на smtp_password: ${P:-нет файла}"
if [ "$1" = "--send-test" ]; then
  amtool --alertmanager.url="$AM" alert add CheckServerTest severity=warning instance=check --annotation=summary="Тестовое письмо проверки готовности" >/dev/null 2>&1 && ok "тестовый алерт отправлен — проверьте почту" || fail "не удалось отправить тестовый алерт"
else
  warn "реальная отправка письма не проверялась: запустите с --send-test"
fi

section "5. Безопасность"
LISTEN=$(ss -ltnH | awk '{print $4}')
for p in 9090 9093 9115; do
  if echo "$LISTEN" | grep -E ":$p\$" | grep -vq '^127\.0\.0\.1:\|^\[::1\]:'; then fail "порт $p слушает не только localhost"; else ok "порт $p доступен только локально"; fi
done
iptables -S INPUT 2>/dev/null | grep -q '^-P INPUT DROP' && ok "iptables: политика INPUT = DROP" || fail "iptables: политика INPUT не DROP (запустите harden-server.sh)"
iptables -S INPUT 2>/dev/null | grep -q -- '--dport 22.*-j ACCEPT' && ok "SSH разрешён правилом iptables" || warn "правило для SSH не найдено — проверьте доступ"
SSHD=$(sshd -T 2>/dev/null)
echo "$SSHD" | grep -qi '^permitrootlogin no' && ok "SSH: root-вход запрещён" || fail "SSH: root-вход разрешён"
echo "$SSHD" | grep -qi '^passwordauthentication no' && ok "SSH: вход по паролю отключён" || fail "SSH: вход по паролю включён"
check "fail2ban запущен" systemctl is-active --quiet fail2ban
check "unattended-upgrades установлен" dpkg -s unattended-upgrades
[ "$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)" = 1 ] && ok "sysctl-хардениг применён" || fail "sysctl-хардениг не применён"
[ -f /etc/iptables/rules.v4 ] && ok "правила iptables сохранены (переживут перезагрузку)" || fail "правила iptables не сохранены"

summary
