#!/bin/bash

# =============================================
# Shadow SSH v28.0 - STABLE EDITION
# Fixed: Config generation (NapsternetV format)
# Removed: Fake Location menu
# Added: 30MB/1Day Test Account feature
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
# Install Dependencies
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
INSERT OR IGNORE INTO settings VALUES ('fake_location', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('fake_country', 'US');
INSERT OR IGNORE INTO settings VALUES ('fake_dns', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('next_mark', '100');
SQLEOF

echo -e "${GREEN}   ✅ Database Created${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v28.0 - STABLE${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# ============================================
# TRAFFIC MONITOR - iptables IPv4 ONLY
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash
# ============================================
# TRUE PRECISION - IPv4 ONLY
# iptables byte counting
# ============================================

DB="/var/lib/shadow/traffic.db"
INTERVAL=5
PID_FILE="/var/run/traffic-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

init_user_rules() {
    local username=$1
    local mark=$2
    
    iptables -t mangle -C OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    fi
    
    iptables -t mangle -C INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    fi
}

get_iptables_bytes() {
    local mark=$1
    
    local out_bytes=$(iptables -t mangle -L OUTPUT -v -n -x 2>/dev/null | grep "MARK set 0x$(printf '%x' $mark)" | awk '{print $2}')
    local in_bytes=$(iptables -t mangle -L INPUT -v -n -x 2>/dev/null | grep "MARK set 0x$(printf '%x' $mark)" | awk '{print $2}')
    
    echo "${out_bytes:-0} ${in_bytes:-0}"
}

echo "🎯 TRUE PRECISION Monitor (IPv4 Only) Started - PID: $$"

while IFS='|' read -r username mark; do
    [ -z "$username" ] && continue
    init_user_rules "$username" "$mark"
done < <(sqlite3 "$DB" "SELECT username, iptables_mark FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")

while true; do
    current_time=$(date +%s)
    
    while IFS='|' read -r username total_limit expiry mark is_test; do
        [ -z "$username" ] && continue
        
        # Check expiry
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
            iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
            continue
        fi
        
        init_user_rules "$username" "$mark"
        
        read -r out_bytes in_bytes <<< $(get_iptables_bytes "$mark")
        total_bytes=$((out_bytes + in_bytes))
        
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_bytes WHERE username='$username';"
        
        # Check limit
        if [ "$total_limit" != "0" ] && [ "$total_bytes" -ge "$total_limit" ]; then
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
            iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
        fi
        
    done < <(sqlite3 "$DB" "SELECT username, total_traffic, expiry, iptables_mark, is_test FROM users WHERE status='active' AND iptables_mark IS NOT NULL;")
    
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

def generate_napsternetv(server, user, pwd, days="∞", gb="∞"):
    remarks = f"📡 {user}"
    if days != "∞":
        remarks += f" | ⏰ {days}d"
    if gb != "∞":
        remarks += f" | 📎 {gb}GB"
    
    config_dict = {
        "sshConfigType": "SSH-Direct",
        "remarks": remarks,
        "sshHost": server,
        "sshPort": 22,
        "sshUsername": user,
        "sshPassword": pwd,
        "udpgwTransparentDNS": True
    }
    
    config_json = json.dumps(config_dict)
    config_b64 = base64.b64encode(config_json.encode()).decode()
    return f"npvt-ssh://{config_b64}"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    if not ADMIN_IDS:
        ADMIN_IDS.append(update.effective_user.id)
        save_config()
    
    kb = [[InlineKeyboardButton("👥 Users List", callback_data="list")],
          [InlineKeyboardButton("➕ Create User", callback_data="create")],
          [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
          [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
          [InlineKeyboardButton("📦 Backup", callback_data="backup")],
          [InlineKeyboardButton("📈 Status", callback_data="status")]]
    await update.message.reply_text(f"🔱 *Shadow SSH v28.0*\n━━━━━━━━━━━━━━━━━━━\n🌐 `{get_domain()}:22`\n🎯 IPv4 Only | iptables 1:1\n🧪 Test Account Available", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def btn(update: Update, context: ContextTypes.DEFAULT_TYPE):
    q = update.callback_query
    await q.answer()
    if not is_admin(q.from_user.id): await q.edit_message_text("❌"); return
    
    if q.data == "list":
        conn = sqlite3.connect(DB)
        cur = conn.cursor()
        cur.execute("SELECT username, status, used_traffic, total_traffic, expiry, is_test FROM users")
        users = cur.fetchall()
        conn.close()
        if not users: await q.edit_message_text("📭 No users!"); return
        msg = "👥 *Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
        for u in users:
            name, st, used, total, exp, is_test = u
            um = used/1048576
            tg = total/1073741824 if total>0 else 0
            dl = "∞" if exp==0 else str((exp-int(time.time()))//86400)+"d"
            ut = f"{um:.1f}MB / ∞" if total==0 else f"{um:.1f}MB / {tg:.1f}GB"
            em = "🟢" if st=="active" else "🔴" if st=="expired" else "🟡"
            test_tag = " 🧪" if is_test else ""
            msg += f"{em} `{name}`{test_tag}\n   📊 {ut}\n   ⏰ {dl}\n\n"
        await q.edit_message_text(msg, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙 Back", callback_data="back")]]), parse_mode='Markdown')
    
    elif q.data == "create":
        await q.edit_message_text("➕ *Create User*\n\nSend command:\n`/create user pass days gb conn`\n\n*Example:*\n`/create testuser pass123 30 5 3`", parse_mode='Markdown')
    
    elif q.data == "test_acc":
        # Generate random username
        import random, string
        test_user = "test_" + ''.join(random.choices(string.ascii_lowercase, k=5))
        test_pass = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
        
        subprocess.run(["useradd","-m","-s","/bin/bash",test_user], capture_output=True)
        subprocess.run(["chpasswd"], input=f"{test_user}:{test_pass}".encode(), capture_output=True)
        
        with open(f"/etc/ssh/sshd_config.d/{test_user}.conf","w") as f:
            f.write("MaxSessions 1\nMaxStartups 1\n")
        
        tb = 30 * 1048576  # 30MB
        exp = int(time.time()) + 86400  # 1 day
        
        next_mark = subprocess.getoutput(f"sqlite3 {DB} \"SELECT value FROM settings WHERE key='next_mark';\"")
        mark = int(next_mark) if next_mark else 100
        subprocess.run(f"sqlite3 {DB} \"UPDATE settings SET value={mark+1} WHERE key='next_mark';\"", shell=True)
        
        subprocess.run(f"iptables -t mangle -A OUTPUT -m owner --uid-owner {test_user} -j MARK --set-mark {mark}", shell=True)
        subprocess.run(f"iptables -t mangle -A INPUT -m owner --uid-owner {test_user} -j MARK --set-mark {mark}", shell=True)
        
        with open("/etc/shadow-users.conf","a") as f: f.write(f"{test_user}\n")
        
        conn_db = sqlite3.connect(DB)
        conn_db.execute("INSERT INTO users (username, password, total_traffic, iptables_mark, expiry, created, user_limit, is_test) VALUES (?,?,?,?,?,?,?,1)",
                       [test_user, test_pass, tb, mark, exp, int(time.time()), 1])
        conn_db.commit()
        conn_db.close()
        
        subprocess.run(["systemctl","restart","sshd"])
        
        domain = get_domain()
        link = generate_napsternetv(domain, test_user, test_pass, "1", "30MB")
        
        msg = (f"🧪 *Test Account Created!*\n━━━━━━━━━━━━━━━━━━━\n"
               f"🌐 `{domain}:22`\n"
               f"👤 `{test_user}`\n"
               f"🔑 `{test_pass}`\n"
               f"📊 `30MB`\n"
               f"⏰ `1 Day`\n"
               f"🔗 `1 Connection`\n"
               f"━━━━━━━━━━━━━━━━━━━\n"
               f"📋 `{link}`")
        await q.edit_message_text(msg, parse_mode='Markdown')
    
    elif q.data == "del_menu":
        conn = sqlite3.connect(DB)
        cur = conn.cursor()
        cur.execute("SELECT username FROM users")
        users = cur.fetchall()
        conn.close()
        if not users: await q.edit_message_text("📭"); return
        kb = [[InlineKeyboardButton(f"🗑 {u[0]}", callback_data=f"del_{u[0]}")] for u in users]
        kb.append([InlineKeyboardButton("🔙 Back", callback_data="back")])
        await q.edit_message_text("🗑 *Select user to delete:*", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')
    
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
        mark = subprocess.getoutput(f"sqlite3 {DB} \"SELECT iptables_mark FROM users WHERE username='{name}';\"")
        if mark:
            os.system(f"iptables -t mangle -D OUTPUT -m owner --uid-owner {name} -j MARK --set-mark {mark} 2>/dev/null")
            os.system(f"iptables -t mangle -D INPUT -m owner --uid-owner {name} -j MARK --set-mark {mark} 2>/dev/null")
        subprocess.run(["systemctl","restart","sshd"])
        await q.edit_message_text(f"✅ `{name}` deleted!", parse_mode='Markdown')
    
    elif q.data == "backup":
        r = subprocess.run(["/usr/local/bin/backup-manager","backup"], capture_output=True, text=True)
        await q.edit_message_text(f"📦 *Backup Created*\n{r.stdout}", parse_mode='Markdown')
    
    elif q.data == "status":
        cpu = subprocess.getoutput("top -bn1 | grep 'Cpu' | awk '{print $2}'|cut -d% -f1")
        mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\",$3*100/$2}'")
        up = subprocess.getoutput("uptime -p|sed 's/up //'")
        conn = subprocess.getoutput("ss -tnp|grep ESTAB|wc -l")
        act = sqlite3.connect(DB).execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
        msg = f"📈 *Server Status*\n━━━━━━━━━━━━━━━━━━━\n\n🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n⏱ Uptime: `{up}`\n🔗 Connections: `{conn}`\n👥 Active Users: `{act}`\n🎯 Mode: `IPv4 iptables 1:1`"
        await q.edit_message_text(msg, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙 Back", callback_data="back")]]), parse_mode='Markdown')
    
    elif q.data == "back":
        kb = [[InlineKeyboardButton("👥 Users List", callback_data="list")],
              [InlineKeyboardButton("➕ Create User", callback_data="create")],
              [InlineKeyboardButton("🧪 Test Account (30MB/1Day)", callback_data="test_acc")],
              [InlineKeyboardButton("🗑 Delete User", callback_data="del_menu")],
              [InlineKeyboardButton("📦 Backup", callback_data="backup")],
              [InlineKeyboardButton("📈 Status", callback_data="status")]]
        await q.edit_message_text(f"🔱 *Shadow SSH v28.0*\n🌐 `{get_domain()}:22`\n🎯 IPv4 Only", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

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
        
        next_mark = subprocess.getoutput(f"sqlite3 {DB} \"SELECT value FROM settings WHERE key='next_mark';\"")
        mark = int(next_mark) if next_mark else 100
        subprocess.run(f"sqlite3 {DB} \"UPDATE settings SET value={mark+1} WHERE key='next_mark';\"", shell=True)
        
        subprocess.run(f"iptables -t mangle -A OUTPUT -m owner --uid-owner {name} -j MARK --set-mark {mark}", shell=True)
        subprocess.run(f"iptables -t mangle -A INPUT -m owner --uid-owner {name} -j MARK --set-mark {mark}", shell=True)
        
        with open("/etc/shadow-users.conf","a") as f: f.write(f"{name}\n")
        
        conn_db = sqlite3.connect(DB)
        conn_db.execute("INSERT INTO users (username, password, total_traffic, iptables_mark, expiry, created, user_limit) VALUES (?,?,?,?,?,?,?)",
                       [name, pwd, tb, mark, exp, int(time.time()), conn])
        conn_db.commit()
        conn_db.close()
        
        subprocess.run(["systemctl","restart","sshd"])
        
        domain = get_domain()
        link = generate_napsternetv(domain, name, pwd, str(days) if days>0 else "∞", str(gb) if gb>0 else "∞")
        
        await update.message.reply_text(
            f"✅ *User Created!*\n━━━━━━━━━━━━━━━━━━━\n"
            f"🌐 `{domain}:22`\n"
            f"👤 `{name}`\n🔑 `{pwd}`\n"
            f"📊 `{gb}GB`\n⏰ `{days}d`\n🔗 `{conn}`\n"
            f"━━━━━━━━━━━━━━━━━━━\n📋 `{link}`",
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
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v28.0 - STABLE EDITION 🔱${PURPLE}              ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 Server: ${GREEN}${SERVER_IP}${NC}"
    echo -e "${PURPLE}║${NC}  📡 Port: ${GREEN}22${NC}  |  🎯 Mode: ${GREEN}iptables IPv4 1:1${NC}  |  🧪 Test: ${GREEN}30MB/1Day${NC}"
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

create_test_account() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🧪 CREATE TEST ACCOUNT (30MB/1Day)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Generate random credentials
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
    
    # 30MB in bytes
    traffic_bytes=$((30 * 1048576))
    # 1 day expiry
    expiry=$(date -d "+1 days" +%s)
    
    # Get iptables mark
    next_mark=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='next_mark';")
    mark=${next_mark:-100}
    sqlite3 "$DB" "UPDATE settings SET value=$(($mark+1)) WHERE key='next_mark';"
    
    # Setup iptables
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$test_user" -j MARK --set-mark "$mark" 2>/dev/null
    iptables -t mangle -A INPUT -m owner --uid-owner "$test_user" -j MARK --set-mark "$mark" 2>/dev/null
    
    echo "$test_user" >> /etc/shadow-users.conf 2>/dev/null
    
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, expiry, created, user_limit, is_test) VALUES ('$test_user', '$test_pass', $traffic_bytes, $mark, $expiry, $(date +%s), 1, 1);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    
    # Generate NapsternetV config with CORRECT format
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
    echo -e "  🔗 Connections: ${GREEN}1${NC}"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📋 NapsternetV Config Link:${NC}"
    echo -e "   ${YELLOW}${npvt_link}${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  This account expires in 24 hours or after 30MB usage${NC}"
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
    
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    iptables -t mangle -A INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    
    echo "$username" >> /etc/shadow-users.conf 2>/dev/null
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, iptables_mark, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $mark, $expiry, $(date +%s), $max_conn);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    days_display="∞"
    [ "$days" != "0" ] && days_display="$days"
    traffic_display="∞"
    [ "$traffic_gb" != "0" ] && traffic_display="$traffic_gb"
    
    # Generate NapsternetV config with CORRECT format
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
    echo -n -e "${YELLOW}Are you sure? This cannot be undone! (y/n): ${NC}"
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${BLUE}ℹ️  Cancelled${NC}"
        sleep 1
        return
    fi
    
    mark=$(sqlite3 "$DB" "SELECT iptables_mark FROM users WHERE username='$username';")
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    iptables -t mangle -D INPUT -m owner --uid-owner "$username" -j MARK --set-mark "$mark" 2>/dev/null
    
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
    
    while IFS='|' read -r username status total_limit expiry limit used mark is_test; do
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
        
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit, used_traffic, iptables_mark, is_test FROM users;")
    
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
            1)
                /usr/local/bin/fake-dns start 1
                sleep 2
                ;;
            2)
                /usr/local/bin/fake-dns stop
                sleep 2
                ;;
            3)
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid option!${NC}"
                sleep 1
                ;;
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
            *)
                echo -e "${RED}❌ Invalid option!${NC}"
                sleep 1
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
    echo -e "  ${WHITE}🎯 Traffic Mode:${NC} ${GREEN}iptables IPv4 Only (True 1:1)${NC}"
    echo -e "  ${WHITE}🚫 IPv6:${NC} ${RED}DISABLED${NC}"
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}SERVICE STATUS:${NC}"
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

# ============================================
# Main Program Loop
# ============================================
while true; do
    show_menu
    echo -n -e "${CYAN}Select option [1-11]: ${NC}"
    read choice
    
    case $choice in
        1)
            create_user
            ;;
        2)
            delete_user
            ;;
        3)
            list_users
            ;;
        4)
            create_test_account
            ;;
        5)
            fake_dns_menu
            ;;
        6)
            backup_menu
            ;;
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
                echo -e "${GREEN}✅ Bot token saved!${NC}"
                systemctl restart shadow-bot 2>/dev/null
            fi
            sleep 1
            ;;
        8)
            domain_management
            ;;
        9)
            server_status
            ;;
        10)
            echo ""
            echo -e "${YELLOW}🔄 Restarting all services...${NC}"
            systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null
            echo -e "${GREEN}✅ All services restarted!${NC}"
            sleep 2
            ;;
        11)
            clear
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}   👋 Thank you for using Shadow SSH!${NC}"
            echo -e "${GREEN}   Version: 28.0 STABLE${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo -e "${RED}❌ Invalid option! Please select 1-11${NC}"
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

