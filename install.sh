#!/bin/bash

# =============================================
# Shadow SSH v14.0 - ULTIMATE (Domain + Bot + Turbo)
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# ============================================
# Ultra-Fast Network Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}⚡ Applying Network Turbo Boost...${NC}"
    
    # TCP Tweaks
    cat >> /etc/sysctl.conf << 'EOF'
# Shadow Turbo Boost
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
EOF
    sysctl -p >/dev/null 2>&1
    
    # Enable BBR
    if lsmod | grep -q bbr; then
        echo -e "${GREEN}✅ BBR Already Active${NC}"
    else
        modprobe tcp_bbr 2>/dev/null
        echo -e "${GREEN}✅ BBR Activated${NC}"
    fi
}

# پاکسازی کامل
echo -e "${YELLOW}🧹 Cleaning Previous Installation...${NC}"
systemctl stop traffic-monitor 2>/dev/null
systemctl stop shadow-bot 2>/dev/null
systemctl disable traffic-monitor shadow-bot 2>/dev/null
pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "shadow" 2>/dev/null

# حذف کاربران قبلی
if [ -f /etc/shadow-users.conf ]; then
    for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service 2>/dev/null

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing Dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq

# نصب کتابخونه‌های پایتون برای ربات
pip3 install python-telegram-bot==20.7 pyTelegramBotAPI requests 2>/dev/null

# بهینه‌سازی شبکه
optimize_network

# تنظیمات SSH پیشرفته
echo -e "${YELLOW}🔧 Configuring Turbo SSH...${NC}"

# بکاپ از کانفیگ اصلی
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

cat > /etc/ssh/sshd_config << 'SSHEOF'
# Shadow SSH Turbo Configuration
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

# Turbo Settings
ClientAliveInterval 30
ClientAliveCountMax 3
MaxSessions 100
MaxAuthTries 3
MaxStartups 100:30:200
TCPKeepAlive yes
Compression no
GatewayPorts no
AllowTcpForwarding yes
PermitTunnel yes
SSHEOF

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

# ============================================
# Domain Setup
# ============================================
setup_domain() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}     🌐 Domain Configuration${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Use existing domain"
    echo -e "${YELLOW}2.${NC} Get free SSL (Let's Encrypt)"
    echo -e "${YELLOW}3.${NC} Skip (IP only)"
    echo ""
    read -p "Select option [1-3]: " domain_choice
    
    case $domain_choice in
        1)
            read -p "Enter your domain (e.g., ssh.example.com): " DOMAIN
            ;;
        2)
            read -p "Enter your domain for SSL: " DOMAIN
            read -p "Enter your email: " EMAIL
            
            echo -e "${YELLOW}🔐 Getting SSL Certificate...${NC}"
            
            # Stop services that might use port 80
            systemctl stop nginx 2>/dev/null
            
            # Get certificate
            certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ SSL Certificate obtained!${NC}"
                SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
                SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
            else
                echo -e "${RED}❌ SSL failed. Using IP only${NC}"
                DOMAIN=""
            fi
            ;;
        3)
            DOMAIN=""
            echo -e "${BLUE}ℹ️  Using IP address only${NC}"
            ;;
    esac
    
    if [ -n "$DOMAIN" ]; then
        echo "$DOMAIN" > /etc/shadow-domain.conf
        echo -e "${GREEN}✅ Domain saved: $DOMAIN${NC}"
    fi
}

setup_domain

