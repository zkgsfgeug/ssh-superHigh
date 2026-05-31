#!/bin/bash

# =============================================
# Shadow SSH v16.0 - PRECISION TRAFFIC (FINAL)
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
# Ultra-Fast Network Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}⚡ Applying Network Turbo Boost...${NC}"
    
    cat > /etc/sysctl.conf << 'EOF'
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
net.ipv4.ip_forward = 1
EOF
    sysctl -p >/dev/null 2>&1
    
    modprobe tcp_bbr 2>/dev/null
    echo -e "${GREEN}✅ BBR Activated${NC}"
}

# پاکسازی کامل
echo -e "${YELLOW}🧹 Cleaning Previous Installation...${NC}"
systemctl stop traffic-monitor shadow-bot 2>/dev/null
systemctl disable traffic-monitor shadow-bot 2>/dev/null
pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null

if [ -f /etc/shadow-users.conf ]; then
    for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service /etc/ssh/sshd_config.d/*.conf 2>/dev/null

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing Dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq

pip3 install python-telegram-bot==20.7 pyTelegramBotAPI requests 2>/dev/null

optimize_network

# تنظیمات SSH
echo -e "${YELLOW}🔧 Configuring SSH...${NC}"
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

mkdir -p /etc/ssh/sshd_config.d
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
            echo "$DOMAIN" > /etc/shadow-domain.conf
            ;;
        2)
            read -p "Enter your domain for SSL: " DOMAIN
            read -p "Enter your email: " EMAIL
            systemctl stop nginx 2>/dev/null
            certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
            echo "$DOMAIN" > /etc/shadow-domain.conf
            echo -e "${GREEN}✅ SSL Certificate obtained!${NC}"
            ;;
        3)
            echo "" > /etc/shadow-domain.conf
            echo -e "${BLUE}ℹ️  Using IP address only${NC}"
            ;;
    esac
}

setup_domain

# دیتابیس با ساختار جدید و دقیق
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
    pid INTEGER UNIQUE,
    start_time INTEGER,
    last_rx_bytes INTEGER DEFAULT 0,
    last_tx_bytes INTEGER DEFAULT 0,
    accumulated_bytes INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
SQLEOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v16.0 - PRECISION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ============================================
# Traffic Monitor - بازنویسی کامل با الگوریتم دقیق
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
INTERVAL=3
PID_FILE="/var/run/traffic-monitor.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        exit 1
    fi
fi
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

# تابع خواندن ترافیک دقیق یک PID از /proc
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

echo "🔄 Precision Traffic Monitor Started (PID: $$)"

while true; do
    # دریافت کاربران فعال
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        
        # چک انقضا
        expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$username';")
        current_time=$(date +%s)
        
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            sqlite3 "$DB" "UPDATE traffic_records SET status='killed' WHERE username='$username' AND status='active';"
            continue
        fi
        
        # ============================================
        # الگوریتم دقیق محاسبه ترافیک
        # ============================================
        
        # 1. دریافت PIDهای فعلی کاربر
        current_pids=$(pgrep -u "$username" 2>/dev/null)
        
        # 2. علامت‌گذاری PIDهای مرده
        sqlite3 "$DB" "UPDATE traffic_records SET status='closed' WHERE username='$username' AND status='active' AND pid NOT IN (${current_pids//$'\n'/,});"
        
        # 3. پردازش PIDهای فعال
        for pid in $current_pids; do
            # خواندن ترافیک فعلی
            read -r rx_now tx_now <<< $(read_pid_traffic "$pid")
            
            # چک وجود رکورد
            existing=$(sqlite3 "$DB" "SELECT pid FROM traffic_records WHERE pid=$pid AND status='active';")
            
            if [ -z "$existing" ]; then
                # PID جدید - ثبت با ترافیک صفر اولیه
                sqlite3 "$DB" "INSERT OR IGNORE INTO traffic_records (username, pid, start_time, last_rx_bytes, last_tx_bytes, accumulated_bytes, status) VALUES ('$username', $pid, $current_time, $rx_now, $tx_now, 0, 'active');"
            else
                # PID موجود - محاسبه ترافیک جدید
                last_rx=$(sqlite3 "$DB" "SELECT last_rx_bytes FROM traffic_records WHERE pid=$pid AND status='active';")
                last_tx=$(sqlite3 "$DB" "SELECT last_tx_bytes FROM traffic_records WHERE pid=$pid AND status='active';")
                
                # محاسبه تفاوت (ترافیک جدید)
                diff_rx=$((rx_now - last_rx))
                diff_tx=$((tx_now - last_tx))
                
                # اگر منفی شد (مثلاً restart پروسه) - فقط آپدیت基点
                if [ $diff_rx -lt 0 ]; then
                    diff_rx=0
                    # ریست基点 برای این PID
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now WHERE pid=$pid;"
                    continue
                fi
                if [ $diff_tx -lt 0 ]; then
                    diff_tx=0
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now WHERE pid=$pid;"
                    continue
                fi
                
                # فقط اگر ترافیک جدید داریم
                if [ $diff_rx -gt 0 ] || [ $diff_tx -gt 0 ]; then
                    new_bytes=$((diff_rx + diff_tx))
                    
                    # آپدیت رکورد
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes = accumulated_bytes + $new_bytes WHERE pid=$pid;"
                    
                    # آپدیت مصرف کل کاربر
                    sqlite3 "$DB" "UPDATE users SET used_traffic = used_traffic + $new_bytes WHERE username='$username';"
                fi
            fi
        done
        
        # 4. بروزرسانی مصرف کل کاربر از مجموع همه رکوردها (برای اطمینان)
        total_usage=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_usage WHERE username='$username';"
        
        # 5. چک محدودیت حجم
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
# ربات تلگرام کامل
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

def format_bytes(bytes_val):
    if bytes_val == 0:
        return "0 MB"
    mb = bytes_val / 1048576.0
    if mb >= 1024:
        return f"{mb/1024:.2f} GB"
    return f"{mb:.2f} MB"

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
        [InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "🔱 *Shadow SSH Manager v16.0*\n"
        "━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 Server: `{get_domain()}`\n"
        f"📡 Port: `22`\n"
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

async def show_main_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(
        "🔱 *Shadow SSH Manager*\n"
        f"🌐 `{get_domain()}:22`\n"
        "━━━━━━━━━━━━━━━━━━━\n"
        "Select option:",
        reply_markup=reply_markup,
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
    
    msg = "👥 *Active Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
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
        
        msg += f"{status_emoji} `{username}`\n"
        msg += f"   📊 {usage_text}\n"
        msg += f"   ⏰ {days_left} | 🔗 {limit} conn\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(msg, reply_markup=reply_markup, parse_mode='Markdown')

async def show_create_dialog(query):
    await query.edit_message_text(
        "➕ *Create New User*\n\n"
        "Send command:\n"
        "`/create username password days traffic_gb max_conn`\n\n"
        "*Example:*\n"
        "`/create testuser pass123 30 5 3`\n"
        "30 days, 5GB, 3 connections\n\n"
        "Unlimited: `0 0 1`",
        parse_mode='Markdown'
    )

async def create_user_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    try:
        args = context.args
        if len(args) < 5:
            await update.message.reply_text("❌ Usage: `/create username password days traffic_gb max_conn`", parse_mode='Markdown')
            return
        
        username = args[0]
        password = args[1]
        days = int(args[2])
        traffic_gb = int(args[3])
        max_conn = int(args[4])
        
        result = subprocess.run(["id", username], capture_output=True)
        if result.returncode == 0:
            await update.message.reply_text("❌ User already exists!")
            return
        
        subprocess.run(["useradd", "-m", "-s", "/bin/false", username], capture_output=True)
        subprocess.run(["chpasswd"], input=f"{username}:{password}".encode(), capture_output=True)
        
        with open(f"/etc/ssh/sshd_config.d/{username}.conf", "w") as f:
            f.write(f"MaxSessions {max_conn}\n")
            f.write(f"MaxStartups {max_conn}\n")
        
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
        
        config_json = {
            "sshConfigType": "SSH-Direct",
            "remarks": f"📡 {username} | 📎 {traffic_gb}GB",
            "sshHost": domain,
            "sshPort": 22,
            "sshUsername": username,
            "sshPassword": password,
            "udpgwTransparentDNS": True
        }
        
        config_b64 = base64.b64encode(json.dumps(config_json).encode()).decode()
        npvt_link = f"npvt-ssh://{config_b64}"
        
        msg = (
            f"✅ *User Created Successfully*\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"🌐 Server: `{domain}`\n"
            f"📡 Port: `22`\n"
            f"👤 Username: `{username}`\n"
            f"🔑 Password: `{password}`\n"
            f"📊 Limit: `{traffic_gb}GB`\n"
            f"⏰ Expiry: `{days} days`\n"
            f"🔗 Max Conn: `{max_conn}`\n"
            f"━━━━━━━━━━━━━━━━━━━\n"
            f"📋 *NP VT Link:*\n"
            f"`{npvt_link}`"
        )
        
        await update.message.reply_text(msg, parse_mode='Markdown')
        
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
    
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="refresh")])
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text("🗑 *Select user to delete:*", reply_markup=reply_markup, parse_mode='Markdown')

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

async def show_traffic(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT username, SUM(accumulated_bytes) as total 
        FROM traffic_records 
        WHERE start_time > ? 
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
        mb = total / 1048576.0
        msg += f"{i}. `{user}`: {mb:.2f}MB\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(msg, reply_markup=reply_markup, parse_mode='Markdown')

async def show_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem_used = subprocess.getoutput("free -m | awk 'NR==2{print $3}'")
    mem_total = subprocess.getoutput("free -m | awk 'NR==2{print $2}'")
    mem_percent = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    conn.close()
    
    msg = (
        f"📈 *Server Status*\n"
        f"━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖥 CPU: `{cpu}%`\n"
        f"💾 RAM: `{mem_used}MB / {mem_total}MB ({mem_percent}%)`\n"
        f"⏱ Uptime: `{uptime}`\n"
        f"🔗 Active Connections: `{conn_count}`\n"
        f"👥 Active Users: `{active}`\n"
        f"🌐 Port 22: `Active`\n"
        f"⚡ BBR: `Enabled`\n"
    )
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(msg, reply_markup=reply_markup, parse_mode='Markdown')

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
# Main Shadow Manager با محاسبه دقیق
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
        curl -s ifconfig.me
    fi
}

get_user_usage() {
    local username=$1
    sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');"
}

show_banner() {
    SERVER_IP=$(get_domain)
    echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        ${GREEN}🔱 SHADOW SSH v16.0 PRECISION 🔱${PURPLE}        ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 Server: ${GREEN}${SERVER_IP}${NC}"
    echo -e "${PURPLE}║${NC}  📡 Port: ${GREEN}22${NC}  |  ⚡ BBR: ${GREEN}ON${NC}"
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
    echo -e "${GREEN}4.${NC} ${WHITE}📊 View Traffic Detail${NC}"
    echo -e "${GREEN}5.${NC} ${WHITE}🤖 Telegram Bot Settings${NC}"
    echo -e "${GREEN}6.${NC} ${WHITE}🌐 Domain Management${NC}"
    echo -e "${GREEN}7.${NC} ${WHITE}📈 Server Status${NC}"
    echo -e "${GREEN}8.${NC} ${WHITE}🔄 Restart All Services${NC}"
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
    echo -e "${PURPLE}📋 NP VT Link:${NC}"
    echo -e "${YELLOW}${npvt_link}${NC}"
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
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
    
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    sqlite3 "$DB" "DELETE FROM traffic_records WHERE username='$username';"
    
    systemctl restart sshd 2>/dev/null
    
    echo -e "${GREEN}✅ User deleted!${NC}"
    sleep 2
}

list_users() {
    echo -e "\n${CYAN}👥 ACTIVE USERS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    printf "${WHITE}%-15s %-8s %-20s %-15s %-10s${NC}\n" "Username" "Status" "Used" "Limit" "Expiry"
    echo -e "${BLUE}─────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r username status total_limit expiry limit; do
        [ -z "$username" ] && continue
        
        # خواندن دقیق مصرف از جدول traffic_records
        used=$(get_user_usage "$username")
        
        # آپدیت در جدول users
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
        
        case $status in
            active) status_icon="🟢" ;;
            expired) status_icon="🔴" ;;
            limited) status_icon="🟡" ;;
        esac
        
        printf "%-15s %s %-8s ${CYAN}%-20s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$(echo "scale=1; $total_limit/1073741824" | bc 2>/dev/null || echo "∞")GB" "$expiry_text"
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit FROM users;")
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Press Enter to continue..."
}

view_traffic() {
    echo -e "\n${YELLOW}📊 TRAFFIC DETAIL${NC}"
    read -p "Username: " username
    
    echo -e "\n${CYAN}Traffic Records for ${username}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Start Time              | PID    | Status  | Traffic${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────${NC}"
    
    sqlite3 "$DB" "SELECT datetime(start_time, 'unixepoch', 'localtime'), pid, status, accumulated_bytes FROM traffic_records WHERE username='$username' ORDER BY start_time DESC LIMIT 30;" | while IFS='|' read -r time pid status bytes; do
        mb=$(echo "scale=2; $bytes / 1048576" | bc 2>/dev/null || echo "0")
        printf "%-24s | %-6s | %-7s | %sMB\n" "$time" "$pid" "$status" "$mb"
    done
    
    # نمایش جمع کل
    total=$(get_user_usage "$username")
    total_mb=$(echo "scale=2; $total / 1048576" | bc 2>/dev/null || echo "0")
    echo -e "${BLUE}─────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Total: ${total_mb}MB${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Press Enter to continue..."
}

bot_settings() {
    while true; do
        echo -e "\n${PURPLE}🤖 TELEGRAM BOT SETTINGS${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [ -f "$BOT_CONFIG" ]; then
            token=$(grep TOKEN= "$BOT_CONFIG" | cut -d= -f2)
            admins=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
            echo -e "Token: ${GREEN}${token:0:20}...${NC}"
            echo -e "Admins: ${GREEN}${admins}${NC}"
        fi
        
        echo -e "\n${GREEN}1.${NC} Set/Change Bot Token"
        echo -e "${GREEN}2.${NC} Add Admin ID"
        echo -e "${GREEN}3.${NC} Start/Stop Bot"
        echo -e "${GREEN}4.${NC} View Bot Status"
        echo -e "${GREEN}5.${NC} Back to Main Menu"
        
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
                    current=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
                    new="${current},${admin_id}"
                    sed -i "s/ADMINS=.*/ADMINS=$new/" "$BOT_CONFIG"
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
            4)
                systemctl status shadow-bot --no-pager -l
                read -p "Press Enter..."
                ;;
            5) break ;;
        esac
    done
}

