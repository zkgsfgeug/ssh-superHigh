#!/bin/bash

# =============================================
# SHADOW SSH v13.0 - FINAL WORKING
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# پاکسازی قبلی
pkill -9 shadow 2>/dev/null
rm -rf /usr/local/bin/shadow /etc/shadow-* /var/lib/shadow 2>/dev/null

# نصب پیش‌نیازها
apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc ufw

# تنظیم SSH
sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
systemctl enable ssh 2>/dev/null
systemctl restart ssh 2>/dev/null

# دیتابیس
mkdir -p /var/lib/shadow
sqlite3 /var/lib/shadow/shadow.db << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT,
    traffic_limit INTEGER,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS traffic (
    username TEXT,
    rx_bytes INTEGER DEFAULT 0,
    tx_bytes INTEGER DEFAULT 0,
    last_update INTEGER,
    FOREIGN KEY(username) REFERENCES users(username)
);
EOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}     SHADOW SSH v13.0 - FINAL${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ==================== اسکریپت مانیتور ====================
cat > /usr/local/bin/traffic-monitor << 'MONITOR'
#!/bin/bash

DB="/var/lib/shadow/shadow.db"

# گرفتن ترافیک دقیق از /proc
get_traffic() {
    local user=$1
    local total_rx=0
    local total_tx=0
    
    for pid in $(pgrep -u "$user" 2>/dev/null); do
        if [ -f "/proc/$pid/net/dev" ]; then
            rx=$(awk '/eth0|ens|wlan|venet|tun|tap|wg/ {sum+=$2} END {print sum}' /proc/$pid/net/dev 2>/dev/null)
            tx=$(awk '/eth0|ens|wlan|venet|tun|tap|wg/ {sum+=$10} END {print sum}' /proc/$pid/net/dev 2>/dev/null)
            total_rx=$((total_rx + ${rx:-0}))
            total_tx=$((total_tx + ${tx:-0}))
        fi
    done
    
    echo "$total_rx $total_tx"
}

while true; do
    sleep 10
    
    sqlite3 "$DB" "SELECT username, traffic_limit FROM users WHERE status='active'" 2>/dev/null | while IFS='|' read user limit; do
        [ -z "$user" ] && continue
        
        # گرفتن ترافیک
        read rx tx <<< $(get_traffic "$user")
        
        # تبدیل به مگابایت
        used_mb=$(((rx + tx) / 1024 / 1024))
        
        # ذخیره در دیتابیس
        sqlite3 "$DB" "REPLACE INTO traffic (username, rx_bytes, tx_bytes, last_update) 
                       VALUES ('$user', $rx, $tx, $(date +%s))" 2>/dev/null
        
        # بررسی محدودیت
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

# تابع گرفتن IP
get_ip() {
    curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "0.0.0.0"
}

# تابع گرفتن سرور
get_server() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE" | head -1
    else
        get_ip
    fi
}

# تابع گرفتن ترافیک مصرفی
get_used() {
    local user=$1
    sqlite3 "$DB" "SELECT (rx_bytes + tx_bytes) / 1024 / 1024 FROM traffic WHERE username='$user' ORDER BY last_update DESC LIMIT 1" 2>/dev/null | head -1
    [ -z "$used" ] && echo "0" || echo "$used"
}

# تابع ساخت کانفیگ
make_config() {
    local user=$1
    local pass=$2
    local used=$(get_used "$user")
    local limit=$(sqlite3 "$DB" "SELECT traffic_limit FROM users WHERE username='$user'" 2>/dev/null)
    local remain=$((limit - used))
    [ $remain -lt 0 ] && remain=0
    
    cat <<EOF
{
  "sshConfigType": "SSH-Direct",
  "remarks": "✅ ${user} | 💾 ${remain}MB",
  "sshHost": "$(get_server)",
  "sshPort": 22,
  "sshUsername": "$user",
  "sshPassword": "$pass",
  "udpgwTransparentDNS": true
}
EOF
}

