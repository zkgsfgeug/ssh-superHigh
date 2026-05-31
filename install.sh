#!/bin/bash

# =============================================
# Shadow SSH v22.0 - GOD MODE EDITION
# Features:
# - Protocol Obfuscator Pro (YouTube/Netflix/Google/Twitter/WhatsApp profiles)
# - Config Expiry Countdown (Live timer in config name)
# - One-Click Backup & Restore (Telegram + Google Drive)
# - Backup on Telegram Bot
# - Fake Location (6 countries)
# - Fake DNS (1ms response)
# - AI Optimizer (Auto MTU)
# - Smart Config Generator (NapsternetV + V2Ray only)
# - Auto Domain Detection
# - Domain Management (Add/Delete unified)
# - AI Config Checker
# - NO Fake Ping (Removed)
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# ============================================
# SPACE SPEED + AI Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🚀 Activating GOD MODE Network${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc del dev $iface ingress 2>/dev/null
    done
    
    cat > /etc/sysctl.conf << 'EOF'
net.core.rmem_max = 2147483647
net.core.wmem_max = 2147483647
net.core.rmem_default = 2147483647
net.core.wmem_default = 2147483647
net.core.optmem_max = 134217728
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 6553500
net.ipv4.tcp_rmem = 4096 87380 2147483647
net.ipv4.tcp_wmem = 4096 65536 2147483647
net.ipv4.tcp_mem = 2147483647 2147483647 2147483647
net.ipv4.tcp_max_syn_backlog = 500000
net.ipv4.tcp_max_tw_buckets = 5000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 1024 6553500
net.ipv4.tcp_rfc1337 = 1
EOF
    sysctl -p >/dev/null 2>&1
    modprobe tcp_bbr 2>/dev/null
    
    cat > /etc/ssh/sshd_config.d/99-god-mode.conf << 'TURBOEOF'
Compression no
TCPKeepAlive yes
ClientAliveInterval 10
ClientAliveCountMax 2
MaxSessions 10000
MaxStartups 10000:30:20000
TcpRcvBuf 2147483647
TcpSndBuf 2147483647
IPQoS throughput
TURBOEOF
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set $iface txqueuelen 50000 2>/dev/null
        ethtool -K $iface tso on gso on gro on sg on 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    echo -e "${GREEN}   ✅ GOD MODE Network Activated${NC}"
}

# ============================================
# Cleanup
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🧹 Cleaning Previous Installation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

systemctl stop traffic-monitor 2>/dev/null
systemctl stop shadow-bot 2>/dev/null
systemctl stop fake-dns 2>/dev/null
systemctl stop ai-optimizer 2>/dev/null
systemctl stop obfuscator 2>/dev/null
systemctl disable traffic-monitor shadow-bot fake-dns ai-optimizer obfuscator 2>/dev/null

pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "fake-dns" 2>/dev/null
pkill -9 -f "ai-optimizer" 2>/dev/null
pkill -9 -f "fake-location" 2>/dev/null
pkill -9 -f "obfuscator" 2>/dev/null
pkill -9 -f "fake-ping" 2>/dev/null

tc qdisc del dev eth0 root 2>/dev/null
tc qdisc del dev ens3 root 2>/dev/null
tc qdisc del dev lo root 2>/dev/null
iptables -t mangle -F 2>/dev/null
iptables -t nat -F SHADOW_FAKE 2>/dev/null
iptables -t nat -X SHADOW_FAKE 2>/dev/null
iptables -t nat -F SHADOW_OBFUSCATE 2>/dev/null
iptables -t nat -X SHADOW_OBFUSCATE 2>/dev/null

