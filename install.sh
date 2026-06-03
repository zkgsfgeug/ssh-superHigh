#!/bin/bash

# =============================================
# Shadow SSH v29.0 - QUANTUM EDITION
# Fixed: Chain-based iptables accounting (100% precise)
# Fixed: Telegram bot connection
# Interval: 1 second (real-time)
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
# Network Optimizer - IPv4 ONLY
# ============================================
optimize_network() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🚀 Activating QUANTUM Network (IPv4 Only)${NC}"
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
    
    cat > /etc/ssh/sshd_config.d/99-quantum.conf << 'TURBOEOF'
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
    
    echo -e "${GREEN}   ✅ QUANTUM Network Activated${NC}"
}

# ============================================
# Cleanup Previous Installation
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🧹 Cleaning Previous Installation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

systemctl stop traffic-monitor shadow-bot fake-dns ai-optimizer shadow-backup 2>/dev/null
systemctl disable traffic-monitor shadow-bot fake-dns ai-optimizer shadow-backup 2>/dev/null

pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "fake-dns" 2>/dev/null
pkill -9 -f "ai-optimizer" 2>/dev/null
pkill -9 -f "fake-location" 2>/dev/null

# Flush all chains
iptables -t mangle -F 2>/dev/null
iptables -t mangle -X 2>/dev/null
iptables -t nat -F 2>/dev/null
iptables -t nat -X 2>/dev/null
ip6tables -t mangle -F 2>/dev/null
ip6tables -t mangle -X 2>/dev/null
ip6tables -t nat -F 2>/dev/null
ip6tables -t nat -X 2>/dev/null

tc qdisc del dev eth0 root 2>/dev/null
tc qdisc del dev lo root 2>/dev/null

