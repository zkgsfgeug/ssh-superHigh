#!/bin/bash

# =============================================
# SHADOW SSH v14.0 - FINAL WORKING
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

# پاکسازی قبلی
rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/shadow-domain.conf 2>/dev/null
systemctl stop traffic-monitor 2>/dev/null
systemctl disable traffic-monitor 2>/dev/null
pkill -9 shadow 2>/dev/null
pkill -9 traffic-monitor 2>/dev/null

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc ufw

# تنظیم SSH
sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
systemctl enable ssh 2>/dev/null
systemctl restart ssh 2>/dev/null

# باز کردن پورت
ufw allow 22/tcp 2>/dev/null

# دیتابیس
mkdir -p /var/lib/shadow
sqlite3 /var/lib/shadow/shadow.db << 'EOF'
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS traffic;
CREATE TABLE users (
    username TEXT PRIMARY KEY,
    password TEXT,
    traffic_limit INTEGER,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active'
);
CREATE TABLE traffic (
    username TEXT PRIMARY KEY,
    rx_bytes INTEGER DEFAULT 0,
    tx_bytes INTEGER DEFAULT 0,
    last_update INTEGER
);
EOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}     SHADOW SSH v14.0 - FINAL${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ==================== اسکریپت مانیتور ====================
cat > /usr/local/bin/traffic-monitor << 'MONITOR'
#!/bin/bash

DB="/var/lib/shadow/shadow.db"
INTERVAL=10

get_traffic() {
    local user=$1
    local total_rx=0
    local total_tx=0
    
    for pid in $(pgrep -u "$user" 2>/dev/null); do
        if [ -f "/proc/$pid/net/dev" ]; then
            rx=$(awk '/eth0|ens|venet|tun|tap/' /proc/$pid/net/dev 2>/dev/null | awk '{sum+=$2} END {print sum}')
            tx=$(awk '/eth0|ens|venet|tun|tap/' /proc/$pid/net/dev 2>/dev/null | awk '{sum+=$10} END {print sum}')
            total_rx=$((total_rx + ${rx:-0}))
            total_tx=$((total_tx + ${tx:-0}))
        fi
    done
    
    echo "$total_rx $total_tx"
}

while true; do
    sleep $INTERVAL
    
    sqlite3 "$DB" "SELECT username, traffic_limit FROM users WHERE status='active'" 2>/dev/null | while IFS='|' read user limit; do
        [ -z "$user" ] && continue
        
        read rx tx <<< $(get_traffic "$user")
        
        used_mb=$(((rx + tx) / 1024 / 1024))
        
        sqlite3 "$DB" "REPLACE INTO traffic VALUES ('$user', $rx, $tx, $(date +%s))" 2>/dev/null
        
        if [ "$used_mb" -ge "$limit" ]; then
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$user'" 2>/dev/null
            pkill -u "$user" 2>/dev/null
            usermod -L "$user" 2>/dev/null
            echo "$(date): User $user limited (${used_mb}/${limit} MB)" >> /var/log/shadow-monitor.log
        fi
    done
done
MONITOR

chmod +x /usr/local/bin/traffic-monitor

# سرویس مانیتور
cat > /etc/systemd/system/traffic-monitor.service << 'SERVICE'
[Unit]
Description=Traffic Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-monitor
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable traffic-monitor
systemctl start traffic-monitor

# ==================== تابع کمکی ====================
cat > /usr/local/bin/mkconfig << 'MKCONFIG'
#!/bin/bash
user="$1"
pass="$2"
server="$3"
limit="$4"

cat <<EOF
{
  "sshConfigType": "SSH-Direct",
  "remarks": "✅ ${user} | 💾 ${limit} MB",
  "sshHost": "${server}",
  "sshPort": 22,
  "sshUsername": "${user}",
  "sshPassword": "${pass}",
  "udpgwTransparentDNS": true
}
EOF
MKCONFIG

chmod +x /usr/local/bin/mkconfig

# ==================== پنل اصلی ====================
cat > /usr/local/bin/shadow << 'PANEL'
#!/bin/bash

DB="/var/lib/shadow/shadow.db"
DOMAIN_FILE="/etc/shadow-domain.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

get_ip() {
    curl -s -4 --max-time 2 ifconfig.me 2>/dev/null || \
    curl -s -4 --max-time 2 icanhazip.com 2>/dev/null || \
    curl -s -4 --max-time 2 ipinfo.io/ip 2>/dev/null || \
    echo "0.0.0.0"
}

get_server() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE" | head -1
    else
        get_ip
    fi
}

get_used() {
    local user=$1
    local used=$(sqlite3 "$DB" "SELECT (rx_bytes + tx_bytes) / 1024 / 1024 FROM traffic WHERE username='$user'" 2>/dev/null)
    echo "${used:-0}"
}

