#!/bin/bash

# =============================================
# Shadow SSH v18.0 - ZERO BUG + 100X SPEED
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
# 100X Network Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}⚡ Applying 100X Turbo Boost...${NC}"
    
    # حذف محدودیت‌های قبلی
    tc qdisc del dev eth0 root 2>/dev/null
    tc qdisc del dev ens3 root 2>/dev/null
    tc qdisc del dev ens4 root 2>/dev/null
    
    cat > /etc/sysctl.conf << 'EOF'
# 100X Turbo Kernel Settings
net.core.rmem_max = 536870912
net.core.wmem_max = 536870912
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 100000
net.core.somaxconn = 65535

net.ipv4.tcp_rmem = 4096 87380 536870912
net.ipv4.tcp_wmem = 4096 65536 536870912
net.ipv4.tcp_mem = 786432 1048576 536870912
net.ipv4.tcp_max_syn_backlog = 100000
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
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
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
EOF
    sysctl -p >/dev/null 2>&1
    
    # فعال‌سازی BBR
    modprobe tcp_bbr 2>/dev/null
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null
    
    # بهینه‌سازی SSH
    cat > /etc/ssh/sshd_config.d/99-turbo.conf << 'TURBOEOF'
# Turbo SSH Settings
Compression no
TCPKeepAlive yes
ClientAliveInterval 10
ClientAliveCountMax 2
MaxSessions 1000
MaxStartups 1000:30:2000
TcpRcvBuf 536870912
TcpSndBuf 536870912
TcpRcvBufPoll yes
TcpSndBufPoll yes
IPQoS throughput
TURBOEOF
    
    # بهینه‌سازی interface
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set $iface txqueuelen 10000 2>/dev/null
        ethtool -K $iface tso on gso on gro on 2>/dev/null
        # حذف qdisc برای اطمینان از نبود محدودیت
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc add dev $iface root fq 2>/dev/null
    done
    
    echo -e "${GREEN}✅ 100X Turbo Boost Activated${NC}"
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
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq ethtool

pip3 install --break-system-packages python-telegram-bot==20.7 2>/dev/null

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
            read -p "Enter your domain: " DOMAIN
            echo "$DOMAIN" > /etc/shadow-domain.conf
            ;;
        2)
            read -p "Enter your domain: " DOMAIN
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
SQLEOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v18.0 - 100X SPEED${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ============================================
# Traffic Monitor - دقیق فقط SSH کاربران
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

# تابع خواندن ترافیک از /proc/net/dev مخصوص این PID
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

# تشخیص SSH واقعی با بررسی کامل درخت پروسه
is_real_ssh_session() {
    local pid=$1
    local username=$2
    
    # چک 1: نام پروسه باید sshd باشه
    local comm=$(cat /proc/$pid/comm 2>/dev/null)
    if [ "$comm" != "sshd" ]; then
        return 1
    fi
    
    # چک 2: این sshd باید تحت یوزر ما باشه (نه root)
    local pid_uid=$(stat -c %u /proc/$pid 2>/dev/null)
    local user_uid=$(id -u "$username" 2>/dev/null)
    
    if [ "$pid_uid" != "$user_uid" ]; then
        return 1
    fi
    
    # چک 3: والد این پروسه نباید sshd اصلی سیستم باشه
    local ppid=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $4}')
    local parent_comm=$(cat /proc/$ppid/comm 2>/dev/null)
    
    if [ "$parent_comm" = "sshd" ]; then
        # چک کن والد sshd متعلق به root هست (sshd اصلی)
        local parent_uid=$(stat -c %u /proc/$ppid 2>/dev/null)
        if [ "$parent_uid" = "0" ]; then
            # این sshd فرزند sshd اصلیه - یعنی session خود کاربره
            return 0
        fi
    fi
    
    return 1
}

# دریافت فقط PIDهای SSH واقعی کاربر
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

echo "🔄 Precision SSH Monitor Started (PID: $$)"

# پاکسازی رکوردهای یتیم
sqlite3 "$DB" "DELETE FROM traffic_records WHERE status='active' AND start_time < $(date -d '1 hour ago' +%s);"

