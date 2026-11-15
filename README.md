# Хранилище резервных копий: пакеты и порядок установки

## Состав

| Файл | Ставится на | Назначение |
|---|---|---|
| `packages/backup-storage_1.3_all.deb` | backup-хост (`server-backup`) | Бэкап на restic, systemd-таймеры, проверка восстановления, `backup-storage-selfcheck` |
| `packages/prometheus-config_1.3_all.deb` | ВМ с Prometheus | Правила алертов (`backup.yml`, `backup-apt.yml`), `prometheus-config-check` |
| `source/` | — | Исходники обоих пакетов (каталог `debian/` для `dpkg-buildpackage`, `tests/` с тестами правил) |

## Порядок

### 1. backup-хост
```bash
sudo apt install /tmp/backup-storage_1.3_all.deb      # на вопрос про backup.conf: N
sudo sh -c 'mkdir -p /etc/restic && openssl rand -base64 32 > /etc/restic/password && chmod 600 /etc/restic/password'
sudo cat /etc/restic/password                          # сохранить в менеджер паролей и офлайн-копию
export RESTIC_PASSWORD_FILE=/etc/restic/password
sudo -E restic -r /srv/backup/restic init
sudo nano /etc/backup-storage/backup.conf              # BACKUP_PATHS, METRIC_DIR, при необходимости PG_DB / RESTIC_REMOTE
sudo systemctl start backup-storage.service
sudo systemctl start backup-storage-check.service
sudo systemctl enable --now backup-storage.timer backup-storage-check.timer
sudo backup-storage-selfcheck
```
Каталог `METRIC_DIR` должен совпадать с textfile-каталогом node_exporter
(в Ubuntu: `/var/lib/prometheus/node-exporter`).

### 2. ВМ с Prometheus
```bash
sudo apt install jq /tmp/prometheus-config_1.3_all.deb
```
В `/etc/prometheus/prometheus.yml` один раз: `rule_files: ['/etc/prometheus/rules/*.yml']`
и job `backup-host` с адресом `<server-backup>:9100` (отступы job'ов одинаковые, только пробелы).
```bash
sudo promtool check config /etc/prometheus/prometheus.yml
sudo systemctl reload prometheus
sudo prometheus-config-check
```
Порт 9100 на backup-хосте откройте только для адреса Prometheus.

## Проверка алертов (пункт 7 задания)

```bash
# на backup-хосте: имитация «бэкапа не было 30 часов»
echo "backup_last_success_timestamp_seconds $(( $(date +%s) - 108000 ))" | sudo tee /var/lib/prometheus/node-exporter/backup.prom
# через 10 минут BackupTooOld = firing (http://<prometheus>:9090/alerts); сделайте скриншот
sudo systemctl start backup-storage.service            # вернуть метрику в норму
# BackupHostDown: sudo systemctl stop prometheus-node-exporter  (через 5 минут), затем запустить обратно
```

## Что делают алерты

BackupTooOld (бэкап старше 26 ч), BackupCheckTooOld (проверка старше 8 суток),
BackupHostDown, BackupDiskAlmostFull (меньше 15% на `/` или `/srv`),
BackupDiskWillFillIn24h, AptRepoUnavailable (нужен job `blackbox-apt`; пока нет
apt-репозитория, он необязателен).

## Известные ограничения

- Внешней копии нет (`RESTIC_REMOTE` пуст): при потере диска backup-хоста данные потеряны.
  Для 3-2-1 нужен второй хост или объектное хранилище.
- Пакеты собраны через `dpkg-deb` без debhelper, `promtool test rules` и `lintian` не запускались.
  Перед публикацией в apt-репозиторий пересоберите: `dpkg-buildpackage -us -uc -b`.
- Во всех пакетах стоит заглушка `Ваше Имя <you@example.com>`.
- Таймеры не включаются при установке: сначала нужны репозиторий restic и конфиг.