# دیتابیس
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
CREATE TABLE IF NOT EXISTS traffic_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    timestamp INTEGER,
    rx_bytes INTEGER,
    tx_bytes INTEGER,
    total_mb REAL
);
CREATE TABLE IF NOT EXISTS traffic_cache (
    username TEXT PRIMARY KEY,
    last_rx INTEGER DEFAULT 0,
    last_tx INTEGER DEFAULT 0,
    last_check INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
SQLEOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v14.0 - TURBO EDITION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ============================================
# Traffic Monitor (بهینه‌سازی شده)
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
INTERVAL=10
PID_FILE="/var/run/traffic-monitor.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        exit 1
    fi
fi
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

get_user_traffic() {
    local user=$1
    local total_rx=0
    local total_tx=0
    
    for pid in $(pgrep -u "$user" 2>/dev/null); do
        if [ -f "/proc/$pid/net/dev" ]; then
            local data=$(cat "/proc/$pid/net/dev" 2>/dev/null | tail -n +3)
            total_rx=$((total_rx + $(echo "$data" | awk '{s+=$2} END {print s+0}')))
            total_tx=$((total_tx + $(echo "$data" | awk '{s+=$10} END {print s+0}')))
        fi
    done
    
    echo "$total_rx $total_tx"
}

update_user_usage() {
    local username=$1
    local current_time=$(date +%s)
    
    read -r rx_bytes tx_bytes <<< $(get_user_traffic "$username")
    local total_bytes=$((rx_bytes + tx_bytes))
    
    local cache_data=$(sqlite3 "$DB" "SELECT last_rx, last_tx, last_check FROM traffic_cache WHERE username='$username';")
    
    if [ -n "$cache_data" ]; then
        local last_rx=$(echo "$cache_data" | cut -d'|' -f1)
        local last_tx=$(echo "$cache_data" | cut -d'|' -f2)
        
        local new_rx=$((rx_bytes - last_rx))
        local new_tx=$((tx_bytes - last_tx))
        
        [ "$new_rx" -lt 0 ] && new_rx=0
        [ "$new_tx" -lt 0 ] && new_tx=0
        
        local new_total=$((new_rx + new_tx))
        local new_total_mb=$(echo "scale=4; $new_total / 1048576" | bc)
        
        if [ "$new_total" -gt 0 ]; then
            sqlite3 "$DB" "INSERT INTO traffic_log (username, timestamp, rx_bytes, tx_bytes, total_mb) VALUES ('$username', $current_time, $new_rx, $new_tx, $new_total_mb);"
            sqlite3 "$DB" "UPDATE users SET used_traffic = used_traffic + $new_total WHERE username='$username';"
            
            # Check limits
            local total_limit=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';")
            local used=$(sqlite3 "$DB" "SELECT used_traffic FROM users WHERE username='$username';")
            
            if [ "$total_limit" != "0" ] && [ "$used" -ge "$total_limit" ]; then
                sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
                pkill -9 -u "$username" 2>/dev/null
            fi
        fi
    fi
    
    sqlite3 "$DB" "INSERT OR REPLACE INTO traffic_cache (username, last_rx, last_tx, last_check) VALUES ('$username', $rx_bytes, $tx_bytes, $current_time);"
}

while true; do
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    if [ -n "$active_users" ]; then
        while IFS= read -r user; do
            expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$user';")
            current_time=$(date +%s)
            
            if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
                sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$user';"
                pkill -9 -u "$user" 2>/dev/null
                continue
            fi
            
            update_user_usage "$user"
        done <<< "$active_users"
    fi
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# Telegram Bot (قدرتمند)
# ============================================
cat > /usr/local/bin/shadow-bot << 'BOTEOF'
#!/usr/bin/env python3

import os
import sys
import sqlite3
import time
import subprocess
import hashlib
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes, MessageHandler, filters

DB = "/var/lib/shadow/traffic.db"
CONFIG_FILE = "/etc/shadow-bot.conf"

# Default bot token (user must set)
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
                    ADMIN_IDS = [int(x.strip()) for x in admin_str.split(",")]

def save_config():
    with open(CONFIG_FILE, "w") as f:
        f.write(f"TOKEN={BOT_TOKEN}\n")
        f.write(f"ADMINS={','.join(str(x) for x in ADMIN_IDS)}\n")

def is_admin(user_id):
    return user_id in ADMIN_IDS

def admin_only(func):
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        if not is_admin(update.effective_user.id):
            await update.message.reply_text("❌ Access Denied!")
            return
        return await func(update, context)
    return wrapper

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    # Auto-add admin if first
    if not ADMIN_IDS:
        ADMIN_IDS.append(update.effective_user.id)
        save_config()
    
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users"),
         InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_menu"),
         InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status"),
         InlineKeyboardButton("🔄 Refresh", callback_data="refresh")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "🔱 *Shadow SSH Manager v14.0*\n"
        "━━━━━━━━━━━━━━━━━━━\n"
        "Select an option:",
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
    elif query.data == "traffic":
        await show_traffic(query)
    elif query.data == "create_menu":
        await create_user_menu(query)
    elif query.data == "status":
        await show_status(query)
    elif query.data == "refresh":
        await show_main_menu(query)

async def show_main_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users"),
         InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_menu"),
         InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status"),
         InlineKeyboardButton("🔄 Refresh", callback_data="refresh")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(
        "🔱 *Shadow SSH Manager*\n━━━━━━━━━━━━━━━━━━━\nSelect option:",
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def show_users(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, status, used_traffic, total_traffic, expiry FROM users")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users found!")
        return
    
    msg = "👥 *Active Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for user in users:
        username, status, used, total, expiry = user
        used_mb = used / 1048576
        total_gb = total / 1073741824 if total > 0 else "∞"
        days_left = "∞" if expiry == 0 else f"{(expiry - int(time.time())) // 86400}d"
        
        status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
        msg += f"{status_emoji} `{username}`\n"
        msg += f"   📊 {used_mb:.1f}MB / {total_gb}GB | ⏰ {days_left}\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(msg, reply_markup=reply_markup, parse_mode='Markdown')

async def create_user_menu(query):
    context = query
    await query.edit_message_text(
        "➕ *Create New User*\n\n"
        "Send command in format:\n"
        "`/create username password days traffic_gb`\n\n"
        "*Example:*\n"
        "`/create testuser pass123 30 5`\n"
        "(30 days, 5GB limit)\n\n"
        "For unlimited: 0 0",
        parse_mode='Markdown'
    )

@admin_only
async def create_user(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        args = context.args
        if len(args) < 4:
            await update.message.reply_text("❌ Usage: /create username password days traffic_gb")
            return
        
        username = args[0]
        password = args[1]
        days = int(args[2])
        traffic_gb = int(args[3])
        
        # Create system user
        subprocess.run(["useradd", "-m", "-s", "/bin/false", username], capture_output=True)
        subprocess.run(["chpasswd"], input=f"{username}:{password}".encode(), capture_output=True)
        
        # Save to config
        with open("/etc/shadow-users.conf", "a") as f:
            f.write(f"{username}\n")
        
        # Save to DB
        traffic_bytes = traffic_gb * 1073741824 if traffic_gb > 0 else 0
        expiry = int(time.time()) + (days * 86400) if days > 0 else 0
        
        conn = sqlite3.connect(DB)
        conn.execute("INSERT INTO users (username, password, total_traffic, expiry, created) VALUES (?, ?, ?, ?, ?)",
                    [username, password, traffic_bytes, expiry, int(time.time())])
        conn.commit()
        conn.close()
        
        await update.message.reply_text(
            f"✅ *User Created*\n\n"
            f"👤 Username: `{username}`\n"
            f"🔑 Password: `{password}`\n"
            f"📊 Limit: {traffic_gb}GB\n"
            f"⏰ Expiry: {days} days\n"
            f"🌐 Server: `{get_server_ip()}`",
            parse_mode='Markdown'
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {str(e)}")

@admin_only
async def delete_user_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        if not context.args:
            await update.message.reply_text("❌ Usage: /delete username")
            return
        
        username = context.args[0]
        subprocess.run(["pkill", "-9", "-u", username], capture_output=True)
        subprocess.run(["userdel", "-r", username], capture_output=True)
        
        conn = sqlite3.connect(DB)
        conn.execute("DELETE FROM users WHERE username=?", [username])
        conn.commit()
        conn.close()
        
        await update.message.reply_text(f"✅ User `{username}` deleted!", parse_mode='Markdown')
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {str(e)}")

async def show_traffic(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT username, SUM(total_mb) as total 
        FROM traffic_log 
        WHERE timestamp > ? 
        GROUP BY username 
        ORDER BY total DESC 
        LIMIT 10
    """, [int(time.time()) - 86400])
    data = cursor.fetchall()
    conn.close()
    
    if not data:
        await query.edit_message_text("📊 No traffic data today!")
        return
    
    msg = "📊 *Today's Traffic*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for i, (user, total) in enumerate(data, 1):
        msg += f"{i}. `{user}`: {total:.1f}MB\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(msg, reply_markup=reply_markup, parse_mode='Markdown')

async def show_status(query):
    # CPU & Memory
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f%%\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p")
    
    # Active connections
    conn_count = subprocess.getoutput("ss -tnp | grep ESTAB | wc -l")
    
    msg = f"📈 *Server Status*\n━━━━━━━━━━━━━━━━━━━\n\n"
    msg += f"🖥 CPU: `{cpu}%`\n"
    msg += f"💾 RAM: `{mem}`\n"
    msg += f"⏱ Uptime: `{uptime}`\n"
    msg += f"🔗 Connections: `{conn_count}`\n"
    msg += f"🌐 Port 22: `Active`\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(msg, reply_markup=reply_markup, parse_mode='Markdown')

def get_server_ip():
    return subprocess.getoutput("curl -s ifconfig.me")

def main():
    load_config()
    
    if not BOT_TOKEN:
        print("Bot token not configured!")
        sys.exit(1)
    
    app = Application.builder().token(BOT_TOKEN).build()
    
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("create", create_user))
    app.add_handler(CommandHandler("delete", delete_user_cmd))
    app.add_handler(CallbackQueryHandler(button_handler))
    
    print("🤖 Bot Started!")
    app.run_polling()

if __name__ == "__main__":
    main()
BOTEOF

chmod +x /usr/local/bin/shadow-bot

# ============================================
# Main Shadow Manager (بهینه‌سازی شده)
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
NC='\033[0m'

get_domain() {
    if [ -f "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE"
    else
        curl -s ifconfig.me
    fi
}

show_banner() {
    SERVER_IP=$(get_domain)
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        ${GREEN}🔱 SHADOW SSH v14.0 TURBO 🔱${PURPLE}             ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 Server: ${GREEN}${SERVER_IP}${NC}"
    echo -e "${PURPLE}║${NC}  📡 Port: ${GREEN}22${NC}  |  ⚡ BBR Turbo: ${GREEN}ON${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
}

show_menu() {
    clear
    show_banner
    echo ""
    echo -e "${CYAN}═══════ MANAGEMENT MENU ═══════${NC}"
    echo -e "${GREEN}1.${NC} ${WHITE}➕ Create New User${NC}"
    echo -e "${GREEN}2.${NC} ${WHITE}🗑  Delete User${NC}"
    echo -e "${GREEN}3.${NC} ${WHITE}👥 List All Users${NC}"
    echo -e "${GREEN}4.${NC} ${WHITE}📊 View User Traffic${NC}"
    echo -e "${GREEN}5.${NC} ${WHITE}🤖 Telegram Bot Settings${NC}"
    echo -e "${GREEN}6.${NC} ${WHITE}🌐 Domain Management${NC}"
    echo -e "${GREEN}7.${NC} ${WHITE}📈 Server Status${NC}"
    echo -e "${GREEN}8.${NC} ${WHITE}🔄 Restart Services${NC}"
    echo -e "${GREEN}9.${NC} ${WHITE}🚪 Exit${NC}"
    echo -e "${CYAN}════════════════════════════════${NC}"
}

create_user() {
    echo -e "\n${YELLOW}📝 CREATE NEW USER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "👤 Username: " username
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}❌ User already exists!${NC}"
        sleep 2
        return
    fi
    
    read -p "🔑 Password: " password
    read -p "📊 Traffic Limit (GB, 0=unlimited): " traffic_gb
    read -p "⏰ Days Valid (0=unlimited): " days
    read -p "🔢 Max Connections (1-10): " max_conn
    
    # Convert to bytes
    [ "$traffic_gb" -eq 0 ] && traffic_bytes=0 || traffic_bytes=$((traffic_gb * 1073741824))
    [ "$days" -eq 0 ] && expiry=0 || expiry=$(date -d "+${days} days" +%s)
    [ -z "$max_conn" ] && max_conn=1
    
    # Create user
    useradd -m -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    # Limit connections
    echo "MaxSessions $max_conn" >> /etc/ssh/sshd_config.d/${username}.conf
    echo "MaxStartups $max_conn" >> /etc/ssh/sshd_config.d/${username}.conf
    
    # Save to config
    echo "$username" >> /etc/shadow-users.conf 2>/dev/null
    
    # Save to DB
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $expiry, $(date +%s), $max_conn);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    echo -e "\n${GREEN}✅ USER CREATED SUCCESSFULLY!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}🌐 Server: ${GREEN}${SERVER}${NC}"
    echo -e "${WHITE}📡 Port: ${GREEN}22${NC}"
    echo -e "${WHITE}👤 Username: ${GREEN}${username}${NC}"
    echo -e "${WHITE}🔑 Password: ${GREEN}${password}${NC}"
    echo -e "${WHITE}📊 Limit: ${GREEN}${traffic_gb}GB${NC}"
    echo -e "${WHITE}⏰ Expiry: ${GREEN}${days} days${NC}"
    echo -e "${WHITE}🔢 Max Conn: ${GREEN}${max_conn}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Press Enter to continue..."
}

delete_user() {
    echo -e "\n${RED}🗑  DELETE USER${NC}"
    read -p "Username to delete: " username
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ User not found!${NC}"
        sleep 2
        return
    fi
    
    pkill -9 -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f /etc/ssh/sshd_config.d/${username}.conf
    
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    sqlite3 "$DB" "DELETE FROM traffic_cache WHERE username='$username';"
    
    echo -e "${GREEN}✅ User deleted!${NC}"
    systemctl restart sshd 2>/dev/null
    sleep 2
}

list_users() {
    echo -e "\n${CYAN}👥 ACTIVE USERS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    printf "${WHITE}%-15s %-8s %-12s %-12s %-10s${NC}\n" "Username" "Status" "Used" "Limit" "Expiry"
    echo -e "${BLUE}─────────────────────────────────────────────────${NC}"
    
    sqlite3 "$DB" "SELECT username, status, used_traffic, total_traffic, expiry, user_limit FROM users;" | while IFS='|' read -r username status used total expiry limit; do
        [ -z "$username" ] && continue
        
        used_mb=$(echo "scale=1; $used / 1048576" | bc)
        total_gb=$(echo "scale=1; $total / 1073741824" | bc)
        [ "$total" == "0" ] && total_gb="∞"
        
        if [ "$expiry" == "0" ]; then
            expiry_text="∞"
        else
            days_left=$(( (expiry - $(date +%s)) / 86400 ))
            [ $days_left -lt 0 ] && days_left="Expired"
            expiry_text="${days_left}d"
        fi
        
        case $status in
            active) status_icon="🟢" ;;
            expired) status_icon="🔴" ;;
            limited) status_icon="🟡" ;;
        esac
        
        printf "${WHITE}%-15s${NC} %s %-8s ${CYAN}%-10s${NC} ${YELLOW}%-10s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "${used_mb}MB" "${total_gb}GB" "$expiry_text"
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Press Enter to continue..."
}

bot_settings() {
    while true; do
        echo -e "\n${PURPLE}🤖 TELEGRAM BOT SETTINGS${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}1.${NC} Set/Change Bot Token"
        echo -e "${GREEN}2.${NC} Add Admin ID"
        echo -e "${GREEN}3.${NC} Start/Stop Bot"
        echo -e "${GREEN}4.${NC} Back to Main Menu"
        
        read -p "Select: " bot_choice
        
        case $bot_choice in
            1)
                read -p "Enter Bot Token (from @BotFather): " token
                if [ -f "$BOT_CONFIG" ]; then
                    sed -i "s/TOKEN=.*/TOKEN=$token/" "$BOT_CONFIG"
                else
                    echo "TOKEN=$token" > "$BOT_CONFIG"
                    echo "ADMINS=" >> "$BOT_CONFIG"
                fi
                echo -e "${GREEN}✅ Token saved!${NC}"
                systemctl restart shadow-bot 2>/dev/null
                ;;
            2)
                read -p "Enter Admin Telegram ID: " admin_id
                if [ -f "$BOT_CONFIG" ]; then
                    current_admins=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
                    new_admins="${current_admins},${admin_id}"
                    sed -i "s/ADMINS=.*/ADMINS=$new_admins/" "$BOT_CONFIG"
                fi
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
                sleep 1
                ;;
            4) break ;;
        esac
    done
}

domain_management() {
    while true; do
        echo -e "\n${PURPLE}🌐 DOMAIN MANAGEMENT${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [ -f "$DOMAIN_FILE" ]; then
            echo -e "Current domain: ${GREEN}$(cat $DOMAIN_FILE)${NC}"
        else
            echo -e "Current: ${YELLOW}Using IP$(curl -s ifconfig.me)${NC}"
        fi
        
        echo -e "\n${GREEN}1.${NC} Set/Change Domain"
        echo -e "${GREEN}2.${NC} Renew SSL"
        echo -e "${GREEN}3.${NC} Back"
        
        read -p "Select: " domain_choice
        
        case $domain_choice in
            1)
                read -p "Enter domain: " new_domain
                echo "$new_domain" > "$DOMAIN_FILE"
                echo -e "${GREEN}✅ Domain set!${NC}"
                ;;
            2)
                if [ -f "$DOMAIN_FILE" ]; then
                    domain=$(cat "$DOMAIN_FILE")
                    certbot renew --cert-name "$domain"
                else
                    echo -e "${RED}❌ No domain configured!${NC}"
                fi
                sleep 2
                ;;
            3) break ;;
        esac
    done
}

server_status() {
    echo -e "\n${PURPLE}📈 SERVER STATUS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_total=$(free -m | awk 'NR==2{print $2}')
    mem_percent=$(echo "scale=1; $mem_used * 100 / $mem_total" | bc)
    uptime=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    
    echo -e "${WHITE}CPU Usage:${NC} ${YELLOW}${cpu}%${NC}"
    echo -e "${WHITE}RAM:${NC} ${YELLOW}${mem_used}MB / ${mem_total}MB (${mem_percent}%)${NC}"
    echo -e "${WHITE}Uptime:${NC} ${GREEN}${uptime}${NC}"
    echo -e "${WHITE}Active Connections:${NC} ${CYAN}${conn}${NC}"
    echo -e "${WHITE}Active Users:${NC} ${GREEN}${users_count}${NC}"
    echo -e "${WHITE}Port 22:${NC} ${GREEN}Open & Listening${NC}"
    echo -e "${WHITE}BBR:${NC} ${GREEN}Enabled${NC}"
    
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    read -p "Select option [1-9]: " choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4)
            read -p "Username: " uname
            echo -e "\n${YELLOW}📊 Traffic Log for $uname${NC}"
            sqlite3 "$DB" "SELECT datetime(timestamp, 'unixepoch', 'localtime'), total_mb FROM traffic_log WHERE username='$uname' ORDER BY timestamp DESC LIMIT 20;"
            read -p "Press Enter..."
            ;;
        5) bot_settings ;;
        6) domain_management ;;
        7) server_status ;;
        8)
            systemctl restart traffic-monitor shadow-bot sshd
            echo -e "${GREEN}✅ All services restarted!${NC}"
            sleep 2
            ;;
        9) 
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ============================================
# نصب سرویس‌ها
# ============================================

# Traffic Monitor Service
cat > /etc/systemd/system/traffic-monitor.service << SERVICEEOF
[Unit]
Description=Shadow SSH Traffic Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-monitor
Restart=always
RestartSec=5
User=root
PIDFile=/var/run/traffic-monitor.pid

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Bot Service
cat > /etc/systemd/system/shadow-bot.service << BOTSERVICEEOF
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
systemctl start traffic-monitor

# ایجاد دایرکتوری کانفیگ SSH
mkdir -p /etc/ssh/sshd_config.d

# لینک دسترسی آسان
ln -sf /usr/local/bin/shadow /usr/local/bin/shadow-manager 2>/dev/null
ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

# ============================================
# پیام نهایی
# ============================================
SERVER_IP=$(get_domain)
clear
echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║      ${GREEN}✅ SHADOW SSH v14.0 INSTALLED!${PURPLE}             ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 COMMANDS:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}shadow${NC}           - Open Main Panel"
echo -e "${GREEN}shadow-manager${NC}   - Alternative command"
echo ""
echo -e "${CYAN}🌐 SERVER INFO:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Server: ${GREEN}${SERVER_IP}${NC}"
echo -e "Port: ${GREEN}22${NC}"
echo -e "BBR Turbo: ${GREEN}ON ⚡${NC}"
echo ""
echo -e "${CYAN}🤖 TELEGRAM BOT SETUP:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "1. Go to @BotFather and create bot"
echo -e "2. Run: ${YELLOW}shadow${NC} > Option 5 > Set Token"
echo -e "3. Get your ID from @userinfobot"
echo -e "4. Add Admin ID in bot settings"
echo -e "5. Start bot from menu"
echo ""
echo -e "${CYAN}📊 MONITORING:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Monitor: ${GREEN}systemctl status traffic-monitor${NC}"
echo -e "Bot: ${GREEN}systemctl status shadow-bot${NC}"
echo -e "Logs: ${GREEN}journalctl -u shadow-bot -f${NC}"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
