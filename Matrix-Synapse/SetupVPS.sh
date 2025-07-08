set -e
set -u

### === ПЕРЕМЕННЫЕ ===
NEW_USER="matrixadmin"
SSH_PORT="22"
PUBLIC_KEY="ssh-rsa AAAA...твой_ssh_ключ_сюда"

### === ПРОВЕРКА ROOT ===
if [[ "$EUID" -ne 0 ]]; then
  echo "Запусти скрипт от root!"
  exit 1
fi

echo "🔧 Обновление системы..."
apt update && apt upgrade -y

echo "📦 Установка полезных утилит..."
apt install -y sudo curl wget git ufw fail2ban unzip net-tools jq \
  gnupg2 ca-certificates lsb-release software-properties-common \
  lsof bash-completion apt-transport-https software-properties-common

### === СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ ===
echo "👤 Создание пользователя $NEW_USER..."
adduser --disabled-password --gecos "" "$NEW_USER"
usermod -aG sudo "$NEW_USER"

echo "🔑 Установка SSH-ключа для $NEW_USER..."
mkdir -p /home/$NEW_USER/.ssh
echo "$PUBLIC_KEY" > /home/$NEW_USER/.ssh/authorized_keys
chmod 600 /home/$NEW_USER/.ssh/authorized_keys
chmod 700 /home/$NEW_USER/.ssh
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh

### === НАСТРОЙКА SSH ===
echo "🛡 Настройка SSH..."
sed -i "s/^#Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl reload sshd

### === НАСТРОЙКА FIREWALL ===
echo "🔥 Настройка UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw --force enable

### === НАСТРОЙКА Fail2Ban ===
echo "🚨 Настройка Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban

### === УСТАНОВКА Docker ===
echo "🐳 Установка Docker..."
curl -fsSL https://get.docker.com | sh
usermod -aG docker "$NEW_USER"

### === УСТАНОВКА Docker Compose ===
echo "🔧 Установка Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

### === УСТАНОВКА Nginx и Certbot ===
echo "🌐 Установка Nginx и Certbot..."
apt install -y nginx certbot python3-certbot-nginx
systemctl enable nginx
systemctl start nginx

### === УСТАНОВКА PostgreSQL ===
echo "🗄 Установка PostgreSQL..."
apt install -y postgresql postgresql-contrib

### === НАСТРОЙКА ВРЕМЕНИ ===
echo "⏱️ Настройка времени..."
timedatectl set-timezone UTC
timedatectl set-ntp true