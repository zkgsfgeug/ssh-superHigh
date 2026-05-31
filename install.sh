#!/bin/bash

# =============================================
# Shadow SSH v12.0 - WITH DATABASE & ACCURATE TRACKING
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# پاکسازی کامل
echo -e "${YELLOW}🧹 Cleaning previous installation...${NC}"
rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /etc/shadow-* /etc/shadow-traffic /var/lib/shadow /etc/systemd/system/traffic-monitor.service 2>/dev/null
systemctl stop traffic-monitor 2>/dev/null
systemctl disable traffic-monitor 2>/dev/null
pkill -9 shadow 2>/dev/null
pkill -9 traffic-monitor 2>/dev/null

for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
    userdel -r "$user" 2>/dev/null
done

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget coreutils openssh-server sqlite3 bc

# تنظیمات اولیه
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد دیتابیس و دایرکتوری‌ها
mkdir -p /var/lib/shadow
sqlite3 /var/lib/shadow/traffic.db << 'SQLEOF'
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT,
    total_traffic INTEGER,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS traffic_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    timestamp INTEGER,
    rx_bytes INTEGER,
    tx_bytes INTEGER,
    total_mb INTEGER
);
CREATE INDEX IF NOT EXISTS idx_username ON traffic_log(username);
CREATE INDEX IF NOT EXISTS idx_timestamp ON traffic_log(timestamp);
SQLEOF

chmod 755 /var/lib/shadow
chmod 644 /var/lib/shadow/traffic.db

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v12.0 - DATABASE EDITION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# =============================================
# اسکریپت مانیتورینگ (IPTables-based)
# =============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
INTERVAL=10

# تابع گرفتن ترافیک از iptables
get_iptables_traffic() {
    local user=$1
    local mark=$((1000 + $(echo "$user" | cksum | cut -d' ' -f1) % 9000))
    
    # ایجاد چین جداگانه برای هر کاربر
    if ! iptables -L "USER_$user" -n 2>/dev/null | grep -q "Chain USER_$user"; then
        iptables -N "USER_$user" 2>/dev/null
        iptables -I OUTPUT -m owner --uid-owner "$user" -j "USER_$user" 2>/dev/null
        iptables -I INPUT -m owner --uid-owner "$user" -j "USER_$user" 2>/dev/null
    fi
    
    # صفر کردن قبلی
    iptables -Z "USER_$user" 2>/dev/null
    
    # خواندن ترافیک
    local rx=$(iptables -L "USER_$user" -v -n -x 2>/dev/null | grep -v "Chain" | awk '{sum+=$2} END {print sum}')
    local tx=$(iptables -L "USER_$user" -v -n -x 2>/dev/null | grep -v "Chain" | awk '{sum+=$10} END {print sum}')
    
    echo "${rx:-0} ${tx:-0}"
}

while true; do
    sleep $INTERVAL
    
    sqlite3 "$DB" "SELECT username, total_traffic, status FROM users WHERE status='active'" 2>/dev/null | while IFS='|' read user total status; do
        [ -z "$user" ] && continue
        
        # گرفتن ترافیک از روش‌های مختلف
        rx_total=0
        tx_total=0
        
        # روش 1: iptables
        iptables_data=$(get_iptables_traffic "$user")
        rx_iptables=$(echo "$iptables_data" | cut -d' ' -f1)
        tx_iptables=$(echo "$iptables_data" | cut -d' ' -f2)
        rx_total=$((rx_total + rx_iptables))
        tx_total=$((tx_total + tx_iptables))
        
        # روش 2: /proc (برای fallback)
        for pid in $(pgrep -u "$user" 2>/dev/null); do
            if [ -f "/proc/$pid/net/dev" ]; then
                rx_proc=$(awk '/eth0|ens|venet|tun|tap/ {sum+=$2} END {print sum}' /proc/$pid/net/dev 2>/dev/null)
                tx_proc=$(awk '/eth0|ens|venet|tun|tap/ {sum+=$10} END {print sum}' /proc/$pid/net/dev 2>/dev/null)
                rx_total=$((rx_total + ${rx_proc:-0}))
                tx_total=$((tx_total + ${tx_proc:-0}))
            fi
        done
        
        # تبدیل به مگابایت
        total_mb=$(((rx_total + tx_total) / 1024 / 1024))
        
        # ذخیره در دیتابیس
        sqlite3 "$DB" "INSERT INTO traffic_log (username, timestamp, rx_bytes, tx_bytes, total_mb) 
                       VALUES ('$user', $(date +%s), $rx_total, $tx_total, $total_mb)" 2>/dev/null
        
        # بروزرسانی وضعیت کاربر
        if [ "$total_mb" -ge "$total" ]; then
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$user'" 2>/dev/null
            pkill -u "$user" 2>/dev/null
            usermod -L "$user" 2>/dev/null
            echo "$(date): User $user disabled (${total_mb}/${total} MB)" >> /var/log/shadow-monitor.log
        fi
    done
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# سرویس
cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Traffic Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-monitor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable traffic-monitor 2>/dev/null
systemctl start traffic-monitor 2>/dev/null

