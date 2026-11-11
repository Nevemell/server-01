#!/bin/bash
# Харденинг сервера Prometheus. Использование: ADMIN_IP=203.0.113.10 ./harden-server.sh
# ВНИМАНИЕ: SSH останется доступен только с ADMIN_IP и только по ключам. Убедитесь, что ключ уже добавлен.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Запустите от root"; exit 1; }
: "${ADMIN_IP:?Укажите ADMIN_IP}"

apt-get install -y unattended-upgrades fail2ban iptables iptables-persistent

# SSH
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<EOC
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
X11Forwarding no
AllowAgentForwarding no
EOC
sshd -t && systemctl reload ssh

# Фаерволл: по умолчанию DROP, SSH только с админского IP, веб-интерфейсы только через localhost/SSH-туннель
iptables -F INPUT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s "$ADMIN_IP" -j ACCEPT
iptables -P INPUT DROP
netfilter-persistent save

# sysctl
cat > /etc/sysctl.d/99-hardening.conf <<EOC
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.tcp_syncookies=1
net.ipv4.icmp_echo_ignore_broadcasts=1
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
EOC
sysctl --system >/dev/null

# Автообновления безопасности и fail2ban
dpkg-reconfigure -f noninteractive unattended-upgrades
cat > /etc/fail2ban/jail.d/sshd.local <<EOC
[sshd]
enabled = true
backend = systemd
maxretry = 3
bantime = 1h
EOC
systemctl enable --now fail2ban && systemctl restart fail2ban

# Права на секреты
chmod 0640 /etc/monitoring/smtp_password 2>/dev/null || true
echo "Харденинг выполнен."