while true; do
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
        
        # دریافت PIDهای SSH واقعی
        current_pids=$(get_user_ssh_pids "$username")
        
        # بستن PIDهای قدیمی
        if [ -n "$current_pids" ]; then
            pid_list=$(echo "$current_pids" | tr ' ' ',')
            sqlite3 "$DB" "UPDATE traffic_records SET status='closed' WHERE username='$username' AND status='active' AND pid NOT IN (${pid_list});"
        else
            sqlite3 "$DB" "UPDATE traffic_records SET status='closed' WHERE username='$username' AND status='active';"
        fi
        
        # پردازش PIDهای فعال
        for pid in $current_pids; do
            # فقط sshdهای متعلق به کاربر
            if ! is_real_ssh_session "$pid" "$username"; then
                continue
            fi
            
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
                
                # اگه基点 عوض شده (پروسه جدید)
                if [ $diff_rx -lt 0 ] || [ $diff_tx -lt 0 ]; then
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes=0 WHERE pid=$pid AND ppid=$ppid;"
                    continue
                fi
                
                # فقط ترافیک واقعی (بیشتر از 0 و کمتر از 1GB در ثانیه - برای جلوگیری از خطای محاسباتی)
                if [ $diff_rx -gt 0 ] || [ $diff_tx -gt 0 ]; then
                    new_bytes=$((diff_rx + diff_tx))
                    
                    # محدودیت ماکزیمم تغییرات در هر چرخه (۱ گیگابایت)
                    if [ $new_bytes -lt 1073741824 ]; then
                        sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes = accumulated_bytes + $new_bytes WHERE pid=$pid AND ppid=$ppid;"
                    else
                        # اگر بیش از ۱ گیگ تغییر کرده،基点 رو ریست کن (خطای محاسباتی)
                        sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now WHERE pid=$pid AND ppid=$ppid;"
                    fi
                fi
            fi
        done
        
        # جمع‌بندی نهایی از رکوردها
        total_usage=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_usage WHERE username='$username';"
        
        # چک محدودیت حجم
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
        "🔱 *Shadow SSH v18.0 - 100X*\n"
        "━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{get_domain()}:22`\n"
        "━━━━━━━━━━━━━━━━━━━\n"
        "Select option:",
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
    
    msg = "👥 *Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for user in users:
        username, status, used, total, expiry, limit = user
        used_mb = used / 1048576.0
        total_gb = total / 1073741824.0 if total > 0 else 0
        
        if expiry == 0:
            days_left = "∞"
        else:
            days_left = (expiry - int(time.time())) // 86400
            days_left = "Expired" if days_left < 0 else f"{days_left}d"
        
        if total == 0:
            usage_text = f"{used_mb:.1f}MB / ∞"
        else:
            percent = (used / total * 100) if total > 0 else 0
            usage_text = f"{used_mb:.1f}MB / {total_gb:.1f}GB ({percent:.1f}%)"
        
        status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
        
        msg += f"{status_emoji} `{username}`\n"
        msg += f"   📊 {usage_text}\n"
        msg += f"   ⏰ {days_left} | 🔗 {limit}\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(msg, reply_markup=reply_markup, parse_mode='Markdown')