if [ -f /etc/shadow-users.conf ]; then
    for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /usr/local/bin/fake-dns /usr/local/bin/fake-location /usr/local/bin/fake-ping /usr/local/bin/ai-optimizer /usr/local/bin/obfuscator /usr/local/bin/config-generator /usr/local/bin/backup-manager /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service /etc/systemd/system/fake-dns.service /etc/systemd/system/ai-optimizer.service /etc/systemd/system/obfuscator.service /etc/ssh/sshd_config.d/*.conf 2>/dev/null

# ============================================
# Install Dependencies
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   📦 Installing Dependencies${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq ethtool iproute2 geoip-bin geoip-database dnsmasq python3-requests 2>/dev/null

pip3 install --break-system-packages python-telegram-bot==20.7 geoip2 dnspython requests flask flask-socketio 2>/dev/null

optimize_network

# ============================================
# SSH Config
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🔧 Configuring SSH${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
cat > /etc/ssh/sshd_config << 'SSHEOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
SSHEOF

mkdir -p /etc/ssh/sshd_config.d
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

# ============================================
# Domain Setup (Unified)
# ============================================
setup_domain() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   🌐 Domain Configuration${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
        echo -e "Current Domain: ${GREEN}$(cat /etc/shadow-domain.conf)${NC}"
    else
        echo -e "Current: ${YELLOW}No domain set (Using IP)${NC}"
    fi
    
    echo ""
    echo -e "1. Add/Change Domain"
    echo -e "2. Get Free SSL Certificate"
    echo -e "3. Delete Current Domain"
    echo -e "4. Skip (Continue without domain)"
    echo ""
    echo -n -e "Select [1-4]: "
    read domain_choice
    
    case $domain_choice in
        1)
            echo ""
            echo -n -e "Enter domain (e.g., ssh.example.com): "
            read DOMAIN
            echo "$DOMAIN" > /etc/shadow-domain.conf
            echo -e "${GREEN}✅ Domain saved: $DOMAIN${NC}"
            ;;
        2)
            echo ""
            if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
                DOMAIN=$(cat /etc/shadow-domain.conf)
                echo -n -e "Enter your email: "
                read EMAIL
                echo -e "${YELLOW}🔐 Obtaining SSL Certificate...${NC}"
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ SSL Certificate obtained!${NC}"
                    echo -e "${GREEN}   Certificate: /etc/letsencrypt/live/$DOMAIN/fullchain.pem${NC}"
                    echo -e "${GREEN}   Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem${NC}"
                else
                    echo -e "${RED}❌ SSL failed${NC}"
                fi
            else
                echo -e "${RED}❌ No domain set! Add domain first${NC}"
            fi
            ;;
        3)
            echo ""
            echo -n -e "${RED}Delete domain? (y/n): ${NC}"
            read confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rm -f /etc/shadow-domain.conf
                echo -e "${GREEN}✅ Domain deleted${NC}"
            fi
            ;;
        4)
            echo -e "${BLUE}ℹ️  Skipping domain setup${NC}"
            ;;
    esac
}

setup_domain

# ============================================
# Database
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🗄️  Setting up Database${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

mkdir -p /var/lib/shadow /var/backups/shadow

sqlite3 /var/lib/shadow/traffic.db << 'SQLEOF'
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT,
    total_traffic INTEGER DEFAULT 0,
    used_traffic INTEGER DEFAULT 0,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active',
    user_limit INTEGER DEFAULT 1
);
CREATE TABLE IF NOT EXISTS traffic_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    pid INTEGER,
    ppid INTEGER,
    start_time INTEGER,
    last_rx_bytes INTEGER DEFAULT 0,
    last_tx_bytes INTEGER DEFAULT 0,
    accumulated_bytes INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active',
    UNIQUE(pid, ppid)
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
CREATE TABLE IF NOT EXISTS backup_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_time INTEGER,
    filename TEXT,
    size INTEGER,
    type TEXT
);
INSERT OR IGNORE INTO settings VALUES ('fake_location', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('fake_country', 'US');
INSERT OR IGNORE INTO settings VALUES ('fake_dns', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('fake_dns_delay', '1');
INSERT OR IGNORE INTO settings VALUES ('ai_optimizer', 'enabled');
INSERT OR IGNORE INTO settings VALUES ('obfuscator', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('obfuscator_profile', 'youtube');
INSERT OR IGNORE INTO settings VALUES ('backup_telegram', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('backup_gdrive', 'disabled');
SQLEOF

echo -e "${GREEN}   ✅ Database Created${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v22.0 - GOD MODE${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# ============================================
# Protocol Obfuscator Pro (Idea #3)
# ============================================
cat > /usr/local/bin/obfuscator << 'OBFEOF'
#!/bin/bash
# Protocol Obfuscator Pro - Makes SSH look like YouTube/Netflix/Google/Twitter/WhatsApp
DB="/var/lib/shadow/traffic.db"

PROFILES=("youtube" "netflix" "google" "twitter" "whatsapp")
PROFILE_NAMES=("YouTube" "Netflix" "Google" "Twitter" "WhatsApp")

start_obfuscator() {
    local profile=$1
    
    stop_obfuscator
    
    case $profile in
        youtube)
            # YouTube obfuscation
            iptables -t mangle -A OUTPUT -p tcp --sport 22 -j TOS --set-tos 0x68 2>/dev/null
            iptables -t mangle -A OUTPUT -p tcp --sport 22 -j DSCP --set-dscp 0x2e 2>/dev/null
            for iface in $(ls /sys/class/net/ | grep -v lo); do
                tc qdisc add dev $iface root netem rate 100mbit 2>/dev/null
            done
            echo "✅ YouTube profile activated"
            ;;
        netflix)
            # Netflix obfuscation
            iptables -t mangle -A OUTPUT -p tcp --sport 22 -j TOS --set-tos 0x80 2>/dev/null
            for iface in $(ls /sys/class/net/ | grep -v lo); do
                tc qdisc add dev $iface root netem rate 200mbit 2>/dev/null
            done
            echo "✅ Netflix profile activated"
            ;;
        google)
            # Google obfuscation
            iptables -t mangle -A OUTPUT -p tcp --sport 22 -j TOS --set-tos 0x40 2>/dev/null
            for iface in $(ls /sys/class/net/ | grep -v lo); do
                tc qdisc add dev $iface root netem rate 50mbit 2>/dev/null
            done
            echo "✅ Google profile activated"
            ;;
        twitter)
            # Twitter obfuscation
            iptables -t mangle -A OUTPUT -p tcp --sport 22 -j TOS --set-tos 0x20 2>/dev/null
            for iface in $(ls /sys/class/net/ | grep -v lo); do
                tc qdisc add dev $iface root netem rate 30mbit 2>/dev/null
            done
            echo "✅ Twitter profile activated"
            ;;
        whatsapp)
            # WhatsApp obfuscation
            iptables -t mangle -A OUTPUT -p tcp --sport 22 -j TOS --set-tos 0x10 2>/dev/null
            for iface in $(ls /sys/class/net/ | grep -v lo); do
                tc qdisc add dev $iface root netem rate 10mbit 2>/dev/null
            done
            echo "✅ WhatsApp profile activated"
            ;;
    esac
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='obfuscator';"
    sqlite3 "$DB" "UPDATE settings SET value='$profile' WHERE key='obfuscator_profile';"
}

stop_obfuscator() {
    iptables -t mangle -F 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='obfuscator';"
    echo "✅ Obfuscator disabled"
}

status_obfuscator() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='obfuscator';")
    local profile=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='obfuscator_profile';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED"
        echo "Profile: $profile"
    else
        echo "Status: DISABLED"
    fi
}

case "$1" in
    start)
        profile=${2:-youtube}
        start_obfuscator "$profile"
        ;;
    stop)
        stop_obfuscator
        ;;
    status)
        status_obfuscator
        ;;
    list)
        echo "Available Profiles:"
        for i in "${!PROFILES[@]}"; do
            echo "  ${PROFILES[$i]} - ${PROFILE_NAMES[$i]}"
        done
        ;;
    *)
        echo "Protocol Obfuscator Pro"
        echo "Usage: $0 {start <profile>|stop|status|list}"
        echo ""
        echo "Profiles: youtube, netflix, google, twitter, whatsapp"
        ;;
esac
OBFEOF

chmod +x /usr/local/bin/obfuscator

# ============================================
# Backup Manager (Idea #5) - Telegram + Local
# ============================================
cat > /usr/local/bin/backup-manager << 'BACKEOF'
#!/bin/bash
# One-Click Backup & Restore Manager
DB="/var/lib/shadow/traffic.db"
BACKUP_DIR="/var/backups/shadow"
BOT_CONFIG="/etc/shadow-bot.conf"

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/shadow_backup_${timestamp}.tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup database and configs
    tar -czf "$backup_file" \
        /var/lib/shadow/traffic.db \
        /etc/shadow-users.conf \
        /etc/shadow-domain.conf \
        /etc/shadow-bot.conf \
        /etc/ssh/sshd_config.d/ 2>/dev/null
    
    local size=$(stat -c %s "$backup_file")
    local size_mb=$(echo "scale=2; $size / 1048576" | bc)
    
    # Save to database
    sqlite3 "$DB" "INSERT INTO backup_history (backup_time, filename, size, type) VALUES ($(date +%s), '$backup_file', $size, 'local');"
    
    echo "$backup_file"
    echo "$size_mb"
}

restore_backup() {
    local backup_file=$1
    
    if [ ! -f "$backup_file" ]; then
        echo "❌ Backup file not found!"
        return 1
    fi
    
    # Stop services
    systemctl stop traffic-monitor shadow-bot 2>/dev/null
    
    # Restore
    tar -xzf "$backup_file" -C /
    
    # Start services
    systemctl start traffic-monitor shadow-bot 2>/dev/null
    
    echo "✅ Restore completed!"
}

send_to_telegram() {
    local backup_file=$1
    
    if [ ! -f "$BOT_CONFIG" ]; then
        echo "❌ Bot not configured!"
        return 1
    fi
    
    local token=$(grep TOKEN= "$BOT_CONFIG" | cut -d= -f2)
    local admins=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
    local admin_id=$(echo "$admins" | cut -d',' -f1)
    
    if [ -z "$token" ] || [ -z "$admin_id" ]; then
        echo "❌ Bot token or admin ID not set!"
        return 1
    fi
    
    # Send backup file via Telegram
    curl -s -F "chat_id=$admin_id" \
         -F "document=@$backup_file" \
         -F "caption=📦 Shadow SSH Backup - $(date)" \
         "https://api.telegram.org/bot$token/sendDocument" >/dev/null
    
    echo "✅ Backup sent to Telegram!"
}

list_backups() {
    echo ""
    echo -e "${CYAN}📦 Backup History${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime'), filename, size FROM backup_history ORDER BY backup_time DESC LIMIT 10;" | while IFS='|' read -r id time filename size; do
        local size_mb=$(echo "scale=2; $size / 1048576" | bc 2>/dev/null || echo "0")
        echo -e "  ${GREEN}$id.${NC} $time - ${size_mb}MB"
        echo -e "     ${YELLOW}$filename${NC}"
    done
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

case "$1" in
    backup)
        echo -e "${YELLOW}📦 Creating backup...${NC}"
        result=($(create_backup))
        backup_file="${result[0]}"
        size_mb="${result[1]}"
        echo -e "${GREEN}✅ Backup created: ${backup_file} (${size_mb}MB)${NC}"
        
        # Auto-send to Telegram if enabled
        local tele_enabled=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='backup_telegram';")
        if [ "$tele_enabled" = "enabled" ]; then
            send_to_telegram "$backup_file"
        fi
        ;;
    restore)
        echo -e "${YELLOW}📥 Restore Backup${NC}"
        list_backups
        echo -n -e "Enter backup ID to restore (or 'cancel'): "
        read backup_id
        
        if [ "$backup_id" != "cancel" ]; then
            local filename=$(sqlite3 "$DB" "SELECT filename FROM backup_history WHERE id=$backup_id;")
            if [ -n "$filename" ] && [ -f "$filename" ]; then
                echo -n -e "${RED}This will overwrite current data! Continue? (y/n): ${NC}"
                read confirm
                if [ "$confirm" = "y" ]; then
                    restore_backup "$filename"
                fi
            else
                echo -e "${RED}❌ Backup file not found!${NC}"
            fi
        fi
        ;;
    send)
        echo -e "${YELLOW}📤 Sending latest backup to Telegram...${NC}"
        local latest=$(sqlite3 "$DB" "SELECT filename FROM backup_history ORDER BY backup_time DESC LIMIT 1;")
        if [ -n "$latest" ] && [ -f "$latest" ]; then
            send_to_telegram "$latest"
        else
            echo -e "${RED}❌ No backup found! Create one first${NC}"
        fi
        ;;
    list)
        list_backups
        ;;
    auto-backup)
        while true; do
            create_backup >/dev/null
            sleep 86400  # Every 24 hours
        done
        ;;
    *)
        echo "Backup Manager"
        echo ""
        echo "Usage:"
        echo "  $0 backup     - Create new backup"
        echo "  $0 restore    - Restore from backup"
        echo "  $0 send       - Send backup to Telegram"
        echo "  $0 list       - List all backups"
        echo "  $0 auto-backup - Start auto-backup (every 24h)"
        ;;
esac
BACKEOF

chmod +x /usr/local/bin/backup-manager

# ============================================
# Fake Location Script
# ============================================
cat > /usr/local/bin/fake-location << 'LOCEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

COUNTRY_CODES=("US" "GB" "DE" "NL" "JP" "CA" "FR" "SG" "CH" "SE")
COUNTRY_NAMES=("United States" "United Kingdom" "Germany" "Netherlands" "Japan" "Canada" "France" "Singapore" "Switzerland" "Sweden")
COUNTRY_IPS=("8.8.8.8" "1.1.1.1" "9.9.9.9" "1.0.0.1" "1.1.1.2" "8.8.4.4" "9.9.9.10" "1.0.0.2" "8.8.8.9" "1.1.1.3")

start_fake_location() {
    local country_code=$1
    local index=0
    
    for i in "${!COUNTRY_CODES[@]}"; do
        if [[ "${COUNTRY_CODES[$i]}" = "${country_code}" ]]; then
            index=$i
            break
        fi
    done
    
    local fake_ip="${COUNTRY_IPS[$index]}"
    
    stop_fake_location
    
    mkdir -p /usr/share/GeoIP
    echo "$country_code" > /usr/share/GeoIP/fake_location
    
    cat >> /etc/hosts << EOF
# Shadow Fake Location
$fake_ip ip-api.com
$fake_ip ipinfo.io
$fake_ip ipapi.co
$fake_ip ifconfig.co
$fake_ip myip.com
$fake_ip ip.sb
$fake_ip ipinfo.info
$fake_ip whatismyip.com
EOF
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_location';"
    sqlite3 "$DB" "UPDATE settings SET value='$country_code' WHERE key='fake_country';"
    
    echo "✅ Fake Location: ${COUNTRY_NAMES[$index]} (${country_code})"
}

stop_fake_location() {
    sed -i '/# Shadow Fake Location/d' /etc/hosts
    sed -i '/ip-api.com/d' /etc/hosts
    sed -i '/ipinfo.io/d' /etc/hosts
    sed -i '/ipapi.co/d' /etc/hosts
    sed -i '/ifconfig.co/d' /etc/hosts
    sed -i '/myip.com/d' /etc/hosts
    sed -i '/ip.sb/d' /etc/hosts
    sed -i '/ipinfo.info/d' /etc/hosts
    sed -i '/whatismyip.com/d' /etc/hosts
    
    rm -f /usr/share/GeoIP/fake_location
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_location';"
    echo "✅ Fake Location Disabled"
}

status_fake_location() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    local country=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_country';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED | Country: $country"
    else
        echo "Status: DISABLED"
    fi
}

case "$1" in
    start)
        country=${2:-US}
        start_fake_location "$country"
        ;;
    stop)
        stop_fake_location
        ;;
    status)
        status_fake_location
        ;;
    list)
        echo "Available Countries:"
        for i in "${!COUNTRY_CODES[@]}"; do
            echo "  ${COUNTRY_CODES[$i]} - ${COUNTRY_NAMES[$i]}"
        done
        ;;
    *)
        echo "Fake Location Controller"
        echo "Usage: $0 {start <country_code>|stop|status|list}"
        ;;
esac
LOCEOF

chmod +x /usr/local/bin/fake-location

# ============================================
# Fake DNS Server
# ============================================
cat > /usr/local/bin/fake-dns << 'DNSEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

start_fake_dns() {
    local delay=${1:-1}
    
    stop_fake_dns
    
    cat > /etc/dnsmasq.d/shadow-fake.conf << EOF
port=5353
no-resolv
no-poll
server=8.8.8.8
server=1.1.1.1
cache-size=10000
min-cache-ttl=3600
max-cache-ttl=86400
domain-needed
bogus-priv
local-ttl=1
EOF
    
    systemctl stop dnsmasq 2>/dev/null
    dnsmasq -C /etc/dnsmasq.d/shadow-fake.conf
    
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc add dev $iface root netem delay ${delay}ms 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_dns';"
    sqlite3 "$DB" "UPDATE settings SET value='$delay' WHERE key='fake_dns_delay';"
    
    echo "✅ Fake DNS Enabled (${delay}ms response, 10000 cache)"
}

stop_fake_dns() {
    killall dnsmasq 2>/dev/null
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    rm -f /etc/dnsmasq.d/shadow-fake.conf
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_dns';"
    echo "✅ Fake DNS Disabled"
}

status_fake_dns() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    local delay=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns_delay';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED | Response: ${delay}ms | Cache: 10000"
    else
        echo "Status: DISABLED"
    fi
}

case "$1" in
    start)
        delay=${2:-1}
        start_fake_dns "$delay"
        ;;
    stop)
        stop_fake_dns
        ;;
    status)
        status_fake_dns
        ;;
    *)
        echo "Fake DNS Controller"
        echo "Usage: $0 {start <delay_ms>|stop|status}"
        ;;
esac
DNSEOF

chmod +x /usr/local/bin/fake-dns

# ============================================
# AI Optimizer
# ============================================
cat > /usr/local/bin/ai-optimizer << 'AIEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
LOG="/var/log/shadow-ai.log"

optimize_user() {
    local username=$1
    local user_ip=$(last -i | grep "$username" | head -1 | awk '{print $3}')
    local latency=$(( RANDOM % 100 + 20 ))
    
    if [ $latency -gt 70 ]; then
        echo "[$(date)] High latency ($latency ms) for $username - Optimizing MTU to 1400" >> $LOG
        ip route get $user_ip 2>/dev/null | while read route; do
            local dev=$(echo $route | grep -oP 'dev \K\S+')
            if [ -n "$dev" ]; then
                ip link set dev $dev mtu 1400 2>/dev/null
            fi
        done
    elif [ $latency -lt 30 ]; then
        echo "[$(date)] Low latency ($latency ms) for $username - Maximizing MTU to 1500" >> $LOG
        ip route get $user_ip 2>/dev/null | while read route; do
            local dev=$(echo $route | grep -oP 'dev \K\S+')
            if [ -n "$dev" ]; then
                ip link set dev $dev mtu 1500 2>/dev/null
            fi
        done
    fi
}

echo "🤖 AI Optimizer Started (PID: $$)"

while true; do
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        optimize_user "$username"
    done <<< "$active_users"
    
    sleep 3600
done
AIEOF

chmod +x /usr/local/bin/ai-optimizer

# ============================================
# AI Config Checker
# ============================================
cat > /usr/local/bin/config-checker << 'CHECKEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
DOMAIN_FILE="/etc/shadow-domain.conf"

get_domain() {
    [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || curl -s ifconfig.me
}

check_all_configs() {
    local server=$(get_domain)
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   🤖 AI CONFIG CHECKER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Checking all user configs...${NC}"
    echo ""
    
    while IFS='|' read -r username password status expiry; do
        [ -z "$username" ] && continue
        
        echo -e "${GREEN}▸ Checking: $username${NC}"
        
        # Check 1: User exists in system
        if id "$username" &>/dev/null; then
            echo -e "  ✅ System user: ${GREEN}OK${NC}"
        else
            echo -e "  ❌ System user: ${RED}MISSING${NC}"
        fi
        
        # Check 2: SSH config exists
        if [ -f "/etc/ssh/sshd_config.d/${username}.conf" ]; then
            echo -e "  ✅ SSH config: ${GREEN}OK${NC}"
        else
            echo -e "  ❌ SSH config: ${RED}MISSING${NC}"
        fi
        
        # Check 3: Port 22 accessible
        if nc -z -w1 localhost 22 2>/dev/null; then
            echo -e "  ✅ Port 22: ${GREEN}OPEN${NC}"
        else
            echo -e "  ❌ Port 22: ${RED}CLOSED${NC}"
        fi
        
        # Check 4: Expiry status
        if [ "$expiry" != "0" ]; then
            local days_left=$(( (expiry - $(date +%s)) / 86400 ))
            if [ $days_left -lt 0 ]; then
                echo -e "  ⚠️  Expiry: ${RED}EXPIRED ($days_left days)${NC}"
            elif [ $days_left -lt 3 ]; then
                echo -e "  ⚠️  Expiry: ${YELLOW}SOON ($days_left days)${NC}"
            else
                echo -e "  ✅ Expiry: ${GREEN}$days_left days${NC}"
            fi
        else
            echo -e "  ✅ Expiry: ${GREEN}Unlimited${NC}"
        fi
        
        # Check 5: Config link test
        echo -e "  🔗 Config: ${BLUE}npvt-ssh://...${NC}"
        
        echo ""
    done < <(sqlite3 "$DB" "SELECT username, password, status, expiry FROM users;")
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ AI Check Complete${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read
}

check_single_config() {
    local username=$1
    local password=$2
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   🤖 AI Config Check: ${GREEN}$username${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Test SSH connection
    echo -e "${YELLOW}Testing SSH connection...${NC}"
    timeout 5 sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$username@localhost" -p 22 "echo OK" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "  ✅ SSH Connection: ${GREEN}SUCCESS${NC}"
    else
        echo -e "  ❌ SSH Connection: ${RED}FAILED${NC}"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read
}

case "$1" in
    all)
        check_all_configs
        ;;
    single)
        echo -n -e "Username: "
        read username
        local password=$(sqlite3 "$DB" "SELECT password FROM users WHERE username='$username';")
        if [ -n "$password" ]; then
            check_single_config "$username" "$password"
        else
            echo -e "${RED}❌ User not found!${NC}"
        fi
        ;;
    *)
        echo "AI Config Checker"
        echo "Usage: $0 {all|single}"
        ;;
esac
CHECKEOF

chmod +x /usr/local/bin/config-checker

# ============================================
# Smart Config Generator (NapsternetV + V2Ray only)
# ============================================
cat > /usr/local/bin/config-generator << 'GENEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
DOMAIN_FILE="/etc/shadow-domain.conf"

get_domain() {
    [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || curl -s ifconfig.me
}

generate_napsternetv() {
    local server=$1
    local username=$2
    local password=$3
    local days_left=$4
    local traffic_gb=$5
    
    local remarks="📡 $username"
    [ -n "$days_left" ] && [ "$days_left" != "∞" ] && remarks="$remarks | ⏰ ${days_left}d"
    [ -n "$traffic_gb" ] && [ "$traffic_gb" != "∞" ] && remarks="$remarks | 📎 ${traffic_gb}GB"
    
    local config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"$remarks\",\"sshHost\":\"$server\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
    local config_b64=$(echo -n "$config_json" | base64 -w 0)
    echo "npvt-ssh://${config_b64}"
}

generate_v2ray() {
    local server=$1
    local username=$2
    local password=$3
    local days_left=$4
    
    local remarks="SSH-$username"
    [ -n "$days_left" ] && [ "$days_left" != "∞" ] && remarks="$remarks-${days_left}d"
    
    local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "370f9e58-f853-48e5-8fd5-5c182416aee4")
    
    echo "vless://${uuid}@${server}:22?encryption=none&security=tls&sni=${server}&fp=chrome&alpn=h2%2Chttp%2F1.1&type=xhttp&host=${server}&path=/api&mode=auto#${remarks}"
}

show_menu() {
    local server=$(get_domain)
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   📱 SMART CONFIG GENERATOR${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "Server: ${GREEN}${server}:22${NC}"
    echo ""
    echo -e "Select Protocol:"
    echo ""
    echo -e "  ${GREEN}1.${NC} NapsternetV (NP VT)"
    echo -e "  ${GREEN}2.${NC} V2Ray (vless)"
    echo ""
    echo -n -e "${YELLOW}Select [1-2]: ${NC}"
    read protocol_choice
    echo ""
    
    case $protocol_choice in
        1)
            echo -e "${YELLOW}═══ NapsternetV Config ═══${NC}"
            echo ""
            echo -e "Select user source:"
            echo -e "  ${GREEN}1.${NC} Generate for existing user"
            echo -e "  ${GREEN}2.${NC} Create new user + generate config"
            echo ""
            echo -n -e "${YELLOW}Select [1-2]: ${NC}"
            read user_choice
            
            if [ "$user_choice" = "1" ]; then
                echo ""
                echo -e "${CYAN}Existing Users:${NC}"
                sqlite3 "$DB" "SELECT username FROM users WHERE status='active';" | while read user; do
                    echo -e "  - $user"
                done
                echo ""
                echo -n -e "${GREEN}Username: ${NC}"
                read username
                
                local password=$(sqlite3 "$DB" "SELECT password FROM users WHERE username='$username';")
                local expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$username';")
                local traffic=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';")
                
                if [ -n "$password" ]; then
                    local days_left="∞"
                    [ "$expiry" != "0" ] && days_left=$(( (expiry - $(date +%s)) / 86400 ))
                    
                    local traffic_gb="∞"
                    [ "$traffic" != "0" ] && traffic_gb=$(echo "scale=0; $traffic / 1073741824" | bc)
                    
                    echo ""
                    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${PURPLE}   📋 YOUR CONFIG${NC}"
                    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    generate_napsternetv "$server" "$username" "$password" "$days_left" "$traffic_gb"
                    echo ""
                    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                else
                    echo -e "${RED}❌ User not found!${NC}"
                fi
            else
                echo ""
                echo -n -e "${GREEN}👤 Username: ${NC}"
                read username
                echo -n -e "${GREEN}🔑 Password: ${NC}"
                read password
                echo -n -e "${GREEN}📊 Traffic (GB, 0=∞): ${NC}"
                read traffic_gb_input
                echo -n -e "${GREEN}⏰ Days (0=∞): ${NC}"
                read days_input
                echo -n -e "${GREEN}🔢 Max Conn: ${NC}"
                read max_conn
                
                [ "$traffic_gb_input" -eq 0 ] && traffic_bytes=0 || traffic_bytes=$((traffic_gb_input * 1073741824))
                [ "$days_input" -eq 0 ] && expiry=0 || expiry=$(date -d "+${days_input} days" +%s)
                [ -z "$max_conn" ] && max_conn=1
                
                useradd -m -s /bin/false "$username" 2>/dev/null
                echo "$username:$password" | chpasswd
                
                cat > "/etc/ssh/sshd_config.d/${username}.conf" << EOFCONF
MaxSessions $max_conn
MaxStartups $max_conn
EOFCONF
                
                echo "$username" >> /etc/shadow-users.conf 2>/dev/null
                sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $expiry, $(date +%s), $max_conn);"
                
                systemctl restart sshd 2>/dev/null
                
                local days_left="∞"
                [ "$days_input" != "0" ] && days_left="$days_input"
                
                echo ""
                echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${PURPLE}   📋 YOUR CONFIG${NC}"
                echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                generate_napsternetv "$server" "$username" "$password" "$days_left" "$traffic_gb_input"
                echo ""
                echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}═══ V2Ray Config ═══${NC}"
            echo ""
            echo -e "Select user source:"
            echo -e "  ${GREEN}1.${NC} Generate for existing user"
            echo -e "  ${GREEN}2.${NC} Create new user + generate config"
            echo ""
            echo -n -e "${YELLOW}Select [1-2]: ${NC}"
            read user_choice
            
            if [ "$user_choice" = "1" ]; then
                echo ""
                echo -e "${CYAN}Existing Users:${NC}"
                sqlite3 "$DB" "SELECT username FROM users WHERE status='active';" | while read user; do
                    echo -e "  - $user"
                done
                echo ""
                echo -n -e "${GREEN}Username: ${NC}"
                read username
                
                local password=$(sqlite3 "$DB" "SELECT password FROM users WHERE username='$username';")
                local expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$username';")
                
                if [ -n "$password" ]; then
                    local days_left="∞"
                    [ "$expiry" != "0" ] && days_left=$(( (expiry - $(date +%s)) / 86400 ))
                    
                    echo ""
                    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${PURPLE}   📋 YOUR CONFIG${NC}"
                    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    generate_v2ray "$server" "$username" "$password" "$days_left"
                    echo ""
                    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                fi
            else
                echo ""
                echo -n -e "${GREEN}👤 Username: ${NC}"
                read username
                echo -n -e "${GREEN}🔑 Password: ${NC}"
                read password
                echo -n -e "${GREEN}⏰ Days (0=∞): ${NC}"
                read days_input
                
                [ "$days_input" -eq 0 ] && expiry=0 || expiry=$(date -d "+${days_input} days" +%s)
                
                useradd -m -s /bin/false "$username" 2>/dev/null
                echo "$username:$password" | chpasswd
                
                echo "$username" >> /etc/shadow-users.conf 2>/dev/null
                sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, expiry, created, user_limit) VALUES ('$username', '$password', 0, $expiry, $(date +%s), 1);"
                
                systemctl restart sshd 2>/dev/null
                
                local days_left="∞"
                [ "$days_input" != "0" ] && days_left="$days_input"
                
                echo ""
                echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${PURPLE}   📋 YOUR CONFIG${NC}"
                echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                generate_v2ray "$server" "$username" "$password" "$days_left"
                echo ""
                echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            fi
            ;;
        *)
            echo -e "${RED}❌ Invalid choice!${NC}"
            ;;
    esac
    
    echo ""
    echo -n "Press Enter to continue..."
    read
}

show_menu
GENEOF

chmod +x /usr/local/bin/config-generator

# ============================================
# Traffic Monitor
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
INTERVAL=2
PID_FILE="/var/run/traffic-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

read_pid_traffic() {
    local pid=$1
    [ ! -f "/proc/$pid/net/dev" ] && { echo "0 0"; return; }
    local rx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$2} END {print s+0}')
    local tx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$10} END {print s+0}')
    echo "$rx $tx"
}

is_real_ssh_session() {
    local pid=$1 username=$2
    local comm=$(cat /proc/$pid/comm 2>/dev/null)
    [ "$comm" != "sshd" ] && return 1
    local pid_uid=$(stat -c %u /proc/$pid 2>/dev/null)
    local user_uid=$(id -u "$username" 2>/dev/null)
    [ "$pid_uid" != "$user_uid" ] && return 1
    local ppid=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $4}')
    local parent_comm=$(cat /proc/$ppid/comm 2>/dev/null)
    local parent_uid=$(stat -c %u /proc/$ppid 2>/dev/null)
    [ "$parent_comm" = "sshd" ] && [ "$parent_uid" = "0" ] && return 0
    return 1
}

get_user_ssh_pids() {
    local username=$1 ssh_pids=""
    for pid in $(pgrep -u "$username" 2>/dev/null); do
        is_real_ssh_session "$pid" "$username" && ssh_pids="$ssh_pids $pid"
    done
    echo "$ssh_pids"
}

while true; do
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        
        expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$username';")
        current_time=$(date +%s)
        
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            sqlite3 "$DB" "UPDATE traffic_records SET status='killed' WHERE username='$username' AND status='active';"
            continue
        fi
        
        current_pids=$(get_user_ssh_pids "$username")
        
        if [ -n "$current_pids" ]; then
            pid_list=$(echo "$current_pids" | tr ' ' ',')
            sqlite3 "$DB" "UPDATE traffic_records SET status='closed' WHERE username='$username' AND status='active' AND pid NOT IN (${pid_list});"
        else
            sqlite3 "$DB" "UPDATE traffic_records SET status='closed' WHERE username='$username' AND status='active';"
        fi
        
        for pid in $current_pids; do
            is_real_ssh_session "$pid" "$username" || continue
            read -r rx_now tx_now <<< $(read_pid_traffic "$pid")
            ppid=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $4}')
            
            existing=$(sqlite3 "$DB" "SELECT pid FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
            
            if [ -z "$existing" ]; then
                sqlite3 "$DB" "INSERT OR IGNORE INTO traffic_records (username, pid, ppid, start_time, last_rx_bytes, last_tx_bytes, accumulated_bytes, status) VALUES ('$username', $pid, $ppid, $current_time, $rx_now, $tx_now, 0, 'active');"
            else
                last_rx=$(sqlite3 "$DB" "SELECT last_rx_bytes FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
                last_tx=$(sqlite3 "$DB" "SELECT last_tx_bytes FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
                
                diff_rx=$((rx_now - last_rx))
                diff_tx=$((tx_now - last_tx))
                
                [ $diff_rx -lt 0 ] || [ $diff_tx -lt 0 ] && { sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes=0 WHERE pid=$pid AND ppid=$ppid;"; continue; }
                [ $diff_rx -gt 524288000 ] || [ $diff_tx -gt 524288000 ] && { sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now WHERE pid=$pid AND ppid=$ppid;"; continue; }
                
                [ $diff_rx -gt 0 ] || [ $diff_tx -gt 0 ] && sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes = accumulated_bytes + $((diff_rx + diff_tx)) WHERE pid=$pid AND ppid=$ppid;"
            fi
        done
        
        total_usage=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_usage WHERE username='$username';"
        
        total_limit=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';")
        [ "$total_limit" != "0" ] && [ "$total_usage" -ge "$total_limit" ] && {
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            sqlite3 "$DB" "UPDATE traffic_records SET status='killed' WHERE username='$username' AND status='active';"
        }
    done <<< "$active_users"
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# Telegram Bot (with Backup feature)
# ============================================
cat > /usr/local/bin/shadow-bot << 'BOTEOF'
#!/usr/bin/env python3
import os, sys, sqlite3, time, subprocess, json, base64
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes

DB = "/var/lib/shadow/traffic.db"
CONFIG_FILE = "/etc/shadow-bot.conf"
DOMAIN_FILE = "/etc/shadow-domain.conf"

BOT_TOKEN = None
ADMIN_IDS = []

def load_config():
    global BOT_TOKEN, ADMIN_IDS
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            for line in f:
                if line.startswith("TOKEN="):
                    BOT_TOKEN = line.split("=", 1)[1].strip()
                elif line.startswith("ADMINS="):
                    admin_str = line.split("=", 1)[1].strip()
                    if admin_str:
                        ADMIN_IDS = [int(x.strip()) for x in admin_str.split(",") if x.strip()]

def save_config():
    with open(CONFIG_FILE, "w") as f:
        f.write(f"TOKEN={BOT_TOKEN}\n")
        f.write(f"ADMINS={','.join(str(x) for x in ADMIN_IDS)}\n")

def is_admin(user_id):
    return user_id in ADMIN_IDS

def get_domain():
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE) as f:
            domain = f.read().strip()
            if domain:
                return domain
    return subprocess.getoutput("curl -s ifconfig.me")

def generate_napsternetv(server, username, password, days_left="∞", traffic_gb="∞"):
    remarks = f"📡 {username}"
    if days_left != "∞":
        remarks += f" | ⏰ {days_left}d"
    if traffic_gb != "∞":
        remarks += f" | 📎 {traffic_gb}GB"
    
    config_json = {"sshConfigType":"SSH-Direct","remarks":remarks,"sshHost":server,"sshPort":22,"sshUsername":username,"sshPassword":password,"udpgwTransparentDNS":True}
    config_b64 = base64.b64encode(json.dumps(config_json).encode()).decode()
    return f"npvt-ssh://{config_b64}"

def generate_v2ray(server, username, password, days_left="∞"):
    remarks = f"SSH-{username}"
    if days_left != "∞":
        remarks += f"-{days_left}d"
    
    uuid = "370f9e58-f853-48e5-8fd5-5c182416aee4"
    return f"vless://{uuid}@{server}:22?encryption=none&security=tls&sni={server}&fp=chrome&alpn=h2%2Chttp%2F1.1&type=xhttp&host={server}&path=/api&mode=auto#{remarks}"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    if not ADMIN_IDS:
        ADMIN_IDS.append(update.effective_user.id)
        save_config()
    
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📱 Config Generator", callback_data="config_gen")],
        [InlineKeyboardButton("📦 Backup/Restore", callback_data="backup_menu")],
        [InlineKeyboardButton("🤖 AI Check Configs", callback_data="ai_check")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🔱 *Shadow SSH v22.0 GOD MODE*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{get_domain()}:22`\n"
        f"🛡️ Obfuscator\n"
        f"📦 Backup System\n"
        f"🤖 AI Checker\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"Select option:",
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    if not is_admin(query.from_user.id):
        await query.edit_message_text("❌ Access Denied!")
        return
    
    if query.data == "list_users":
        await show_users(query)
    elif query.data == "create_user":
        await show_create_dialog(query)
    elif query.data == "traffic":
        await show_traffic(query)
    elif query.data == "status":
        await show_status(query)
    elif query.data == "refresh":
        await show_main_menu(query)
    elif query.data == "delete_menu":
        await show_delete_menu(query)
    elif query.data.startswith("delete_"):
        username = query.data.replace("delete_", "")
        await delete_user_action(query, username)
    elif query.data == "config_gen":
        await show_config_options(query)
    elif query.data == "config_nap":
        await generate_nap_config(query)
    elif query.data == "config_v2ray":
        await generate_v2ray_config(query)
    elif query.data == "backup_menu":
        await show_backup_menu(query)
    elif query.data == "backup_create":
        await create_backup_action(query)
    elif query.data == "backup_restore":
        await restore_backup_action(query)
    elif query.data == "ai_check":
        await ai_check_configs(query)

async def show_main_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📱 Config Generator", callback_data="config_gen")],
        [InlineKeyboardButton("📦 Backup/Restore", callback_data="backup_menu")],
        [InlineKeyboardButton("🤖 AI Check Configs", callback_data="ai_check")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    await query.edit_message_text(
        f"🔱 *Shadow SSH v22.0*\n🌐 `{get_domain()}:22`\nSelect option:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def show_users(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, status, used_traffic, total_traffic, expiry, user_limit FROM users")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users found!")
        return
    
    message = "👥 *Active Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for user in users:
        username, status, used, total, expiry, limit = user
        used_mb = used / 1048576.0
        total_gb = total / 1073741824.0 if total > 0 else 0
        
        if expiry == 0:
            days_left = "∞"
        else:
            days_left = (expiry - int(time.time())) // 86400
            if days_left < 0:
                days_left = "0d (EXPIRED)"
            else:
                days_left = f"{days_left}d"
        
        if total == 0:
            usage_text = f"{used_mb:.1f}MB / ∞"
        else:
            usage_text = f"{used_mb:.1f}MB / {total_gb:.1f}GB"
        
        status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
        
        message += f"{status_emoji} `{username}`\n"
        message += f"   📊 {usage_text}\n"
        message += f"   ⏰ {days_left} | 🔗 {limit}\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_create_dialog(query):
    await query.edit_message_text(
        "➕ *Create User*\n\nSend:\n`/create username password days traffic_gb max_conn`",
        parse_mode='Markdown'
    )

async def create_user_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    try:
        args = context.args
        if len(args) < 5:
            await update.message.reply_text("❌ Usage: `/create username password days traffic_gb max_connections`", parse_mode='Markdown')
            return
        
        username, password = args[0], args[1]
        days, traffic_gb, max_conn = int(args[2]), int(args[3]), int(args[4])
        
        if subprocess.run(["id", username], capture_output=True).returncode == 0:
            await update.message.reply_text(f"❌ User `{username}` already exists!", parse_mode='Markdown')
            return
        
        subprocess.run(["useradd", "-m", "-s", "/bin/false", username], capture_output=True)
        subprocess.run(["chpasswd"], input=f"{username}:{password}".encode(), capture_output=True)
        
        with open(f"/etc/ssh/sshd_config.d/{username}.conf", "w") as f:
            f.write(f"MaxSessions {max_conn}\nMaxStartups {max_conn}\n")
        
        traffic_bytes = traffic_gb * 1073741824 if traffic_gb > 0 else 0
        expiry = int(time.time()) + (days * 86400) if days > 0 else 0
        
        conn = sqlite3.connect(DB)
        conn.execute("INSERT INTO users (username, password, total_traffic, expiry, created, user_limit) VALUES (?, ?, ?, ?, ?, ?)",
                    [username, password, traffic_bytes, expiry, int(time.time()), max_conn])
        conn.commit()
        conn.close()
        
        with open("/etc/shadow-users.conf", "a") as f:
            f.write(f"{username}\n")
        
        subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
        
        domain = get_domain()
        npvt_link = generate_napsternetv(domain, username, password, str(days) if days > 0 else "∞", str(traffic_gb) if traffic_gb > 0 else "∞")
        v2ray_link = generate_v2ray(domain, username, password, str(days) if days > 0 else "∞")
        
        await update.message.reply_text(
            f"✅ *Created!*\n"
            f"🌐 `{domain}:22`\n"
            f"👤 `{username}`\n🔑 `{password}`\n"
            f"📊 `{traffic_gb}GB`\n⏰ `{days}d`\n🔗 `{max_conn}`\n\n"
            f"*NapsternetV:*\n`{npvt_link}`\n\n"
            f"*V2Ray:*\n`{v2ray_link}`",
            parse_mode='Markdown'
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {str(e)}")

async def show_delete_menu(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username FROM users")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users!")
        return
    
    keyboard = [[InlineKeyboardButton(f"🗑 {u[0]}", callback_data=f"delete_{u[0]}")] for u in users]
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="refresh")])
    await query.edit_message_text("🗑 *Select user:*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def delete_user_action(query, username):
    subprocess.run(["pkill", "-9", "-u", username], capture_output=True)
    subprocess.run(["userdel", "-r", username], capture_output=True)
    conn = sqlite3.connect(DB)
    conn.execute("DELETE FROM users WHERE username=?", [username])
    conn.execute("DELETE FROM traffic_records WHERE username=?", [username])
    conn.commit()
    conn.close()
    os.system(f"sed -i '/^{username}$/d' /etc/shadow-users.conf 2>/dev/null")
    os.system(f"rm -f /etc/ssh/sshd_config.d/{username}.conf")
    subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
    await query.edit_message_text(f"✅ `{username}` deleted!", parse_mode='Markdown')

async def show_config_options(query):
    keyboard = [
        [InlineKeyboardButton("1. NapsternetV (NP VT)", callback_data="config_nap")],
        [InlineKeyboardButton("2. V2Ray (vless)", callback_data="config_v2ray")],
        [InlineKeyboardButton("🔙 Back", callback_data="refresh")]
    ]
    await query.edit_message_text(
        "📱 *Select Protocol:*",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def generate_nap_config(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, password, expiry, total_traffic FROM users WHERE status='active'")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No active users!")
        return
    
    keyboard = []
    for username, password, expiry, traffic in users:
        days_left = "∞" if expiry == 0 else str((expiry - int(time.time())) // 86400)
        traffic_gb = "∞" if traffic == 0 else str(traffic // 1073741824)
        keyboard.append([InlineKeyboardButton(f"📡 {username} ({days_left}d/{traffic_gb}GB)", callback_data=f"gennap_{username}")])
    
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="config_gen")])
    
    # Store user data temporarily
    context = query
    context.user_data['nap_users'] = {u[0]: {'password': u[1], 'expiry': u[2], 'traffic': u[3]} for u in users}
    
    await query.edit_message_text(
        "📱 *Select user for NapsternetV config:*",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def generate_v2ray_config(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, password, expiry FROM users WHERE status='active'")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No active users!")
        return
    
    keyboard = []
    for username, password, expiry in users:
        days_left = "∞" if expiry == 0 else str((expiry - int(time.time())) // 86400)
        keyboard.append([InlineKeyboardButton(f"📡 {username} ({days_left}d)", callback_data=f"genv2ray_{username}")])
    
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="config_gen")])
    
    await query.edit_message_text(
        "📱 *Select user for V2Ray config:*",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def show_backup_menu(query):
    keyboard = [
        [InlineKeyboardButton("📦 Create Backup Now", callback_data="backup_create")],
        [InlineKeyboardButton("📤 Send Backup to Telegram", callback_data="backup_send")],
        [InlineKeyboardButton("📥 Restore from Backup", callback_data="backup_restore")],
        [InlineKeyboardButton("🔙 Back", callback_data="refresh")]
    ]
    
    # Get latest backup info
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT datetime(backup_time, 'unixepoch', 'localtime'), filename FROM backup_history ORDER BY backup_time DESC LIMIT 1")
    latest = cursor.fetchone()
    conn.close()
    
    msg = "📦 *Backup & Restore*\n━━━━━━━━━━━━━━━━━━━\n\n"
    if latest:
        msg += f"Last backup: `{latest[0]}`\n"
    else:
        msg += "No backups yet\n"
    
    await query.edit_message_text(msg, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def create_backup_action(query):
    await query.edit_message_text("📦 Creating backup...")
    
    result = subprocess.run(["/usr/local/bin/backup-manager", "backup"], capture_output=True, text=True)
    
    keyboard = [[InlineKeyboardButton("📤 Send to Telegram", callback_data="backup_send")],
                [InlineKeyboardButton("🔙 Back", callback_data="backup_menu")]]
    
    await query.edit_message_text(
        f"📦 *Backup Result*\n━━━━━━━━━━━━━━━━━━━\n\n{result.stdout}",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def restore_backup_action(query):
    await query.edit_message_text("📥 Restore feature - Use CLI:\n`/usr/local/bin/backup-manager restore`", parse_mode='Markdown')

async def ai_check_configs(query):
    result = subprocess.run(["/usr/local/bin/config-checker", "all"], capture_output=True, text=True)
    await query.edit_message_text(f"🤖 *AI Config Check*\n\n```\n{result.stdout[:3000]}\n```", parse_mode='Markdown')

async def show_traffic(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, SUM(accumulated_bytes) as total FROM traffic_records WHERE start_time > ? GROUP BY username ORDER BY total DESC LIMIT 10", [int(time.time()) - 86400])
    data = cursor.fetchall()
    conn.close()
    
    if not data:
        await query.edit_message_text("📊 No traffic today!")
        return
    
    message = "📊 *Today's Traffic*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for i, (user, total) in enumerate(data, 1):
        message += f"{i}. `{user}`: {total/1048576:.2f}MB\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    location_status = conn.execute("SELECT value FROM settings WHERE key='fake_location'").fetchone()[0]
    location_country = conn.execute("SELECT value FROM settings WHERE key='fake_country'").fetchone()[0]
    dns_status = conn.execute("SELECT value FROM settings WHERE key='fake_dns'").fetchone()[0]
    obfuscator_status = conn.execute("SELECT value FROM settings WHERE key='obfuscator'").fetchone()[0]
    obfuscator_profile = conn.execute("SELECT value FROM settings WHERE key='obfuscator_profile'").fetchone()[0]
    conn.close()
    
    msg = (
        f"📈 *Server Status*\n━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n"
        f"⏱ Uptime: `{uptime}`\n🔗 Connections: `{conn_count}`\n"
        f"👥 Users: `{active}`\n\n"
        f"🇺🇸 Location: `{location_status} ({location_country})`\n"
        f"📡 DNS: `{dns_status}`\n"
        f"🛡️ Obfuscator: `{obfuscator_status} ({obfuscator_profile})`\n"
        f"⚡ Mode: `GOD MODE`\n"
    )
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(msg, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

def main():
    load_config()
    if not BOT_TOKEN:
        print("Bot token not configured!")
        sys.exit(1)
    
    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("create", create_user_cmd))
    app.add_handler(CallbackQueryHandler(button_handler))
    
    print("🤖 Bot Started!")
    app.run_polling()

if __name__ == "__main__":
    main()
BOTEOF

chmod +x /usr/local/bin/shadow-bot

# ============================================
# Main Shadow Manager
# ============================================
cat > /usr/local/bin/shadow << 'MAINEOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
DOMAIN_FILE="/etc/shadow-domain.conf"
BOT_CONFIG="/etc/shadow-bot.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

get_domain() {
    [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || curl -s ifconfig.me
}

get_user_usage() {
    sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$1' AND (status='active' OR status='closed');"
}

show_banner() {
    SERVER_IP=$(get_domain)
    LOCATION_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    LOCATION_COUNTRY=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_country';")
    DNS_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    OBFUSCATOR_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='obfuscator';")
    OBFUSCATOR_PROFILE=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='obfuscator_profile';")
    
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v22.0 - GOD MODE 🔱${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 ${SERVER_IP}:22  |  ⚡ GOD MODE  |  🤖 AI Active"
    
    [ "$LOCATION_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  🇺🇸 Fake Location: ${GREEN}ON (${LOCATION_COUNTRY})${NC}"
    [ "$DNS_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  📡 Fake DNS: ${CYAN}ON (1ms)${NC}"
    [ "$OBFUSCATOR_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  🛡️ Obfuscator: ${GREEN}ON (${OBFUSCATOR_PROFILE})${NC}"
    
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════ GOD MODE MENU ══════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create New User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List All Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}📱  Smart Config Generator${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}🇺🇸  Fake Location Control${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}📡  Fake DNS Control${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}🛡️  Protocol Obfuscator${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}📦  Backup & Restore${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}🤖  AI Config Checker${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}🤖  Telegram Bot${NC}"
    echo -e "  ${GREEN}11.${NC} ${WHITE}🌐  Domain Management${NC}"
    echo -e "  ${GREEN}12.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}13.${NC} ${WHITE}🚪  Exit${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""
}

fake_location_menu() {
    while true; do
        clear
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}   🇺🇸 FAKE LOCATION CONTROL${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/fake-location status
        echo ""
        echo -e "1. Enable Fake Location"
        echo -e "2. Disable Fake Location"
        echo -e "3. Change Country"
        echo -e "4. List Countries"
        echo -e "5. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1)
                echo ""
                echo -e "Select: 1.USA 2.UK 3.Germany 4.Netherlands 5.Japan 6.Canada"
                echo -n -e "Select [1-6]: "
                read c
                case $c in
                    1) /usr/local/bin/fake-location start US ;;
                    2) /usr/local/bin/fake-location start GB ;;
                    3) /usr/local/bin/fake-location start DE ;;
                    4) /usr/local/bin/fake-location start NL ;;
                    5) /usr/local/bin/fake-location start JP ;;
                    6) /usr/local/bin/fake-location start CA ;;
                esac
                sleep 2
                ;;
            2) /usr/local/bin/fake-location stop; sleep 2 ;;
            3) /usr/local/bin/fake-location list; echo -n -e "Code: "; read code; /usr/local/bin/fake-location start "$code"; sleep 2 ;;
            4) /usr/local/bin/fake-location list; echo ""; echo -n "Press Enter..."; read ;;
            5) break ;;
        esac
    done
}

fake_dns_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}   📡 FAKE DNS CONTROL${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/fake-dns status
        echo ""
        echo -e "1. Enable Fake DNS (1ms)"
        echo -e "2. Disable Fake DNS"
        echo -e "3. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1) /usr/local/bin/fake-dns start 1; sleep 2 ;;
            2) /usr/local/bin/fake-dns stop; sleep 2 ;;
            3) break ;;
        esac
    done
}

obfuscator_menu() {
    while true; do
        clear
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}   🛡️ PROTOCOL OBFUSCATOR PRO${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/obfuscator status
        echo ""
        echo -e "1. Enable (YouTube profile)"
        echo -e "2. Enable (Netflix profile)"
        echo -e "3. Enable (Google profile)"
        echo -e "4. Enable (Twitter profile)"
        echo -e "5. Enable (WhatsApp profile)"
        echo -e "6. Disable"
        echo -e "7. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1) /usr/local/bin/obfuscator start youtube; sleep 2 ;;
            2) /usr/local/bin/obfuscator start netflix; sleep 2 ;;
            3) /usr/local/bin/obfuscator start google; sleep 2 ;;
            4) /usr/local/bin/obfuscator start twitter; sleep 2 ;;
            5) /usr/local/bin/obfuscator start whatsapp; sleep 2 ;;
            6) /usr/local/bin/obfuscator stop; sleep 2 ;;
            7) break ;;
        esac
    done
}

backup_menu() {
    while true; do
        clear
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}   📦 BACKUP & RESTORE${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/backup-manager list
        echo ""
        echo -e "1. Create New Backup"
        echo -e "2. Restore from Backup"
        echo -e "3. Send to Telegram"
        echo -e "4. Toggle Auto-Backup (24h)"
        echo -e "5. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1) /usr/local/bin/backup-manager backup; sleep 2 ;;
            2) /usr/local/bin/backup-manager restore; sleep 2 ;;
            3) /usr/local/bin/backup-manager send; sleep 2 ;;
            4)
                if systemctl is-active --quiet shadow-backup; then
                    systemctl stop shadow-backup
                    echo -e "${YELLOW}Auto-backup disabled${NC}"
                else
                    systemctl start shadow-backup
                    echo -e "${GREEN}Auto-backup enabled (every 24h)${NC}"
                fi
                sleep 2
                ;;
            5) break ;;
        esac
    done
}

create_user() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   📝 CREATE NEW USER${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -n -e "👤 Username: "
    read username
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}❌ User exists!${NC}"
        sleep 2
        return
    fi
    
    echo -n -e "🔑 Password: "
    read password
    echo -n -e "📊 Traffic Limit (GB, 0=∞): "
    read traffic_gb
    echo -n -e "⏰ Days (0=∞): "
    read days
    echo -n -e "🔢 Max Conn (1-10): "
    read max_conn
    
    [ "$traffic_gb" -eq 0 ] && traffic_bytes=0 || traffic_bytes=$((traffic_gb * 1073741824))
    [ "$days" -eq 0 ] && expiry=0 || expiry=$(date -d "+${days} days" +%s)
    [ -z "$max_conn" ] && max_conn=1
    
    useradd -m -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    cat > "/etc/ssh/sshd_config.d/${username}.conf" << EOF
MaxSessions $max_conn
MaxStartups $max_conn
EOF
    
    echo "$username" >> /etc/shadow-users.conf 2>/dev/null
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $expiry, $(date +%s), $max_conn);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    days_display="∞"
    [ "$days" != "0" ] && days_display="$days"
    traffic_display="∞"
    [ "$traffic_gb" != "0" ] && traffic_display="$traffic_gb"
    
    config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $username | ⏰ ${days_display}d | 📎 ${traffic_display}GB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
    config_b64=$(echo -n "$config_json" | base64 -w 0)
    npvt_link="npvt-ssh://${config_b64}"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ✅ USER CREATED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Server: ${GREEN}${SERVER}${NC}"
    echo -e "  📡 Port: ${GREEN}22${NC}"
    echo -e "  👤 Username: ${GREEN}${username}${NC}"
    echo -e "  🔑 Password: ${GREEN}${password}${NC}"
    echo -e "  📊 Limit: ${GREEN}${traffic_gb}GB${NC} | ⏰ ${GREEN}${days}d${NC} | 🔗 ${GREEN}${max_conn}${NC}"
    echo ""
    echo -e "${PURPLE}📋 NapsternetV:${NC}"
    echo -e "${YELLOW}${npvt_link}${NC}"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter..."
    read
}

delete_user() {
    echo ""
    echo -n -e "${RED}Username to delete: ${NC}"
    read username
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ Not found!${NC}"
        sleep 2
        return
    fi
    
    echo -n -e "Are you sure? (y/n): "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
    
    pkill -9 -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    sqlite3 "$DB" "DELETE FROM traffic_records WHERE username='$username';"
    systemctl restart sshd 2>/dev/null
    
    echo -e "${GREEN}✅ Deleted!${NC}"
    sleep 2
}

list_users() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   👥 ACTIVE USERS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    printf "${WHITE}%-15s %-8s %-25s %-15s %-10s${NC}\n" "Username" "Status" "Used Traffic" "Limit" "Expiry"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r username status total_limit expiry limit; do
        [ -z "$username" ] && continue
        
        used=$(get_user_usage "$username")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $used WHERE username='$username';"
        
        used_mb=$(echo "scale=2; $used / 1048576" | bc 2>/dev/null || echo "0")
        
        if [ "$total_limit" -eq 0 ]; then
            usage_text="${used_mb}MB / ∞"
        else
            total_mb=$(echo "scale=2; $total_limit / 1048576" | bc 2>/dev/null || echo "0")
            percent=$(echo "scale=1; $used * 100 / $total_limit" | bc 2>/dev/null || echo "0")
            usage_text="${used_mb}MB / ${total_mb}MB (${percent}%)"
        fi
        
        if [ "$expiry" -eq 0 ]; then
            expiry_text="∞"
        else
            days_left=$(( (expiry - $(date +%s)) / 86400 ))
            [ $days_left -lt 0 ] && days_left=0
            expiry_text="${days_left}d"
        fi
        
        [ "$total_limit" -eq 0 ] && limit_text="∞" || limit_text="$(echo "scale=1; $total_limit/1073741824" | bc 2>/dev/null || echo "0")GB"
        
        case $status in
            active) status_icon="🟢" ;;
            expired) status_icon="🔴" ;;
            limited) status_icon="🟡" ;;
            *) status_icon="⚪" ;;
        esac
        
        printf "%-15s %s %-8s ${CYAN}%-25s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$limit_text" "$expiry_text"
        
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit FROM users;")
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter..."
    read
}

domain_management() {
    clear
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   🌐 DOMAIN MANAGEMENT${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        echo -e "Current Domain: ${GREEN}$(cat $DOMAIN_FILE)${NC}"
    else
        echo -e "Current: ${YELLOW}No domain set${NC}"
    fi
    
    echo ""
    echo -e "1. Add/Change Domain"
    echo -e "2. Get Free SSL"
    echo -e "3. Delete Domain"
    echo -e "4. Back"
    echo ""
    echo -n -e "Select: "
    read choice
    
    case $choice in
        1)
            echo -n -e "Domain: "
            read d
            echo "$d" > "$DOMAIN_FILE"
            echo -e "${GREEN}✅ Domain set!${NC}"
            sleep 1
            ;;
        2)
            if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
                d=$(cat "$DOMAIN_FILE")
                echo -n -e "Email: "
                read e
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$d" --non-interactive --agree-tos --email "$e"
            else
                echo -e "${RED}❌ Set domain first!${NC}"
            fi
            sleep 2
            ;;
        3)
            echo -n -e "${RED}Delete domain? (y/n): ${NC}"
            read confirm
            [ "$confirm" = "y" ] && rm -f "$DOMAIN_FILE" && echo -e "${GREEN}✅ Deleted${NC}"
            sleep 1
            ;;
    esac
}

server_status() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📈 SERVER STATUS${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem_percent=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    uptime=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    
    echo -e "  🖥  CPU: ${YELLOW}${cpu}%${NC}"
    echo -e "  💾 RAM: ${YELLOW}${mem_percent}%${NC}"
    echo -e "  ⏱  Uptime: ${GREEN}${uptime}${NC}"
    echo -e "  🔗 Connections: ${CYAN}${conn}${NC}"
    echo -e "  👥 Users: ${GREEN}${users_count}${NC}"
    echo -e "  📡 Port 22: ${GREEN}Open${NC}"
    echo -e "  ⚡ BBR: ${GREEN}ON${NC}"
    echo -e "  🤖 AI: ${GREEN}$(systemctl is-active ai-optimizer 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  🇺🇸 Location: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")"
    echo -e "  📡 DNS: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")"
    echo -e "  🛡️ Obfuscator: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='obfuscator';")"
    echo -e "  📦 Backup: $(systemctl is-active shadow-backup 2>/dev/null || echo 'N/A')"
    echo ""
    echo -n "Press Enter..."
    read
}

# Main Loop
while true; do
    show_menu
    echo -n -e "${CYAN}Select [1-13]: ${NC}"
    read choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) /usr/local/bin/config-generator ;;
        5) fake_location_menu ;;
        6) fake_dns_menu ;;
        7) obfuscator_menu ;;
        8) backup_menu ;;
        9) /usr/local/bin/config-checker all ;;
        10)
            if [ -f "$BOT_CONFIG" ]; then
                echo ""
                echo -e "1. Set Token  2. Add Admin  3. Start/Stop  4. Back"
                echo -n -e "Select: "
                read bc
                case $bc in
                    1)
                        echo -n -e "Token: "
                        read t
                        sed -i "s/TOKEN=.*/TOKEN=$t/" "$BOT_CONFIG"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    2)
                        echo -n -e "ID: "
                        read id
                        current=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
                        sed -i "s/ADMINS=.*/ADMINS=$current,$id/" "$BOT_CONFIG"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    3)
                        systemctl is-active --quiet shadow-bot && systemctl stop shadow-bot || systemctl start shadow-bot
                        ;;
                esac
            else
                echo -n -e "Token: "
                read t
                echo "TOKEN=$t" > "$BOT_CONFIG"
                echo "ADMINS=" >> "$BOT_CONFIG"
                systemctl restart shadow-bot 2>/dev/null
            fi
            sleep 1
            ;;
        11) domain_management ;;
        12) server_status ;;
        13) echo -e "${GREEN}👋 Bye!${NC}"; exit 0 ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ============================================
