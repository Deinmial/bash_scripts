#!/bin/bash
# Скрипт первоначальной настройки Alt Linux
# Запускать от root
# Перед запуском убедится, что в SRC_DIR (ниже в коде есть переменаая) есть
# 1) ssh ключи
# 2) шрифт
# 3) openssh
# 4) klnagent64
# 5) r7-office

set -e # Останавливать выполнение при ошибке

# Цвета для логов
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

error_exit() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# Проверка прав root
if [ "$(id -u)" != "0" ]; then
   error_exit "Скрипт должен выполняться от root"
fi

# Путь к исходным файлам
SRC_DIR="/home/GOVIRK.RU/d.homyakov/setup"

# ---------------------------------------------------------
# НАСТРОЙКИ XRDP
# ---------------------------------------------------------
DESKTOP_ENV="mate"

case "$DESKTOP_ENV" in
    mate)     SESSION_CMD="mate-session" ;;
    xfce4)    SESSION_CMD="startxfce4" ;;
    gnome)    SESSION_CMD="gnome-session" ;;
    kde)      SESSION_CMD="startkde" ;;       # startplasma-x11 для новых версий
    cinnamon) SESSION_CMD="cinnamon-session" ;;
    *)        SESSION_CMD="mate-session" ;;     # По умолчанию
esac

# Пользователи для RDP для группы tsusers
RDP_USERS=("d.homyakov" "altws10admin" "a.shapkin")

# ---------------------------------------------------------
# ФУНКЦИИ
# ---------------------------------------------------------

# Настройки для sshd_config
apply_ssh_config() {
    local file=$1
    # Port
    sed -i 's/^#*Port .*/Port 25372/' "$file"
    grep -q "^Port " "$file" || echo "Port 25372" >> "$file"

    # PermitRootLogin
    sed -i 's/^#*PermitRootLogin .*/PermitRootLogin without-password/' "$file"
    grep -q "^PermitRootLogin " "$file" || echo "PermitRootLogin without-password" >> "$file"

    # MaxAuthTries
    sed -i 's/^#*MaxAuthTries .*/MaxAuthTries 3/' "$file"
    grep -q "^MaxAuthTries " "$file" || echo "MaxAuthTries 3" >> "$file"

    # PubkeyAuthentication
    sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' "$file"
    grep -q "^PubkeyAuthentication " "$file" || echo "PubkeyAuthentication yes" >> "$file"

    # PasswordAuthentication
    sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' "$file"
    grep -q "^PasswordAuthentication " "$file" || echo "PasswordAuthentication no" >> "$file"

    # PermitEmptyPasswords
    sed -i 's/^#*PermitEmptyPasswords .*/PermitEmptyPasswords no/' "$file"
    grep -q "^PermitEmptyPasswords " "$file" || echo "PermitEmptyPasswords no" >> "$file"

    # AllowAgentForwarding
    sed -i 's/^#*AllowAgentForwarding .*/AllowAgentForwarding no/' "$file"
    grep -q "^AllowAgentForwarding " "$file" || echo "AllowAgentForwarding no" >> "$file"

    # X11Forwarding
    sed -i 's/^#*X11Forwarding .*/X11Forwarding yes/' "$file"
    grep -q "^X11Forwarding " "$file" || echo "X11Forwarding yes" >> "$file"
}

# Добавление SSH ключа
add_key_to_authorized() {
    local user=$1
    local key_file=$2
    local home_dir

    if [ "$user" == "root" ]; then
        home_dir="/root"
    else
        home_dir="/home/$user"
        if ! id -u "$user" >/dev/null 2>&1; then
            log "WARNING: Пользователь $user не найден, ключи пропущены"
            return
        fi
    fi

    local ssh_dir="$home_dir/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    chown -R "$user":"$(id -gn $user)" "$ssh_dir"

    if [ -f "$key_file" ]; then
        # Проверяем, нет ли уже такого ключа
        if ! grep -qF "$(cat $key_file)" "$auth_keys" 2>/dev/null; then
            cat "$key_file" >> "$auth_keys"
            chmod 600 "$auth_keys"
            chown "$user":"$(id -gn $user)" "$auth_keys"
            log "Ключ для $user добавлен из $key_file"
        else
            log "Ключ для $user уже есть"
        fi
    else
        log "WARNING: Файл ключа $key_file не найден"
    fi
}

# ---------------------------------------------------------
# 1. Подготовка SSH
# ---------------------------------------------------------
log "Настройка SSH ключей и базовой конфигурации..."

# 1. Мой ключ (в root и в мой пользователь)
add_key_to_authorized "root" "$SRC_DIR/1_ssh/id_rsa.pub"
add_key_to_authorized "d.homyakov" "$SRC_DIR/1_ssh/id_rsa.pub"