# منو
while true; do
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        SHADOW SSH v13.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   Server: $(get_server):22"
    echo -e "   Monitor: $(systemctl is-active traffic-monitor)"
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
    echo -n "Choose: "
    read choice
    
    case $choice in
        1)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}CREATE USER${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            
            echo -n "Username (a-z,0-9): "
            read username
            [[ ! "$username" =~ ^[a-z0-9]+$ ]] && echo -e "${RED}Invalid!${NC}" && sleep 2 && continue
            
            echo -n "Password: "
            read password
            [ -z "$password" ] && echo -e "${RED}Required!${NC}" && sleep 2 && continue
            
            echo -n "Traffic (MB): "
            read traffic
            [[ ! "$traffic" =~ ^[0-9]+$ ]] && echo -e "${RED}Number only!${NC}" && sleep 2 && continue
            
            echo -n "Days: "
            read days
            [[ ! "$days" =~ ^[0-9]+$ ]] && echo -e "${RED}Number only!${NC}" && sleep 2 && continue
            
            # ذخیره
            expiry=$(date -d "+$days days" +%s)
            sqlite3 "$DB" "INSERT INTO users VALUES ('$username', '$password', $traffic, $expiry, $(date +%s), 'active')" 2>/dev/null
            sqlite3 "$DB" "INSERT INTO traffic VALUES ('$username', 0, 0, $(date +%s))" 2>/dev/null
            
            # کاربر سیستمی
            useradd -M -s /bin/false "$username" 2>/dev/null
            echo "$username:$password" | chpasswd 2>/dev/null
            
            # کانفیگ
            config=$(make_config "$username" "$password")
            b64=$(echo -n "$config" | base64 -w 0)
            
            clear
            echo -e "${GREEN}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}✅ USER CREATED${NC}"
            echo -e "${GREEN}════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${YELLOW}CONFIG:${NC}"
            echo -e "${BLUE}────────────────────────────────────────${NC}"
            echo -e "${GREEN}npvt-ssh://${b64}${NC}"
            echo -e "${BLUE}────────────────────────────────────────${NC}"
            echo ""
            echo -e "Server: $(get_server):22"
            echo -e "User: $username"
            echo -e "Pass: $password"
            echo -e "Traffic: $traffic MB"
            echo -e "Days: $days days"
            echo ""
            read -p "Press Enter..."
            ;;
        2)
            clear
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${GREEN}USERS LIST${NC}"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            
            sqlite3 "$DB" "SELECT username, traffic_limit, expiry, status FROM users" 2>/dev/null | while IFS='|' read user limit expiry status; do
                used=$(sqlite3 "$DB" "SELECT (rx_bytes + tx_bytes) / 1024 / 1024 FROM traffic WHERE username='$user' ORDER BY last_update DESC LIMIT 1" 2>/dev/null)
                [ -z "$used" ] && used=0
                remain=$((limit - used))
                [ $remain -lt 0 ] && remain=0
                days_left=$(( (expiry - $(date +%s)) / 86400 ))
                
                if [ "$status" = "limited" ] || [ $days_left -lt 0 ]; then
                    echo -e "   ${RED}❌ $user | ${used}/${limit}MB | EXPIRED${NC}"
                else
                    echo -e "   ${GREEN}✅ $user | ${used}/${limit}MB | ${remain}MB left | ${days_left}d${NC}"
                fi
            done
            echo ""
            read -p "Press Enter..."
            ;;
        3)
            clear
            echo -n "Username: "
            read username
            pass=$(sqlite3 "$DB" "SELECT password FROM users WHERE username='$username'" 2>/dev/null)
            if [ -z "$pass" ]; then
                echo -e "${RED}Not found!${NC}"
                sleep 2
                continue
            fi
            config=$(make_config "$username" "$pass")
            b64=$(echo -n "$config" | base64 -w 0)
            clear
            echo -e "${GREEN}npvt-ssh://${b64}${NC}"
            echo ""
            read -p "Press Enter..."
            ;;
        4)
            clear
            echo -n "Username: "
            read username
            data=$(sqlite3 "$DB" "SELECT traffic_limit, expiry, status FROM users WHERE username='$username'" 2>/dev/null)
            if [ -z "$data" ]; then
                echo -e "${RED}Not found!${NC}"
                sleep 2
                continue
            fi
            limit=$(echo "$data" | cut -d'|' -f1)
            expiry=$(echo "$data" | cut -d'|' -f2)
            used=$(sqlite3 "$DB" "SELECT (rx_bytes + tx_bytes) / 1024 / 1024 FROM traffic WHERE username='$username' ORDER BY last_update DESC LIMIT 1" 2>/dev/null)
            [ -z "$used" ] && used=0
            remain=$((limit - used))
            [ $remain -lt 0 ] && remain=0
            days_left=$(( (expiry - $(date +%s)) / 86400 ))
            percent=$((used * 100 / limit))
            [ $percent -gt 100 ] && percent=100
            
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo -e "${CYAN}Stats: $username${NC}"
            echo -e "${BLUE}────────────────────────────────────────────${NC}"
            echo -e "Total:  ${YELLOW}${limit} MB${NC}"
            echo -e "Used:   ${RED}${used} MB${NC}"
            echo -e "Remain: ${GREEN}${remain} MB${NC}"
            echo -e "Days:   ${days_left} days left${NC}"
            echo -e "Progress: ${percent}%"
            echo -e "${BLUE}════════════════════════════════════════════${NC}"
            echo ""
            read -p "Press Enter..."
            ;;
        5)
            clear
            echo -n "Username: "
            read username
            echo -n "Type 'yes': "
            read confirm
            [ "$confirm" != "yes" ] && continue
            pkill -u "$username" 2>/dev/null
            userdel -r "$username" 2>/dev/null
            sqlite3 "$DB" "DELETE FROM users WHERE username='$username'" 2>/dev/null
            sqlite3 "$DB" "DELETE FROM traffic WHERE username='$username'" 2>/dev/null
            echo -e "${GREEN}Deleted!${NC}"
            sleep 2
            ;;
        6)
            clear
            echo -n "Domain: "
            read domain
            [ -n "$domain" ] && echo "$domain" > /etc/shadow-domain.conf
            echo -e "${GREEN}Domain set!${NC}"
            sleep 2
            ;;
        7)
            echo "" > /etc/shadow-domain.conf
            echo -e "${GREEN}Domain removed!${NC}"
            sleep 2
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
    esac
done
PANEL

chmod +x /usr/local/bin/shadow

# باز کردن پورت
ufw allow 22/tcp 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}🚀 Run:${NC} shadow"
echo -e ""
echo -e "${CYAN}How it works:${NC}"
echo -e "  • Monitor checks traffic every 10 seconds"
echo -e "  • When limit reached → user auto-disabled"
echo -e "  • Domain support (Option 6)"
echo -e ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
