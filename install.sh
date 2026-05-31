#!/bin/bash

# =============================================
# Shadow SSH v27.1 - IPv4 ONLY PRECISION
# Fixed: Only count IPv4 traffic, ignore IPv6
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
    echo -e "${YELLOW}🚀 Activating PRECISION Network (IPv4 Only)${NC}"
    
    # Disable IPv6 completely
    cat >> /etc/sysctl.conf << 'EOF'
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p >/dev/null 2>&1
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        # Disable IPv6 on interface
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
    
    # SSH - Listen on IPv4 only
    cat > /etc/ssh/sshd_config.d/99-precision.conf << 'TURBOEOF'
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
    
    echo -e "${GREEN}✅ Network Activated (IPv4 Only)${NC}"
}

# ============================================
# Cleanup
# ============================================
echo -e "${YELLOW}🧹 Cleaning Previous Installation${NC}"

systemctl stop traffic-monitor shadow-bot fake-dns ai-optimizer shadow-backup 2>/dev/null
systemctl disable traffic-monitor shadow-bot fake-dns ai-optimizer shadow-backup 2>/dev/null

pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "fake-dns" 2>/dev/null
pkill -9 -f "ai-optimizer" 2>/dev/null
pkill -9 -f "fake-location" 2>/dev/null

iptables -t mangle -F 2>/dev/null
iptables -t nat -F 2>/dev/null
ip6tables -t mangle -F 2>/dev/null
ip6tables -t nat -F 2>/dev/null
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
# Install
# ============================================
echo -e "${YELLOW}📦 Installing Dependencies${NC}"
apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc procps python3 python3-pip net-tools certbot nginx dnsmasq 2>/dev/null
pip3 install --break-system-packages python-telegram-bot==20.7 2>/dev/null

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

# Domain
setup_domain() {
    echo -e "${PURPLE}🌐 Domain Configuration${NC}"
    if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
        echo -e "Current: ${GREEN}$(cat /etc/shadow-domain.conf)${NC}"
    else
        echo -e "Current: ${YELLOW}No domain${NC}"
    fi
    echo ""
    echo -e "1. Add/Change  2. Get SSL  3. Delete  4. Skip"
    echo -n -e "Select [1-4]: "
    read choice
    case $choice in
        1) echo -n -e "Domain: "; read DOMAIN; echo "$DOMAIN" > /etc/shadow-domain.conf; echo -e "${GREEN}✅ Saved${NC}" ;;
        2)
            if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
                DOMAIN=$(cat /etc/shadow-domain.conf)
                echo -n -e "Email: "; read EMAIL
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
                [ $? -eq 0 ] && echo -e "${GREEN}✅ SSL obtained${NC}" || echo -e "${RED}❌ Failed${NC}"
            fi
            ;;
        3) echo -n -e "${RED}Delete? (y/n): ${NC}"; read confirm; [ "$confirm" = "y" ] && rm -f /etc/shadow-domain.conf && echo -e "${GREEN}✅ Deleted${NC}" ;;
        4) echo -e "${BLUE}ℹ️ Skipping${NC}" ;;
    esac
}
setup_domain

