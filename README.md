# Мониторинг: Prometheus + Alertmanager + OpenVPN

Мониторинг виртуальных машин и OpenVPN-сервера: сбор метрик, 33 алерта, уведомления на e-mail.
Разворачивается двумя deb-пакетами или скриптами.

## Как это работает

Prometheus сам опрашивает машины каждые 15 секунд, проверяет правила алертов и передаёт сработавшие в Alertmanager,
а тот отправляет письма.

```
ВМ и VPN-сервер                     Сервер мониторинга
┌──────────────────────┐           ┌────────────────────────────┐
│ node_exporter   :9100│ ◄──────── │ Prometheus :9090           │
│ openvpn_exporter:9176│ ◄──────── │   └─► Alertmanager :9093 ──► e-mail
│ iptables: доступ     │           │ blackbox_exporter :9115    │
│ только с Prometheus  │           │ (ping машин)               │
└──────────────────────┘           └────────────────────────────┘
```

## Серверы

| Роль | Что установлено |
|---|---|
| Сервер мониторинга | Prometheus, Alertmanager, blackbox_exporter (порты слушают только `127.0.0.1`) |
| VPN-сервер | OpenVPN, node_exporter, openvpn_exporter |
| Остальные ВМ | node_exporter |

Prometheus лучше держать на отдельной машине: если он стоит на наблюдаемом сервере, то при падении сервера алерт не придёт.

## Требования

- Debian 12+ или Ubuntu 22.04/24.04, права `sudo`.
- Минимум 3 ВМ: сервер мониторинга, VPN-сервер и ещё одна машина.
- Сеть: с сервера мониторинга доступны порты 9100 и 9176 на ВМ и SMTP-сервер (порт 587 или 465).
- Почтовый ящик с логином и паролем (для Gmail и Яндекса нужен пароль приложения).
- На VPN-сервере для сборки экспортёра: `golang-go`, `git`.
- В `/etc/openvpn/server/server.conf` должны быть строки:
  ```
  status /var/log/openvpn/openvpn-status.log 10
  status-version 2
  ```

Остальное (Prometheus, node_exporter и т. д.) ставится автоматически как зависимости пакетов.

## Установка

Вместо `MON_IP` подставьте адрес сервера мониторинга, **без угловых скобок**. Файлы `.deb` кладите в `/tmp`.

**1. Сервер мониторинга**

```bash
sudo apt install /tmp/monitoring-server_1.2_all.deb
sudo nano /etc/prometheus/targets/node.yml        # адреса ВМ с портом 9100
sudo nano /etc/prometheus/targets/openvpn.yml     # VPN-сервер с портом 9176
sudo nano /etc/prometheus/targets/icmp.yml        # адреса ВМ для ping
sudo nano /etc/prometheus/alertmanager.yml        # SMTP-сервер, отправитель, получатель
echo 'ПАРОЛЬ_ПОЧТЫ' | sudo tee /etc/monitoring/smtp_password >/dev/null
sudo systemctl restart prometheus-alertmanager
```

**2. Каждая ВМ**

```bash
sudo PROMETHEUS_IP=MON_IP apt install /tmp/monitoring-agent_1.2_all.deb
```

**3. VPN-сервер (дополнительно)**

```bash
sudo ./scripts/install-openvpn-exporter.sh
```

**4. Защита сервера мониторинга** (последним шагом, держите вторую SSH-сессию)

```bash
sudo ADMIN_IP=ВАШ_IP ./scripts/harden-server.sh
```

Узнать свой IP: `echo $SSH_CLIENT | awk '{print $1}'`.

Вместо пакетов можно использовать скрипты: `scripts/install-server.sh` и `scripts/install-agent.sh`.

## Проверка

```bash
sudo monitoring-check-server --send-test    # на сервере мониторинга
sudo monitoring-check-agent                 # на каждой ВМ (на VPN-сервере: monitoring-check-agent openvpn)
```