while true; do
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        SHADOW SSH v14.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "   ${YELLOW}Monitor:${NC} $(systemctl is-active traffic-monitor)"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${GREEN}1${NC}) Create User"
    echo -e "   ${CYAN}2${NC}) List Users"
    echo -e "   ${YELLOW}3${NC}) Show Config"
    echo -e "   ${GREEN}4${NC}) User Stats"
    echo -e "   ${RED}5${NC}) Delete User"
    echo -e "   ${BLUE}6${NC}) Set Domain"
    echo -e "   ${YELLOW}7${NC}) Remove Domain"
    echo -e "   ${RED}0${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -n "👉 Choose: "
    read choice
    
    case $choice in
        1)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}✨ CREATE USER${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            echo -n "👤 Username (a-z, 0-9): "
            read username
            if [[ ! "$username" =~ ^[a-z0-9]+$ ]]; then
                echo -e "${RED}❌ Invalid! Use only a-z and 0-9${NC}"
                sleep 2
                continue
            fi
            
            echo -n "🔑 Password: "
            read password
            if [ -z "$password" ]; then
                echo -e "${RED}❌ Password required!${NC}"
                sleep 2
                continue
            fi
            
            echo -n "📊 Traffic (MB): "
            read traffic
            if [[ ! "$traffic" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}❌ Must be number!${NC}"
                sleep 2
                continue
            fi
            
            echo -n "📅 Days: "
            read days
            if [[ ! "$days" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}❌ Must be number!${NC}"
                sleep 2
                continue
            fi
            
            # چک تکراری
            if sqlite3 "$DB" "SELECT username FROM users WHERE username='$username'" 2>/dev/null | grep -q "$username"; then
                echo -e "${RED}❌ User exists!${NC}"
                sleep 2
                continue
            fi
            
            # محاسبات
            expiry=$(date -d "+$days days" +%s)
            now=$(date +%s)
            server=$(get_server)
            
            # ذخیره در دیتابیس
            sqlite3 "$DB" "INSERT INTO users VALUES ('$username', '$password', $traffic, $expiry, $now, 'active')" 2>/dev/null
            sqlite3 "$DB" "INSERT INTO traffic VALUES ('$username', 0, 0, $now)" 2>/dev/null
            
            # ساخت کاربر سیستمی
            useradd -M -s /bin/false "$username" 2>/dev/null
            echo "$username:$password" | chpasswd 2>/dev/null
            
            # ساخت کانفیگ با استفاده از تابع جداگانه
            config=$(cat <<EOF
{
  "sshConfigType": "SSH-Direct",
  "remarks": "✅ ${username} | 💾 ${traffic} MB",
  "sshHost": "${server}",
  "sshPort": 22,
  "sshUsername": "${username}",
  "sshPassword": "${password}",
  "udpgwTransparentDNS": true
}
EOF
)
            b64=$(echo -n "$config" | base64 -w 0)
            
            clear
            echo -e "${GREEN}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}✅ USER CREATED!${NC}"
            echo -e "${GREEN}════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${YELLOW}📱 NPVT CONFIG:${NC}"
            echo -e "${BLUE}────────────────────────────────────────────${NC}"
            echo -e "${GREEN}npvt-ssh://${b64}${NC}"
            echo -e "${BLUE}────────────────────────────────────────────${NC}"
            echo ""
            echo -e "${CYAN}📋 Details:${NC}"
            echo -e "   Server: ${server}:22"
            echo -e "   Username: ${username}"
            echo -e "   Password: ${password}"
            echo -e "   Traffic: ${traffic} MB"
            echo -e "   Expiry: ${days} days"
            echo ""
            echo -e "${YELLOW}⚠️  Traffic is monitored every 10 seconds!${NC}"
            echo -e "${YELLOW}   User will disconnect when limit reached.${NC}"
            echo ""
            read -p "Press Enter..."
            ;;
        2)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}📋 USERS LIST${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            
            count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null)
            if [ "$count" -eq 0 ]; then
                echo -e "${RED}❌ No users${NC}"
            else
                printf "   %-15s %-12s %-10s %-10s\n" "USER" "TOTAL" "USED" "REMAIN"
                echo -e "${BLUE}────────────────────────────────────────────${NC}"
                
                sqlite3 "$DB" "SELECT username, traffic_limit, expiry, status FROM users" 2>/dev/null | while IFS='|' read user limit expiry status; do
                    used=$(get_used "$user")
                    remain=$((limit - used))
                    [ $remain -lt 0 ] && remain=0
                    days_left=$(( (expiry - $(date +%s)) / 86400 ))
                    
                    if [ "$status" = "limited" ] || [ $days_left -lt 0 ] || [ $remain -eq 0 ]; then
                        printf "   ${RED}%-15s %-12s %-10s %-10s${NC}\n" "$user" "${limit}MB" "${used}MB" "❌ DISABLED"
                    else
                        printf "   ${GREEN}✅${NC} ${GREEN}%-13s${NC} ${YELLOW}%-12s${NC} ${CYAN}%-10s${NC} ${GREEN}%s${NC}\n" "$user" "${limit}MB" "${used}MB" "${remain}MB"
                    fi
                done
            fi
            echo ""
            read -p "Press Enter..."
            ;;
        3)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}📄 SHOW CONFIG${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            echo -n "👤 Username: "
            read username
            
            data=$(sqlite3 "$DB" "SELECT password, traffic_limit FROM users WHERE username='$username'" 2>/dev/null)
            if [ -z "$data" ]; then
                echo -e "${RED}❌ User not found!${NC}"
                sleep 2
                continue
            fi
            
            pass=$(echo "$data" | cut -d'|' -f1)
            limit=$(echo "$data" | cut -d'|' -f2)
            server=$(get_server)
            
            config=$(cat <<EOF
{
  "sshConfigType": "SSH-Direct",
  "remarks": "✅ ${username} | 💾 ${limit} MB",
  "sshHost": "${server}",
  "sshPort": 22,
  "sshUsername": "${username}",
  "sshPassword": "${pass}",
  "udpgwTransparentDNS": true
}
EOF
)
            b64=$(echo -n "$config" | base64 -w 0)
            
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}📱 CONFIG FOR: ${CYAN}${username}${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${GREEN}npvt-ssh://${b64}${NC}"
            echo ""
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            read -p "Press Enter..."
            ;;
        4)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}📊 USER STATS${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            echo -n "👤 Username: "
            read username
            
            data=$(sqlite3 "$DB" "SELECT traffic_limit, expiry, status FROM users WHERE username='$username'" 2>/dev/null)
            if [ -z "$data" ]; then
                echo -e "${RED}❌ User not found!${NC}"
                sleep 2
                continue
            fi
            
            limit=$(echo "$data" | cut -d'|' -f1)
            expiry=$(echo "$data" | cut -d'|' -f2)
            status=$(echo "$data" | cut -d'|' -f3)
            used=$(get_used "$username")
            remain=$((limit - used))
            [ $remain -lt 0 ] && remain=0
            days_left=$(( (expiry - $(date +%s)) / 86400 ))
            percent=0
            [ $limit -gt 0 ] && percent=$((used * 100 / limit))
            [ $percent -gt 100 ] && percent=100
            
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${CYAN}📊 Statistics for: ${GREEN}${username}${NC}"
            echo -e "${BLUE}────────────────────────────────────────────${NC}"
            echo -e "   Total:   ${YELLOW}${limit} MB${NC}"
            echo -e "   Used:    ${RED}${used} MB${NC}"
            echo -e "   Remain:  ${GREEN}${remain} MB${NC}"
            echo -e "   Days:    ${days_left} days left${NC}"
            echo -e "   Status:  $([ "$status" = "active" ] && echo "${GREEN}ACTIVE${NC}" || echo "${RED}DISABLED${NC}")"
            
            # نوار پیشرفت
            bar_len=30
            filled=$((percent * bar_len / 100))
            echo -ne "   Progress: ["
            printf "%${filled}s" | tr ' ' '█'
            printf "%$((bar_len - filled))s" | tr ' ' '░'
            echo "] ${percent}%"
            
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            read -p "Press Enter..."
            ;;
        5)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${RED}🗑️ DELETE USER${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            echo -n "👤 Username: "
            read username
            
            if ! sqlite3 "$DB" "SELECT username FROM users WHERE username='$username'" 2>/dev/null | grep -q "$username"; then
                echo -e "${RED}❌ User not found!${NC}"
                sleep 2
                continue
            fi
            
            echo -n "⚠️ Type 'yes' to confirm: "
            read confirm
            if [ "$confirm" != "yes" ]; then
                echo -e "${YELLOW}Cancelled${NC}"
                sleep 1
                continue
            fi
            
            pkill -u "$username" 2>/dev/null
            userdel -r "$username" 2>/dev/null
            sqlite3 "$DB" "DELETE FROM users WHERE username='$username'" 2>/dev/null
            sqlite3 "$DB" "DELETE FROM traffic WHERE username='$username'" 2>/dev/null
            
            echo -e "${GREEN}✅ User deleted!${NC}"
            sleep 2
            ;;
        6)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}🌐 SET DOMAIN${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            echo -n "👉 Domain (e.g., example.com): "
            read domain
            if [ -n "$domain" ]; then
                echo "$domain" > "$DOMAIN_FILE"
                echo -e "${GREEN}✅ Domain set to: $domain${NC}"
            else
                echo -e "${RED}❌ Invalid${NC}"
            fi
            sleep 2
            ;;
        7)
            echo "" > "$DOMAIN_FILE"
            echo -e "${GREEN}✅ Domain removed. Back to IP mode.${NC}"
            sleep 2
            ;;
        0)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice!${NC}"
            sleep 1
            ;;
    esac
done
PANEL

chmod +x /usr/local/bin/shadow

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}🚀 Run:${NC} shadow"
echo ""
echo -e "${CYAN}✨ Features:${NC}"
echo -e "   • Traffic monitored every 10 seconds"
echo -e "   • Auto disconnect when limit reached"
echo -e "   • Domain or IP support"
echo -e "   • SQLite database for accuracy"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
