#!/bin/bash

# =============================================
# Shadow SSH v30.0 - EMPIRE EDITION
# Client Dashboard + Visual Analytics + Full Bot
# Chain-based iptables | 1s interval | IPv4 only
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
    echo -e "${YELLOW}   🚀 Activating EMPIRE Network (IPv4 Only)${NC}"
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
    
    cat > /etc/ssh/sshd_config.d/99-empire.conf << 'TURBOEOF'
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
    
    echo -e "${GREEN}   ✅ EMPIRE Network Activated${NC}"
}

# ============================================
# Cleanup
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🧹 Cleaning Previous Installation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

systemctl stop traffic-monitor shadow-bot shadow-dashboard 2>/dev/null
systemctl disable traffic-monitor shadow-bot shadow-dashboard 2>/dev/null

pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "shadow-dashboard" 2>/dev/null
pkill -9 -f "fake-dns" 2>/dev/null
pkill -9 -f "ai-optimizer" 2>/dev/null
pkill -9 -f "fake-location" 2>/dev/null

iptables -t mangle -F 2>/dev/null
iptables -t mangle -X 2>/dev/null
iptables -t nat -F 2>/dev/null
iptables -t nat -X 2>/dev/null
ip6tables -t mangle -F 2>/dev/null
ip6tables -t mangle -X 2>/dev/null

tc qdisc del dev eth0 root 2>/dev/null
tc qdisc del dev lo root 2>/dev/null