# 2. Ключ второго админа (только в root)
add_key_to_authorized "root" "$SRC_DIR/2_ssh/id_rsa.pub"

# Применяем конфиг к текущему sshd (чтобы не потерять доступ до сборки нового)
SSHD_CONFIG_OLD="/etc/openssh/sshd_config"
if [ -f "$SSHD_CONFIG_OLD" ]; then
    apply_ssh_config "$SSHD_CONFIG_OLD"
    systemctl restart sshd
fi

# ---------------------------------------------------------
# 2. Настройка /etc/hosts
# ---------------------------------------------------------
log "Настройка /etc/hosts..."
grep -qxF "10.3.1.201.1	Vs" /etc/hosts || echo "10.3.1.201.1	Vs" >> /etc/hosts
grep -qxF "10.3.1.25		Kodeks" /etc/hosts || echo "10.3.1.25		Kodeks" >> /etc/hosts
grep -qxF "10.38.94.5	glad1" /etc/hosts || echo "10.38.94.5	glad1" >> /etc/hosts

# ---------------------------------------------------------
# 3. Репозитории
# ---------------------------------------------------------
log "Настройка репозиториев..."
apt-repo rm all
apt-repo add rpm http://10.3.2.135/mirror p10/branch/noarch classic
apt-repo add rpm http://10.3.2.135/mirror p10/branch/x86_64 classic
apt-repo add rpm http://10.3.2.135/mirror p10/branch/x86_64-i586 classic
apt-repo add rpm http://10.3.2.135/own x86_64 own

# ---------------------------------------------------------
# 4. Обновление системы и зависимости для сборки
# ---------------------------------------------------------
log "Обновление пакетной базы и установка зависимостей..."
apt-get update -y
# gcc, make и devel-пакеты нужны для сборки OpenSSH из исходников
apt-get install -y libjansson4 expect newt52 gcc make zlib-devel openssl-devel pam-devel
apt-get dist-upgrade -y

# ---------------------------------------------------------
# 5. Сетевой диск (pam_mount + cifs)
# ---------------------------------------------------------
log "Установка пакетов для сетевого диска..."
apt-get install -y pam_mount cifs-utils systemd-settings-enable-kill-user-processes

log "Настройка PAM..."
PAM_FILE="/etc/pam.d/system-auth"

if [ ! -f "${PAM_FILE}.bak" ]; then
    cp "$PAM_FILE" "${PAM_FILE}.bak"
fi

sed -i '/pam_mount.so/d' "$PAM_FILE"
sed -i '/pam_succeed_if.so.*systemd-user/d' "$PAM_FILE"

echo "session         [success=1 default=ignore] pam_succeed_if.so  service = systemd-user quiet" >> "$PAM_FILE"
echo "session         optional        pam_mount.so" >> "$PAM_FILE"

if [ -f "$SRC_DIR/pam_mount.conf.xml" ]; then
    cp -f "$SRC_DIR/pam_mount.conf.xml" /etc/security/pam_mount.conf.xml
    log "Конфиг pam_mount обновлен"
else
    error_exit "Файл $SRC_DIR/pam_mount.conf.xml не найден"
fi

# ---------------------------------------------------------
# 6. Установка R7-Office
# ---------------------------------------------------------
log "Установка R7-Office..."
R7_PKG="$SRC_DIR/r7-office-2026.1.2-1942.p8.x86_64.rpm"
if [ -f "$R7_PKG" ]; then
    apt-get install -y "$R7_PKG"
else
    error_exit "Пакет R7-Office не найден: $R7_PKG"
fi

# ---------------------------------------------------------
# 7. Шрифты
# ---------------------------------------------------------
log "Установка шрифтов..."
FONT_SRC="$SRC_DIR/fonts/TimesNewRomanRegular.ttf"
if [ -f "$FONT_SRC" ]; then
    cp -f "$FONT_SRC" /usr/share/fonts/
    fc-cache -f -v > /dev/null 2>&1
    log "Шрифт Times New Roman установлен"
else
    log "WARNING: Шрифт не найден"
fi

# ---------------------------------------------------------
# 8. Kaspersky klnagent64
# ---------------------------------------------------------
log "Установка и настройка Kaspersky klnagent64..."
KLN_PKG="$SRC_DIR/klnagent64-15.0.0-12912.x86_64.rpm"

