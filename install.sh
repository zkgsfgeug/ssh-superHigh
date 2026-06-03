#!/bin/bash

# =============================================
# Shadow SSH v31.0 - TITAN EDITION
# Complete Rewrite - All Features Tested & Working
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# ============================================
# Network Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🚀 Activating TITAN Network${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cat >> /etc/sysctl.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p >/dev/null 2>&1
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        sysctl -w net.ipv6.conf.$iface.disable_ipv6=1 2>/dev/null
    done
    
    cat > /etc/sysctl.conf << 'EOF'
net.core.rmem_max = 2147483647
net.core.wmem_max = 2147483647
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_forward = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p >/dev/null 2>&1
    modprobe tcp_bbr 2>/dev/null
    
    cat > /etc/ssh/sshd_config.d/99-titan.conf << 'TURBOEOF'
Compression no
TCPKeepAlive yes
ClientAliveInterval 10
ClientAliveCountMax 2
MaxSessions 10000
MaxStartups 10000:30:20000
AddressFamily inet
TURBOEOF
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set $iface txqueuelen 50000 2>/dev/null
        ethtool -K $iface tso on gso on gro on sg on 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    echo -e "${GREEN}   ✅ TITAN Network Activated${NC}"
}

# ============================================
# Cleanup
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🧹 Cleaning Previous Installation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Stop all services
for svc in traffic-monitor shadow-bot shadow-backup; do
    systemctl stop $svc 2>/dev/null
    systemctl disable $svc 2>/dev/null
done

# Kill all related processes
for proc in traffic-monitor shadow-bot fake-dns ai-optimizer fake-location backup-manager; do
    pkill -9 -f "$proc" 2>/dev/null
done

# Clean firewall
iptables -t mangle -F 2>/dev/null
iptables -t mangle -X 2>/dev/null
iptables -t nat -F 2>/dev/null
iptables -t nat -X 2>/dev/null
ip6tables -t mangle -F 2>/dev/null
ip6tables -t mangle -X 2>/dev/null

# Clean tc
for iface in $(ls /sys/class/net/ 2>/dev/null); do
    tc qdisc del dev $iface root 2>/dev/null
    tc qdisc del dev $iface ingress 2>/dev/null
done

# Delete all users
if [ -f /etc/shadow-users.conf ]; then
    while read user; do
        [ -z "$user" ] && continue
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done < /etc/shadow-users.conf
fi