if [ -f /etc/shadow-users.conf ]; then
    for user in $(cat /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /usr/local/bin/shadow-dashboard /usr/local/bin/fake-dns /usr/local/bin/fake-location /usr/local/bin/ai-optimizer /usr/local/bin/backup-manager /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service /etc/systemd/system/shadow-dashboard.service /etc/ssh/sshd_config.d/*.conf 2>/dev/null

# ============================================
# Install Dependencies
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   📦 Installing Dependencies${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc procps python3 python3-pip net-tools certbot nginx 2>/dev/null

# Install Python packages
pip3 install --break-system-packages python-telegram-bot==20.7 flask flask-login matplotlib numpy Pillow 2>/dev/null

# Verify critical imports
python3 -c "from telegram import Update; from flask import Flask; import matplotlib; print('All imports OK')" 2>/dev/null || {
    echo -e "${YELLOW}Retrying install...${NC}"
    pip3 install --force-reinstall --break-system-packages python-telegram-bot==20.7 flask matplotlib
}

optimize_network

# SSH Config
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
    echo -e "  ${GREEN}4.${NC} ${WHITE}Skip${NC}"
    echo ""
    echo -n -e "${CYAN}Select option [1-4]: ${NC}"
    read choice
    
    case $choice in
        1) echo -n -e "${GREEN}Enter domain: ${NC}"; read DOMAIN; echo "$DOMAIN" > /etc/shadow-domain.conf; echo -e "${GREEN}✅ Domain saved${NC}" ;;
        2)
            if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
                DOMAIN=$(cat /etc/shadow-domain.conf)
                echo -n -e "${GREEN}Enter email: ${NC}"; read EMAIL
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
                [ $? -eq 0 ] && echo -e "${GREEN}✅ SSL obtained${NC}" || echo -e "${RED}❌ Failed${NC}"
            else echo -e "${RED}❌ Set domain first${NC}"; fi
            ;;
        3) echo -n -e "${RED}Delete? (y/n): ${NC}"; read cf; [ "$cf" = "y" ] && rm -f /etc/shadow-domain.conf && echo -e "${GREEN}✅ Deleted${NC}" ;;
    esac
}
setup_domain

# ============================================
# Database
# ============================================
mkdir -p /var/lib/shadow /var/backups/shadow /var/lib/shadow/charts

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
CREATE TABLE IF NOT EXISTS traffic_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    timestamp INTEGER,
    bytes_used INTEGER
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
INSERT OR IGNORE INTO settings VALUES ('dashboard_port', '8080');
SQLEOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v30.0 - EMPIRE${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ============================================
# TRAFFIC MONITOR - Chain-based, 1s interval
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
    local username=$1; local mark=$2; local chain_name="SHADOW_${username}"
    iptables -t mangle -N "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    iptables -t mangle -C OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null || iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -C INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null || iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -C "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null || iptables -t mangle -A "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    sqlite3 "$DB" "UPDATE users SET chain_name='$chain_name' WHERE username='$username';"
}

get_chain_bytes() {
    local chain_name=$1
    local bytes=$(iptables -t mangle -L "$chain_name" -v -n -x 2>/dev/null | grep "MARK set" | awk '{print $2+0}')
    echo "${bytes:-0}"
}

remove_user_chain() {
    local username=$1; local chain_name="SHADOW_${username}"
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    iptables -t mangle -X "$chain_name" 2>/dev/null
}

echo "🎯 EMPIRE Monitor Started (PID: $$) | Chain-based | 1s interval"

while IFS='|' read -r username mark chain_name; do
    [ -z "$username" ] && continue
    [ -z "$chain_name" ] && create_user_chain "$username" "$mark"
done < <(sqlite3 "$DB" "SELECT username, iptables_mark, chain_name FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")

while true; do
    current_time=$(date +%s)
    
    while IFS='|' read -r username total_limit expiry mark chain_name is_test; do
        [ -z "$username" ] && continue
        
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            [ -n "$chain_name" ] && remove_user_chain "$username"
            continue
        fi
        
        [ -z "$chain_name" ] && { create_user_chain "$username" "$mark"; chain_name="SHADOW_${username}"; }
        iptables -t mangle -L "$chain_name" >/dev/null 2>&1 || create_user_chain "$username" "$mark"
        
        total_bytes=$(get_chain_bytes "$chain_name")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_bytes WHERE username='$username';"
        sqlite3 "$DB" "INSERT INTO traffic_history (username, timestamp, bytes_used) VALUES ('$username', $current_time, $total_bytes);"
        
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
    sqlite3 "$DB" "INSERT INTO backup_history (backup_time, filename, size, type) VALUES ($(date +%s), '$backup_file', $(stat -c %s "$backup_file"), 'local');"
    echo "$backup_file"
}

case "$1" in
    backup) create_backup ;;
    restore)
        sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime') FROM backup_history ORDER BY backup_time DESC LIMIT 10;" | while IFS='|' read id time; do echo "$id - $time"; done
        echo -n "Enter ID: "; read id
        file=$(sqlite3 "$DB" "SELECT filename FROM backup_history WHERE id=$id;")
        [ -n "$file" ] && [ -f "$file" ] && { systemctl stop traffic-monitor shadow-bot 2>/dev/null; tar -xzf "$file" -C /; systemctl start traffic-monitor shadow-bot 2>/dev/null; echo "✅ Restored!"; }
        ;;
    auto-backup) while true; do create_backup >/dev/null; sleep 86400; done ;;
    *) echo "Usage: $0 {backup|restore|auto-backup}" ;;
esac
BACKEOF

chmod +x /usr/local/bin/backup-manager

# ============================================
# TELEGRAM BOT - FULL MANAGEMENT + CLIENT PANEL + ANALYTICS
# ============================================
cat > /usr/local/bin/shadow-bot << 'BOTEOF'
#!/usr/bin/env python3
import os, sys, sqlite3, time, subprocess, json, base64, random, string, io, tempfile
from datetime import datetime, timedelta

try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes, ConversationHandler
except ImportError:
    subprocess.run(["pip3", "install", "--break-system-packages", "python-telegram-bot==20.7"])
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes, ConversationHandler

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    subprocess.run(["pip3", "install", "--break-system-packages", "matplotlib"])
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    MATPLOTLIB_AVAILABLE = True

DB = "/var/lib/shadow/traffic.db"
CONFIG_FILE = "/etc/shadow-bot.conf"
DOMAIN_FILE = "/etc/shadow-domain.conf"

BOT_TOKEN = None
ADMIN_IDS = []
CLIENT_SESSIONS = {}  # {user_id: username}

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
    if gb != "∞": remarks += f" | 📎 {gb}"
    config_dict = {"sshConfigType":"SSH-Direct","remarks":remarks,"sshHost":server,"sshPort":22,"sshUsername":user,"sshPassword":pwd,"udpgwTransparentDNS":True}
    return "npvt-ssh://" + base64.b64encode(json.dumps(config_dict).encode()).decode()

def get_user_info(username):
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT status, used_traffic, total_traffic, expiry, user_limit, created, is_test FROM users WHERE username=?", [username])
    row = cur.fetchone()
    conn.close()
    return row

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

def generate_traffic_chart(username):
    if not MATPLOTLIB_AVAILABLE:
        return None
    
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    # Get last 24 hours of traffic data
    since = int(time.time()) - 86400
    cur.execute("SELECT timestamp, bytes_used FROM traffic_history WHERE username=? AND timestamp > ? ORDER BY timestamp ASC", [username, since])
    data = cur.fetchall()
    conn.close()
    
    if not data or len(data) < 2:
        return None
    
    times = [datetime.fromtimestamp(t) for t, _ in data]
    bytes_mb = [b / 1048576 for _, b in data]
    
    plt.figure(figsize=(10, 5))
    plt.plot(times, bytes_mb, color='#00ff88', linewidth=2, marker='o', markersize=3)
    plt.fill_between(times, bytes_mb, alpha=0.2, color='#00ff88')
    plt.title(f'Traffic Usage - {username} (Last 24h)', color='white', fontsize=14)
    plt.xlabel('Time', color='white')
    plt.ylabel('MB', color='white')
    plt.grid(True, alpha=0.2, color='white')
    plt.gca().set_facecolor('#1a1a2e')
    plt.gcf().set_facecolor('#1a1a2e')
    plt.gca().tick_params(colors='white')
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
    plt.xticks(rotation=45)
    plt.tight_layout()
    
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=100, transparent=False)
    buf.seek(0)
    plt.close()
    return buf

# ============================================
# START COMMAND
# ============================================
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    
    if is_admin(user_id):
        if not ADMIN_IDS:
            ADMIN_IDS.append(user_id)
            save_config()
        
        kb = [[InlineKeyboardButton("👥 Users List", callback_data="list")],
              [InlineKeyboardButton("➕ Create User", callback_data="create")],
              [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
              [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
              [InlineKeyboardButton("📊 Traffic Analytics", callback_data="analytics")],
              [InlineKeyboardButton("📦 Backup", callback_data="backup")],
              [InlineKeyboardButton("📈 Server Status", callback_data="status")]]
        await update.message.reply_text(
            f"🔱 *Admin Panel | Shadow v30.0*\n━━━━━━━━━━━━━━━━━━━\n🌐 `{get_domain()}:22`\n🎯 Chain-based iptables\n━━━━━━━━━━━━━━━━━━━\nSelect option:",
            reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown'
        )
    else:
        # Non-admin - ask for password
        CLIENT_SESSIONS[user_id] = {"state": "waiting_password"}
        await update.message.reply_text(
            "🔐 *Client Login*\n\nPlease enter your SSH password to access your panel:",
            parse_mode='Markdown'
        )

# ============================================
# MESSAGE HANDLER (Password check + Client panel)
# ============================================
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text.strip()
    
    # Admin commands
    if is_admin(user_id) and text.startswith('/create'):
        await create_user_cmd(update, context)
        return
    
    # Check if waiting for password
    if user_id in CLIENT_SESSIONS and CLIENT_SESSIONS[user_id].get("state") == "waiting_password":
        password = text
        
        # Search for user with this password
        conn = sqlite3.connect(DB)
        cur = conn.cursor()
        cur.execute("SELECT username FROM users WHERE password=?", [password])
        row = cur.fetchone()
        conn.close()
        
        if row:
            username = row[0]
            CLIENT_SESSIONS[user_id] = {"state": "logged_in", "username": username}
            await show_client_panel(update, username)
        else:
            await update.message.reply_text("❌ Invalid password! Please try again or type /start to return.")
        return
    
    # Check if logged in client
    if user_id in CLIENT_SESSIONS and CLIENT_SESSIONS[user_id].get("state") == "logged_in":
        username = CLIENT_SESSIONS[user_id]["username"]
        cmd = text.lower()
        
        if cmd == "📊 my usage":
            await show_client_panel(update, username)
        elif cmd == "📈 traffic chart":
            await send_traffic_chart(update, username)
        elif cmd == "📋 my config":
            info = get_user_info(username)
            if info:
                domain = get_domain()
                days_left = "∞" if info[3] == 0 else str((info[3] - int(time.time())) // 86400) + "d"
                total_gb = "∞" if info[2] == 0 else f"{info[2]/1073741824:.1f}GB"
                link = gen_nap(domain, username, "••••••••", days_left, total_gb)
                await update.message.reply_text(f"📋 *Your Config*\n\n`{link}`\n\n⚠️ Password hidden for security", parse_mode='Markdown')
        elif cmd == "🚪 logout":
            del CLIENT_SESSIONS[user_id]
            await update.message.reply_text("✅ Logged out. Type /start to login again.")
        else:
            await update.message.reply_text("Please use the buttons below:")

async def show_client_panel(update, username):
    info = get_user_info(username)
    if not info:
        await update.message.reply_text("❌ Account not found!")
        return
    
    status, used, total, expiry, limit, created, is_test = info
    
    used_mb = used / 1048576
    total_gb = "∞" if total == 0 else f"{total/1073741824:.1f}GB"
    total_mb = total / 1048576 if total > 0 else float('inf')
    
    if total == 0:
        percent = 0
        usage_text = f"{used_mb:.1f}MB / ∞"
    else:
        percent = min((used / total) * 100, 100)
        usage_text = f"{used_mb:.1f}MB / {total_gb}"
    
    if expiry == 0:
        days_left = "∞"
        days_left_num = float('inf')
    else:
        days_left_num = (expiry - int(time.time())) / 86400
        days_left = f"{int(days_left_num)}d" if days_left_num > 0 else "EXPIRED"
    
    # Progress bar
    bar_length = 20
    filled = int(bar_length * percent / 100)
    bar = "█" * filled + "░" * (bar_length - filled)
    
    status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
    
    message = (
        f"👤 *Client Panel - {username}*\n"
        f"━━━━━━━━━━━━━━━━━━━\n\n"
        f"{status_emoji} Status: *{status.upper()}*\n\n"
        f"📊 *Traffic Usage:*\n"
        f"`{bar}`\n"
        f"{usage_text} ({percent:.1f}%)\n\n"
        f"⏰ *Expiry:* {days_left}\n"
        f"🔗 *Max Connections:* {limit}\n"
        f"🧪 *Test Account:* {'Yes' if is_test else 'No'}\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
    )
    
    kb = [[InlineKeyboardButton("📊 My Usage", callback_data=f"client_usage_{username}")],
          [InlineKeyboardButton("📈 Traffic Chart", callback_data=f"client_chart_{username}")],
          [InlineKeyboardButton("📋 My Config", callback_data=f"client_config_{username}")],
          [InlineKeyboardButton("🚪 Logout", callback_data="client_logout")]]
    
    if isinstance(update, Update):
        await update.message.reply_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')
    else:
        await update.edit_message_text(message, reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def send_traffic_chart(update, username):
    buf = generate_traffic_chart(username)
    if buf:
        await update.message.reply_photo(photo=buf, caption=f"📈 24h Traffic Chart - {username}")
    else:
        await update.message.reply_text("📊 Not enough data yet. Keep using your connection and check back later!")

# ============================================
# BUTTON HANDLER
# ============================================
async def btn(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    user_id = q.from_user.id
    
    # Handle client buttons
    if q.data.startswith("client_"):
        if user_id in CLIENT_SESSIONS and CLIENT_SESSIONS[user_id].get("state") == "logged_in":
            username = CLIENT_SESSIONS[user_id]["username"]
            if q.data == "client_logout":
                del CLIENT_SESSIONS[user_id]
                await q.edit_message_text("✅ Logged out. Type /start to login again.")
            elif q.data.startswith("client_usage_"):
                await show_client_panel(q, username)
            elif q.data.startswith("client_chart_"):
                await q.edit_message_text("Generating chart...")
                buf = generate_traffic_chart(username)
                if buf:
                    await q.message.reply_photo(photo=buf, caption=f"📈 24h Traffic - {username}")
                    await q.edit_message_text("✅ Chart generated!")
                else:
                    await q.edit_message_text("📊 Not enough data yet.")
            elif q.data.startswith("client_config_"):
                info = get_user_info(username)
                if info:
                    domain = get_domain()
                    days_left = "∞" if info[3] == 0 else str((info[3] - int(time.time())) // 86400) + "d"
                    total_gb = "∞" if info[2] == 0 else f"{info[2]/1073741824:.1f}GB"
                    link = gen_nap(domain, username, "••••••••", days_left, total_gb)
                    await q.edit_message_text(f"📋 *Your Config*\n\n`{link}`", parse_mode='Markdown')
        return
    
    # Admin only below
    if not is_admin(user_id): await q.edit_message_text("❌"); return
    
    if q.data == "list":
        conn = sqlite3.connect(DB)
        cur = conn.cursor()
        cur.execute("SELECT username, status, used_traffic, total_traffic, expiry, is_test FROM users")
        users = cur.fetchall()
        conn.close()
        if not users: await q.edit_message_text("📭"); return
        msg = "👥 *Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
        for u in users:
            name, st, used, total, exp, is_test = u
            um = used/1048576; tg = total/1073741824 if total>0 else 0
            dl = "∞" if exp==0 else str((exp-int(time.time()))//86400)+"d"
            ut = f"{um:.1f}MB / ∞" if total==0 else f"{um:.1f}MB / {tg:.1f}GB"
            em = "🟢" if st=="active" else "🔴" if st=="expired" else "🟡"
            test_tag = " 🧪" if is_test else ""
            msg += f"{em} `{name}`{test_tag}\n   📊 {ut}\n   ⏰ {dl}\n\n"
        await q.edit_message_text(msg, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙", callback_data="back")]]), parse_mode='Markdown')
    
    elif q.data == "create":
        await q.edit_message_text("➕ *Create User*\n\nSend: `/create user pass days gb conn`", parse_mode='Markdown')
    
    elif q.data == "test_acc":
        test_user = "test_" + ''.join(random.choices(string.ascii_lowercase, k=5))
        test_pass = ''.join(random.choices(string.ascii_letters + string.digits, k=10))
        
        subprocess.run(["useradd","-m","-s","/bin/bash",test_user])
        subprocess.run(["chpasswd"], input=f"{test_user}:{test_pass}".encode())
        with open(f"/etc/ssh/sshd_config.d/{test_user}.conf","w") as f: f.write("MaxSessions 1\nMaxStartups 1\n")
        
        next_mark = subprocess.getoutput(f"sqlite3 {DB} \"SELECT value FROM settings WHERE key='next_mark';\"")
        mark = int(next_mark) if next_mark and next_mark.isdigit() else 100
        subprocess.run(f"sqlite3 {DB} \"UPDATE settings SET value={mark+1} WHERE key='next_mark';\"", shell=True)
        
        chain_name = create_user_chain(test_user, mark)
        
        with open("/etc/shadow-users.conf","a") as f: f.write(f"{test_user}\n")
        conn = sqlite3.connect(DB)
        conn.execute("INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit, is_test) VALUES (?,?,?,?,?,?,?,?,1)",
                    [test_user, test_pass, 30*1048576, mark, chain_name, int(time.time())+86400, int(time.time()), 1])
        conn.commit(); conn.close()
        subprocess.run(["systemctl","restart","sshd"])
        
        domain = get_domain()
        link = gen_nap(domain, test_user, test_pass, "1", "30MB")
        msg = f"🧪 *Test Account!*\n━━━━━━━━━━━━━━━━━━━\n🌐 `{domain}:22`\n👤 `{test_user}`\n🔑 `{test_pass}`\n📊 `30MB`\n⏰ `1 Day`\n━━━━━━━━━━━━━━━━━━━\n📋 `{link}`"
        await q.edit_message_text(msg, parse_mode='Markdown')
    
    elif q.data == "del_menu":
        conn = sqlite3.connect(DB); cur = conn.cursor()
        cur.execute("SELECT username FROM users"); users = cur.fetchall(); conn.close()
        if not users: await q.edit_message_text("📭"); return
        kb = [[InlineKeyboardButton(f"🗑 {u[0]}", callback_data=f"del_{u[0]}")] for u in users]
        kb.append([InlineKeyboardButton("🔙", callback_data="back")])
        await q.edit_message_text("🗑 *Select:*", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')
    
    elif q.data.startswith("del_"):
        name = q.data[4:]
        remove_user_chain(name)
        subprocess.run(["pkill","-9","-u",name]); subprocess.run(["userdel","-r",name])
        conn = sqlite3.connect(DB); conn.execute("DELETE FROM users WHERE username=?",[name]); conn.commit(); conn.close()
        os.system(f"sed -i '/^{name}$/d' /etc/shadow-users.conf 2>/dev/null")
        os.system(f"rm -f /etc/ssh/sshd_config.d/{name}.conf")
        subprocess.run(["systemctl","restart","sshd"])
        await q.edit_message_text(f"✅ `{name}` deleted!", parse_mode='Markdown')
    
    elif q.data == "analytics":
        await show_analytics_menu(q)
    
    elif q.data == "analytics_all":
        buf = generate_all_users_chart()
        if buf:
            await q.message.reply_photo(photo=buf, caption="📊 All Users - 24h Traffic")
        else:
            await q.edit_message_text("📊 Not enough data.")
    
    elif q.data.startswith("analytics_user_"):
        username = q.data.replace("analytics_user_", "")
        buf = generate_traffic_chart(username)
        if buf:
            await q.message.reply_photo(photo=buf, caption=f"📈 24h Traffic - {username}")
        else:
            await q.edit_message_text(f"📊 No data for {username}")
    
    elif q.data == "backup":
        r = subprocess.run(["/usr/local/bin/backup-manager","backup"], capture_output=True, text=True)
        await q.edit_message_text(f"📦 *Backup*\n{r.stdout}", parse_mode='Markdown')
    
    elif q.data == "status":
        cpu = subprocess.getoutput("top -bn1 | grep 'Cpu' | awk '{print $2}'|cut -d% -f1")
        mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\",$3*100/$2}'")
        up = subprocess.getoutput("uptime -p|sed 's/up //'")
        conn_count = subprocess.getoutput("ss -tnp|grep ESTAB|wc -l")
        act = sqlite3.connect(DB).execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
        msg = f"📈 *Status*\n━━━━━━━━━━━━━━━━━━━\n\n🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n⏱ `{up}`\n🔗 `{conn_count}`\n👥 `{act}`\n🎯 Chain-based | 1s"
        await q.edit_message_text(msg, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙", callback_data="back")]]), parse_mode='Markdown')
    
    elif q.data == "back":
        kb = [[InlineKeyboardButton("👥 Users List", callback_data="list")],
              [InlineKeyboardButton("➕ Create User", callback_data="create")],
              [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
              [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
              [InlineKeyboardButton("📊 Traffic Analytics", callback_data="analytics")],
              [InlineKeyboardButton("📦 Backup", callback_data="backup")],
              [InlineKeyboardButton("📈 Server Status", callback_data="status")]]
        await q.edit_message_text(f"🔱 *Admin Panel*\n🌐 `{get_domain()}:22`", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def show_analytics_menu(q):
    conn = sqlite3.connect(DB); cur = conn.cursor()
    cur.execute("SELECT DISTINCT username FROM traffic_history WHERE timestamp > ?", [int(time.time())-86400])
    users = cur.fetchall(); conn.close()
    
    kb = [[InlineKeyboardButton("📊 All Users Chart", callback_data="analytics_all")]]
    for (u,) in users[:20]:
        kb.append([InlineKeyboardButton(f"📈 {u}", callback_data=f"analytics_user_{u}")])
    kb.append([InlineKeyboardButton("🔙", callback_data="back")])
    await q.edit_message_text("📊 *Traffic Analytics*\nSelect user to view chart:", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

def generate_all_users_chart():
    if not MATPLOTLIB_AVAILABLE: return None
    
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    since = int(time.time()) - 86400
    cur.execute("SELECT username, timestamp, bytes_used FROM traffic_history WHERE timestamp > ? ORDER BY timestamp ASC", [since])
    data = cur.fetchall()
    conn.close()
    
    if not data: return None
    
    users = {}
    for username, ts, bytes_used in data:
        if username not in users:
            users[username] = {"times": [], "bytes": []}
        users[username]["times"].append(datetime.fromtimestamp(ts))
        users[username]["bytes"].append(bytes_used / 1048576)
    
    plt.figure(figsize=(12, 6))
    colors = ['#00ff88', '#ff6b6b', '#ffd93d', '#6c5ce7', '#a8e6cf', '#ff8c00', '#00d2ff', '#ff69b4']
    
    for i, (username, user_data) in enumerate(users.items()):
        if len(user_data["times"]) > 1:
            color = colors[i % len(colors)]
            plt.plot(user_data["times"], user_data["bytes"], color=color, linewidth=2, label=username[:15])
    
    plt.title('All Users Traffic - Last 24h', color='white', fontsize=14)
    plt.xlabel('Time', color='white')
    plt.ylabel('MB', color='white')
    plt.legend(loc='upper left', fontsize=8, facecolor='#1a1a2e', edgecolor='white', labelcolor='white')
    plt.grid(True, alpha=0.2, color='white')
    plt.gca().set_facecolor('#1a1a2e')
    plt.gcf().set_facecolor('#1a1a2e')
    plt.gca().tick_params(colors='white')
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
    plt.xticks(rotation=45)
    plt.tight_layout()
    
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=100)
    buf.seek(0)
    plt.close()
    return buf

async def create_user_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id): await update.message.reply_text("❌"); return
    try:
        a = context.args
        if len(a)<5: await update.message.reply_text("❌ `/create user pass days gb conn`", parse_mode='Markdown'); return
        name, pwd, days, gb, conn = a[0], a[1], int(a[2]), int(a[3]), int(a[4])
        
        if subprocess.run(["id",name], capture_output=True).returncode==0:
            await update.message.reply_text(f"❌ `{name}` exists!", parse_mode='Markdown'); return
        
        subprocess.run(["useradd","-m","-s","/bin/bash",name])
        subprocess.run(["chpasswd"], input=f"{name}:{pwd}".encode())
        with open(f"/etc/ssh/sshd_config.d/{name}.conf","w") as f: f.write(f"MaxSessions {conn}\nMaxStartups {conn}\n")
        
        next_mark = subprocess.getoutput(f"sqlite3 {DB} \"SELECT value FROM settings WHERE key='next_mark';\"")
        mark = int(next_mark) if next_mark and next_mark.isdigit() else 100
        subprocess.run(f"sqlite3 {DB} \"UPDATE settings SET value={mark+1} WHERE key='next_mark';\"", shell=True)
        
        chain_name = create_user_chain(name, mark)
        
        tb = gb*1073741824 if gb>0 else 0
        exp = int(time.time())+(days*86400) if days>0 else 0
        
        with open("/etc/shadow-users.conf","a") as f: f.write(f"{name}\n")
        conn = sqlite3.connect(DB)
        conn.execute("INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit) VALUES (?,?,?,?,?,?,?,?)",
                    [name, pwd, tb, mark, chain_name, exp, int(time.time()), conn])
        conn.commit(); conn.close()
        subprocess.run(["systemctl","restart","sshd"])
        
        domain = get_domain()
        link = gen_nap(domain, name, pwd, str(days) if days>0 else "∞", f"{gb}GB" if gb>0 else "∞")
        await update.message.reply_text(
            f"✅ *Created!*\n🌐 `{domain}:22`\n👤 `{name}`\n🔑 `{pwd}`\n📊 `{gb}GB`\n⏰ `{days}d`\n🔗 `{conn}`\n\n📋 `{link}`",
            parse_mode='Markdown'
        )
    except Exception as e:
        await update.message.reply_text(f"❌ {str(e)}")

def main():
    load_config()
    if not BOT_TOKEN: print("No token!"); sys.exit(1)
    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(btn))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    print("🤖 EMPIRE Bot Started!")
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

get_domain() { [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || curl -s4 ifconfig.me; }

show_banner() {
    SERVER_IP=$(get_domain)
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v30.0 - EMPIRE EDITION 🔱${PURPLE}              ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 ${SERVER_IP}:22  |  🎯 Chain-based  |  ⏱ 1s  |  📊 Analytics${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════ EMPIRE MENU ══════════════${NC}"
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

create_user() {
    echo -n -e "👤 Username: "; read username
    id "$username" &>/dev/null && { echo -e "${RED}❌ Exists!${NC}"; sleep 2; return; }
    echo -n -e "🔑 Password: "; read password
    echo -n -e "📊 Traffic (GB, 0=∞): "; read tg; echo -n -e "⏰ Days (0=∞): "; read d
    echo -n -e "🔢 Max Conn: "; read mc; [ -z "$mc" ] && mc=1
    
    useradd -m -s /bin/bash "$username"; echo "$username:$password" | chpasswd
    cat > "/etc/ssh/sshd_config.d/${username}.conf" << EOF
MaxSessions $mc
MaxStartups $mc
EOF
    
    nm=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';"); mark=${nm:-100}
    sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
    
    chain_name="SHADOW_${username}"
    iptables -t mangle -N "$chain_name" 2>/dev/null
    iptables -t mangle -F "$chain_name" 2>/dev/null
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j "$chain_name" 2>/dev/null
    iptables -t mangle -A "$chain_name" -j MARK --set-mark "$mark" 2>/dev/null
    
    [ "$tg" -eq 0 ] && tb=0 || tb=$((tg * 1073741824))
    [ "$d" -eq 0 ] && exp=0 || exp=$(date -d "+${d} days" +%s)
    
    echo "$username" >> /etc/shadow-users.conf
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit) VALUES ('$username', '$password', $tb, $mark, '$chain_name', $exp, $(date +%s), $mc);"
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    dd="∞"; [ "$d" != "0" ] && dd="$d"; td="∞"; [ "$tg" != "0" ] && td="$tg"
    cj="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $username | ⏰ ${dd}d | 📎 ${td}GB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
    cb=$(echo -n "$cj" | base64 -w 0)
    
    echo -e "${GREEN}✅ Created!${NC}\n🌐 ${SERVER}\n👤 ${username}\n🔑 ${password}\n📊 ${tg}GB | ⏰ ${d}d\n📋 ${YELLOW}npvt-ssh://${cb}${NC}"
    echo -n "Press Enter..."; read
}

delete_user() {
    echo -n -e "${RED}Username: ${NC}"; read username
    id "$username" &>/dev/null || { echo -e "${RED}❌${NC}"; sleep 2; return; }
    echo -n "Sure? (y/n): "; read c; [ "$c" != "y" ] && return
    
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j "SHADOW_${username}" 2>/dev/null
    iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j "SHADOW_${username}" 2>/dev/null
    iptables -t mangle -F "SHADOW_${username}" 2>/dev/null
    iptables -t mangle -X "SHADOW_${username}" 2>/dev/null
    
    pkill -9 -u "$username" 2>/dev/null; userdel -r "$username" 2>/dev/null
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    systemctl restart sshd 2>/dev/null
    echo -e "${GREEN}✅${NC}"; sleep 2
}

list_users() {
    echo ""
    echo -e "${CYAN}👥 USERS${NC}"
    printf "${WHITE}%-15s %-8s %-25s %-15s %-10s${NC}\n" "Username" "Status" "Used" "Limit" "Expiry"
    echo -e "${BLUE}──────────────────────────────────────────────────────────${NC}"
    while IFS='|' read -r u s tl exp lim used mark cn it; do
        [ -z "$u" ] && continue
        um=$(echo "scale=2; $used/1048576" | bc)
        if [ "$tl" -eq 0 ]; then ut="${um}MB / ∞"
        else tm=$(echo "scale=2; $tl/1048576" | bc); p=$(echo "scale=1; $used*100/$tl" | bc); ut="${um}MB / ${tm}MB (${p}%)"; fi
        [ "$exp" -eq 0 ] && et="∞" || { dl=$(((exp-$(date +%s))/86400)); [ $dl -lt 0 ] && dl=0; et="${dl}d"; }
        [ "$tl" -eq 0 ] && lt="∞" || lt="$(echo "scale=1; $tl/1073741824" | bc)GB"
        case $s in active) si="🟢" ;; expired) si="🔴" ;; limited) si="🟡" ;; *) si="⚪" ;; esac
        tt=""; [ "$it" = "1" ] && tt=" 🧪"
        printf "%-15s %s %-8s ${CYAN}%-25s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" "$u" "$si" "$s" "$ut" "$lt" "$et"
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit, used_traffic, iptables_mark, chain_name, is_test FROM users;")
    echo ""; echo -n "Press Enter..."; read
}

create_test_account() {
    tu="test_$(cat /dev/urandom | tr -dc 'a-z' | head -c 5)"; tp=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)
    echo -e "${CYAN}Test: ${GREEN}${tu}${NC} / ${GREEN}${tp}${NC}"; echo -n "Create? (y/n): "; read c; [ "$c" != "y" ] && return
    
    useradd -m -s /bin/bash "$tu"; echo "$tu:$tp" | chpasswd
    cat > "/etc/ssh/sshd_config.d/${tu}.conf" << EOF
MaxSessions 1
MaxStartups 1
EOF
    
    nm=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';"); mark=${nm:-100}
    sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
    
    cn="SHADOW_${tu}"
    iptables -t mangle -N "$cn" 2>/dev/null; iptables -t mangle -F "$cn" 2>/dev/null
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$tu" -j "$cn" 2>/dev/null
    iptables -t mangle -A INPUT -m owner --uid-owner "$tu" -j "$cn" 2>/dev/null
    iptables -t mangle -A "$cn" -j MARK --set-mark "$mark" 2>/dev/null
    
    echo "$tu" >> /etc/shadow-users.conf
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, chain_name, expiry, created, user_limit, is_test) VALUES ('$tu', '$tp', $((30*1048576)), $mark, '$cn', $(date -d '+1 days' +%s), $(date +%s), 1, 1);"
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    cj="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"🧪 Test ${tu} | ⏰ 1d | 📎 30MB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$tu\",\"sshPassword\":\"$tp\",\"udpgwTransparentDNS\":true}"
    cb=$(echo -n "$cj" | base64 -w 0)
    echo -e "${GREEN}✅${NC}\n🌐 ${SERVER}\n👤 ${tu}\n🔑 ${tp}\n📊 30MB | ⏰ 1d\n📋 ${YELLOW}npvt-ssh://${cb}${NC}"
    echo -n "Press Enter..."; read
}

backup_menu() {
    while true; do
        clear; echo -e "${BLUE}📦 BACKUP${NC}"
        sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime') FROM backup_history ORDER BY backup_time DESC LIMIT 5;" 2>/dev/null
        echo -e "\n1. Create  2. Restore  3. Auto  4. Back"; echo -n "Select: "; read c
        case $c in
            1) /usr/local/bin/backup-manager backup; sleep 2 ;;
            2) /usr/local/bin/backup-manager restore; sleep 2 ;;
            3) systemctl is-active --quiet shadow-backup && systemctl stop shadow-backup || systemctl start shadow-backup; sleep 2 ;;
            4) break ;;
        esac
    done
}

domain_management() {
    clear; echo -e "${PURPLE}🌐 DOMAIN${NC}"
    [ -f "$DOMAIN_FILE" ] && echo -e "Current: ${GREEN}$(cat $DOMAIN_FILE)${NC}" || echo -e "Current: ${YELLOW}No domain${NC}"
    echo -e "\n1. Add/Change  2. SSL  3. Delete  4. Back"; echo -n "Select: "; read c
    case $c in
        1) echo -n "Domain: "; read d; echo "$d" > "$DOMAIN_FILE"; echo -e "${GREEN}✅${NC}"; sleep 1 ;;
        2) [ -f "$DOMAIN_FILE" ] && { d=$(cat "$DOMAIN_FILE"); echo -n "Email: "; read e; systemctl stop nginx 2>/dev/null; certbot certonly --standalone -d "$d" --non-interactive --agree-tos --email "$e"; } || echo -e "${RED}Set domain first${NC}"; sleep 2 ;;
        3) echo -n "${RED}Delete? (y/n): ${NC}"; read cf; [ "$cf" = "y" ] && rm -f "$DOMAIN_FILE" && echo -e "${GREEN}✅${NC}"; sleep 1 ;;
    esac
}

server_status() {
    echo -e "${PURPLE}📈 STATUS${NC}"
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}'|cut -d% -f1)
    mem=$(free -m|awk 'NR==2{printf "%.1f",$3*100/$2}')
    up=$(uptime -p|sed 's/up //'); conn=$(ss -tnp 2>/dev/null|grep ESTAB|wc -l)
    us=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    echo -e "🖥 CPU: ${YELLOW}${cpu}%${NC}  💾 RAM: ${YELLOW}${mem}%${NC}  ⏱ ${GREEN}${up}${NC}  🔗 ${CYAN}${conn}${NC}  👥 ${GREEN}${us}${NC}"
    echo -e "🎯 Chain-based | ⏱ 1s | 📊 Analytics | 🚫 IPv6 OFF"
    echo ""; echo -n "Press Enter..."; read
}

while true; do
    show_menu; echo -n -e "${CYAN}Select [1-10]: ${NC}"; read choice
    case $choice in
        1) create_user ;; 2) delete_user ;; 3) list_users ;; 4) create_test_account ;;
        5) backup_menu ;;
        6)
            if [ -f "$BOT_CONFIG" ]; then
                echo -e "1. Token  2. Admin  3. Start/Stop  4. Status  5. Back"; echo -n "Select: "; read bc
                case $bc in
                    1) echo -n "Token: "; read t; sed -i "s/TOKEN=.*/TOKEN=$t/" "$BOT_CONFIG"; systemctl restart shadow-bot 2>/dev/null ;;
                    2) echo -n "ID: "; read id; cur=$(grep ADMINS= "$BOT_CONFIG"|cut -d= -f2); sed -i "s/ADMINS=.*/ADMINS=$cur,$id/" "$BOT_CONFIG"; systemctl restart shadow-bot 2>/dev/null ;;
                    3) systemctl is-active --quiet shadow-bot && systemctl stop shadow-bot || systemctl start shadow-bot ;;
                    4) systemctl status shadow-bot --no-pager -l; echo ""; echo -n "Press Enter..."; read ;;
                esac
            else
                echo -n "Token: "; read t; echo "TOKEN=$t" > "$BOT_CONFIG"; echo "ADMINS=" >> "$BOT_CONFIG"; systemctl restart shadow-bot 2>/dev/null
            fi; sleep 1 ;;
        7) domain_management ;; 8) server_status ;;
        9) systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null; echo -e "${GREEN}✅${NC}"; sleep 2 ;;
        10) echo -e "${GREEN}👋${NC}"; exit 0 ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ============================================
# Services
# ============================================
cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Shadow SSH EMPIRE Traffic Monitor
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
Description=Shadow SSH EMPIRE Bot (Full)
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

clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ${GREEN}✅ SHADOW SSH v30.0 - EMPIRE EDITION INSTALLED!${PURPLE}        ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 ${YELLOW}shadow${CYAN} - Open Admin Panel${NC}"
echo ""
echo -e "${GREEN}🎯 EMPIRE FEATURES:${NC}"
echo -e "  👤 Client Panel - Login with password in Telegram Bot"
echo -e "  📊 Traffic Analytics - Charts for 24h usage"
echo -e "  🎯 Chain-based iptables (100% precise)"
echo -e "  ⏱ 1 second interval (Real-time)"
echo -e "  🧪 Test Account (30MB/1Day)"
echo -e "  🤖 Full Bot Management"
echo ""
echo -e "${CYAN}👤 CLIENT ACCESS:${NC}"
echo -e "  1. Go to your Telegram Bot"
echo -e "  2. Send /start"
echo -e "  3. Enter SSH password to login"
echo -e "  4. View usage, charts, and config"
echo ""
