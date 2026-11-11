# Мониторинг: Prometheus + Alertmanager + OpenVPN (версия 1.2)

Схема: 3 ВМ — сервер мониторинга (Prometheus, Alertmanager, blackbox) и две рабочие ВМ (одна из них OpenVPN).
Prometheus сам опрашивает машины (pull); порты экспортёров закрыты для всех, кроме IP Prometheus.

## Состав
- `server/` — конфиги Prometheus/Alertmanager/blackbox, `rules/` (33 алерта), `targets/` (список машин).
- `agent/` — всё для ВМ: фаервол, textfile-метрики (сертификаты, reboot, порт OpenVPN), юнит openvpn_exporter, права на статус-файл.
- `scripts/` — установка, харденинг, проверки готовности, сборка пакетов.
- `dist/` — готовые deb: `monitoring-server_1.2_all.deb`, `monitoring-agent_1.2_all.deb`.

## 1. Сервер мониторинга
    sudo apt install /tmp/monitoring-server_1.2_all.deb      # или: sudo scripts/install-server.sh
    sudo nano /etc/prometheus/targets/node.yml                # IP машин:9100 (включая 127.0.0.1:9100 самого сервера)
    sudo nano /etc/prometheus/targets/openvpn.yml             # VPN-сервер:9176
    sudo nano /etc/prometheus/targets/icmp.yml                # IP машин (ping)
    sudo nano /etc/prometheus/alertmanager.yml                # SMTP-сервер, from, to
    echo 'ПАРОЛЬ' | sudo tee /etc/monitoring/smtp_password >/dev/null
    sudo systemctl restart prometheus-alertmanager
    sudo monitoring-check-server --send-test

Файл `targets/openvpn-port.yml` по умолчанию пустой (`[]`): OpenVPN по UDP не проверяется TCP-пробой.
Вместо этого агент отдаёт метрику `openvpn_listening` (алерт `OpenVPNNotListening`).
Для OpenVPN по TCP впишите туда `- targets: ['IP:порт']`.

## 2. Каждая ВМ
    sudo PROMETHEUS_IP=1.2.3.4 apt install /tmp/monitoring-agent_1.2_all.deb
    sudo monitoring-check-agent

Без угловых скобок вокруг IP. Кладите .deb в /tmp, а не в домашнюю папку (иначе предупреждение про `_apt`).

## 3. VPN-сервер дополнительно
В `/etc/openvpn/server/server.conf` должно быть:

    status /var/log/openvpn/openvpn-status.log 10
    status-version 2

Затем:

    sudo systemctl restart openvpn-server@server
    sudo ./scripts/install-openvpn-exporter.sh      # нужны Go и доступ к GitHub; ставит экспортёр и права на статус-файл
    sudo monitoring-check-agent openvpn

## 4. Харденинг сервера мониторинга (последним шагом)
Держите вторую SSH-сессию. Свой IP: `echo $SSH_CLIENT | awk '{print $1}'`.

    sudo ADMIN_IP=203.0.113.10 ./scripts/harden-server.sh
    sudo monitoring-check-server --send-test

Если потеряли доступ: из запасной сессии `sudo iptables -P INPUT ACCEPT`.

## 5. Веб-интерфейс
    ssh -L 9090:127.0.0.1:9090 user@сервер     ->  http://localhost:9090  (/targets, /alerts, /graph)

## 6. Сборка пакетов
    scripts/build-debs.sh        # результат в dist/

## Проверка готовности
- `check-server.sh [--send-test]` / `monitoring-check-server` — сервисы, конфиги, цели UP, правила, почта, безопасность.
- `check-agent.sh [openvpn]` / `monitoring-check-agent` — node_exporter, метрики, фаервол, OpenVPN.
Код возврата 0 — готово, 1 — есть ошибки.

## Известные особенности
- Правило `OpenVPNServiceDown` ищет юниты `openvpn`, `openvpn-server@*`, `openvpn@*`.
- Фаервол агента пропускает loopback, иначе локальные проверки порта 9100 не работают.
- `openvpn_exporter` ставится из исходников (`go install`); для закрытой сети положите готовый бинарник в `/usr/local/bin/openvpn_exporter`.