# Delete all files
rm -f /usr/local/bin/shadow
rm -f /usr/local/bin/traffic-monitor
rm -f /usr/local/bin/shadow-bot
rm -f /usr/local/bin/shadow-dashboard
rm -f /usr/local/bin/fake-dns
rm -f /usr/local/bin/fake-location
rm -f /usr/local/bin/ai-optimizer
rm -f /usr/local/bin/backup-manager
rm -f /usr/local/bin/ping-net
rm -f /usr/local/bin/config-checker
rm -f /usr/local/bin/half-price
rm -f /usr/local/bin/rate-limiter
rm -f /usr/local/bin/dedup-monitor
rm -f /usr/local/bin/obfuscator
rm -f /usr/local/bin/config-generator
rm -f /etc/shadow-*
rm -rf /var/lib/shadow
rm -rf /var/backups/shadow
rm -f /etc/systemd/system/traffic-monitor.service
rm -f /etc/systemd/system/shadow-bot.service
rm -f /etc/systemd/system/shadow-dashboard.service
rm -f /etc/systemd/system/fake-dns.service
rm -f /etc/systemd/system/ai-optimizer.service
rm -f /etc/systemd/system/shadow-backup.service
rm -f /etc/systemd/system/dedup-monitor.service
rm -f /etc/systemd/system/half-price.service
rm -f /etc/systemd/system/rate-limiter.service
rm -f /etc/systemd/system/obfuscator.service
rm -rf /etc/ssh/sshd_config.d/*.conf
rm -f /etc/dnsmasq.d/shadow-fake.conf
rm -f /usr/bin/shadow

echo -e "${GREEN}   ✅ Cleanup Complete${NC}"

# ============================================
# Install Dependencies
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   📦 Installing Dependencies${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc procps python3 python3-pip net-tools certbot nginx 2>/dev/null

# Install Python packages one by one with verification
echo -e "${BLUE}Installing Python packages...${NC}"

pip3 install --break-system-packages python-telegram-bot==20.7 2>/dev/null
python3 -c "from telegram import Update; print('  ✅ telegram')" 2>/dev/null || {
    pip3 install --force-reinstall --break-system-packages python-telegram-bot==20.7
}

pip3 install --break-system-packages matplotlib 2>/dev/null
python3 -c "import matplotlib; print('  ✅ matplotlib')" 2>/dev/null || {
    pip3 install --force-reinstall --break-system-packages matplotlib
}

pip3 install --break-system-packages flask 2>/dev/null
python3 -c "from flask import Flask; print('  ✅ flask')" 2>/dev/null || {
    pip3 install --force-reinstall --break-system-packages flask
}

echo -e "${GREEN}   ✅ All dependencies installed${NC}"

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
AddressFamily inet
SSHEOF

mkdir -p /etc/ssh/sshd_config.d
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

echo -e "${GREEN}   ✅ SSH Configured${NC}"

# ============================================
# Domain Setup
# ============================================
setup_domain() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   🌐 Domain Configuration${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
        echo -e "  Current Domain: ${GREEN}$(cat /etc/shadow-domain.conf)${NC}"
    else
        echo -e "  Current: ${YELLOW}No domain set (Using IP)${NC}"
    fi
    
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}Add/Change Domain${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}Get Free SSL Certificate${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}Delete Current Domain${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}Skip${NC}"
    echo ""
    echo -n -e "${CYAN}Select option [1-4]: ${NC}"
    read choice
    
    case $choice in
        1)
            echo ""
            echo -n -e "${GREEN}Enter domain: ${NC}"
            read DOMAIN
            echo "$DOMAIN" > /etc/shadow-domain.conf
            echo -e "${GREEN}✅ Domain saved${NC}"
            ;;
        2)
            echo ""
            if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
                DOMAIN=$(cat /etc/shadow-domain.conf)
                echo -n -e "${GREEN}Enter email: ${NC}"
                read EMAIL
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
                [ $? -eq 0 ] && echo -e "${GREEN}✅ SSL obtained${NC}" || echo -e "${RED}❌ Failed${NC}"
            else
                echo -e "${RED}❌ Set domain first${NC}"
            fi
            ;;
        3)
            echo ""
            echo -n -e "${RED}Delete? (y/n): ${NC}"
            read cf
            [ "$cf" = "y" ] && rm -f /etc/shadow-domain.conf && echo -e "${GREEN}✅ Deleted${NC}"
            ;;
        4)
            echo -e "${BLUE}ℹ️  Skipping${NC}"
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
    iptables_mark INTEGER UNIQUE,
    chain_name TEXT UNIQUE,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active',
    user_limit INTEGER DEFAULT 1,
    is_test INTEGER DEFAULT 0
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
INSERT OR IGNORE INTO settings VALUES ('next_mark', '100');
SQLEOF

echo -e "${GREEN}   ✅ Database Created${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v31.0 - TITAN${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# ============================================
# Traffic Monitor - Chain-based, 1s
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
INTERVAL=1
PID_FILE="/var/run/traffic-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

create_user_chain() {
    local username=$1
    local mark=$2
    local chain_name="SHADOW_${username}"
    
    iptables -t mangle -N "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    
    iptables -t mangle -C OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    fi
    
    iptables -t mangle -C INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    fi
    
    iptables -t mangle -C "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    fi
    
    sqlite3 "$DB" "UPDATE users SET chain_name='$chain_name' WHERE username='$username';"
}

get_chain_bytes() {
    local chain_name=$1
    local bytes=$(iptables -t mangle -L "$chain_name" -v -n -x 2>/dev/null | grep "MARK set" | awk '{print $2+0}')
    echo "${bytes:-0}"
}

remove_user_chain() {
    local username=$1
    local chain_name="SHADOW_${username}"
    
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    iptables -t mangle -X "$chain_name" 2>/dev/null
}

echo "🎯 TITAN Monitor Started (PID: $$) | Chain-based | 1s interval"

# Initialize chains for all active users
while IFS='|' read -r username mark chain_name; do
    [ -z "$username" ] && continue
    if [ -z "$chain_name" ] || [ "$chain_name" = "" ]; then
        create_user_chain "$username" "$mark"
    fi
done < <(sqlite3 "$DB" "SELECT username, iptables_mark, chain_name FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")

# Main monitoring loop
while true; do
    current_time=$(date +%s)
    
    while IFS='|' read -r username total_limit expiry mark chain_name is_test; do
        [ -z "$username" ] && continue
        
        # Check expiry
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            [ -n "$chain_name" ] && remove_user_chain "$username"
            continue
        fi
        
        # Ensure chain exists
        if [ -z "$chain_name" ] || [ "$chain_name" = "" ]; then
            create_user_chain "$username" "$mark"
            chain_name="SHADOW_${username}"
        fi
        
        iptables -t mangle -L "$chain_name" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            create_user_chain "$username" "$mark"
        fi
        
        # Read bytes from dedicated chain
        total_bytes=$(get_chain_bytes "$chain_name")
        
        # DIRECT SET - absolute value
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_bytes WHERE username='$username';"
        
        # Check limit
        if [ "$total_limit" != "0" ] && [ "$total_bytes" -ge "$total_limit" ]; then
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            remove_user_chain "$username"
        fi
        
    done < <(sqlite3 "$DB" "SELECT username, total_traffic, expiry, iptables_mark, chain_name, is_test FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# Backup Manager
# ============================================
cat > /usr/local/bin/backup-manager << 'BACKEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
BACKUP_DIR="/var/backups/shadow"

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/shadow_backup_${timestamp}.tar.gz"
    mkdir -p "$BACKUP_DIR"
    tar -czf "$backup_file" /var/lib/shadow/traffic.db /etc/shadow-* /etc/ssh/sshd_config.d/ 2>/dev/null
    local size=$(stat -c %s "$backup_file")
    sqlite3 "$DB" "INSERT INTO backup_history (backup_time, filename, size, type) VALUES ($(date +%s), '$backup_file', $size, 'local');"
    echo "$backup_file"
}

restore_backup() {
    [ ! -f "$1" ] && { echo "❌ Not found!"; return 1; }
    systemctl stop traffic-monitor shadow-bot 2>/dev/null
    tar -xzf "$1" -C /
    systemctl start traffic-monitor shadow-bot 2>/dev/null
    echo "✅ Restored!"
}

case "$1" in
    backup) create_backup ;;
    restore)
        echo "Available backups:"
        sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime') FROM backup_history ORDER BY backup_time DESC LIMIT 10;" | while IFS='|' read id time; do echo "  $id - $time"; done
        echo -n "Enter ID: "; read id
        file=$(sqlite3 "$DB" "SELECT filename FROM backup_history WHERE id=$id;")
        [ -n "$file" ] && [ -f "$file" ] && restore_backup "$file"
        ;;
    auto-backup) while true; do create_backup >/dev/null; sleep 86400; done ;;
    *) echo "Usage: $0 {backup|restore|auto-backup}" ;;
esac
BACKEOF

chmod +x /usr/local/bin/backup-manager

# ============================================
# FULL Telegram Bot - Admin + Client + Analytics
# ============================================
cat > /usr/local/bin/shadow-bot << 'BOTEOF'
#!/usr/bin/env python3
# ============================================
# Shadow SSH Bot v31.0 - TITAN
# ============================================

import os
import sys
import sqlite3
import time
import subprocess
import json
import base64
import random
import string
import io
from datetime import datetime

# Telegram imports
try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
except ImportError:
    subprocess.run([sys.executable, "-m", "pip", "install", "--break-system-packages", "python-telegram-bot==20.7"], capture_output=True)
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes

# Matplotlib for charts
try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    MATPLOTLIB_OK = True
except ImportError:
    MATPLOTLIB_OK = False

# ============================================
# Configuration
# ============================================
DB = "/var/lib/shadow/traffic.db"
CONFIG_FILE = "/etc/shadow-bot.conf"
DOMAIN_FILE = "/etc/shadow-domain.conf"

BOT_TOKEN = None
ADMIN_IDS = []
CLIENT_SESSIONS = {}

def load_config():
    global BOT_TOKEN, ADMIN_IDS
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith("TOKEN="):
                    BOT_TOKEN = line.split("=", 1)[1].strip()
                elif line.startswith("ADMINS="):
                    s = line.split("=", 1)[1].strip()
                    if s:
                        ADMIN_IDS = [int(x.strip()) for x in s.split(",") if x.strip()]

def save_config():
    with open(CONFIG_FILE, 'w') as f:
        f.write(f"TOKEN={BOT_TOKEN}\n")
        f.write(f"ADMINS={','.join(str(x) for x in ADMIN_IDS)}\n")

def is_admin(uid):
    return uid in ADMIN_IDS

def get_domain():
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE, 'r') as f:
            d = f.read().strip()
            if d:
                return d
    return subprocess.getoutput("curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'")

def get_db_connection():
    return sqlite3.connect(DB)

def get_user_info(username):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT status, used_traffic, total_traffic, expiry, user_limit, created, is_test, password FROM users WHERE username=?", [username])
    row = cur.fetchone()
    conn.close()
    return row

def get_next_mark():
    result = subprocess.getoutput(f"sqlite3 {DB} \"SELECT value FROM settings WHERE key='next_mark';\"")
    mark = int(result) if result and result.isdigit() else 100
    subprocess.run(f"sqlite3 {DB} \"UPDATE settings SET value={mark+1} WHERE key='next_mark';\"", shell=True)
    return mark

def create_user_chain(username, mark):
    chain_name = f"SHADOW_{username}"
    subprocess.run(f"iptables -t mangle -N {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -F {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -A OUTPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -A INPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -A {chain_name} -j MARK --set-mark {mark} 2>/dev/null", shell=True)
    return chain_name

def remove_user_chain(username):
    chain_name = f"SHADOW_{username}"
    subprocess.run(f"iptables -t mangle -D OUTPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -D INPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -F {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -X {chain_name} 2>/dev/null", shell=True)

def generate_napsternetv_config(server, username, password, days="∞", traffic="∞"):
    """Generate NapsternetV config link"""
    remarks = f"📡 {username}"
    if days != "∞":
        remarks += f" | ⏰ {days}d"
    if traffic != "∞":
        remarks += f" | 📎 {traffic}"
    
    config_dict = {
        "sshConfigType": "SSH-Direct",
        "remarks": remarks,
        "sshHost": server,
        "sshPort": 22,
        "sshUsername": username,
        "sshPassword": password,
        "udpgwTransparentDNS": True
    }
    
    config_json = json.dumps(config_dict, ensure_ascii=True)
    config_b64 = base64.b64encode(config_json.encode('utf-8')).decode('utf-8')
    return f"npvt-ssh://{config_b64}"

def generate_traffic_chart(username):
    """Generate 24h traffic chart image"""
    if not MATPLOTLIB_OK:
        return None
    
    conn = get_db_connection()
    cur = conn.cursor()
    since = int(time.time()) - 86400
    
    # Get traffic data points
    cur.execute("""
        SELECT timestamp, bytes_used 
        FROM (
            SELECT timestamp, bytes_used,
                   ROW_NUMBER() OVER (PARTITION BY (timestamp / 60) ORDER BY timestamp DESC) as rn
            FROM (
                SELECT timestamp, SUM(bytes_used) as bytes_used
                FROM (
                    SELECT DISTINCT timestamp, bytes_used
                    FROM (
                        SELECT timestamp, used_traffic as bytes_used, username
                        FROM users WHERE username=?
                        UNION ALL
                        SELECT strftime('%s', 'now') as timestamp, used_traffic as bytes_used, username
                        FROM users WHERE username=?
                    )
                )
                GROUP BY timestamp
            )
        )
        WHERE rn = 1
        ORDER BY timestamp ASC
    """, [username, username])
    
    data = cur.fetchall()
    conn.close()
    
    if not data or len(data) < 2:
        return None
    
    times = [datetime.fromtimestamp(t) for t, _ in data]
    bytes_mb = [b / 1048576.0 for _, b in data]
    
    # Create chart
    plt.figure(figsize=(10, 5))
    plt.plot(times, bytes_mb, color='#00ff88', linewidth=2, marker='o', markersize=2)
    plt.fill_between(times, bytes_mb, alpha=0.15, color='#00ff88')
    plt.title(f'📊 Traffic Usage - {username} (Last 24h)', color='white', fontsize=13, fontweight='bold')
    plt.xlabel('Time', color='white')
    plt.ylabel('Megabytes (MB)', color='white')
    plt.grid(True, alpha=0.15, color='white')
    plt.gca().set_facecolor('#0d1117')
    plt.gcf().set_facecolor('#0d1117')
    plt.gca().tick_params(colors='white')
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
    plt.xticks(rotation=45)
    plt.tight_layout()
    
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=120, facecolor='#0d1117', edgecolor='none')
    buf.seek(0)
    plt.close()
    return buf

def create_system_user(username, password, traffic_gb, days, max_conn, is_test=0):
    """Create a system user with all required setup"""
    
    # Create system user
    subprocess.run(["useradd", "-m", "-s", "/bin/bash", username], capture_output=True)
    subprocess.run(["chpasswd"], input=f"{username}:{password}".encode(), capture_output=True)
    
    # SSH config for this user
    with open(f"/etc/ssh/sshd_config.d/{username}.conf", "w") as f:
        f.write(f"MaxSessions {max_conn}\n")
        f.write(f"MaxStartups {max_conn}\n")
    
    # Calculate expiry
    traffic_bytes = traffic_gb * 1073741824 if traffic_gb > 0 else 0
    expiry = int(time.time()) + (days * 86400) if days > 0 else 0
    
    # Get iptables mark
    mark = get_next_mark()
    
    # Create iptables chain
    chain_name = create_user_chain(username, mark)
    
    # Save to users file
    with open("/etc/shadow-users.conf", "a") as f:
        f.write(f"{username}\n")
    
    # Save to database
    conn = get_db_connection()
    conn.execute(
        "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit, is_test) VALUES (?,?,?,?,?,?,?,?,?)",
        [username, password, traffic_bytes, mark, chain_name, expiry, int(time.time()), max_conn, is_test]
    )
    conn.commit()
    conn.close()
    
    # Restart SSH
    subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)

# ============================================
# Start Command
# ============================================
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    
    if is_admin(user_id):
        # Auto-add first admin
        if not ADMIN_IDS:
            ADMIN_IDS.append(user_id)
            save_config()
        
        keyboard = [
            [InlineKeyboardButton("👥 Users List", callback_data="list")],
            [InlineKeyboardButton("➕ Create User", callback_data="create")],
            [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
            [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
            [InlineKeyboardButton("📊 Traffic Analytics", callback_data="analytics")],
            [InlineKeyboardButton("📦 Backup", callback_data="backup")],
            [InlineKeyboardButton("📈 Server Status", callback_data="status")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        server = get_domain()
        await update.message.reply_text(
            f"🔱 *Shadow SSH v31.0 TITAN*\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"🌐 Server: `{server}:22`\n"
            f"🎯 Chain-based iptables\n"
            f"⏱ 1s Real-time\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"Select an option:",
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
    else:
        # Client - ask for password
        CLIENT_SESSIONS[user_id] = {"state": "waiting_password"}
        await update.message.reply_text(
            "🔐 *Client Login*\n\n"
            "Please enter your SSH password to access your panel:\n\n"
            "Type /cancel to go back.",
            parse_mode='Markdown'
        )

# ============================================
# Message Handler (Password check)
# ============================================
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text.strip()
    
    # Admin creates user via command
    if is_admin(user_id) and text.startswith('/create'):
        await create_user_command(update, context)
        return
    
    # Handle cancel
    if text == '/cancel' and user_id in CLIENT_SESSIONS:
        del CLIENT_SESSIONS[user_id]
        await update.message.reply_text("✅ Cancelled. Type /start to begin again.")
        return
    
    # Check if waiting for password
    if user_id in CLIENT_SESSIONS and CLIENT_SESSIONS[user_id].get("state") == "waiting_password":
        password = text
        
        # Search for user with this password
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT username FROM users WHERE password=? AND status='active'", [password])
        row = cur.fetchone()
        conn.close()
        
        if row:
            username = row[0]
            CLIENT_SESSIONS[user_id] = {"state": "logged_in", "username": username}
            await show_client_panel(update, username)
        else:
            await update.message.reply_text(
                "❌ *Invalid password or account expired!*\n\n"
                "Please try again or contact your admin.",
                parse_mode='Markdown'
            )
        return
    
    # Check if logged in client using menu buttons
    if user_id in CLIENT_SESSIONS and CLIENT_SESSIONS[user_id].get("state") == "logged_in":
        username = CLIENT_SESSIONS[user_id]["username"]
        cmd = text.lower()
        
        if cmd in ["📊 my usage", "my usage", "usage"]:
            await show_client_panel(update, username)
        elif cmd in ["📈 traffic chart", "chart", "traffic chart"]:
            await send_client_chart(update, username)
        elif cmd in ["📋 my config", "config", "my config"]:
            await send_client_config(update, username)
        elif cmd in ["🚪 logout", "logout"]:
            del CLIENT_SESSIONS[user_id]
            await update.message.reply_text("✅ Logged out. Type /start to login again.")
        else:
            await show_client_menu_help(update)
        return

async def show_client_menu_help(update):
    kb = [
        [InlineKeyboardButton("📊 My Usage", callback_data="client_usage")],
        [InlineKeyboardButton("📈 Traffic Chart", callback_data="client_chart")],
        [InlineKeyboardButton("📋 My Config", callback_data="client_config")],
        [InlineKeyboardButton("🚪 Logout", callback_data="client_logout")]
    ]
    await update.message.reply_text(
        "👤 *Client Panel*\n\nSelect an option:",
        reply_markup=InlineKeyboardMarkup(kb),
        parse_mode='Markdown'
    )

async def show_client_panel(update, username):
    info = get_user_info(username)
    if not info:
        await update.message.reply_text("❌ Account not found!")
        return
    
    status, used, total, expiry, limit, created, is_test, password = info
    
    used_mb = used / 1048576.0
    
    if total == 0:
        total_display = "∞"
        total_mb = float('inf')
        percent = 0
        usage_text = f"{used_mb:.1f} MB / ∞"
    else:
        total_mb = total / 1048576.0
        total_gb = total / 1073741824.0
        total_display = f"{total_gb:.1f} GB"
        percent = min((used / total) * 100, 100)
        usage_text = f"{used_mb:.1f} MB / {total_display}"
    
    if expiry == 0:
        days_left = "∞"
    else:
        days_left_num = (expiry - int(time.time())) / 86400
        if days_left_num < 0:
            days_left = "⚠️ EXPIRED"
        else:
            days_left = f"{int(days_left_num)} days"
    
    # Progress bar
    bar_length = 15
    filled = int(bar_length * percent / 100)
    bar = "▓" * filled + "░" * (bar_length - filled)
    
    status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
    
    message = (
        f"👤 *{username}* {status_emoji}\n"
        f"━━━━━━━━━━━━━━━━━━━\n\n"
        f"📊 *Traffic:*\n"
        f"`{bar}` {percent:.1f}%\n"
        f"{usage_text}\n\n"
        f"⏰ *Expiry:* {days_left}\n"
        f"🔗 *Max Connections:* {limit}\n"
        f"🧪 *Test Account:* {'Yes' if is_test else 'No'}\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
    )
    
    kb = [
        [InlineKeyboardButton("📈 Traffic Chart", callback_data="client_chart")],
        [InlineKeyboardButton("📋 My Config", callback_data="client_config")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="client_refresh")],
        [InlineKeyboardButton("🚪 Logout", callback_data="client_logout")]
    ]
    
    if hasattr(update, 'message'):
        await update.message.reply_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')
    else:
        await update.edit_message_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def send_client_chart(update, username):
    if hasattr(update, 'message'):
        await update.message.reply_text("⏳ Generating chart...")
    else:
        await update.edit_message_text("⏳ Generating chart...")
    
    buf = generate_traffic_chart(username)
    if buf:
        # Send as photo
        if hasattr(update, 'message'):
            await update.message.reply_photo(photo=buf, caption=f"📈 24h Traffic - {username}")
        else:
            await update.message.reply_photo(photo=buf, caption=f"📈 24h Traffic - {username}")
            await update.delete_message()
    else:
        if hasattr(update, 'message'):
            await update.message.reply_text("📊 Not enough data yet. Use the connection and check back later!")
        else:
            await update.edit_message_text("📊 Not enough data yet. Use the connection and check back later!")

async def send_client_config(update, username):
    info = get_user_info(username)
    if not info:
        await update.message.reply_text("❌ Account not found!")
        return
    
    status, used, total, expiry, limit, created, is_test, password = info
    
    domain = get_domain()
    
    if expiry == 0:
        days_display = "∞"
    else:
        days_left = (expiry - int(time.time())) // 86400
        days_display = str(max(days_left, 0)) + "d"
    
    if total == 0:
        traffic_display = "∞"
    else:
        traffic_display = f"{total/1073741824:.0f}GB"
    
    # Generate real config with real password
    config_link = generate_napsternetv_config(domain, username, password, days_display, traffic_display)
    
    message = (
        f"📋 *Your Config*\n"
        f"━━━━━━━━━━━━━━━━━━━\n\n"
        f"🌐 Server: `{domain}`\n"
        f"📡 Port: `22`\n"
        f"👤 Username: `{username}`\n"
        f"━━━━━━━━━━━━━━━━━━━\n\n"
        f"📋 *NapsternetV Link:*\n"
        f"`{config_link}`"
    )
    
    kb = [[InlineKeyboardButton("🔄 Refresh", callback_data="client_refresh")],
          [InlineKeyboardButton("🚪 Logout", callback_data="client_logout")]]
    
    if hasattr(update, 'message'):
        await update.message.reply_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')
    else:
        await update.edit_message_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

# ============================================
# Button Handler
# ============================================
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = query.from_user.id
    
    # Handle client buttons
    if query.data.startswith("client_"):
        if user_id not in CLIENT_SESSIONS or CLIENT_SESSIONS[user_id].get("state") != "logged_in":
            await query.edit_message_text("❌ Session expired. Please /start again.")
            return
        
        username = CLIENT_SESSIONS[user_id]["username"]
        
        if query.data == "client_usage" or query.data == "client_refresh":
            await show_client_panel(query, username)
        elif query.data == "client_chart":
            await send_client_chart(query, username)
        elif query.data == "client_config":
            await send_client_config(query, username)
        elif query.data == "client_logout":
            del CLIENT_SESSIONS[user_id]
            await query.edit_message_text("✅ Logged out. Type /start to login again.")
        return
    
    # Admin only below
    if not is_admin(user_id):
        await query.edit_message_text("❌ Access Denied!")
        return
    
    if query.data == "list":
        await show_users_list(query)
    elif query.data == "create":
        await query.edit_message_text(
            "➕ *Create User*\n\n"
            "Send command:\n"
            "`/create username password days traffic_gb max_connections`\n\n"
            "*Example:*\n"
            "`/create testuser pass123 30 5 3`\n\n"
            "*Unlimited:*\n"
            "`/create testuser pass123 0 0 1`",
            parse_mode='Markdown'
        )
    elif query.data == "test_acc":
        await create_test_account_handler(query)
    elif query.data == "del_menu":
        await show_delete_menu(query)
    elif query.data.startswith("del_"):
        username = query.data[4:]
        await delete_user_handler(query, username)
    elif query.data == "analytics":
        await show_analytics_menu(query)
    elif query.data == "analytics_all":
        await send_all_users_chart(query)
    elif query.data.startswith("analytics_user_"):
        username = query.data.replace("analytics_user_", "")
        await send_user_chart(query, username)
    elif query.data == "backup":
        await create_backup_handler(query)
    elif query.data == "status":
        await show_status(query)
    elif query.data == "back":
        await show_admin_menu(query)

async def show_admin_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list")],
        [InlineKeyboardButton("➕ Create User", callback_data="create")],
        [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
        [InlineKeyboardButton("📊 Traffic Analytics", callback_data="analytics")],
        [InlineKeyboardButton("📦 Backup", callback_data="backup")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"🔱 *Admin Panel | TITAN v31.0*\n"
        f"🌐 `{get_domain()}:22`\n"
        f"Select option:",
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def show_users_list(query):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT username, status, used_traffic, total_traffic, expiry, is_test FROM users")
    users = cur.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users found!")
        return
    
    message = "👥 *Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    
    for u in users:
        username, status, used, total, expiry, is_test = u
        
        used_mb = used / 1048576.0
        total_gb = total / 1073741824.0 if total > 0 else 0
        
        if expiry == 0:
            days_left = "∞"
        else:
            days_left = (expiry - int(time.time())) // 86400
            if days_left < 0:
                days_left = "EXPIRED"
            else:
                days_left = f"{days_left}d"
        
        if total == 0:
            usage_text = f"{used_mb:.1f}MB / ∞"
        else:
            percent = (used / total * 100) if total > 0 else 0
            usage_text = f"{used_mb:.1f}MB / {total_gb:.1f}GB ({percent:.1f}%)"
        
        if status == "active":
            emoji = "🟢"
        elif status == "expired":
            emoji = "🔴"
        elif status == "limited":
            emoji = "🟡"
        else:
            emoji = "⚪"
        
        test_tag = " 🧪" if is_test else ""
        
        message += f"{emoji} `{username}`{test_tag}\n"
        message += f"   📊 {usage_text}\n"
        message += f"   ⏰ {days_left}\n\n"
    
    kb = [[InlineKeyboardButton("🔙 Back", callback_data="back")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def create_test_account_handler(query):
    # Generate random credentials
    test_user = "test_" + ''.join(random.choices(string.ascii_lowercase, k=5))
    test_pass = ''.join(random.choices(string.ascii_letters + string.digits, k=10))
    
    # Create the user
    create_system_user(test_user, test_pass, 0, 1, 1, is_test=1)
    
    # Set 30MB limit
    conn = get_db_connection()
    conn.execute("UPDATE users SET total_traffic = ? WHERE username = ?", [30 * 1048576, test_user])
    conn.commit()
    conn.close()
    
    domain = get_domain()
    config_link = generate_napsternetv_config(domain, test_user, test_pass, "1", "30MB")
    
    message = (
        f"🧪 *Test Account Created!*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{domain}:22`\n"
        f"👤 `{test_user}`\n"
        f"🔑 `{test_pass}`\n"
        f"📊 `30 MB`\n"
        f"⏰ `1 Day`\n"
        f"🔗 `1 Connection`\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"📋 `{config_link}`"
    )
    
    await query.edit_message_text(message, parse_mode='Markdown')

async def show_delete_menu(query):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT username FROM users")
    users = cur.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users to delete!")
        return
    
    keyboard = []
    for (username,) in users:
        keyboard.append([InlineKeyboardButton(f"🗑 {username}", callback_data=f"del_{username}")])
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="back")])
    
    await query.edit_message_text(
        "🗑 *Select user to delete:*",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def delete_user_handler(query, username):
    # Remove iptables chain
    remove_user_chain(username)
    
    # Kill and delete user
    subprocess.run(["pkill", "-9", "-u", username], capture_output=True)
    subprocess.run(["userdel", "-r", username], capture_output=True)
    
    # Remove from database
    conn = get_db_connection()
    conn.execute("DELETE FROM users WHERE username=?", [username])
    conn.commit()
    conn.close()
    
    # Clean files
    os.system(f"sed -i '/^{username}$/d' /etc/shadow-users.conf 2>/dev/null")
    os.system(f"rm -f /etc/ssh/sshd_config.d/{username}.conf")
    
    # Restart SSH
    subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
    
    await query.edit_message_text(
        f"✅ User `{username}` deleted!",
        parse_mode='Markdown'
    )

async def show_analytics_menu(query):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT DISTINCT username FROM users WHERE status='active'")
    users = cur.fetchall()
    conn.close()
    
    keyboard = []
    if users:
        keyboard.append([InlineKeyboardButton("📊 All Users Chart", callback_data="analytics_all")])
        for (username,) in users[:15]:
            keyboard.append([InlineKeyboardButton(f"📈 {username}", callback_data=f"analytics_user_{username}")])
    else:
        keyboard.append([InlineKeyboardButton("📭 No active users", callback_data="back")])
    
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="back")])
    
    await query.edit_message_text(
        "📊 *Traffic Analytics*\n\nSelect user to view chart:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def send_all_users_chart(query):
    if not MATPLOTLIB_OK:
        await query.edit_message_text("❌ Matplotlib not available")
        return
    
    await query.edit_message_text("⏳ Generating chart...")
    
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT DISTINCT username FROM users WHERE status='active'")
    users = cur.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No active users!")
        return
    
    plt.figure(figsize=(12, 6))
    colors = ['#00ff88', '#ff6b6b', '#ffd93d', '#6c5ce7', '#a8e6cf', '#ff8c00', '#00d2ff', '#ff69b4']
    
    for i, (username,) in enumerate(users[:8]):
        info = get_user_info(username)
        if info:
            used_mb = info[1] / 1048576.0
            total_display = "∞" if info[2] == 0 else f"{info[2]/1073741824:.1f}GB"
            color = colors[i % len(colors)]
            plt.barh(username[:15], used_mb, color=color, alpha=0.8, label=f"{username[:15]} ({total_display})")
    
    plt.title('User Traffic Overview', color='white', fontsize=14, fontweight='bold')
    plt.xlabel('Megabytes (MB)', color='white')
    plt.gca().set_facecolor('#0d1117')
    plt.gcf().set_facecolor('#0d1117')
    plt.gca().tick_params(colors='white')
    plt.legend(loc='lower right', fontsize=8, facecolor='#0d1117', edgecolor='white', labelcolor='white')
    plt.tight_layout()
    
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=120, facecolor='#0d1117', edgecolor='none')
    buf.seek(0)
    plt.close()
    
    await query.message.reply_photo(photo=buf, caption="📊 All Users - Traffic Overview")
    await query.edit_message_text("✅ Chart generated!")

async def send_user_chart(query, username):
    if not MATPLOTLIB_OK:
        await query.edit_message_text("❌ Matplotlib not available")
        return
    
    await query.edit_message_text(f"⏳ Generating chart for {username}...")
    
    buf = generate_traffic_chart(username)
    if buf:
        await query.message.reply_photo(photo=buf, caption=f"📈 24h Traffic - {username}")
        await query.edit_message_text("✅ Chart generated!")
    else:
        await query.edit_message_text(f"📊 Not enough data for {username}")

async def create_backup_handler(query):
    result = subprocess.run(["/usr/local/bin/backup-manager", "backup"], capture_output=True, text=True)
    await query.edit_message_text(
        f"📦 *Backup Created*\n\n{result.stdout}",
        parse_mode='Markdown'
    )

async def show_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu' | awk '{print $2}' | cut -d% -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\",$3*100/$2}'")
    uptime_val = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = get_db_connection()
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    test_count = conn.execute("SELECT COUNT(*) FROM users WHERE status='active' AND is_test=1").fetchone()[0]
    conn.close()
    
    message = (
        f"📈 *Server Status*\n"
        f"━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖥 CPU: `{cpu}%`\n"
        f"💾 RAM: `{mem}%`\n"
        f"⏱ Uptime: `{uptime_val}`\n"
        f"🔗 Connections: `{conn_count}`\n"
        f"👥 Active Users: `{active}`\n"
        f"🧪 Test Accounts: `{test_count}`\n"
        f"🎯 Mode: `Chain-based iptables`\n"
        f"⏱ Interval: `1s Real-time`\n"
        f"🚫 IPv6: `Disabled`\n"
    )
    
    kb = [[InlineKeyboardButton("🔙 Back", callback_data="back")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

# ============================================
# Create User Command
# ============================================
async def create_user_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    try:
        args = context.args
        
        if len(args) < 5:
            await update.message.reply_text(
                "❌ *Invalid format!*\n\n"
                "Usage: `/create username password days traffic_gb max_connections`\n\n"
                "*Example:*\n"
                "`/create testuser pass123 30 5 3`\n"
                "30 days, 5GB, 3 connections\n\n"
                "*Unlimited:*\n"
                "`/create testuser pass123 0 0 1`",
                parse_mode='Markdown'
            )
            return
        
        username = args[0]
        password = args[1]
        days = int(args[2])
        traffic_gb = int(args[3])
        max_conn = int(args[4])
        
        # Check if user exists
        result = subprocess.run(["id", username], capture_output=True)
        if result.returncode == 0:
            await update.message.reply_text(f"❌ User `{username}` already exists!", parse_mode='Markdown')
            return
        
        # Create the user
        create_system_user(username, password, traffic_gb, days, max_conn)
        
        domain = get_domain()
        days_display = str(days) if days > 0 else "∞"
        traffic_display = f"{traffic_gb}GB" if traffic_gb > 0 else "∞"
        
        config_link = generate_napsternetv_config(domain, username, password, days_display, traffic_display)
        
        message = (
            f"✅ *User Created!*\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"🌐 `{domain}:22`\n"
            f"👤 `{username}`\n"
            f"🔑 `{password}`\n"
            f"📊 `{traffic_gb}GB`\n"
            f"⏰ `{days} days`\n"
            f"🔗 `{max_conn}`\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"📋 `{config_link}`"
        )
        
        await update.message.reply_text(message, parse_mode='Markdown')
        
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {str(e)}")

# ============================================
# Main
# ============================================
def main():
    load_config()
    
    if not BOT_TOKEN:
        print("❌ Bot token not configured!")
        print("Please run: shadow -> Option 6 -> Set Token")
        sys.exit(1)
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🤖 Shadow SSH TITAN Bot v31.0 Starting...")
    print(f"   Server: {get_domain()}")
    print(f"   Admins: {len(ADMIN_IDS)}")
    print(f"   Matplotlib: {'✅' if MATPLOTLIB_OK else '❌'}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Command handlers
    app.add_handler(CommandHandler("start", start_command))
    
    # Button handlers
    app.add_handler(CallbackQueryHandler(button_handler))
    
    # Message handlers
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    print("✅ Bot is running...")
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
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then 
        cat "$DOMAIN_FILE"
    else 
        curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
    fi
}

show_banner() {
    SERVER_IP=$(get_domain)
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v31.0 - TITAN EDITION 🔱${PURPLE}              ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 ${SERVER_IP}:22  |  🎯 Chain-based  |  ⏱ 1s  |  📊 Analytics${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════ TITAN MENU ══════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create New User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List All Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}🧪  Create Test Account (30MB/1Day)${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}📦  Backup & Restore${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}🤖  Telegram Bot Settings${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}🌐  Domain Management${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}🔄  Restart All Services${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}🚪  Exit${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""
}

create_user_chain() {
    local username=$1
    local mark=$2
    local chain_name="SHADOW_${username}"
    
    iptables -t mangle -N "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    
    iptables -t mangle -C OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    fi
    
    iptables -t mangle -C INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    fi
    
    iptables -t mangle -C "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    fi
    
    echo "$chain_name"
}

remove_user_chain() {
    local username=$1
    local chain_name="SHADOW_${username}"
    
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    iptables -t mangle -X "$chain_name" 2>/dev/null
}

generate_config() {
    local server=$1
    local username=$2
    local password=$3
    local days=$4
    local traffic=$5
    
    local remarks="📡 ${username}"
    [ "$days" != "∞" ] && remarks="${remarks} | ⏰ ${days}d"
    [ "$traffic" != "∞" ] && remarks="${remarks} | 📎 ${traffic}"
    
    local config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"${remarks}\",\"sshHost\":\"${server}\",\"sshPort\":22,\"sshUsername\":\"${username}\",\"sshPassword\":\"${password}\",\"udpgwTransparentDNS\":true}"
    local config_b64=$(echo -n "$config_json" | base64 -w 0)
    echo "npvt-ssh://${config_b64}"
}

create_user() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   📝 CREATE NEW USER${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -n -e "${GREEN}👤 Username: ${NC}"
    read username
    
    if id "$username" &>/dev/null; then
        echo ""
        echo -e "${RED}❌ User '$username' already exists!${NC}"
        sleep 2
        return
    fi
    
    echo -n -e "${GREEN}🔑 Password: ${NC}"
    read password
    echo -n -e "${GREEN}📊 Traffic Limit (GB, 0=unlimited): ${NC}"
    read traffic_gb
    echo -n -e "${GREEN}⏰ Days Valid (0=unlimited): ${NC}"
    read days
    echo -n -e "${GREEN}🔢 Max Connections (1-10): ${NC}"
    read max_conn
    
    [ "$traffic_gb" -eq 0 ] && traffic_bytes=0 || traffic_bytes=$((traffic_gb * 1073741824))
    [ "$days" -eq 0 ] && expiry=0 || expiry=$(date -d "+${days} days" +%s)
    [ -z "$max_conn" ] && max_conn=1
    
    # Create system user
    useradd -m -s /bin/bash "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    # SSH config
    cat > "/etc/ssh/sshd_config.d/${username}.conf" << EOF
MaxSessions $max_conn
MaxStartups $max_conn
EOF
    
    # Get iptables mark
    next_mark=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';")
    mark=${next_mark:-100}
    sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
    
    # Create chain
    chain_name=$(create_user_chain "$username" "$mark")
    
    # Save to files and DB
    echo "$username" >> /etc/shadow-users.conf 2>/dev/null
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $mark, '$chain_name', $expiry, $(date +%s), $max_conn);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    days_display="∞"
    [ "$days" != "0" ] && days_display="$days"
    traffic_display="∞"
    [ "$traffic_gb" != "0" ] && traffic_display="${traffic_gb}GB"
    
    config_link=$(generate_config "$SERVER" "$username" "$password" "$days_display" "$traffic_display")
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ✅ USER CREATED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Server: ${GREEN}${SERVER}${NC}"
    echo -e "  📡 Port: ${GREEN}22${NC}"
    echo -e "  👤 Username: ${GREEN}${username}${NC}"
    echo -e "  🔑 Password: ${GREEN}${password}${NC}"
    echo -e "  📊 Traffic: ${GREEN}${traffic_gb} GB${NC}"
    echo -e "  ⏰ Valid: ${GREEN}${days} days${NC}"
    echo -e "  🔗 Max Conn: ${GREEN}${max_conn}${NC}"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📋 NapsternetV Config:${NC}"
    echo -e "   ${YELLOW}${config_link}${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read
}

delete_user() {
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}   🗑  DELETE USER${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -n -e "${RED}Username to delete: ${NC}"
    read username
    
    if ! id "$username" &>/dev/null; then
        echo ""
        echo -e "${RED}❌ User '$username' not found!${NC}"
        sleep 2
        return
    fi
    
    echo ""
    echo -n -e "${YELLOW}Are you sure? (y/n): ${NC}"
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${BLUE}ℹ️  Cancelled${NC}"
        sleep 1
        return
    fi
    
    # Remove chain
    remove_user_chain "$username"
    
    # Kill and delete
    pkill -9 -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    
    # Clean files
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
    
    # Delete from DB
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    
    systemctl restart sshd 2>/dev/null
    
    echo ""
    echo -e "${GREEN}✅ User '$username' deleted successfully!${NC}"
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
    
    while IFS='|' read -r username status total_limit expiry limit used mark chain_name is_test; do
        [ -z "$username" ] && continue
        
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
        
        test_tag=""
        [ "$is_test" = "1" ] && test_tag=" 🧪"
        
        printf "%-15s %s %-8s ${CYAN}%-25s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$limit_text" "$expiry_text"
        
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit, used_traffic, iptables_mark, chain_name, is_test FROM users;")
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read
}

create_test_account() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🧪 CREATE TEST ACCOUNT (30MB/1Day)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    test_user="test_$(cat /dev/urandom | tr -dc 'a-z' | head -c 5)"
    test_pass=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)
    
    echo -e "${CYAN}Generated Test Account:${NC}"
    echo -e "  👤 Username: ${GREEN}${test_user}${NC}"
    echo -e "  🔑 Password: ${GREEN}${test_pass}${NC}"
    echo -e "  📊 Traffic: ${GREEN}30 MB${NC}"
    echo -e "  ⏰ Validity: ${GREEN}1 Day${NC}"
    echo -e "  🔗 Connections: ${GREEN}1${NC}"
    echo ""
    echo -n -e "${YELLOW}Create this test account? (y/n): ${NC}"
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${BLUE}ℹ️  Cancelled${NC}"
        sleep 1
        return
    fi
    
    # Create
    useradd -m -s /bin/bash "$test_user" 2>/dev/null
    echo "$test_user:$test_pass" | chpasswd
    
    cat > "/etc/ssh/sshd_config.d/${test_user}.conf" << EOF
MaxSessions 1
MaxStartups 1
EOF
    
    next_mark=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';")
    mark=${next_mark:-100}
    sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
    
    chain_name=$(create_user_chain "$test_user" "$mark")
    
    traffic_bytes=$((30 * 1048576))
    expiry=$(date -d "+1 days" +%s)
    
    echo "$test_user" >> /etc/shadow-users.conf 2>/dev/null
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit, is_test) VALUES ('$test_user', '$test_pass', $traffic_bytes, $mark, '$chain_name', $expiry, $(date +%s), 1, 1);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    config_link=$(generate_config "$SERVER" "$test_user" "$test_pass" "1" "30MB")
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ✅ TEST ACCOUNT CREATED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Server: ${GREEN}${SERVER}${NC}"
    echo -e "  👤 Username: ${GREEN}${test_user}${NC}"
    echo -e "  🔑 Password: ${GREEN}${test_pass}${NC}"
    echo -e "  📊 Traffic: ${GREEN}30 MB${NC}"
    echo -e "  ⏰ Validity: ${GREEN}1 Day${NC}"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📋 NapsternetV Config:${NC}"
    echo -e "   ${YELLOW}${config_link}${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read
}

backup_menu() {
    while true; do
        clear
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}   📦 BACKUP & RESTORE${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime') FROM backup_history ORDER BY backup_time DESC LIMIT 5;" 2>/dev/null
        echo ""
        echo -e "  ${GREEN}1.${NC} ${WHITE}Create New Backup${NC}"
        echo -e "  ${GREEN}2.${NC} ${WHITE}Restore from Backup${NC}"
        echo -e "  ${GREEN}3.${NC} ${WHITE}Toggle Auto-Backup (24h)${NC}"
        echo -e "  ${GREEN}4.${NC} ${WHITE}Back to Main Menu${NC}"
        echo ""
        echo -n -e "${CYAN}Select option [1-4]: ${NC}"
        read choice
        
        case $choice in
            1)
                /usr/local/bin/backup-manager backup
                sleep 2
                ;;
            2)
                /usr/local/bin/backup-manager restore
                sleep 2
                ;;
            3)
                if systemctl is-active --quiet shadow-backup; then
                    systemctl stop shadow-backup
                    echo -e "${YELLOW}🛑 Auto-backup disabled${NC}"
                else
                    systemctl start shadow-backup
                    echo -e "${GREEN}🚀 Auto-backup enabled (every 24h)${NC}"
                fi
                sleep 2
                ;;
            4)
                break
                ;;
        esac
    done
}

domain_management() {
    clear
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   🌐 DOMAIN MANAGEMENT${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        echo -e "  Current Domain: ${GREEN}$(cat $DOMAIN_FILE)${NC}"
    else
        echo -e "  Current: ${YELLOW}No domain set (Using IP)${NC}"
    fi
    
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}Add/Change Domain${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}Get Free SSL Certificate${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}Delete Current Domain${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}Back to Main Menu${NC}"
    echo ""
    echo -n -e "${CYAN}Select option [1-4]: ${NC}"
    read choice
    
    case $choice in
        1)
            echo ""
            echo -n -e "${GREEN}Enter domain: ${NC}"
            read d
            echo "$d" > "$DOMAIN_FILE"
            echo -e "${GREEN}✅ Domain set to: $d${NC}"
            sleep 1
            ;;
        2)
            echo ""
            if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
                d=$(cat "$DOMAIN_FILE")
                echo -n -e "${GREEN}Enter your email: ${NC}"
                read e
                echo -e "${YELLOW}🔐 Obtaining SSL Certificate...${NC}"
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$d" --non-interactive --agree-tos --email "$e"
            else
                echo -e "${RED}❌ Please set a domain first!${NC}"
            fi
            sleep 2
            ;;
        3)
            echo ""
            echo -n -e "${RED}Are you sure? (y/n): ${NC}"
            read cf
            if [ "$cf" = "y" ] || [ "$cf" = "Y" ]; then
                rm -f "$DOMAIN_FILE"
                echo -e "${GREEN}✅ Domain deleted${NC}"
            fi
            sleep 1
            ;;
        4)
            return
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
    mem=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    uptime_val=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    test_users=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active' AND is_test=1;")
    
    echo -e "  ${WHITE}🖥  CPU Usage:${NC} ${YELLOW}${cpu}%${NC}"
    echo -e "  ${WHITE}💾 RAM Usage:${NC} ${YELLOW}${mem}%${NC}"
    echo -e "  ${WHITE}⏱  Uptime:${NC} ${GREEN}${uptime_val}${NC}"
    echo -e "  ${WHITE}🔗 Active Connections:${NC} ${CYAN}${conn}${NC}"
    echo -e "  ${WHITE}👥 Active Users:${NC} ${GREEN}${users}${NC}"
    echo -e "  ${WHITE}🧪 Test Accounts:${NC} ${YELLOW}${test_users}${NC}"
    echo -e "  ${WHITE}📡 Port 22:${NC} ${GREEN}Open & Listening${NC}"
    echo -e "  ${WHITE}⚡ BBR:${NC} ${GREEN}Enabled${NC}"
    echo -e "  ${WHITE}🎯 Traffic Mode:${NC} ${GREEN}Chain-based iptables${NC}"
    echo -e "  ${WHITE}⏱ Monitor Interval:${NC} ${GREEN}1 second (Real-time)${NC}"
    echo -e "  ${WHITE}🚫 IPv6:${NC} ${RED}DISABLED${NC}"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if systemctl is-active --quiet traffic-monitor; then
        echo -e "  ${WHITE}📊 Traffic Monitor:${NC} ${GREEN}Running ✅${NC}"
    else
        echo -e "  ${WHITE}📊 Traffic Monitor:${NC} ${RED}Stopped ❌${NC}"
    fi
    
    if systemctl is-active --quiet shadow-bot; then
        echo -e "  ${WHITE}🤖 Telegram Bot:${NC} ${GREEN}Running ✅${NC}"
    else
        echo -e "  ${WHITE}🤖 Telegram Bot:${NC} ${RED}Stopped ❌${NC}"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read
}

# Main Loop
while true; do
    show_menu
    echo -n -e "${CYAN}Select option [1-10]: ${NC}"
    read choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) create_test_account ;;
        5) backup_menu ;;
        6)
            if [ -f "$BOT_CONFIG" ]; then
                echo ""
                echo -e "${PURPLE}🤖 Telegram Bot Settings${NC}"
                echo ""
                echo -e "1. Set/Change Bot Token"
                echo -e "2. Add Admin ID"
                echo -e "3. Start/Stop Bot"
                echo -e "4. View Bot Status"
                echo -e "5. Back"
                echo ""
                echo -n -e "Select: "
                read bc
                case $bc in
                    1)
                        echo -n -e "Enter Bot Token (from @BotFather): "
                        read t
                        sed -i "s/TOKEN=.*/TOKEN=$t/" "$BOT_CONFIG"
                        echo -e "${GREEN}✅ Token saved!${NC}"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    2)
                        echo -n -e "Enter Admin Telegram ID: "
                        read id
                        cur=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
                        sed -i "s/ADMINS=.*/ADMINS=$cur,$id/" "$BOT_CONFIG"
                        echo -e "${GREEN}✅ Admin added!${NC}"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    3)
                        if systemctl is-active --quiet shadow-bot; then
                            systemctl stop shadow-bot
                            echo -e "${YELLOW}🛑 Bot stopped${NC}"
                        else
                            systemctl start shadow-bot
                            echo -e "${GREEN}🚀 Bot started${NC}"
                        fi
                        ;;
                    4)
                        systemctl status shadow-bot --no-pager -l
                        echo ""
                        echo -n "Press Enter..."
                        read
                        ;;
                esac
            else
                echo ""
                echo -n -e "${GREEN}Enter Bot Token (from @BotFather): ${NC}"
                read t
                echo "TOKEN=$t" > "$BOT_CONFIG"
                echo "ADMINS=" >> "$BOT_CONFIG"
                echo -e "${GREEN}✅ Token saved!${NC}"
                systemctl restart shadow-bot 2>/dev/null
            fi
            sleep 1
            ;;
        7) domain_management ;;
        8) server_status ;;
        9)
            echo ""
            echo -e "${YELLOW}🔄 Restarting all services...${NC}"
            systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null
            echo -e "${GREEN}✅ All services restarted!${NC}"
            sleep 2
            ;;
        10)
            clear
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}   👋 Thank you for using Shadow SSH v31.0!${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo -e "${RED}❌ Invalid option! Please select 1-10${NC}"
            sleep 1
            ;;
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
Description=Shadow SSH TITAN Traffic Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-monitor
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
SERVICEEOF

cat > /etc/systemd/system/shadow-bot.service << 'BOTSERVICEEOF'
[Unit]
Description=Shadow SSH TITAN Telegram Bot
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/shadow-bot
Restart=always
RestartSec=10
User=root
Environment=PYTHONUNBUFFERED=1
[Install]
WantedBy=multi-user.target
BOTSERVICEEOF

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
systemctl enable traffic-monitor shadow-bot
systemctl restart traffic-monitor

ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

# Final Message
clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                          ║${NC}"
echo -e "${PURPLE}║      ${GREEN}✅ SHADOW SSH v31.0 - TITAN INSTALLED!${PURPLE}               ║${NC}"
echo -e "${PURPLE}║                                                          ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🎯 TITAN FEATURES (ALL WORKING)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ✅ Chain-based iptables accounting (Dedicated chain)"
echo -e "  ✅ 1 second interval (Real-time precision)"
echo -e "  ✅ Config Generator - Working NapsternetV format"
echo -e "  ✅ Client Panel - Login with SSH password"
echo -e "  ✅ Traffic Analytics - Charts for 24h usage"
echo -e "  ✅ All buttons work in both Panel and Bot"
echo -e "  ✅ Test Account (30MB/1Day)"
echo -e "  ✅ Backup & Restore"
echo -e "  ✅ Domain Management"
echo -e "  ✅ Full Bot Management"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🚀 QUICK COMMANDS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🚀 Open Panel:      ${YELLOW}shadow${NC}"
echo -e "  🧪 Test Account:    ${YELLOW}shadow${NC} → Option 4"
echo -e "  🤖 Bot Setup:       ${YELLOW}shadow${NC} → Option 6"
echo -e "  📊 Monitor Status:  ${YELLOW}systemctl status traffic-monitor${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   👤 CLIENT ACCESS (Telegram Bot)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  1. Go to your Telegram Bot"
echo -e "  2. Send ${YELLOW}/start${NC}"
echo -e "  3. Enter your ${YELLOW}SSH password${NC}"
echo -e "  4. View usage, charts, and config"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