Итог проверки: «ГОТОВО» или «НЕ ГОТОВО» с перечнем ошибок. Скрипты ничего не меняют.

Веб-интерфейс Prometheus открывается через SSH-туннель:

```bash
ssh -L 9090:127.0.0.1:9090 user@MON_IP
```

Затем `http://localhost:9090` (разделы Targets, Alerts, Graph).

Тест алерта: на второй ВМ выполните `sudo systemctl stop prometheus-node-exporter`. Через 2–3 минуты придёт письмо `InstanceDown`,
после `sudo systemctl start prometheus-node-exporter` придёт письмо о восстановлении.

## Какие алерты есть

- **ВМ (22):** недоступность и ping, CPU, load, iowait, steal, память, swap, OOM, место и inode на диске, прогноз заполнения диска, read-only ФС,
  нагрузка диска, ошибки сети, conntrack, файловые дескрипторы, сдвиг времени, перезагрузки, упавшие systemd-юниты.
- **OpenVPN (11):** сервис не работает, `tun0` не поднят, порт не слушается, нет клиентов, резкое падение числа клиентов,
  слишком много клиентов, аномальный трафик, сертификат скоро истечёт.

Письма: critical повторяются раз в час, warning раз в 4 часа, info раз в сутки; о восстановлении приходят всегда.

## Безопасность

- Prometheus, Alertmanager и blackbox слушают только `127.0.0.1`.
- На ВМ `iptables` пускает порты 9100 и 9176 только с IP Prometheus.
- На сервере мониторинга политика `INPUT = DROP`, SSH только с вашего IP и только по ключам, работают fail2ban и автообновления.
- Пароль почты хранится в отдельном файле `/etc/monitoring/smtp_password`.

Если после харденинга пропал SSH (сменился IP): из консоли ВМ выполните `sudo iptables -P INPUT ACCEPT`.

## Файлы

| Файл или папка | Для чего |
|---|---|
| `server/prometheus.yml` | конфиг Prometheus |
| `server/alertmanager.yml` | отправка писем, группировка, повторы |
| `server/blackbox.yml` | проверка ping |
| `server/rules/` | правила алертов (`infra.yml`, `openvpn.yml`, `openvpn-udp.yml`) |
| `server/targets/` | списки машин для опроса |
| `agent/` | фаервол, скрипты для метрик, юнит `openvpn_exporter` |
| `scripts/install-*.sh` | установка без пакетов |
| `scripts/harden-server.sh` | защита сервера мониторинга |
| `scripts/check-*.sh` | проверки готовности |
| `scripts/build-debs.sh` | сборка пакетов в `dist/` |
| `dist/` | готовые deb-пакеты |
| `docs/screenshots/` | скриншоты для отчёта |

Сборка пакетов из исходников: `scripts/build-debs.sh`.

## Частые проблемы

| Проблема | Решение |
|---|---|
| `dpkg -i` ругается на зависимости | используйте `apt install ./файл.deb` |
| Цель в состоянии DOWN | проверьте `PROMETHEUS_IP` в `/etc/monitoring-agent.conf` и `sudo iptables -S MONITORING` |
| Не приходят письма | `sudo journalctl -u prometheus-alertmanager -n 30`: проверьте SMTP-сервер, порт и пароль приложения |
| `openvpn_up 0` | у экспортёра нет доступа к статус-файлу: должны быть права `-rw-r----- root nogroup` |
| Ложный алерт по порту OpenVPN | при OpenVPN по UDP оставьте `targets/openvpn-port.yml` пустым (`[]`) |

## Ограничения

- Один Prometheus без резервирования: при его падении алерты не отправляются.
- Данные хранятся 30 дней.
- `openvpn_exporter` собирается из исходников (`kumina/openvpn_exporter`), в закрытой сети положите готовый бинарник в `/usr/local/bin/openvpn_exporter`.