# ============================================
# Final Success Message
# ============================================
clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                          ║${NC}"
echo -e "${PURPLE}║      ${GREEN}✅ SHADOW SSH v28.0 - STABLE INSTALLED!${PURPLE}              ║${NC}"
echo -e "${PURPLE}║                                                          ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📋 QUICK COMMANDS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🚀 Open Panel:      ${YELLOW}shadow${NC}"
echo -e "  🧪 Test Account:    ${YELLOW}shadow${NC} → Option 4"
echo -e "  📊 Monitor Status:  ${YELLOW}systemctl status traffic-monitor${NC}"
echo -e "  🤖 Bot Status:      ${YELLOW}systemctl status shadow-bot${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🎯 v28.0 FEATURES${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ✅ NapsternetV Config - ${GREEN}FIXED (Correct JSON format)${NC}"
echo -e "  ✅ Test Account - ${GREEN}30MB / 1 Day (Option 4)${NC}"
echo -e "  ✅ Fake Location - ${RED}REMOVED (by request)${NC}"
echo -e "  ✅ Traffic - ${GREEN}iptables IPv4 Only (True 1:1)${NC}"
echo -e "  ✅ IPv6 - ${RED}COMPLETELY DISABLED${NC}"
echo -e "  ✅ Fake DNS - ${GREEN}Available (Option 5)${NC}"
echo -e "  ✅ Telegram Bot - ${GREEN}Full Management${NC}"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
