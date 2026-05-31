#!/bin/bash

# =============================================
# Shadow SSH v19.1 - SPACE SPEED + FAKE PING
# FULL VERSION - BUG FIXED
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
# SPACE SPEED Network Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🚀 Activating SPACE SPEED Mode${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${BLUE}🧹 Removing all network limitations...${NC}"
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc del dev $iface ingress 2>/dev/null
    done
    
    cat > /etc/sysctl.conf << 'EOF'
# SPACE SPEED Kernel Configuration
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
net.ipv4.tcp_abort_on_overflow = 0
EOF
    
    sysctl -p >/dev/null 2>&1
    modprobe tcp_bbr 2>/dev/null
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null
    
    cat > /etc/ssh/sshd_config.d/99-space-speed.conf << 'TURBOEOF'
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
    
    echo -e "${BLUE}⚡ Optimizing network interfaces...${NC}"
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set $iface txqueuelen 50000 2>/dev/null
        ethtool -K $iface tso on gso on gro on sg on 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
        echo -e "   ✅ Interface ${GREEN}$iface${NC} optimized"
    done
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ✅ SPACE SPEED Successfully Activated${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================
# Complete Cleanup
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🧹 Cleaning Previous Installation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

systemctl stop traffic-monitor 2>/dev/null
systemctl stop shadow-bot 2>/dev/null
systemctl disable traffic-monitor 2>/dev/null
systemctl disable shadow-bot 2>/dev/null

pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "fake-ping" 2>/dev/null

tc qdisc del dev eth0 root 2>/dev/null
tc qdisc del dev ens3 root 2>/dev/null
tc qdisc del dev ens4 root 2>/dev/null
iptables -t mangle -F 2>/dev/null
ip rule del fwmark 1 lookup 100 2>/dev/null
ip route del local 0.0.0.0/0 dev lo table 100 2>/dev/null

if [ -f /etc/shadow-users.conf ]; then
    for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
        echo -e "   🗑  Removed user: ${RED}$user${NC}"
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /usr/local/bin/fake-ping /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service /etc/ssh/sshd_config.d/*.conf 2>/dev/null

echo -e "${GREEN}   ✅ Cleanup Complete${NC}"

# ============================================
# Install Dependencies
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   📦 Installing Dependencies${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq ethtool iproute2

pip3 install --break-system-packages python-telegram-bot==20.7 2>/dev/null

echo -e "${GREEN}   ✅ Dependencies Installed${NC}"

optimize_network

# ============================================
# SSH Configuration
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🔧 Configuring SSH Server${NC}"
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

echo -e "${GREEN}   ✅ SSH Server Configured${NC}"

# ============================================
# Domain Setup
# ============================================
setup_domain() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   🌐 Domain Configuration${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} ${WHITE}Use existing domain${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}Get free SSL Certificate (Let's Encrypt)${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}Skip (Use IP address only)${NC}"
    echo ""
    
    echo -n -e "${CYAN}Select option [1-3]: ${NC}"
    read domain_choice
    
    case $domain_choice in
        1)
            echo ""
            echo -n -e "${GREEN}Enter your domain: ${NC}"
            read DOMAIN
            echo "$DOMAIN" > /etc/shadow-domain.conf
            echo -e "${GREEN}✅ Domain saved: $DOMAIN${NC}"
            ;;
        2)
            echo ""
            echo -n -e "${GREEN}Enter your domain: ${NC}"
            read DOMAIN
            echo -n -e "${GREEN}Enter your email: ${NC}"
            read EMAIL
            
            echo -e "${YELLOW}🔐 Obtaining SSL Certificate...${NC}"
            systemctl stop nginx 2>/dev/null
            certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo "$DOMAIN" > /etc/shadow-domain.conf
                echo -e "${GREEN}✅ SSL Certificate obtained successfully!${NC}"
            else
                echo -e "${RED}❌ SSL Certificate failed. Using IP only${NC}"
            fi
            ;;
        3)
            echo "" > /etc/shadow-domain.conf
            echo -e "${BLUE}ℹ️  Using IP address only${NC}"
            ;;
        *)
            echo "" > /etc/shadow-domain.conf
            echo -e "${BLUE}ℹ️  Using IP address only${NC}"
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

mkdir -p /var/lib/shadow

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
INSERT OR IGNORE INTO settings VALUES ('fake_ping', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('ping_value', '100');
SQLEOF

echo -e "${GREEN}   ✅ Database Created${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v19.1 - SPACE SPEED${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# ============================================
# Fake Ping Controller Script
# ============================================
cat > /usr/local/bin/fake-ping << 'PINGEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

start_fake_ping() {
    local target_delay=$1
    local half_delay=$((target_delay / 2))
    
    stop_fake_ping
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc add dev $iface root netem delay ${half_delay}ms 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_ping';"
    sqlite3 "$DB" "UPDATE settings SET value='$target_delay' WHERE key='ping_value';"
    
    echo "✅ Fake ping enabled: ${target_delay}ms (visible in NapsternetV)"
}

stop_fake_ping() {
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_ping';"
    sqlite3 "$DB" "UPDATE settings SET value='0' WHERE key='ping_value';"
    
    echo "✅ Fake ping disabled"
}

status_fake_ping() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_ping';")
    local delay=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='ping_value';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED | Visible Ping: ${delay}ms"
    else
        echo "Status: DISABLED | Real Ping Active"
    fi
}

case "${1}" in
    start)
        delay=${2:-2000}
        start_fake_ping "$delay"
        ;;
    stop)
        stop_fake_ping
        ;;
    status)
        status_fake_ping
        ;;
    *)
        echo "Usage: $0 {start <delay_ms>|stop|status}"
        echo "Examples:"
        echo "  $0 start 2000    # Enable 2000ms fake ping"
        echo "  $0 start 5000    # Enable 5000ms fake ping"
        echo "  $0 stop          # Disable fake ping"
        echo "  $0 status        # Check status"
        ;;
esac
PINGEOF

chmod +x /usr/local/bin/fake-ping

# ============================================
# Precision Traffic Monitor
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
INTERVAL=2
PID_FILE="/var/run/traffic-monitor.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        exit 1
    fi
fi
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

read_pid_traffic() {
    local pid=$1
    if [ ! -f "/proc/$pid/net/dev" ]; then
        echo "0 0"
        return
    fi
    local rx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$2} END {print s+0}')
    local tx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$10} END {print s+0}')
    echo "$rx $tx"
}

is_real_ssh_session() {
    local pid=$1
    local username=$2
    
    local comm=$(cat /proc/$pid/comm 2>/dev/null)
    if [ "$comm" != "sshd" ]; then
        return 1
    fi
    
    local pid_uid=$(stat -c %u /proc/$pid 2>/dev/null)
    local user_uid=$(id -u "$username" 2>/dev/null)
    
    if [ "$pid_uid" != "$user_uid" ]; then
        return 1
    fi
    
    local ppid=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $4}')
    local parent_comm=$(cat /proc/$ppid/comm 2>/dev/null)
    local parent_uid=$(stat -c %u /proc/$ppid 2>/dev/null)
    
    if [ "$parent_comm" = "sshd" ] && [ "$parent_uid" = "0" ]; then
        return 0
    fi
    
    return 1
}

get_user_ssh_pids() {
    local username=$1
    local all_pids=$(pgrep -u "$username" 2>/dev/null)
    local ssh_pids=""
    
    for pid in $all_pids; do
        if is_real_ssh_session "$pid" "$username"; then
            ssh_pids="$ssh_pids $pid"
        fi
    done
    
    echo "$ssh_pids"
}

echo "🔄 Precision SSH Traffic Monitor Started (PID: $$)"
echo "   Mode: Real SSH Traffic Only"
echo "   Protection: Anti-Multiplier Active"

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
                
                if [ $diff_rx -lt 0 ] || [ $diff_tx -lt 0 ]; then
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes=0 WHERE pid=$pid AND ppid=$ppid;"
                    continue
                fi
                
                if [ $diff_rx -gt 524288000 ] || [ $diff_tx -gt 524288000 ]; then
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now WHERE pid=$pid AND ppid=$ppid;"
                    continue
                fi
                
                if [ $diff_rx -gt 0 ] || [ $diff_tx -gt 0 ]; then
                    new_bytes=$((diff_rx + diff_tx))
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes = accumulated_bytes + $new_bytes WHERE pid=$pid AND ppid=$ppid;"
                fi
            fi
        done
        
        total_usage=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_usage WHERE username='$username';"
        
        total_limit=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';")
        
        if [ "$total_limit" != "0" ] && [ "$total_usage" -ge "$total_limit" ]; then
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            sqlite3 "$DB" "UPDATE traffic_records SET status='killed' WHERE username='$username' AND status='active';"
        fi
        
    done <<< "$active_users"
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# Telegram Bot Script
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

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    if not ADMIN_IDS:
        ADMIN_IDS.append(update.effective_user.id)
        save_config()
    
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create New User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh Menu", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🔱 *Shadow SSH Manager v19.1*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{get_domain()}:22`\n"
        f"⚡ Mode: `SPACE SPEED`\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"Select an option:",
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
        await show_users_list(query)
    elif query.data == "create_user":
        await show_create_dialog(query)
    elif query.data == "traffic":
        await show_traffic_report(query)
    elif query.data == "status":
        await show_server_status(query)
    elif query.data == "refresh":
        await show_main_menu(query)
    elif query.data == "delete_menu":
        await show_delete_menu(query)
    elif query.data.startswith("delete_"):
        username = query.data.replace("delete_", "")
        await delete_user_action(query, username)

async def show_main_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create New User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh Menu", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        f"🔱 *Shadow SSH Manager*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{get_domain()}:22`\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"Select an option:",
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def show_users_list(query):
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
                days_left = "Expired"
            else:
                days_left = f"{days_left}d"
        
        if total == 0:
            usage_text = f"{used_mb:.1f}MB / ∞"
        else:
            percent = (used / total * 100) if total > 0 else 0
            usage_text = f"{used_mb:.1f}MB / {total_gb:.1f}GB ({percent:.1f}%)"
        
        status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
        
        message += f"{status_emoji} `{username}`\n"
        message += f"   📊 {usage_text}\n"
        message += f"   ⏰ {days_left} | 🔗 {limit} connections\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back to Menu", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(message, reply_markup=reply_markup, parse_mode='Markdown')

async def show_create_dialog(query):
    await query.edit_message_text(
        "➕ *Create New User*\n\n"
        "Send command:\n"
        "`/create username password days traffic_gb max_connections`\n\n"
        "*Example:*\n"
        "`/create testuser pass123 30 5 3`\n\n"
        "*Unlimited:*\n"
        "`/create user pass 0 0 1`",
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
        
        username = args[0]
        password = args[1]
        days = int(args[2])
        traffic_gb = int(args[3])
        max_conn = int(args[4])
        
        result = subprocess.run(["id", username], capture_output=True)
        if result.returncode == 0:
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
        config_json = {"sshConfigType":"SSH-Direct","remarks":f"📡 {username} | 📎 {traffic_gb}GB","sshHost":domain,"sshPort":22,"sshUsername":username,"sshPassword":password,"udpgwTransparentDNS":True}
        config_b64 = base64.b64encode(json.dumps(config_json).encode()).decode()
        npvt_link = f"npvt-ssh://{config_b64}"
        
        await update.message.reply_text(
            f"✅ *User Created!*\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"🌐 `{domain}:22`\n"
            f"👤 `{username}`\n🔑 `{password}`\n"
            f"📊 `{traffic_gb}GB`\n⏰ `{days}d`\n🔗 `{max_conn}`\n"
            f"━━━━━━━━━━━━━━━━━━━\n📋 `{npvt_link}`",
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
        await query.edit_message_text("📭 No users to delete!")
        return
    
    keyboard = []
    for (username,) in users:
        keyboard.append([InlineKeyboardButton(f"🗑 {username}", callback_data=f"delete_{username}")])
    keyboard.append([InlineKeyboardButton("🔙 Back to Menu", callback_data="refresh")])
    
    await query.edit_message_text("🗑 *Select user to delete:*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

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
    
    await query.edit_message_text(f"✅ User `{username}` deleted!", parse_mode='Markdown')

async def show_traffic_report(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    yesterday = int(time.time()) - 86400
    cursor.execute("SELECT username, SUM(accumulated_bytes) as total FROM traffic_records WHERE start_time > ? GROUP BY username ORDER BY total DESC LIMIT 10", [yesterday])
    data = cursor.fetchall()
    conn.close()
    
    if not data:
        await query.edit_message_text("📊 No traffic data for today!")
        return
    
    message = "📊 *Today's Traffic*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for i, (user, total) in enumerate(data, 1):
        mb = total / 1048576.0
        message += f"{i}. `{user}`: {mb:.2f}MB\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back to Menu", callback_data="refresh")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_server_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    ping_status = conn.execute("SELECT value FROM settings WHERE key='fake_ping'").fetchone()[0]
    ping_value = conn.execute("SELECT value FROM settings WHERE key='ping_value'").fetchone()[0]
    conn.close()
    
    ping_text = f"ON ({ping_value}ms)" if ping_status == "enabled" else "OFF"
    
    msg = (
        f"📈 *Server Status*\n━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n"
        f"⏱ Uptime: `{uptime}`\n🔗 Connections: `{conn_count}`\n"
        f"👥 Users: `{active}`\n📡 Ping: `{ping_text}`\n⚡ Mode: `SPACE`\n"
    )
    
    keyboard = [[InlineKeyboardButton("🔙 Back to Menu", callback_data="refresh")]]
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
# Main Shadow Manager Script
# ============================================
cat > /usr/local/bin/shadow << 'MAINEOF'
#!/bin/bash
# ============================================
# Shadow SSH Manager v19.1 - SPACE SPEED
# ============================================

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
        curl -s ifconfig.me
    fi
}

get_user_usage() {
    local username=$1
    sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');"
}

show_banner() {
    SERVER_IP=$(get_domain)
    PING_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_ping';")
    PING_VALUE=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='ping_value';")
    
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║      ${GREEN}🔱 SHADOW SSH v19.1 - SPACE SPEED EDITION 🔱${PURPLE}      ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 Server: ${GREEN}${SERVER_IP}${NC}"
    echo -e "${PURPLE}║${NC}  📡 Port: ${GREEN}22${NC}  |  ⚡ Mode: ${GREEN}SPACE SPEED${NC}  |  🎯 Traffic: ${GREEN}Real${NC}"
    
    if [ "$PING_STATUS" = "enabled" ]; then
        echo -e "${PURPLE}║${NC}  📡 Fake Ping: ${YELLOW}ACTIVE (${PING_VALUE}ms)${NC}"
    else
        echo -e "${PURPLE}║${NC}  📡 Fake Ping: ${BLUE}DISABLED${NC}"
    fi
    
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════════ MANAGEMENT MENU ══════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create New User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List All Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}📊  View Traffic Details${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}📡  Fake Ping Control${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}🤖  Telegram Bot Settings${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}🌐  Domain Management${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}🔄  Restart All Services${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}🚪  Exit${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo ""
}

fake_ping_menu() {
    while true; do
        clear
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}   📡 FAKE PING CONTROL PANEL${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        PING_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_ping';")
        PING_VALUE=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='ping_value';")
        
        echo -e "  Current Status: ${YELLOW}${PING_STATUS}${NC}"
        if [ "$PING_STATUS" = "enabled" ]; then
            echo -e "  Ping Delay: ${YELLOW}${PING_VALUE}ms${NC}"
        fi
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} ${WHITE}Enable Fake Ping (Custom Delay)${NC}"
        echo -e "  ${GREEN}2.${NC} ${WHITE}Disable Fake Ping${NC}"
        echo -e "  ${GREEN}3.${NC} ${WHITE}Quick Presets${NC}"
        echo -e "  ${GREEN}4.${NC} ${WHITE}Check Status${NC}"
        echo -e "  ${GREEN}5.${NC} ${WHITE}Back to Main Menu${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        echo -n -e "${CYAN}Select option [1-5]: ${NC}"
        read ping_choice
        
        case $ping_choice in
            1)
                echo ""
                echo -e "${YELLOW}Enter ping delay in milliseconds (100-10000)${NC}"
                echo -n -e "${GREEN}Ping Delay (ms): ${NC}"
                read delay
                
                if [ "$delay" -ge 100 ] && [ "$delay" -le 10000 ]; then
                    echo ""
                    /usr/local/bin/fake-ping start "$delay"
                    echo -e "${GREEN}✅ Users will now see ~${delay}ms ping${NC}"
                else
                    echo -e "${RED}❌ Invalid delay! Must be between 100 and 10000${NC}"
                fi
                echo ""
                sleep 2
                ;;
            2)
                echo ""
                echo -n -e "${RED}Are you sure? (y/n): ${NC}"
                read confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    /usr/local/bin/fake-ping stop
                else
                    echo -e "${BLUE}ℹ️  Cancelled${NC}"
                fi
                echo ""
                sleep 2
                ;;
            3)
                echo ""
                echo -e "${CYAN}Presets:${NC}"
                echo -e "  ${GREEN}a.${NC} Very Low (200ms)"
                echo -e "  ${GREEN}b.${NC} Low (500ms)"
                echo -e "  ${GREEN}c.${NC} Medium (1000ms)"
                echo -e "  ${GREEN}d.${NC} High (2000ms)"
                echo -e "  ${GREEN}e.${NC} Very High (5000ms)"
                echo -e "  ${GREEN}f.${NC} Extreme (10000ms)"
                echo ""
                echo -n -e "${CYAN}Select preset [a-f]: ${NC}"
                read preset
                
                case $preset in
                    a) /usr/local/bin/fake-ping start 200 ;;
                    b) /usr/local/bin/fake-ping start 500 ;;
                    c) /usr/local/bin/fake-ping start 1000 ;;
                    d) /usr/local/bin/fake-ping start 2000 ;;
                    e) /usr/local/bin/fake-ping start 5000 ;;
                    f) /usr/local/bin/fake-ping start 10000 ;;
                    *) echo -e "${RED}❌ Invalid preset!${NC}" ;;
                esac
                echo ""
                echo -e "${GREEN}✅ Preset applied!${NC}"
                echo ""
                sleep 2
                ;;
            4)
                echo ""
                /usr/local/bin/fake-ping status
                echo ""
                echo -n "Press Enter to continue..."
                read
                ;;
            5)
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
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
    config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $username | 📎 ${traffic_gb}GB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
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
    echo -e "${PURPLE}📋 NP VT Config Link:${NC}"
    echo -e "${YELLOW}${npvt_link}${NC}"
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
    
    pkill -9 -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    sqlite3 "$DB" "DELETE FROM traffic_records WHERE username='$username';"
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
        
        if [ "$total_limit" -eq 0 ]; then
            limit_text="∞"
        else
            limit_text="$(echo "scale=1; $total_limit/1073741824" | bc 2>/dev/null || echo "0")GB"
        fi
        
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
    echo -n "Press Enter to continue..."
    read
}

view_traffic() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   📊 TRAFFIC DETAILS${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -n -e "${GREEN}Username: ${NC}"
    read username
    
    echo ""
    echo -e "${CYAN}SSH Session Traffic Records for: ${GREEN}${username}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Start Time              | PID     | PPID    | Status   | Traffic${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    sqlite3 "$DB" "SELECT datetime(start_time, 'unixepoch', 'localtime'), pid, ppid, status, accumulated_bytes FROM traffic_records WHERE username='$username' ORDER BY start_time DESC LIMIT 30;" | while IFS='|' read -r time pid ppid status bytes; do
        mb=$(echo "scale=2; $bytes / 1048576" | bc 2>/dev/null || echo "0")
        printf "%-24s | %-7s | %-7s | %-8s | %sMB\n" "$time" "$pid" "$ppid" "$status" "$mb"
    done
    
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    total=$(get_user_usage "$username")
    total_mb=$(echo "scale=2; $total / 1048576" | bc 2>/dev/null || echo "0")
    
    echo -e "${GREEN}Total Real SSH Traffic: ${total_mb}MB${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read
}

bot_settings() {
    while true; do
        echo ""
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${PURPLE}   🤖 TELEGRAM BOT SETTINGS${NC}"
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if [ -f "$BOT_CONFIG" ]; then
            token=$(grep TOKEN= "$BOT_CONFIG" | cut -d= -f2)
            admins=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
            echo -e "  Bot Token: ${GREEN}${token:0:20}...${NC}"
            echo -e "  Admin IDs: ${GREEN}${admins}${NC}"
        else
            echo -e "  ${YELLOW}Bot not configured yet${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1.${NC} ${WHITE}Set/Change Bot Token${NC}"
        echo -e "  ${GREEN}2.${NC} ${WHITE}Add Admin ID${NC}"
        echo -e "  ${GREEN}3.${NC} ${WHITE}Start/Stop Bot${NC}"
        echo -e "  ${GREEN}4.${NC} ${WHITE}View Bot Status${NC}"
        echo -e "  ${GREEN}5.${NC} ${WHITE}Back${NC}"
        echo ""
        
        echo -n -e "${CYAN}Select option [1-5]: ${NC}"
        read bot_choice
        
        case $bot_choice in
            1)
                echo ""
                echo -n -e "${GREEN}Enter Bot Token (from @BotFather): ${NC}"
                read token
                if [ -f "$BOT_CONFIG" ]; then
                    sed -i "s/TOKEN=.*/TOKEN=$token/" "$BOT_CONFIG"
                else
                    echo "TOKEN=$token" > "$BOT_CONFIG"
                    echo "ADMINS=" >> "$BOT_CONFIG"
                fi
                echo -e "${GREEN}✅ Bot token saved!${NC}"
                systemctl restart shadow-bot 2>/dev/null
                sleep 1
                ;;
            2)
                echo ""
                echo -n -e "${GREEN}Enter Admin Telegram ID: ${NC}"
                read admin_id
                if [ -f "$BOT_CONFIG" ]; then
                    current=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
                    new="${current},${admin_id}"
                    sed -i "s/ADMINS=.*/ADMINS=$new/" "$BOT_CONFIG"
                fi
                echo -e "${GREEN}✅ Admin added!${NC}"
                systemctl restart shadow-bot 2>/dev/null
                sleep 1
                ;;
            3)
                if systemctl is-active --quiet shadow-bot; then
                    systemctl stop shadow-bot
                    echo -e "${YELLOW}🛑 Bot stopped${NC}"
                else
                    systemctl start shadow-bot
                    echo -e "${GREEN}🚀 Bot started${NC}"
                fi
                sleep 1
                ;;
            4)
                echo ""
                systemctl status shadow-bot --no-pager -l
                echo ""
                echo -n "Press Enter to continue..."
                read
                ;;
            5)
                break
                ;;
        esac
    done
}