# =============================================
# پنل اصلی
# =============================================
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
DOMAIN_FILE="/etc/shadow-domain.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

is_valid_username() { [[ "$1" =~ ^[a-z0-9]+$ ]]; }
is_number() { [[ "$1" =~ ^[0-9]+$ ]]; }

get_server_ip() {
    local ip=$(curl -s -4 --max-time 2 ifconfig.me 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -s -4 --max-time 2 icanhazip.com 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -s -4 --max-time 2 ipinfo.io/ip 2>/dev/null)
    [ -z "$ip" ] && ip="0.0.0.0"
    echo "$ip"
}

get_server() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        local domain=$(cat "$DOMAIN_FILE" | head -1)
        [ -n "$domain" ] && echo "$domain" && return
    fi
    get_server_ip
}

get_traffic() {
    local user=$1
    local total_mb=$(sqlite3 "$DB" "SELECT total_mb FROM traffic_log WHERE username='$user' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null)
    echo "${total_mb:-0}"
}

get_total_traffic() {
    local user=$1
    local total=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$user'" 2>/dev/null)
    echo "${total:-0}"
}

make_config() {
    local user=$1
    local pass=$2
    local server=$(get_server)
    local used=$(get_traffic "$user")
    local total=$(get_total_traffic "$user")
    local remain=$((total - used))
    [ $remain -lt 0 ] && remain=0
    
    cat <<EOF
{
  "sshConfigType": "SSH-Direct",
  "remarks": "✅ ${user} | 💾 ${remain} MB",
  "sshHost": "$server",
  "sshPort": 22,
  "sshUsername": "$user",
  "sshPassword": "$pass",
  "udpgwTransparentDNS": true
}
EOF
}

menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        🚀 SHADOW SSH v12.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "   ${GREEN}DB Status:${NC} $(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null) users"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${GREEN}✅${NC} ${YELLOW}1${NC}) Create User"
    echo -e "   ${BLUE}📋${NC} ${YELLOW}2${NC}) List Users"
    echo -e "   ${CYAN}📄${NC} ${YELLOW}3${NC}) Show Config"
    echo -e "   ${GREEN}📊${NC} ${YELLOW}4${NC}) User Stats"
    echo -e "   ${RED}🗑️${NC} ${YELLOW}5${NC}) Delete User"
    echo -e "   ${CYAN}🌐${NC} ${YELLOW}6${NC}) Set Domain"
    echo -e "   ${YELLOW}🔙${NC} ${YELLOW}7${NC}) Remove Domain"
    echo -e "   ${RED}❌${NC} ${YELLOW}0${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

create_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✨ CREATE USER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -e "${YELLOW}⚠️  Username: ONLY a-z and 0-9${NC}"
    echo -n "👤 Username: "
    read username
    
    if ! is_valid_username "$username"; then
        echo -e "\n${RED}❌ Invalid! Use only a-z and 0-9${NC}"
        sleep 2
        return
    fi
    
    # چک تکراری
    if sqlite3 "$DB" "SELECT username FROM users WHERE username='$username'" 2>/dev/null | grep -q "$username"; then
        echo -e "\n${RED}❌ User already exists!${NC}"
        sleep 2
        return
    fi
    
    echo -n "🔑 Password: "
    read password
    [ -z "$password" ] && { echo -e "\n${RED}❌ Required!${NC}"; sleep 2; return; }
    
    echo -n "📊 Traffic (MB): "
    read traffic
    ! is_number "$traffic" && { echo -e "\n${RED}❌ Must be number!${NC}"; sleep 2; return; }
    
    echo -n "📅 Days: "
    read days
    ! is_number "$days" && { echo -e "\n${RED}❌ Must be number!${NC}"; sleep 2; return; }

    local expiry=$(date -d "+$days days" +%s)
    local now=$(date +%s)
    
    # ذخیره در دیتابیس
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, expiry, created, status) 
                   VALUES ('$username', '$password', $traffic, $expiry, $now, 'active')" 2>/dev/null
    
    # ایجاد کاربر سیستمی
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    
    # ساخت کانفیگ
    local config=$(make_config "$username" "$password")
    local b64=$(echo -n "$config" | base64 -w 0)
    local npvt="npvt-ssh://${b64}"
    
    clear
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ USER CREATED!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e "${YELLOW}📱 NPVT CONFIG:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt}${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e ""
    echo -e "${CYAN}📋 Details:${NC}"
    echo -e "   Server: $(get_server):22"
    echo -e "   Username: $username"
    echo -e "   Password: $password"
    echo -e "   Traffic: $traffic MB"
    echo -e "   Expiry: $days days"
    echo -e ""
    echo -e "${YELLOW}Press Enter...${NC}"
    read dummy
}