# Database
mkdir -p /var/lib/shadow /var/backups/shadow
sqlite3 /var/lib/shadow/traffic.db << 'SQLEOF'
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT,
    total_traffic INTEGER DEFAULT 0,
    used_traffic INTEGER DEFAULT 0,
    iptables_mark INTEGER UNIQUE,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active',
    user_limit INTEGER DEFAULT 1
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
INSERT OR IGNORE INTO settings VALUES ('next_mark', '100');
SQLEOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v27.1 - IPv4 ONLY${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ============================================
# TRAFFIC MONITOR - iptables IPv4 ONLY
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash
# ============================================
# TRUE PRECISION - IPv4 ONLY
# iptables byte counting (iptables, NOT ip6tables)
# ============================================

DB="/var/lib/shadow/traffic.db"
INTERVAL=5
PID_FILE="/var/run/traffic-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

# Initialize iptables rules for all users (IPv4 only)
init_user_rules() {
    local username=$1
    local mark=$2
    
    # IPv4 OUTPUT
    iptables -t mangle -C OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    fi
    
    # IPv4 INPUT
    iptables -t mangle -C INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    fi
}

get_iptables_bytes() {
    local mark=$1
    
    # ONLY read from iptables (IPv4) - NEVER from ip6tables
    local out_bytes=$(iptables -t mangle -L OUTPUT -v -n -x 2>/dev/null | grep "MARK set 0x$(printf '%x' $mark)" | awk '{print $2}')
    local in_bytes=$(iptables -t mangle -L INPUT -v -n -x 2>/dev/null | grep "MARK set 0x$(printf '%x' $mark)" | awk '{print $2}')
    
    echo "${out_bytes:-0} ${in_bytes:-0}"
}

echo "🎯 TRUE PRECISION Monitor (IPv4 Only) Started - PID: $$"

# Initialize all active users
while IFS='|' read -r username mark; do
    [ -z "$username" ] && continue
    init_user_rules "$username" "$mark"
done < <(sqlite3 "$DB" "SELECT username, iptables_mark FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")

# Main loop
while true; do
    current_time=$(date +%s)
    
    while IFS='|' read -r username total_limit expiry mark; do
        [ -z "$username" ] && continue
        
        # Check expiry
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
            iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
            continue
        fi
        
        # Ensure rules exist
        init_user_rules "$username" "$mark"
        
        # Read IPv4 ONLY counters
        read -r out_bytes in_bytes <<< $(get_iptables_bytes "$mark")
        
        # Total IPv4 traffic in bytes
        total_bytes=$((out_bytes + in_bytes))
        
        # DIRECTLY SET used_traffic (IPv4 only)
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_bytes WHERE username='$username';"
        
        # Check limit
        if [ "$total_limit" != "0" ] && [ "$total_bytes" -ge "$total_limit" ]; then
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
            iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
        fi
        
    done < <(sqlite3 "$DB" "SELECT username, total_traffic, expiry, iptables_mark FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# Fake Location
# ============================================
cat > /usr/local/bin/fake-location << 'LOCEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

COUNTRY_CODES=("US" "GB" "DE" "NL" "JP" "CA")
COUNTRY_NAMES=("United States" "United Kingdom" "Germany" "Netherlands" "Japan" "Canada")
COUNTRY_IPS=("8.8.8.8" "1.1.1.1" "9.9.9.9" "1.0.0.1" "1.1.1.2" "8.8.4.4")

start_fake_location() {
    local country_code=$1
    local index=0
    for i in "${!COUNTRY_CODES[@]}"; do
        [[ "${COUNTRY_CODES[$i]}" = "${country_code}" ]] && { index=$i; break; }
    done
    local fake_ip="${COUNTRY_IPS[$index]}"
    
    stop_fake_location
    
    cat >> /etc/hosts << EOF
$fake_ip ip-api.com
$fake_ip ipinfo.io
$fake_ip ipapi.co
$fake_ip ifconfig.co
$fake_ip myip.com
$fake_ip ip.sb
$fake_ip whatismyip.com
EOF
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_location';"
    sqlite3 "$DB" "UPDATE settings SET value='$country_code' WHERE key='fake_country';"
    echo "✅ Fake Location: ${COUNTRY_NAMES[$index]}"
}

stop_fake_location() {
    for ip in 8.8.8.8 1.1.1.1 9.9.9.9 1.0.0.1 1.1.1.2 8.8.4.4; do
        sed -i "/$ip/d" /etc/hosts
    done
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_location';"
    echo "✅ Fake Location Disabled"
}

status_fake_location() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    local country=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_country';")
    [ "$status" = "enabled" ] && echo "Status: ENABLED | Country: $country" || echo "Status: DISABLED"
}

case "$1" in
    start) country=${2:-US}; start_fake_location "$country" ;;
    stop) stop_fake_location ;;
    status) status_fake_location ;;
    list) for i in "${!COUNTRY_CODES[@]}"; do echo "  ${COUNTRY_CODES[$i]} - ${COUNTRY_NAMES[$i]}"; done ;;
    *) echo "Usage: $0 {start <code>|stop|status|list}" ;;