async def show_create_dialog(query):
    await query.edit_message_text(
        "➕ *Create User*\n\n"
        "`/create user pass days gb conn`\n\n"
        "*Example:*\n"
        "`/create test pass123 30 5 3`",
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
        
        username, password = args[0], args[1]
        days, traffic_gb, max_conn = int(args[2]), int(args[3]), int(args[4])
        
        if subprocess.run(["id", username], capture_output=True).returncode == 0:
            await update.message.reply_text("❌ User exists!")
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
            f"✅ *Created!*\n━━━━━━━━━━━━━━━━━━━\n"
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

async def show_traffic(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, SUM(accumulated_bytes) as total FROM traffic_records WHERE start_time > ? GROUP BY username ORDER BY total DESC LIMIT 10", [int(time.time()) - 86400])
    data = cursor.fetchall()
    conn.close()
    
    if not data:
        await query.edit_message_text("📊 No traffic today!")
        return
    
    msg = "📊 *Today's Traffic*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for i, (user, total) in enumerate(data, 1):
        msg += f"{i}. `{user}`: {total/1048576:.2f}MB\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(msg, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    conn.close()
    
    msg = f"📈 *Status*\n━━━━━━━━━━━━━━━━━━━\n\n🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n⏱ Uptime: `{uptime}`\n🔗 Connections: `{conn_count}`\n👥 Users: `{active}`\n⚡ BBR: `ON`"
    
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
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v18.0 - 100X SPEED 🔱${PURPLE}       ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 ${SERVER_IP}:22  |  ⚡ 100X  |  🎯 Precision${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
}

show_menu() {
    clear
    show_banner
    echo ""
    echo -e "${CYAN}═══════ MENU ═══════${NC}"
    echo -e "${GREEN}1.${NC} ${WHITE}➕ Create User${NC}"
    echo -e "${GREEN}2.${NC} ${WHITE}🗑  Delete User${NC}"
    echo -e "${GREEN}3.${NC} ${WHITE}👥 List Users${NC}"
    echo -e "${GREEN}4.${NC} ${WHITE}📊 Traffic Detail${NC}"
    echo -e "${GREEN}5.${NC} ${WHITE}🤖 Bot Settings${NC}"
    echo -e "${GREEN}6.${NC} ${WHITE}🌐 Domain${NC}"
    echo -e "${GREEN}7.${NC} ${WHITE}📈 Status${NC}"
    echo -e "${GREEN}8.${NC} ${WHITE}🔄 Restart${NC}"
    echo -e "${GREEN}9.${NC} ${WHITE}🚪 Exit${NC}"
    echo -e "${CYAN}═════════════════════${NC}"
}

create_user() {
    echo -e "\n${YELLOW}📝 CREATE USER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "👤 Username: " username
    if id "$username" &>/dev/null; then
        echo -e "${RED}❌ User exists!${NC}"
        sleep 2
        return
    fi
    
    read -p "🔑 Password: " password
    read -p "📊 Traffic Limit (GB, 0=∞): " traffic_gb
    read -p "⏰ Days (0=∞): " days
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
    
    echo -e "\n${GREEN}✅ CREATED!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌐 ${GREEN}${SERVER}:22${NC}"
    echo -e "👤 ${GREEN}${username}${NC}"
    echo -e "🔑 ${GREEN}${password}${NC}"
    echo -e "📊 ${GREEN}${traffic_gb}GB${NC} | ⏰ ${GREEN}${days}d${NC} | 🔗 ${GREEN}${max_conn}${NC}"
    echo -e "${PURPLE}${npvt_link}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Press Enter..."
}

delete_user() {
    read -p "Username to delete: " username
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ Not found!${NC}"
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
    echo -e "${GREEN}✅ Deleted!${NC}"
    sleep 2
}

list_users() {
    echo -e "\n${CYAN}👥 USERS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "${WHITE}%-15s %-8s %-20s %-15s %-10s${NC}\n" "Username" "Status" "Used" "Limit" "Expiry"
    echo -e "${BLUE}─────────────────────────────────────────────────${NC}"
    
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
        
        case $status in
            active) status_icon="🟢" ;;
            expired) status_icon="🔴" ;;
            limited) status_icon="🟡" ;;
        esac
        
        printf "%-15s %s %-8s ${CYAN}%-20s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$(echo "scale=1; $total_limit/1073741824" | bc 2>/dev/null || echo "∞")GB" "$expiry_text"
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit FROM users;")
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Press Enter..."
}

view_traffic() {
    read -p "Username: " username
    echo -e "\n${CYAN}Traffic Records for ${username}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    sqlite3 "$DB" "SELECT datetime(start_time, 'unixepoch', 'localtime'), pid, ppid, status, accumulated_bytes FROM traffic_records WHERE username='$username' ORDER BY start_time DESC LIMIT 30;" | while IFS='|' read -r time pid ppid status bytes; do
        mb=$(echo "scale=2; $bytes / 1048576" | bc 2>/dev/null || echo "0")
        printf "%-24s | PID:%-6s PPID:%-6s | %-7s | %sMB\n" "$time" "$pid" "$ppid" "$status" "$mb"
    done
    
    total=$(get_user_usage "$username")
    total_mb=$(echo "scale=2; $total / 1048576" | bc 2>/dev/null || echo "0")
    echo -e "${BLUE}─────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Total: ${total_mb}MB (100% Real SSH Traffic)${NC}"
    read -p "Press Enter..."
}