list_users() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 USERS LIST${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    local count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null)
    if [ "$count" -eq 0 ]; then
        echo -e "${RED}❌ No users${NC}"
    else
        printf "   %-15s %-10s %-10s %-10s %-10s\n" "USER" "TOTAL" "USED" "REMAIN" "STATUS"
        echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
        
        sqlite3 "$DB" "SELECT username, total_traffic, expiry, status FROM users" 2>/dev/null | while IFS='|' read user total expiry status; do
            local used=$(sqlite3 "$DB" "SELECT total_mb FROM traffic_log WHERE username='$user' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null)
            [ -z "$used" ] && used=0
            local remain=$((total - used))
            [ $remain -lt 0 ] && remain=0
            local days_left=$(( (expiry - $(date +%s)) / 86400 ))
            
            if [ "$status" = "limited" ] || [ $days_left -lt 0 ] || [ $remain -eq 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s %-10s${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB" "DISABLED"
            else
                printf "   ${GREEN}✅${NC} ${GREEN}%-13s${NC} ${YELLOW}%-10s${NC} %-10s ${CYAN}%-10s${NC} ${GREEN}ACTIVE${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB"
            fi
        done
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

show_config() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📄 SHOW CONFIG${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    
    local pass=$(sqlite3 "$DB" "SELECT password FROM users WHERE username='$username'" 2>/dev/null)
    if [ -z "$pass" ]; then
        echo -e "\n${RED}❌ Not found!${NC}"
        sleep 2
        return
    fi
    
    local config=$(make_config "$username" "$pass")
    local b64=$(echo -n "$config" | base64 -w 0)
    local npvt="npvt-ssh://${b64}"
    
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📱 CONFIG FOR: ${CYAN}${username}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${npvt}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

user_stats() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 USER STATS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    
    local user_data=$(sqlite3 "$DB" "SELECT total_traffic, expiry, status FROM users WHERE username='$username'" 2>/dev/null)
    if [ -z "$user_data" ]; then
        echo -e "\n${RED}❌ Not found!${NC}"
        sleep 2
        return
    fi
    
    local total=$(echo "$user_data" | cut -d'|' -f1)
    local expiry_ts=$(echo "$user_data" | cut -d'|' -f2)
    local status=$(echo "$user_data" | cut -d'|' -f3)
    local used=$(sqlite3 "$DB" "SELECT total_mb FROM traffic_log WHERE username='$username' ORDER BY timestamp DESC LIMIT 1" 2>/dev/null)
    [ -z "$used" ] && used=0
    local remain=$((total - used))
    [ $remain -lt 0 ] && remain=0
    local days_left=$(( (expiry_ts - $(date +%s)) / 86400 ))
    local percent=0
    [ $total -gt 0 ] && percent=$((used * 100 / total))
    [ $percent -gt 100 ] && percent=100
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📊 Stats for: ${GREEN}${username}${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   Total:   ${YELLOW}${total} MB${NC}"
    echo -e "   Used:    ${RED}${used} MB${NC}"
    echo -e "   Remain:  ${GREEN}${remain} MB${NC}"
    echo -e "   Days:    ${days_left} days left${NC}"
    echo -e "   Status:  $([ "$status" = "active" ] && echo "${GREEN}ACTIVE${NC}" || echo "${RED}DISABLED${NC}")"
    
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    echo -ne "   Progress: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((bar_len - filled))s" | tr ' ' '░'
    echo "] ${percent}%"
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

delete_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${RED}🗑️ DELETE USER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    
    echo -n "⚠️ Type 'yes': "
    read confirm
    [ "$confirm" != "yes" ] && { echo -e "\n${YELLOW}Cancelled${NC}"; sleep 1; return; }
    
    pkill -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username'" 2>/dev/null
    sqlite3 "$DB" "DELETE FROM traffic_log WHERE username='$username'" 2>/dev/null
    
    echo -e "\n${GREEN}✅ Deleted!${NC}"
    sleep 2
}

set_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 SET DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -n "👉 Domain: "
    read domain
    [ -n "$domain" ] && echo "$domain" > "$DOMAIN_FILE" && echo -e "\n${GREEN}✅ Set: $domain${NC}"
    sleep 2
}

remove_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔙 REMOVE DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo "" > "$DOMAIN_FILE"
    echo -e "${GREEN}✅ Removed${NC}"
    sleep 2
}

while true; do
    menu
    echo -n "👉 Choose [0-7]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) user_stats ;;
        5) delete_user ;;
        6) set_domain ;;
        7) remove_domain ;;
        0) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE! v12.0${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e ""
echo -e "${YELLOW}✨ FEATURES:${NC}"
echo -e "   ${GREEN}✅${NC} SQLite3 Database for accurate tracking"
echo -e "   ${GREEN}✅${NC} IPTables + /proc dual monitoring"
echo -e "   ${GREEN}✅${NC} Real-time traffic updates"
echo -e "   ${GREEN}✅${NC} Auto-disable when limit reached"
echo -e ""
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