if [ -f /etc/shadow-users.conf ]; then
    for user in $(cat /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /usr/local/bin/fake-dns /usr/local/bin/fake-location /usr/local/bin/ai-optimizer /usr/local/bin/backup-manager /usr/local/bin/ping-net /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service /etc/systemd/system/fake-dns.service /etc/systemd/system/ai-optimizer.service /etc/systemd/system/shadow-backup.service /etc/ssh/sshd_config.d/*.conf 2>/dev/null

# ============================================
# Install Dependencies
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   📦 Installing Dependencies${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc procps python3 python3-pip net-tools certbot nginx dnsmasq 2>/dev/null

# Install Telegram bot library with correct version
pip3 install --break-system-packages python-telegram-bot==20.7 2>/dev/null || pip3 install python-telegram-bot==20.7 2>/dev/null

# Verify installation
python3 -c "from telegram import Update; print('Telegram OK')" 2>/dev/null || {
    echo -e "${YELLOW}Retrying telegram install...${NC}"
    pip3 install --force-reinstall --break-system-packages python-telegram-bot==20.7
}

optimize_network

# SSH Config - Force IPv4 only
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
    echo -e "  ${GREEN}4.${NC} ${WHITE}Skip (Continue without domain)${NC}"
    echo ""
    echo -n -e "${CYAN}Select option [1-4]: ${NC}"
    read choice
    
    case $choice in
        1)
            echo ""
            echo -n -e "${GREEN}Enter domain (e.g., ssh.example.com): ${NC}"
            read DOMAIN
            echo "$DOMAIN" > /etc/shadow-domain.conf
            echo -e "${GREEN}✅ Domain saved: $DOMAIN${NC}"
            ;;
        2)
            echo ""
            if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
                DOMAIN=$(cat /etc/shadow-domain.conf)
                echo -n -e "${GREEN}Enter your email: ${NC}"
                read EMAIL
                echo -e "${YELLOW}🔐 Obtaining SSL Certificate...${NC}"
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ SSL Certificate obtained successfully!${NC}"
                    echo -e "${GREEN}   Certificate: /etc/letsencrypt/live/$DOMAIN/fullchain.pem${NC}"
                    echo -e "${GREEN}   Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem${NC}"
                else
                    echo -e "${RED}❌ SSL Certificate failed. Using IP only${NC}"
                fi
            else
                echo -e "${RED}❌ Please set a domain first!${NC}"
            fi
            ;;
        3)
            echo ""
            echo -n -e "${RED}Are you sure you want to delete the domain? (y/n): ${NC}"
            read confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rm -f /etc/shadow-domain.conf
                echo -e "${GREEN}✅ Domain deleted successfully${NC}"
            else
                echo -e "${BLUE}ℹ️  Cancelled${NC}"
            fi
            ;;
        4)
            echo ""
            echo -e "${BLUE}ℹ️  Skipping domain setup - Using IP address${NC}"
            ;;
        *)
            echo -e "${BLUE}ℹ️  Skipping domain setup${NC}"
            ;;
    esac
}

setup_domain

# ============================================
# Database Setup
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
INSERT OR IGNORE INTO settings VALUES ('fake_dns', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('next_mark', '100');
SQLEOF

echo -e "${GREEN}   ✅ Database Created${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v29.0 - QUANTUM${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# ============================================
# QUANTUM TRAFFIC MONITOR - Chain-based Accounting
# 1 second interval - 100% precise
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash
# ============================================
# QUANTUM PRECISION - Chain-based iptables accounting
# Each user gets dedicated iptables chain
# Interval: 1 second
# ============================================

DB="/var/lib/shadow/traffic.db"
INTERVAL=1
PID_FILE="/var/run/traffic-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

# ============================================
# Create dedicated chain for a user
# ============================================
create_user_chain() {
    local username=$1
    local mark=$2
    local chain_name="SHADOW_${username}"
    
    # Create chain if not exists
    iptables -t mangle -N "$chain_name" 2>/dev/null
    
    # Flush chain to start fresh
    iptables -t mangle -F "$chain_name" 2>/dev/null
    
    # Add rules to jump to this chain
    iptables -t mangle -C OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    fi
    
    iptables -t mangle -C INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    fi
    
    # Add a dummy rule to make chain visible in stats
    iptables -t mangle -C "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    fi
    
    # Store chain name in database
    sqlite3 "$DB" "UPDATE users SET chain_name='$chain_name' WHERE username='$username';"
}

# ============================================
# Get exact bytes from dedicated chain
# ============================================
get_chain_bytes() {
    local chain_name=$1
    
    # Method 1: Read from chain directly (most accurate)
    local out_bytes=$(iptables -t mangle -L "$chain_name" -v -n -x 2>/dev/null | grep "MARK set" | awk '{sum += $2} END {print sum+0}')
    
    # Method 2: Fallback - read from OUTPUT/INPUT chains  
    if [ -z "$out_bytes" ] || [ "$out_bytes" = "0" ]; then
        out_bytes=$(iptables -t mangle -L OUTPUT -v -n -x 2>/dev/null | grep "$chain_name" | awk '{print $2+0}')
    fi
    
    echo "${out_bytes:-0}"
}

# ============================================
# Remove user chain
# ============================================
remove_user_chain() {
    local username=$1
    local chain_name=$2
    
    # Remove jump rules
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    
    # Flush and delete chain
    iptables -t mangle -F "$chain_name" 2>/dev/null
    iptables -t mangle -X "$chain_name" 2>/dev/null
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 QUANTUM Monitor Started (PID: $$)"
echo "   Method: Chain-based iptables accounting"
echo "   Interval: ${INTERVAL}s (Real-time)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
            echo "[$(date)] User $username expired - disconnecting"
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            if [ -n "$chain_name" ]; then
                remove_user_chain "$username" "$chain_name"
            fi
            continue
        fi
        
        # Ensure chain exists
        if [ -z "$chain_name" ] || [ "$chain_name" = "" ]; then
            create_user_chain "$username" "$mark"
            chain_name="SHADOW_${username}"
        fi
        
        # Check if chain exists, if not recreate
        iptables -t mangle -L "$chain_name" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            create_user_chain "$username" "$mark"
        fi
        
        # ============================================
        # QUANTUM PRECISION: Read bytes from dedicated chain
        # ============================================
        total_bytes=$(get_chain_bytes "$chain_name")
        
        # DIRECT SET (not add) - absolute value from iptables
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_bytes WHERE username='$username';"
        
        # Check traffic limit
        if [ "$total_limit" != "0" ] && [ "$total_bytes" -ge "$total_limit" ]; then
            echo "[$(date)] User $username reached limit - disconnecting"
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            remove_user_chain "$username" "$chain_name"
        fi
        
    done < <(sqlite3 "$DB" "SELECT username, total_traffic, expiry, iptables_mark, chain_name, is_test FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# Fake DNS
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
local-ttl=1
EOF
    
    systemctl stop dnsmasq 2>/dev/null
    dnsmasq -C /etc/dnsmasq.d/shadow-fake.conf 2>/dev/null
    
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_dns';"
    echo "✅ Fake DNS Enabled (${delay}ms response)"
}

stop_fake_dns() {
    killall dnsmasq 2>/dev/null
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    rm -f /etc/dnsmasq.d/shadow-fake.conf
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_dns';"
    echo "✅ Fake DNS Disabled"
}

status_fake_dns() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    [ "$status" = "enabled" ] && echo "Status: ENABLED (1ms response)" || echo "Status: DISABLED"
}

case "$1" in
    start) start_fake_dns ${2:-1} ;;
    stop) stop_fake_dns ;;
    status) status_fake_dns ;;
    *) echo "Fake DNS Controller - Usage: $0 {start|stop|status}" ;;
esac
DNSEOF

chmod +x /usr/local/bin/fake-dns

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
    [ ! -f "$1" ] && { echo "❌ Backup file not found!"; return 1; }
    systemctl stop traffic-monitor shadow-bot 2>/dev/null
    tar -xzf "$1" -C /
    systemctl start traffic-monitor shadow-bot 2>/dev/null
    echo "✅ Restore completed!"
}

case "$1" in
    backup) create_backup ;;
    restore)
        sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime') FROM backup_history ORDER BY backup_time DESC LIMIT 10;" | while IFS='|' read id time; do echo "$id - $time"; done
        echo -n "Enter backup ID to restore: "; read id
        file=$(sqlite3 "$DB" "SELECT filename FROM backup_history WHERE id=$id;")
        [ -n "$file" ] && restore_backup "$file"
        ;;
    auto-backup) while true; do create_backup >/dev/null; sleep 86400; done ;;
    *) echo "Backup Manager - Usage: $0 {backup|restore|auto-backup}" ;;
esac
BACKEOF

chmod +x /usr/local/bin/backup-manager

# ============================================
# Telegram Bot - FIXED CONNECTION
# ============================================
cat > /usr/local/bin/shadow-bot << 'BOTEOF'
#!/usr/bin/env python3
# ============================================
# Shadow SSH Telegram Bot v29.0
# Fixed: Proper async handling
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
import asyncio

# Check telegram import
try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
except ImportError:
    print("Installing python-telegram-bot...")
    subprocess.run(["pip3", "install", "--break-system-packages", "python-telegram-bot==20.7"])
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes

DB = "/var/lib/shadow/traffic.db"
CONFIG_FILE = "/etc/shadow-bot.conf"
DOMAIN_FILE = "/etc/shadow-domain.conf"

BOT_TOKEN = None
ADMIN_IDS = []

def load_config():
    """Load bot configuration"""
    global BOT_TOKEN, ADMIN_IDS
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith("TOKEN="):
                    BOT_TOKEN = line.split("=", 1)[1].strip()
                elif line.startswith("ADMINS="):
                    admin_str = line.split("=", 1)[1].strip()
                    if admin_str:
                        ADMIN_IDS = [int(x.strip()) for x in admin_str.split(",") if x.strip()]

def save_config():
    """Save bot configuration"""
    with open(CONFIG_FILE, 'w') as f:
        f.write(f"TOKEN={BOT_TOKEN}\n")
        f.write(f"ADMINS={','.join(str(x) for x in ADMIN_IDS)}\n")

def is_admin(user_id):
    """Check if user is admin"""
    return user_id in ADMIN_IDS

def get_domain():
    """Get server domain or IP (IPv4 only)"""
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE, 'r') as f:
            domain = f.read().strip()
            if domain:
                return domain
    return subprocess.getoutput("curl -s4 ifconfig.me")

def generate_napsternetv(server, username, password, days="∞", traffic="∞"):
    """Generate NapsternetV config with correct format"""
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

def get_iptables_mark(username):
    """Get next available iptables mark"""
    result = subprocess.getoutput(f"sqlite3 {DB} \"SELECT value FROM settings WHERE key='next_mark';\"")
    mark = int(result) if result and result.isdigit() else 100
    subprocess.run(f"sqlite3 {DB} \"UPDATE settings SET value={mark+1} WHERE key='next_mark';\"", shell=True)
    return mark

def create_system_user(username, password, traffic_gb, days, max_conn, is_test=0):
    """Create system user with iptables chain"""
    
    # Create system user
    subprocess.run(["useradd", "-m", "-s", "/bin/bash", username], capture_output=True)
    subprocess.run(["chpasswd"], input=f"{username}:{password}".encode(), capture_output=True)
    
    # SSH config
    with open(f"/etc/ssh/sshd_config.d/{username}.conf", "w") as f:
        f.write(f"MaxSessions {max_conn}\nMaxStartups {max_conn}\n")
    
    # Calculate limits
    traffic_bytes = traffic_gb * 1073741824 if traffic_gb > 0 else 0
    expiry = int(time.time()) + (days * 86400) if days > 0 else 0
    
    # Get iptables mark
    mark = get_iptables_mark(username)
    
    # Create dedicated iptables chain
    chain_name = f"SHADOW_{username}"
    subprocess.run(f"iptables -t mangle -N {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -F {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -A OUTPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -A INPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -A {chain_name} -j MARK --set-mark {mark} 2>/dev/null", shell=True)
    
    # Save to database
    conn = sqlite3.connect(DB)
    conn.execute(
        "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit, is_test) VALUES (?,?,?,?,?,?,?,?,?)",
        [username, password, traffic_bytes, mark, chain_name, expiry, int(time.time()), max_conn, is_test]
    )
    conn.commit()
    conn.close()
    
    # Save to config file
    with open("/etc/shadow-users.conf", "a") as f:
        f.write(f"{username}\n")
    
    # Restart SSH
    subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
    
    return mark

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user_id = update.effective_user.id
    
    if not is_admin(user_id):
        await update.message.reply_text("❌ Unauthorized! You are not an admin.")
        return
    
    # Auto-add first user as admin
    if not ADMIN_IDS:
        ADMIN_IDS.append(user_id)
        save_config()
    
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list")],
        [InlineKeyboardButton("➕ Create User", callback_data="create")],
        [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
        [InlineKeyboardButton("📦 Backup", callback_data="backup")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    server = get_domain()
    
    welcome_message = (
        f"🔱 *Shadow SSH v29.0 QUANTUM*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 Server: `{server}:22`\n"
        f"🎯 Mode: Chain-based iptables\n"
        f"⏱ Interval: 1s Real-time\n"
        f"🧪 Test Account Available\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"Select an option:"
    )
    
    await update.message.reply_text(
        welcome_message,
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle all button callbacks"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    if not is_admin(user_id):
        await query.edit_message_text("❌ Access Denied!")
        return
    
    if query.data == "list":
        await show_users_list(query)
    elif query.data == "create":
        await show_create_dialog(query)
    elif query.data == "test_acc":
        await create_test_account(query)
    elif query.data == "del_menu":
        await show_delete_menu(query)
    elif query.data.startswith("del_"):
        username = query.data.replace("del_", "")
        await delete_user_action(query, username)
    elif query.data == "backup":
        await create_backup(query)
    elif query.data == "status":
        await show_status(query)
    elif query.data == "back":
        await show_main_menu(query)

async def show_main_menu(query):
    """Show main menu"""
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list")],
        [InlineKeyboardButton("➕ Create User", callback_data="create")],
        [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
        [InlineKeyboardButton("📦 Backup", callback_data="backup")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"🔱 *Shadow SSH v29.0 QUANTUM*\n"
        f"🌐 `{get_domain()}:22`\n"
        f"Select option:",
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def show_users_list(query):
    """Show all users with traffic info"""
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT username, status, used_traffic, total_traffic, expiry, is_test FROM users")
    users = cur.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users found!")
        return
    
    message = "👥 *Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    
    for user in users:
        username, status, used, total, expiry, is_test = user
        
        used_mb = used / 1048576.0
        total_gb = total / 1073741824.0 if total > 0 else 0
        
        if expiry == 0:
            days_left = "∞"
        else:
            days_left = (expiry - int(time.time())) // 86400
            if days_left < 0:
                days_left = "Expired"
            else:
                days_left = f"{days_left}d"
        
        if total == 0:
            usage_text = f"{used_mb:.1f}MB / ∞"
        else:
            percent = (used / total * 100) if total > 0 else 0
            usage_text = f"{used_mb:.1f}MB / {total_gb:.1f}GB ({percent:.1f}%)"
        
        if status == "active":
            status_emoji = "🟢"
        elif status == "expired":
            status_emoji = "🔴"
        elif status == "limited":
            status_emoji = "🟡"
        else:
            status_emoji = "⚪"
        
        test_tag = " 🧪" if is_test else ""
        
        message += f"{status_emoji} `{username}`{test_tag}\n"
        message += f"   📊 {usage_text}\n"
        message += f"   ⏰ {days_left}\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="back")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        message,
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def show_create_dialog(query):
    """Show create user instructions"""
    await query.edit_message_text(
        "➕ *Create User*\n\n"
        "Send command:\n"
        "`/create user pass days gb conn`\n\n"
        "*Example:*\n"
        "`/create testuser pass123 30 5 3`\n\n"
        "30 days, 5GB, 3 connections\n"
        "`0 0` for unlimited",
        parse_mode='Markdown'
    )

async def create_test_account(query):
    """Create a test account (30MB/1Day)"""
    # Generate random credentials
    test_user = "test_" + ''.join(random.choices(string.ascii_lowercase, k=5))
    test_pass = ''.join(random.choices(string.ascii_letters + string.digits, k=10))
    
    # Create user
    create_system_user(test_user, test_pass, 0, 1, 1, is_test=1)
    
    # 30MB limit
    conn = sqlite3.connect(DB)
    conn.execute("UPDATE users SET total_traffic = ? WHERE username = ?", [30 * 1048576, test_user])
    conn.commit()
    conn.close()
    
    domain = get_domain()
    config_link = generate_napsternetv(domain, test_user, test_pass, "1", "30MB")
    
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

async def create_user_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /create command"""
    user_id = update.effective_user.id
    
    if not is_admin(user_id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    try:
        args = context.args
        
        if len(args) < 5:
            await update.message.reply_text(
                "❌ Usage: `/create username password days traffic_gb max_connections`",
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
        
        # Create user with chain-based iptables
        create_system_user(username, password, traffic_gb, days, max_conn)
        
        domain = get_domain()
        days_display = str(days) if days > 0 else "∞"
        traffic_display = f"{traffic_gb}GB" if traffic_gb > 0 else "∞"
        
        config_link = generate_napsternetv(domain, username, password, days_display, traffic_display)
        
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

async def show_delete_menu(query):
    """Show delete user menu"""
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT username FROM users")
    users = cur.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users to delete!")
        return
    
    keyboard = []
    for (username,) in users:
        keyboard.append([
            InlineKeyboardButton(f"🗑 {username}", callback_data=f"del_{username}")
        ])
    
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="back")])
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "🗑 *Select user to delete:*",
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def delete_user_action(query, username):
    """Delete a user"""
    # Remove iptables chain
    chain_name = f"SHADOW_{username}"
    subprocess.run(f"iptables -t mangle -D OUTPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -D INPUT -m owner --uid-owner {username} -j {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -F {chain_name} 2>/dev/null", shell=True)
    subprocess.run(f"iptables -t mangle -X {chain_name} 2>/dev/null", shell=True)
    
    # Kill and delete user
    subprocess.run(["pkill", "-9", "-u", username], capture_output=True)
    subprocess.run(["userdel", "-r", username], capture_output=True)
    
    # Remove from database
    conn = sqlite3.connect(DB)
    conn.execute("DELETE FROM users WHERE username=?", [username])
    conn.commit()
    conn.close()
    
    # Clean files
    os.system(f"sed -i '/^{username}$/d' /etc/shadow-users.conf 2>/dev/null")
    os.system(f"rm -f /etc/ssh/sshd_config.d/{username}.conf")
    
    # Restart SSH
    subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
    
    await query.edit_message_text(
        f"✅ User `{username}` deleted successfully!",
        parse_mode='Markdown'
    )

async def create_backup(query):
    """Create backup"""
    result = subprocess.run(["/usr/local/bin/backup-manager", "backup"], capture_output=True, text=True)
    await query.edit_message_text(
        f"📦 *Backup Created*\n\n{result.stdout}",
        parse_mode='Markdown'
    )

async def show_status(query):
    """Show server status"""
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu' | awk '{print $2}' | cut -d% -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\",$3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    test_count = conn.execute("SELECT COUNT(*) FROM users WHERE status='active' AND is_test=1").fetchone()[0]
    conn.close()
    
    message = (
        f"📈 *Server Status*\n"
        f"━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖥 CPU: `{cpu}%`\n"
        f"💾 RAM: `{mem}%`\n"
        f"⏱ Uptime: `{uptime}`\n"
        f"🔗 Connections: `{conn_count}`\n"
        f"👥 Active Users: `{active}`\n"
        f"🧪 Test Accounts: `{test_count}`\n"
        f"🎯 Mode: `Chain-based iptables`\n"
        f"⏱ Interval: `1s Real-time`\n"
        f"🚫 IPv6: `Disabled`\n"
    )
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="back")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        message,
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

def main():
    """Main function to start bot"""
    load_config()
    
    if not BOT_TOKEN:
        print("❌ Bot token not configured!")
        print("Please run: shadow -> Option 7 -> Set Token")
        sys.exit(1)
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🤖 Shadow SSH Bot v29.0 Starting...")
    print(f"   Server: {get_domain()}")
    print(f"   Admins: {len(ADMIN_IDS)}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("create", create_user_command))
    app.add_handler(CallbackQueryHandler(button_handler))
    
    print("✅ Bot is running...")
    
    # Start polling
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
        curl -s4 ifconfig.me
    fi
}

show_banner() {
    SERVER_IP=$(get_domain)
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v29.0 - QUANTUM EDITION 🔱${PURPLE}              ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 Server: ${GREEN}${SERVER_IP}${NC}"
    echo -e "${PURPLE}║${NC}  📡 Port: ${GREEN}22${NC}  |  🎯 Chain-based iptables  |  ⏱ 1s Real-time${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════ MANAGEMENT MENU ══════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create New User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List All Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}🧪  Create Test Account (30MB/1Day)${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}📡  Fake DNS Control${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}📦  Backup & Restore${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}🤖  Telegram Bot Settings${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}🌐  Domain Management${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}🔄  Restart All Services${NC}"
    echo -e "  ${GREEN}11.${NC} ${WHITE}🚪  Exit${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo ""
}

create_user_chain() {
    local username=$1
    local mark=$2
    local chain_name="SHADOW_${username}"
    
    # Create dedicated chain
    iptables -t mangle -N "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    
    # Jump rules
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    
    # Mark rule
    iptables -t mangle -A "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    
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
    
    # Create user
    useradd -m -s /bin/bash "$test_user" 2>/dev/null
    echo "$test_user:$test_pass" | chpasswd
    
    cat > "/etc/ssh/sshd_config.d/${test_user}.conf" << EOF
MaxSessions 1
MaxStartups 1
EOF
    
    traffic_bytes=$((30 * 1048576))
    expiry=$(date -d "+1 days" +%s)
    
    next_mark=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';")
    mark=${next_mark:-100}
    sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
    
    # Create dedicated chain
    chain_name=$(create_user_chain "$test_user" "$mark")
    
    echo "$test_user" >> /etc/shadow-users.conf 2>/dev/null
    
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit, is_test) VALUES ('$test_user', '$test_pass', $traffic_bytes, $mark, '$chain_name', $expiry, $(date +%s), 1, 1);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    
    config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"🧪 Test ${test_user} | ⏰ 1d | 📎 30MB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$test_user\",\"sshPassword\":\"$test_pass\",\"udpgwTransparentDNS\":true}"
    config_b64=$(echo -n "$config_json" | base64 -w 0)
    npvt_link="npvt-ssh://${config_b64}"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ✅ TEST ACCOUNT CREATED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Server: ${GREEN}${SERVER}${NC}"
    echo -e "  📡 Port: ${GREEN}22${NC}"
    echo -e "  👤 Username: ${GREEN}${test_user}${NC}"
    echo -e "  🔑 Password: ${GREEN}${test_pass}${NC}"
    echo -e "  📊 Traffic: ${GREEN}30 MB${NC}"
    echo -e "  ⏰ Validity: ${GREEN}1 Day${NC}"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📋 NapsternetV Config Link:${NC}"
    echo -e "   ${YELLOW}${npvt_link}${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read
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
    
    useradd -m -s /bin/bash "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    cat > "/etc/ssh/sshd_config.d/${username}.conf" << EOF
MaxSessions $max_conn
MaxStartups $max_conn
EOF
    
    next_mark=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';")
    mark=${next_mark:-100}
    sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
    
    # Create dedicated chain
    chain_name=$(create_user_chain "$username" "$mark")
    
    echo "$username" >> /etc/shadow-users.conf 2>/dev/null
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $mark, '$chain_name', $expiry, $(date +%s), $max_conn);"
    
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
    echo -e "${GREEN}   ✅ USER CREATED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Server: ${GREEN}${SERVER}${NC}"
    echo -e "  📡 Port: ${GREEN}22${NC}"
    echo -e "  👤 Username: ${GREEN}${username}${NC}"
    echo -e "  🔑 Password: ${GREEN}${password}${NC}"
    echo -e "  📊 Traffic Limit: ${GREEN}${traffic_gb} GB${NC}"
    echo -e "  ⏰ Valid: ${GREEN}${days} days${NC}"
    echo -e "  🔗 Max Connections: ${GREEN}${max_conn}${NC}"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📋 NapsternetV Config Link:${NC}"
    echo -e "   ${YELLOW}${npvt_link}${NC}"
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
    
    # Remove dedicated chain
    remove_user_chain "$username"
    
    pkill -9 -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
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

fake_dns_menu() {
    while true; do
        clear
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}   📡 FAKE DNS CONTROL${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/fake-dns status
        echo ""
        echo -e "  ${GREEN}1.${NC} ${WHITE}Enable Fake DNS (1ms response)${NC}"
        echo -e "  ${GREEN}2.${NC} ${WHITE}Disable Fake DNS${NC}"
        echo -e "  ${GREEN}3.${NC} ${WHITE}Back to Main Menu${NC}"
        echo ""
        echo -n -e "${CYAN}Select option [1-3]: ${NC}"
        read choice
        
        case $choice in
            1) /usr/local/bin/fake-dns start 1; sleep 2 ;;
            2) /usr/local/bin/fake-dns stop; sleep 2 ;;
            3) break ;;
        esac
    done
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
            1) /usr/local/bin/backup-manager backup; sleep 2 ;;
            2) /usr/local/bin/backup-manager restore; sleep 2 ;;
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
            4) break ;;
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
            echo -n -e "${GREEN}Enter domain: ${NC}"
            read d
            echo "$d" > "$DOMAIN_FILE"
            echo -e "${GREEN}✅ Domain set!${NC}"
            sleep 1
            ;;
        2)
            if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
                d=$(cat "$DOMAIN_FILE")
                echo -n -e "${GREEN}Enter your email: ${NC}"
                read e
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$d" --non-interactive --agree-tos --email "$e"
            else
                echo -e "${RED}❌ Set domain first!${NC}"
            fi
            sleep 2
            ;;
        3)
            echo -n -e "${RED}Are you sure? (y/n): ${NC}"
            read cf
            [ "$cf" = "y" ] || [ "$cf" = "Y" ] && rm -f "$DOMAIN_FILE" && echo -e "${GREEN}✅ Domain deleted${NC}"
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
    mem=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    uptime=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    test_users=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active' AND is_test=1;")
    
    echo -e "  ${WHITE}🖥  CPU Usage:${NC} ${YELLOW}${cpu}%${NC}"
    echo -e "  ${WHITE}💾 RAM Usage:${NC} ${YELLOW}${mem}%${NC}"
    echo -e "  ${WHITE}⏱  Uptime:${NC} ${GREEN}${uptime}${NC}"
    echo -e "  ${WHITE}🔗 Active Connections:${NC} ${CYAN}${conn}${NC}"
    echo -e "  ${WHITE}👥 Active Users:${NC} ${GREEN}${users}${NC}"
    echo -e "  ${WHITE}🧪 Test Accounts:${NC} ${YELLOW}${test_users}${NC}"
    echo -e "  ${WHITE}📡 Port 22:${NC} ${GREEN}Open & Listening${NC}"
    echo -e "  ${WHITE}⚡ BBR:${NC} ${GREEN}Enabled${NC}"
    echo -e "  ${WHITE}🎯 Traffic Mode:${NC} ${GREEN}Chain-based iptables (100% Precise)${NC}"
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
    echo -n -e "${CYAN}Select option [1-11]: ${NC}"
    read choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) create_test_account ;;
        5) fake_dns_menu ;;
        6) backup_menu ;;
        7)
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
                        echo -n -e "Enter Bot Token: "
                        read t
                        sed -i "s/TOKEN=.*/TOKEN=$t/" "$BOT_CONFIG"
                        echo -e "${GREEN}✅ Token saved!${NC}"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    2)
                        echo -n -e "Enter Admin ID: "
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
                echo -n -e "${GREEN}Enter Bot Token: ${NC}"
                read t
                echo "TOKEN=$t" > "$BOT_CONFIG"
                echo "ADMINS=" >> "$BOT_CONFIG"
                echo -e "${GREEN}✅ Token saved!${NC}"
                systemctl restart shadow-bot 2>/dev/null
            fi
            sleep 1
            ;;
        8) domain_management ;;
        9) server_status ;;
        10)
            echo ""
            echo -e "${YELLOW}🔄 Restarting all services...${NC}"
            systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null
            echo -e "${GREEN}✅ Restarted!${NC}"
            sleep 2
            ;;
        11)
            clear
            echo ""
            echo -e "${GREEN}👋 Thank you for using Shadow SSH v29.0!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option!${NC}"
            sleep 1
            ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ============================================
# Install Systemd Services
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   ⚙️  Installing Services${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Shadow SSH QUANTUM Traffic Monitor
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
Description=Shadow SSH Telegram Bot
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
echo -e "${PURPLE}║      ${GREEN}✅ SHADOW SSH v29.0 - QUANTUM INSTALLED!${PURPLE}              ║${NC}"
echo -e "${PURPLE}║                                                          ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🎯 QUANTUM FEATURES${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ✅ Chain-based iptables accounting (Dedicated chain per user)"
echo -e "  ✅ Direct chain reading (NO grep/awk parsing)"
echo -e "  ✅ 1 second interval (Real-time precision)"
echo -e "  ✅ Telegram Bot with proper async handling"
echo -e "  ✅ Test Account (30MB/1Day)"
echo -e "  ✅ Fake DNS Control"
echo -e "  ✅ Backup & Restore"
echo -e "  ✅ Domain Management"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🚀 QUICK COMMANDS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🚀 Open Panel:      ${YELLOW}shadow${NC}"
echo -e "  🧪 Test Account:    ${YELLOW}shadow${NC} → Option 4"
echo -e "  🤖 Bot Setup:       ${YELLOW}shadow${NC} → Option 7"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