esac
LOCEOF

chmod +x /usr/local/bin/fake-location

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
    echo "✅ Fake DNS Enabled (${delay}ms)"
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
    [ "$status" = "enabled" ] && echo "Status: ENABLED" || echo "Status: DISABLED"
}

case "$1" in
    start) start_fake_dns ${2:-1} ;;
    stop) stop_fake_dns ;;
    status) status_fake_dns ;;
    *) echo "Usage: $0 {start|stop|status}" ;;
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
    [ ! -f "$1" ] && { echo "❌ Not found!"; return 1; }
    systemctl stop traffic-monitor shadow-bot 2>/dev/null
    tar -xzf "$1" -C /
    systemctl start traffic-monitor shadow-bot 2>/dev/null
    echo "✅ Restored!"
}

case "$1" in
    backup) create_backup ;;
    restore)
        sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime') FROM backup_history ORDER BY backup_time DESC LIMIT 10;" | while IFS='|' read id time; do echo "$id - $time"; done
        echo -n "Enter ID: "; read id
        file=$(sqlite3 "$DB" "SELECT filename FROM backup_history WHERE id=$id;")
        [ -n "$file" ] && restore_backup "$file"
        ;;
    auto-backup) while true; do create_backup >/dev/null; sleep 86400; done ;;
    *) echo "Usage: $0 {backup|restore|auto-backup}" ;;
esac
BACKEOF

chmod +x /usr/local/bin/backup-manager

# ============================================
# Telegram Bot
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
                if line.startswith("TOKEN="): BOT_TOKEN = line.split("=", 1)[1].strip()
                elif line.startswith("ADMINS="):
                    s = line.split("=", 1)[1].strip()
                    if s: ADMIN_IDS = [int(x.strip()) for x in s.split(",") if x.strip()]

def save_config():
    with open(CONFIG_FILE, "w") as f:
        f.write(f"TOKEN={BOT_TOKEN}\nADMINS={','.join(str(x) for x in ADMIN_IDS)}\n")

def is_admin(uid): return uid in ADMIN_IDS

def get_domain():
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE) as f:
            d = f.read().strip()
            if d: return d
    return subprocess.getoutput("curl -s4 ifconfig.me")