domain_management() {
    while true; do
        echo ""
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${PURPLE}   🌐 DOMAIN MANAGEMENT${NC}"
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
            echo -e "  Current Domain: ${GREEN}$(cat $DOMAIN_FILE)${NC}"
        else
            echo -e "  Current: ${YELLOW}Using IP: $(curl -s ifconfig.me)${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1.${NC} ${WHITE}Set/Change Domain${NC}"
        echo -e "  ${GREEN}2.${NC} ${WHITE}Get Free SSL${NC}"
        echo -e "  ${GREEN}3.${NC} ${WHITE}Back${NC}"
        echo ""
        
        echo -n -e "${CYAN}Select option [1-3]: ${NC}"
        read domain_choice
        
        case $domain_choice in
            1)
                echo ""
                echo -n -e "${GREEN}Enter domain: ${NC}"
                read new_domain
                echo "$new_domain" > "$DOMAIN_FILE"
                echo -e "${GREEN}✅ Domain set!${NC}"
                sleep 1
                ;;
            2)
                echo ""
                if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
                    domain=$(cat "$DOMAIN_FILE")
                    echo -n -e "${GREEN}Enter your email: ${NC}"
                    read email
                    systemctl stop nginx 2>/dev/null
                    certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email "$email"
                else
                    echo -e "${RED}❌ Set domain first!${NC}"
                fi
                sleep 2
                ;;
            3)
                break
                ;;
        esac
    done
}