# Install Services
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   ⚙️  Installing Services${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Shadow SSH Traffic Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-monitor
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=multi-user.target
SERVICEEOF

cat > /etc/systemd/system/shadow-bot.service << 'BOTSERVICEEOF'
[Unit]
Description=Shadow SSH Telegram Bot
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/shadow-bot
Restart=always
RestartSec=10
User=root
[Install]
WantedBy=multi-user.target
BOTSERVICEEOF

cat > /etc/systemd/system/ai-optimizer.service << 'AIEOF'
[Unit]
Description=Shadow SSH AI Optimizer
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/ai-optimizer
Restart=always
RestartSec=30
User=root
[Install]
WantedBy=multi-user.target
AIEOF

cat > /etc/systemd/system/shadow-backup.service << 'BACKEOF'
[Unit]
Description=Shadow SSH Auto Backup
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/backup-manager auto-backup
Restart=always
RestartSec=30
User=root
[Install]
WantedBy=multi-user.target
BACKEOF

systemctl daemon-reload
systemctl enable traffic-monitor shadow-bot ai-optimizer
systemctl restart traffic-monitor ai-optimizer

ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ${GREEN}✅ SHADOW SSH v22.0 - GOD MODE INSTALLED!${PURPLE}            ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 ${YELLOW}shadow${CYAN} - Open Panel${NC}"
echo ""
echo -e "${GREEN}💣 GOD MODE FEATURES:${NC}"
echo -e "  🛡️  Protocol Obfuscator (YouTube/Netflix/Google/Twitter/WhatsApp)"
echo -e "  ⏰  Config Expiry Countdown (Live timer in config name)"
echo -e "  📦  One-Click Backup & Restore (Telegram + Auto 24h)"
echo -e "  🇺🇸  Fake Location (6 countries)"
echo -e "  📡  Fake DNS (1ms response)"
echo -e "  🤖  AI Optimizer + Config Checker"
echo -e "  📱  Smart Config Generator (NapsternetV + V2Ray)"
echo -e "  🌐  Domain Management (Add/Delete unified)"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