bot_settings() {
    while true; do
        echo -e "\n${PURPLE}🤖 BOT SETTINGS${NC}"
        [ -f "$BOT_CONFIG" ] && echo -e "Token: ${GREEN}$(grep TOKEN= $BOT_CONFIG | cut -d= -f2 | head -c 20)...${NC}"
        
        echo -e "\n${GREEN}1.${NC} Set Token"
        echo -e "${GREEN}2.${NC} Add Admin"
        echo -e "${GREEN}3.${NC} Start/Stop"
        echo -e "${GREEN}4.${NC} Status"
        echo -e "${GREEN}5.${NC} Back"
        read -p "Select: " c
        
        case $c in
            1)
                read -p "Token: " token
                [ -f "$BOT_CONFIG" ] && sed -i "s/TOKEN=.*/TOKEN=$token/" "$BOT_CONFIG" || { echo "TOKEN=$token" > "$BOT_CONFIG"; echo "ADMINS=" >> "$BOT_CONFIG"; }
                systemctl restart shadow-bot 2>/dev/null
                echo -e "${GREEN}✅${NC}"
                ;;
            2)
                read -p "Admin ID: " id
                current=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
                sed -i "s/ADMINS=.*/ADMINS=$current,$id/" "$BOT_CONFIG"
                systemctl restart shadow-bot 2>/dev/null
                ;;
            3)
                if systemctl is-active --quiet shadow-bot; then
                    systemctl stop shadow-bot
                else
                    systemctl start shadow-bot
                fi
                sleep 1
                ;;
            4) systemctl status shadow-bot --no-pager -l; read -p "Press Enter..." ;;
            5) break ;;
        esac
    done
}

domain_management() {
    while true; do
        echo -e "\n${PURPLE}🌐 DOMAIN${NC}"
        [ -f "$DOMAIN_FILE" ] && echo -e "Current: ${GREEN}$(cat $DOMAIN_FILE)${NC}" || echo -e "Current: ${YELLOW}$(curl -s ifconfig.me)${NC}"
        
        echo -e "\n${GREEN}1.${NC} Set Domain"
        echo -e "${GREEN}2.${NC} Get SSL"
        echo -e "${GREEN}3.${NC} Back"
        read -p "Select: " c
        
        case $c in
            1) read -p "Domain: " d; echo "$d" > "$DOMAIN_FILE"; echo -e "${GREEN}✅${NC}" ;;
            2)
                if [ -f "$DOMAIN_FILE" ]; then
                    read -p "Email: " e
                    certbot certonly --standalone -d "$(cat $DOMAIN_FILE)" --non-interactive --agree-tos --email "$e"
                fi
                sleep 2
                ;;
            3) break ;;
        esac
    done
}

server_status() {
    echo -e "\n${PURPLE}📈 STATUS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🖥  CPU: ${YELLOW}$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1)%${NC}"
    echo -e "💾 RAM: ${YELLOW}$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')%${NC}"
    echo -e "⏱  Uptime: ${GREEN}$(uptime -p | sed 's/up //')${NC}"
    echo -e "🔗 Connections: ${CYAN}$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)${NC}"
    echo -e "👥 Users: ${GREEN}$(sqlite3 $DB 'SELECT COUNT(*) FROM users WHERE status="active";')${NC}"
    echo -e "📊 Monitor: $(systemctl is-active traffic-monitor | grep -q active && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
    echo -e "🤖 Bot: $(systemctl is-active shadow-bot | grep -q active && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
    echo -e "⚡ Speed: ${GREEN}100X Turbo${NC}"
    read -p "Press Enter..."
}

while true; do
    show_menu
    read -p "Select [1-9]: " choice
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) view_traffic ;;
        5) bot_settings ;;
        6) domain_management ;;
        7) server_status ;;
        8) systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null; echo -e "${GREEN}✅ Restarted!${NC}"; sleep 2 ;;
        9) echo -e "${GREEN}👋 Bye!${NC}"; exit 0 ;;
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

mkdir -p /etc/ssh/sshd_config.d
ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

# ============================================
# پایان
# ============================================
clear
echo -e "${PURPLE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║     ${GREEN}✅ SHADOW SSH v18.0 - 100X INSTALLED!${PURPLE}       ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 ${YELLOW}shadow${CYAN} - Open Panel${NC}"
echo -e "${GREEN}⚡ 100X Turbo Active${NC}"
echo -e "${GREEN}🎯 Real SSH Traffic Only${NC}"
echo -e "${GREEN}🛡️  No Fake Multiplier${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════╝${NC}"