def gen_nap(server, user, pwd, days="∞", gb="∞"):
    remarks = f"📡 {user}"
    if days != "∞": remarks += f" | ⏰ {days}d"
    if gb != "∞": remarks += f" | 📎 {gb}GB"
    c = {"sshConfigType":"SSH-Direct","remarks":remarks,"sshHost":server,"sshPort":22,"sshUsername":user,"sshPassword":pwd,"udpgwTransparentDNS":True}
    return "npvt-ssh://" + base64.b64encode(json.dumps(c).encode()).decode()

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    if not ADMIN_IDS:
        ADMIN_IDS.append(update.effective_user.id)
        save_config()
    
    kb = [[InlineKeyboardButton("👥 Users", callback_data="list")],
          [InlineKeyboardButton("➕ Create", callback_data="create")],
          [InlineKeyboardButton("🗑 Delete", callback_data="del_menu")],
          [InlineKeyboardButton("📦 Backup", callback_data="backup")],
          [InlineKeyboardButton("📈 Status", callback_data="status")]]
    await update.message.reply_text(f"🔱 *Shadow v27.1*\n🌐 `{get_domain()}:22`\n🎯 IPv4 Only", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def btn(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    if not is_admin(q.from_user.id): await q.edit_message_text("❌"); return
    
    if q.data == "list":
        conn = sqlite3.connect(DB)
        cur = conn.cursor()
        cur.execute("SELECT username, status, used_traffic, total_traffic, expiry FROM users")
        users = cur.fetchall()
        conn.close()
        if not users: await q.edit_message_text("📭 No users!"); return
        msg = "👥 *Users*\n\n"
        for u in users:
            name, st, used, total, exp = u
            um = used/1048576
            tg = total/1073741824 if total>0 else 0
            dl = "∞" if exp==0 else str((exp-int(time.time()))//86400)+"d"
            ut = f"{um:.1f}MB / ∞" if total==0 else f"{um:.1f}MB / {tg:.1f}GB"
            em = "🟢" if st=="active" else "🔴"
            msg += f"{em} `{name}`\n   📊 {ut}\n   ⏰ {dl}\n\n"
        await q.edit_message_text(msg, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙", callback_data="back")]]), parse_mode='Markdown')
    
    elif q.data == "create":
        await q.edit_message_text("➕ Send: `/create user pass days gb conn`", parse_mode='Markdown')
    
    elif q.data == "del_menu":
        conn = sqlite3.connect(DB)
        cur = conn.cursor()
        cur.execute("SELECT username FROM users")
        users = cur.fetchall()
        conn.close()
        if not users: await q.edit_message_text("📭"); return
        kb = [[InlineKeyboardButton(f"🗑 {u[0]}", callback_data=f"del_{u[0]}")] for u in users]
        kb.append([InlineKeyboardButton("🔙", callback_data="back")])
        await q.edit_message_text("🗑 *Select:*", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')
    
    elif q.data.startswith("del_"):
        name = q.data[4:]
        subprocess.run(["pkill","-9","-u",name])
        subprocess.run(["userdel","-r",name])
        conn = sqlite3.connect(DB)
        conn.execute("DELETE FROM users WHERE username=?",[name])
        conn.commit()
        conn.close()
        os.system(f"sed -i '/^{name}$/d' /etc/shadow-users.conf 2>/dev/null")
        os.system(f"rm -f /etc/ssh/sshd_config.d/{name}.conf")
        mark=$(sqlite3 "$DB" "SELECT iptables_mark FROM users WHERE username='$name';")
        [ -n "$mark" ] && iptables -t mangle -D OUTPUT -m owner --uid-owner "$name" -j MARK --set-mark "$mark" 2>/dev/null
        [ -n "$mark" ] && iptables -t mangle -D INPUT -m owner --uid-owner "$name" -j MARK --set-mark "$mark" 2>/dev/null
        subprocess.run(["systemctl","restart","sshd"])
        await q.edit_message_text(f"✅ `{name}` deleted!", parse_mode='Markdown')
    
    elif q.data == "backup":
        r = subprocess.run(["/usr/local/bin/backup-manager","backup"], capture_output=True, text=True)
        await q.edit_message_text(f"📦 *Backup*\n{r.stdout}", parse_mode='Markdown')
    
    elif q.data == "status":
        cpu = subprocess.getoutput("top -bn1 | grep 'Cpu' | awk '{print $2}'|cut -d% -f1")
        mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\",$3*100/$2}'")
        up = subprocess.getoutput("uptime -p|sed 's/up //'")
        conn = subprocess.getoutput("ss -tnp|grep ESTAB|wc -l")
        act = sqlite3.connect(DB).execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
        msg = f"📈 *Status*\n🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n⏱ `{up}`\n🔗 `{conn}`\n👥 `{act}`\n🎯 IPv4 Only"
        await q.edit_message_text(msg, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙", callback_data="back")]]), parse_mode='Markdown')
    
    elif q.data == "back":
        kb = [[InlineKeyboardButton("👥 Users", callback_data="list")],
              [InlineKeyboardButton("➕ Create", callback_data="create")],
              [InlineKeyboardButton("🗑 Delete", callback_data="del_menu")],
              [InlineKeyboardButton("📦 Backup", callback_data="backup")],
              [InlineKeyboardButton("📈 Status", callback_data="status")]]
        await q.edit_message_text(f"🔱 *Shadow v27.1*\n🌐 `{get_domain()}:22`\n🎯 IPv4 Only", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def create_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id): await update.message.reply_text("❌"); return
    try:
        a = context.args
        if len(a)<5: await update.message.reply_text("❌ `/create user pass days gb conn`", parse_mode='Markdown'); return
        name, pwd, days, gb, conn = a[0], a[1], int(a[2]), int(a[3]), int(a[4])
        
        if subprocess.run(["id",name], capture_output=True).returncode==0:
            await update.message.reply_text(f"❌ `{name}` exists!", parse_mode='Markdown'); return
        
        subprocess.run(["useradd","-m","-s","/bin/bash",name], capture_output=True)
        subprocess.run(["chpasswd"], input=f"{name}:{pwd}".encode(), capture_output=True)
        
        with open(f"/etc/ssh/sshd_config.d/{name}.conf","w") as f:
            f.write(f"MaxSessions {conn}\nMaxStartups {conn}\n")
        
        tb = gb*1073741824 if gb>0 else 0
        exp = int(time.time())+(days*86400) if days>0 else 0
        
        next_mark=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';")
        mark=${next_mark:-100}
        sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
        
        conn_db = sqlite3.connect(DB)
        conn_db.execute("INSERT INTO users (username, password, total_traffic, iptables_mark, expiry, created, user_limit) VALUES (?,?,?,?,?,?,?)",
                       [name, pwd, tb, mark, exp, int(time.time()), conn])
        conn_db.commit()
        conn_db.close()
        
        # IPv4 only iptables rules
        iptables -t mangle -A OUTPUT -m owner --uid-owner "$name" -j MARK --set-mark "$mark" 2>/dev/null
        iptables -t mangle -A INPUT -m owner --uid-owner "$name" -j MARK --set-mark "$mark" 2>/dev/null
        
        with open("/etc/shadow-users.conf","a") as f: f.write(f"{name}\n")
        subprocess.run(["systemctl","restart","sshd"])
        
        domain = get_domain()
        link = gen_nap(domain, name, pwd, str(days) if days>0 else "∞", str(gb) if gb>0 else "∞")
        
        await update.message.reply_text(
            f"✅ *Created!*\n🌐 `{domain}:22`\n👤 `{name}`\n🔑 `{pwd}`\n📊 `{gb}GB`\n⏰ `{days}d`\n🔗 `{conn}`\n🎯 IPv4 Only\n\n📋 `{link}`",
            parse_mode='Markdown'
        )
    except Exception as e:
        await update.message.reply_text(f"❌ {str(e)}")

def main():
    load_config()
    if not BOT_TOKEN: print("No token!"); sys.exit(1)
    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("create", create_cmd))
    app.add_handler(CallbackQueryHandler(btn))
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

# Force IPv4 for all curl calls
get_domain() { [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || curl -s4 ifconfig.me; }

show_banner() {
    SERVER_IP=$(get_domain)
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  ${GREEN}🔱 SHADOW SSH v27.1 - IPv4 ONLY${PURPLE}        ║${NC}"
    echo -e "${PURPLE}║  🌐 ${SERVER_IP}:22  |  🎯 iptables 1:1${PURPLE}       ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════ MENU ══════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}🇺🇸  Fake Location${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}📡  Fake DNS${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}📦  Backup & Restore${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}🤖  Telegram Bot${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}🌐  Domain Management${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}🚪  Exit${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════${NC}"
    echo ""
}

create_user() {
    echo ""
    echo -e "${YELLOW}📝 CREATE USER${NC}"
    echo ""
    
    echo -n -e "👤 Username: "; read username
    if id "$username" &>/dev/null; then echo -e "${RED}❌ User exists!${NC}"; sleep 2; return; fi
    
    echo -n -e "🔑 Password: "; read password
    echo -n -e "📊 Traffic Limit (GB, 0=∞): "; read traffic_gb
    echo -n -e "⏰ Days (0=∞): "; read days
    echo -n -e "🔢 Max Conn (1-10): "; read max_conn
    
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
    
    # IPv4 only
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    
    echo "$username" >> /etc/shadow-users.conf 2>/dev/null
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $mark, $expiry, $(date +%s), $max_conn);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    days_display="∞"; [ "$days" != "0" ] && days_display="$days"
    traffic_display="∞"; [ "$traffic_gb" != "0" ] && traffic_display="$traffic_gb"
    
    config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $username | ⏰ ${days_display}d | 📎 ${traffic_display}GB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
    config_b64=$(echo -n "$config_json" | base64 -w 0)
    npvt_link="npvt-ssh://${config_b64}"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ✅ USER CREATED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 ${GREEN}${SERVER}${NC}"
    echo -e "  👤 ${GREEN}${username}${NC}"
    echo -e "  🔑 ${GREEN}${password}${NC}"
    echo -e "  📊 ${GREEN}${traffic_gb}GB${NC} | ⏰ ${GREEN}${days}d${NC} | 🔗 ${GREEN}${max_conn}${NC}"
    echo -e "  🎯 IPv4 Only"
    echo ""
    echo -e "${PURPLE}📋 ${YELLOW}${npvt_link}${NC}"
    echo ""
    echo -n "Press Enter..."; read
}

delete_user() {
    echo ""
    echo -n -e "${RED}Username to delete: ${NC}"; read username
    if ! id "$username" &>/dev/null; then echo -e "${RED}❌ Not found!${NC}"; sleep 2; return; fi
    
    echo -n -e "Are you sure? (y/n): "; read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
    
    mark=$(sqlite3 "$DB" "SELECT iptables_mark FROM users WHERE username='$username';")
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    
    pkill -9 -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    systemctl restart sshd 2>/dev/null
    
    echo -e "${GREEN}✅ Deleted!${NC}"
    sleep 2
}

list_users() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   👥 ACTIVE USERS (IPv4 Only)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    printf "${WHITE}%-15s %-8s %-25s %-15s %-10s${NC}\n" "Username" "Status" "Used Traffic" "Limit" "Expiry"
    echo -e "${BLUE}──────────────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r username status total_limit expiry limit used mark; do
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
        
        printf "%-15s %s %-8s ${CYAN}%-25s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$limit_text" "$expiry_text"
        
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit, used_traffic, iptables_mark FROM users;")
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter..."; read
}

fake_location_menu() {
    while true; do
        clear
        echo -e "${YELLOW}🇺🇸 FAKE LOCATION${NC}"
        /usr/local/bin/fake-location status
        echo ""
        echo -e "1. Enable  2. Disable  3. Change  4. List  5. Back"
        echo -n -e "Select: "; read c
        case $c in
            1) echo -n "Country: "; read co; /usr/local/bin/fake-location start "$co"; sleep 2 ;;
            2) /usr/local/bin/fake-location stop; sleep 2 ;;
            3) /usr/local/bin/fake-location list; echo -n "Code: "; read co; /usr/local/bin/fake-location start "$co"; sleep 2 ;;
            4) /usr/local/bin/fake-location list; echo ""; echo -n "Press Enter..."; read ;;
            5) break ;;
        esac
    done
}