if [ -f "$KLN_PKG" ]; then
    apt-get install -y "$KLN_PKG"

    # Запускаем пост-инсталляцию
    /usr/bin/expect << 'EOD'
    set timeout 60
    spawn /opt/kaspersky/klnagent64/lib/bin/setup/postinstall.pl

    # 1. Ждем немного, пока появится текст лицензии, и закрываем его (q)
    # sleep 2 дает время на вывод текста в консоль
    sleep 5
    send "q\r"

    # Небольшая пауза, чтобы установщик осознал, что текст прочитан
    sleep 5

    # 2. Принимаем соглашение (Y)
    # Обычно вопрос появляется сразу после закрытия текста
    send "Y\r"

    # 3. IP адрес сервера
    expect "DNS-name"
    send "10.38.94.5\r"

    # 4. Порт (Enter - по умолчанию 14000)
    expect "port number"
    send "\r"

    # 5. SSL Порт (Enter - по умолчанию 13000)
    expect "ssl port number"
    send "\r"

    # 6. Подтверждение SSL (Enter - по умолчанию Y)
    expect "SSL encryption"
    send "\r"

    # 7. Режим шлюза (Enter - по умолчанию 1)
    expect "gateway mode"
    send "\r"

    expect eof
EOD
    log "Kaspersky Agent настроен"
else
    error_exit "Пакет Kaspersky не найден"
fi

# ---------------------------------------------------------
# 9. Yandex Browser
# ---------------------------------------------------------
log "Установка Yandex Browser..."
apt-get install -y yandex-browser-stable

# ---------------------------------------------------------
# 10. Сборка и установка OpenSSH 10.3p1
# ---------------------------------------------------------
log "Сборка OpenSSH 10.3p1..."
OPENSSH_SRC="$SRC_DIR/openssh-10.3p1"

if [ -d "$OPENSSH_SRC" ]; then
    cd "$OPENSSH_SRC"

    log "Конфигурация..."
    chmod +x configure
    if [ -f "./ssh-keygen" ]; then chmod +x ssh-keygen; fi

    ./configure --prefix=/usr --sysconfdir=/etc/openssh --with-pam --with-systemd

    log "Компиляция..."
    make -j$(nproc)

    log "Установка..."
    make install

    log "Проверка версии:"
    ssh -V

    # Применяем конфиг для НОВОЙ версии
    NEW_SSHD_CONFIG="/etc/openssh/sshd_config"
    if [ -f "$NEW_SSHD_CONFIG" ]; then
        apply_ssh_config "$NEW_SSHD_CONFIG"
        log "Конфигурация нового OpenSSH применена"
    else
        # Если файла нет нужно создать из примера
        if [ -f "/etc/openssh/sshd_config.default" ]; then
             cp /etc/openssh/sshd_config.default /etc/openssh/sshd_config
             apply_ssh_config "/etc/openssh/sshd_config"
        fi
    fi

    systemctl daemon-reload
    systemctl restart sshd
    log "OpenSSH 10.3p1 установлен и запущен"

    cd -
else
    error_exit "Папка с исходниками OpenSSH не найдена: $OPENSSH_SRC"
fi

# ---------------------------------------------------------
# 11. Ядро
# ---------------------------------------------------------
log "Обновление ядра..."
apt-get install -y update-kernel
update-kernel -y

# ---------------------------------------------------------
# 12. XRDP
# ---------------------------------------------------------
log "Настройка XRDP для $DESKTOP_ENV..."

apt-get install -y xrdp

STARTWM="/etc/xrdp/startwm.sh"
if grep -q "exit 0" "$STARTWM"; then
    # Удаляем старые команды сессий, чтобы не было конфликтов
    sed -i '/mate-session/d; /startxfce4/d; /gnome-session/d; /startkde/d; /cinnamon-session/d' "$STARTWM"
    # Вставляем новую команду перед exit 0
    sed -i "/^exit 0/i\\$SESSION_CMD" "$STARTWM"
    log "startwm.sh настроен на $SESSION_CMD"
else
    echo "$SESSION_CMD" >> "$STARTWM"
    echo "exit 0" >> "$STARTWM"
fi

getent group tsusers >/dev/null 2>&1 || groupadd tsusers

for user in "${RDP_USERS[@]}"; do
    if id -u "$user" >/dev/null 2>&1; then
        usermod -aG tsusers "$user"
        log "Пользователь $user добавлен в tsusers"
    else
        log "WARNING: Пользователь $user не найден"
    fi
done

systemctl enable xrdp
systemctl restart xrdp
log "XRDP запущен"

# ---------------------------------------------------------
# 13. Перезагрузка
# ---------------------------------------------------------
log "========================================="
log "НАСТРОЙКА ЗАВЕРШЕНА"
log "Перезагрузка через 10 секунд..."
log "========================================="

for i in {10..1}; do
    echo -n "$i "
    sleep 1
done
echo ""
reboot