server_status() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📈 SERVER STATUS${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_total=$(free -m | awk 'NR==2{print $2}')
    mem_percent=$(echo "scale=1; $mem_used * 100 / $mem_total" | bc)
    uptime=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    
    monitor_status=$(systemctl is-active traffic-monitor 2>/dev/null)
    bot_status=$(systemctl is-active shadow-bot 2>/dev/null)
    
    PING_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_ping';")
    PING_VALUE=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='ping_value';")
    
    echo -e "  ${WHITE}🖥  CPU Usage:${NC} ${YELLOW}${cpu}%${NC}"
    echo -e "  ${WHITE}💾 RAM Usage:${NC} ${YELLOW}${mem_used}MB / ${mem_total}MB (${mem_percent}%)${NC}"
    echo -e "  ${WHITE}⏱  Uptime:${NC} ${GREEN}${uptime}${NC}"
    echo -e "  ${WHITE}🔗 Active Connections:${NC} ${CYAN}${conn}${NC}"
    echo -e "  ${WHITE}👥 Active Users:${NC} ${GREEN}${users_count}${NC}"
    echo -e "  ${WHITE}📡 Port 22:${NC} ${GREEN}Open${NC}"
    echo -e "  ${WHITE}⚡ BBR:${NC} ${GREEN}Enabled${NC}"
    echo -e "  ${WHITE}🚀 Speed:${NC} ${GREEN}SPACE SPEED${NC}"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$monitor_status" = "active" ]; then
        echo -e "  ${WHITE}📊 Monitor:${NC} ${GREEN}Running ✅${NC}"
    else
        echo -e "  ${WHITE}📊 Monitor:${NC} ${RED}Stopped ❌${NC}"
    fi
    
    if [ "$bot_status" = "active" ]; then
        echo -e "  ${WHITE}🤖 Bot:${NC} ${GREEN}Running ✅${NC}"
    else
        echo -e "  ${WHITE}🤖 Bot:${NC} ${RED}Stopped ❌${NC}"
    fi
    
    if [ "$PING_STATUS" = "enabled" ]; then
        echo -e "  ${WHITE}📡 Fake Ping:${NC} ${YELLOW}Enabled (${PING_VALUE}ms)${NC}"
    else
        echo -e "  ${WHITE}📡 Fake Ping:${NC} ${BLUE}Disabled${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
        4) view_traffic ;;
        5) fake_ping_menu ;;
        6) bot_settings ;;
        7) domain_management ;;
        8) server_status ;;
        9)
            echo ""
            echo -e "${YELLOW}🔄 Restarting all services...${NC}"
            systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null
            echo -e "${GREEN}✅ Restarted!${NC}"
            sleep 2
            ;;
        10)
            clear
            echo ""
            echo -e "${GREEN}👋 Thank you for using Shadow SSH!${NC}"
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
# Install Services
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   ⚙️  Installing Services${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Shadow SSH Precision Traffic Monitor
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

systemctl daemon-reload
systemctl enable traffic-monitor shadow-bot
systemctl restart traffic-monitor

ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

# Final Message
clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║      ${GREEN}✅ SHADOW SSH v19.1 INSTALLED!${PURPLE}                     ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 Run:${NC} ${YELLOW}shadow${NC}"
echo -e "${GREEN}⚡ SPACE SPEED Active${NC}"
echo -e "${GREEN}📡 Fake Ping: Option 5${NC}"
echo ""