fake_dns_menu() {
    while true; do
        clear
        echo -e "${CYAN}📡 FAKE DNS${NC}"
        /usr/local/bin/fake-dns status
        echo ""
        echo -e "1. Enable  2. Disable  3. Back"
        echo -n -e "Select: "; read c
        case $c in
            1) /usr/local/bin/fake-dns start; sleep 2 ;;
            2) /usr/local/bin/fake-dns stop; sleep 2 ;;
            3) break ;;
        esac
    done
}

backup_menu() {
    while true; do
        clear
        echo -e "${BLUE}📦 BACKUP${NC}"
        sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime') FROM backup_history ORDER BY backup_time DESC LIMIT 5;" 2>/dev/null
        echo ""
        echo -e "1. Create  2. Restore  3. Auto-Backup  4. Back"
        echo -n -e "Select: "; read c
        case $c in
            1) /usr/local/bin/backup-manager backup; sleep 2 ;;
            2) /usr/local/bin/backup-manager restore; sleep 2 ;;
            3) systemctl is-active --quiet shadow-backup && systemctl stop shadow-backup || systemctl start shadow-backup; sleep 2 ;;
            4) break ;;
        esac
    done
}

domain_management() {
    clear
    echo -e "${PURPLE}🌐 DOMAIN${NC}"
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        echo -e "Current: ${GREEN}$(cat $DOMAIN_FILE)${NC}"
    else
        echo -e "Current: ${YELLOW}No domain${NC}"
    fi
    echo ""
    echo -e "1. Add/Change  2. Get SSL  3. Delete  4. Back"
    echo -n -e "Select: "; read c
    case $c in
        1) echo -n "Domain: "; read d; echo "$d" > "$DOMAIN_FILE"; echo -e "${GREEN}✅${NC}"; sleep 1 ;;
        2)
            if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
                d=$(cat "$DOMAIN_FILE")
                echo -n "Email: "; read e
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$d" --non-interactive --agree-tos --email "$e"
            else echo -e "${RED}❌ Set domain first${NC}"
            fi
            sleep 2
            ;;
        3) echo -n -e "${RED}Delete? (y/n): ${NC}"; read cf; [ "$cf" = "y" ] && rm -f "$DOMAIN_FILE" && echo -e "${GREEN}✅${NC}"; sleep 1 ;;
    esac
}

