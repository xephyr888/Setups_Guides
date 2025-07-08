#!/bin/bash
set -e

# === НАСТРОЙКИ ===
USERNAME="deploy"                          # Имя создаваемого пользователя
SSH_PUBKEY="ssh-rsa или ed AAAA..."          # Вставь сюда свой публичный ключ SSH
EMAIL="admin@example.com"                 # Email для Certbot

echo "[1/10] Обновление системы..."
apt update && apt upgrade -y

echo "[2/10] Установка нужных пакетов..."
apt install -y sudo curl ufw gnupg lsb-release ca-certificates apt-transport-https \
               software-properties-common nginx certbot python3-certbot-nginx postgresql

echo "[3/10] Создание пользователя '$USERNAME'..."
adduser --disabled-password --gecos "" "$USERNAME"
usermod -aG sudo "$USERNAME"
mkdir -p /home/$USERNAME/.ssh
echo "$SSH_PUBKEY" > /home/$USERNAME/.ssh/authorized_keys
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

echo "[4/10] Защита SSH..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

echo "[5/10] Настройка фаервола (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw --force enable

echo "[6/10] Установка Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

echo "[7/10] Установка Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
     -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "[8/10] Добавление пользователя '$USERNAME' в группу docker..."
usermod -aG docker $USERNAME

echo "[9/10] Проверка версий:"
docker --version
docker-compose --version

echo "[10/10] Готово!"
echo "➡️ Перезайди по SSH как '$USERNAME' и начинай работу с Docker."