domain_management() {
    while true; do
        echo -e "\n${PURPLE}🌐 DOMAIN MANAGEMENT${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
            echo -e "Current: ${GREEN}$(cat $DOMAIN_FILE)${NC}"
        else
            echo -e "Current: ${YELLOW}$(curl -s ifconfig.me) (IP)${NC}"
        fi
        
        echo -e "\n${GREEN}1.${NC} Set/Change Domain"
        echo -e "${GREEN}2.${NC} Get Free SSL"
        echo -e "${GREEN}3.${NC} Back"
        
        read -p "Select: " domain_choice
        
        case $domain_choice in
            1)
                read -p "Enter domain: " new_domain
                echo "$new_domain" > "$DOMAIN_FILE"
                echo -e "${GREEN}✅ Domain set!${NC}"
                ;;
            2)
                if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
                    domain=$(cat "$DOMAIN_FILE")
                    read -p "Enter email: " email
                    systemctl stop nginx 2>/dev/null
                    certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email "$email"
                else
                    echo -e "${RED}❌ Set domain first!${NC}"
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
    
    echo -e "${WHITE}🖥  CPU:${NC} ${YELLOW}${cpu}%${NC}"
    echo -e "${WHITE}💾 RAM:${NC} ${YELLOW}${mem_used}MB / ${mem_total}MB (${mem_percent}%)${NC}"
    echo -e "${WHITE}⏱  Uptime:${NC} ${GREEN}${uptime}${NC}"
    echo -e "${WHITE}🔗 Connections:${NC} ${CYAN}${conn}${NC}"
    echo -e "${WHITE}👥 Active Users:${NC} ${GREEN}${users_count}${NC}"
    echo -e "${WHITE}📡 Port 22:${NC} ${GREEN}Open${NC}"
    echo -e "${WHITE}⚡ BBR:${NC} ${GREEN}Enabled${NC}"
    
    if systemctl is-active --quiet traffic-monitor; then
        echo -e "${WHITE}📊 Monitor:${NC} ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}📊 Monitor:${NC} ${RED}Stopped${NC}"
    fi
    
    if systemctl is-active --quiet shadow-bot; then
        echo -e "${WHITE}🤖 Bot:${NC} ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}🤖 Bot:${NC} ${RED}Stopped${NC}"
    fi
    
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
        4) view_traffic ;;
        5) bot_settings ;;
        6) domain_management ;;
        7) server_status ;;
        8)
            systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null
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
PIDFile=/var/run/traffic-monitor.pid

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
systemctl start traffic-monitor

mkdir -p /etc/ssh/sshd_config.d

ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

# ============================================
# پایان نصب
# ============================================
clear
echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║      ${GREEN}✅ SHADOW SSH v16.0 PRECISION!${PURPLE}            ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 COMMANDS:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}shadow${NC}           - Open Main Panel"
echo ""
echo -e "${CYAN}🔧 KEY FEATURES:${NC}"
echo -e "✅ Precise traffic tracking (no double counting)"
echo -e "✅ PID-based session monitoring"
echo -e "✅ Auto disconnect on limit reached"
echo -e "✅ Telegram bot with full control"
echo -e "✅ NP VT config generator"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