server_status() {
    echo ""
    echo -e "${PURPLE}📈 STATUS${NC}"
    echo ""
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    uptime=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    
    echo -e "  🖥  CPU: ${YELLOW}${cpu}%${NC}"
    echo -e "  💾 RAM: ${YELLOW}${mem}%${NC}"
    echo -e "  ⏱  Uptime: ${GREEN}${uptime}${NC}"
    echo -e "  🔗 Connections: ${CYAN}${conn}${NC}"
    echo -e "  👥 Users: ${GREEN}${users}${NC}"
    echo -e "  🎯 Mode: ${GREEN}iptables IPv4 Only (True Precision)${NC}"
    echo -e "  📊 Monitor: $(systemctl is-active traffic-monitor | grep -q active && echo "${GREEN}ON${NC}" || echo "${RED}OFF${NC}")"
    echo -e "  🚫 IPv6: ${RED}DISABLED${NC}"
    echo ""
    echo -n "Press Enter..."; read
}

while true; do
    show_menu
    echo -n -e "${CYAN}Select [1-10]: ${NC}"; read choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) fake_location_menu ;;
        5) fake_dns_menu ;;
        6) backup_menu ;;
        7)
            if [ -f "$BOT_CONFIG" ]; then
                echo -e "1. Set Token  2. Add Admin  3. Start/Stop  4. Back"
                echo -n "Select: "; read bc
                case $bc in
                    1) echo -n "Token: "; read t; sed -i "s/TOKEN=.*/TOKEN=$t/" "$BOT_CONFIG"; systemctl restart shadow-bot 2>/dev/null ;;
                    2) echo -n "ID: "; read id; cur=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2); sed -i "s/ADMINS=.*/ADMINS=$cur,$id/" "$BOT_CONFIG"; systemctl restart shadow-bot 2>/dev/null ;;
                    3) systemctl is-active --quiet shadow-bot && systemctl stop shadow-bot || systemctl start shadow-bot ;;
                esac
            else
                echo -n "Token: "; read t
                echo "TOKEN=$t" > "$BOT_CONFIG"
                echo "ADMINS=" >> "$BOT_CONFIG"
                systemctl restart shadow-bot 2>/dev/null
            fi
            sleep 1
            ;;
        8) domain_management ;;
        9) server_status ;;
        10) echo -e "${GREEN}👋 Bye!${NC}"; exit 0 ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ============================================
# Services
# ============================================
cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Shadow SSH True Precision Monitor (IPv4)
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

clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ${GREEN}✅ SHADOW SSH v27.1 - IPv4 ONLY INSTALLED!${PURPLE}            ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 ${YELLOW}shadow${CYAN} - Open Panel${NC}"
echo ""
echo -e "${GREEN}🎯 v27.1 CHANGES:${NC}"
echo -e "  ✅ IPv6 completely DISABLED (sysctl + sshd_config)"
echo -e "  ✅ Only iptables (IPv4) used for counting"
echo -e "  ✅ ip6tables IGNORED"
echo -e "  ✅ curl -4 for all external calls"
echo -e "  ✅ AddressFamily inet in SSH config"
echo ""
echo -e "${RED}🚫 IPv6: OFF${NC}"
echo -e "${GREEN}🎯 IPv4: ONLY${NC}"
echo ""
