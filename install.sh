#!/bin/bash

# =============================================
# Shadow SSH v11.0 - WITH REAL TRAFFIC MONITOR
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
rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /etc/shadow-* /etc/shadow-traffic /etc/systemd/system/traffic-monitor.service 2>/dev/null
pkill -9 shadow 2>/dev/null
pkill -9 traffic-monitor 2>/dev/null

for user in $(grep -oP '^[^:]+' /etc/shadow-users.conf 2>/dev/null); do
    userdel -r "$user" 2>/dev/null
done

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget coreutils openssh-server bc

# تنظیمات اولیه
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌ها
> /etc/shadow-users.conf
> /etc/shadow-domain.conf
mkdir -p /etc/shadow-traffic

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v11.0 - REAL MONITOR${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# =============================================
# اسکریپت مانیتورینگ ترافیک (هر 10 ثانیه)
# =============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
TRAFFIC_DIR="/etc/shadow-traffic"
LOG_FILE="/var/log/traffic-monitor.log"

while true; do
    sleep 10
    
    while IFS=: read -r user pass max_traffic expiry _; do
        [ -z "$user" ] && continue
        
        traffic_file="${TRAFFIC_DIR}/${user}.txt"
        [ ! -f "$traffic_file" ] && echo "0" > "$traffic_file"
        
        # محاسبه ترافیک مصرفی از /proc
        total_bytes=0
        
        # پیدا کردن PID های کاربر
        pids=$(pgrep -u "$user" 2>/dev/null)
        
        for pid in $pids; do
            if [ -d "/proc/$pid" ]; then
                # خواندن آمار شبکه از /proc
                if [ -f "/proc/$pid/net/dev" ]; then
                    rx=$(awk '/eth0|ens|wlan|venet|tun|tap/ {sum+=$2} END {print sum}' /proc/$pid/net/dev 2>/dev/null)
                    tx=$(awk '/eth0|ens|wlan|venet|tun|tap/ {sum+=$10} END {print sum}' /proc/$pid/net/dev 2>/dev/null)
                    [ -n "$rx" ] && [ -n "$tx" ] && total_bytes=$((total_bytes + rx + tx))
                fi
            fi
        done
        
        # تبدیل بایت به مگابایت
        used_mb=$((total_bytes / 1024 / 1024))
        
        # ذخیره ترافیک فعلی
        echo "$used_mb" > "$traffic_file"
        
        # بررسی محدودیت
        if [ "$used_mb" -ge "$max_traffic" ]; then
            # کاربر از محدودیت عبور کرده -> قطع کن
            pkill -u "$user" 2>/dev/null
            usermod -L "$user" 2>/dev/null
            echo "$(date): User $user disabled (${used_mb}/${max_traffic} MB)" >> "$LOG_FILE"
        fi
        
    done < "$CONFIG_FILE"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# سرویس مانیتورینگ
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
systemctl restart traffic-monitor 2>/dev/null

# =============================================
# اسکریپت اصلی پنل
# =============================================
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"
TRAFFIC_DIR="/etc/shadow-traffic"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==================== توابع ====================

is_valid_username() {
    [[ "$1" =~ ^[a-z0-9]+$ ]]
}

is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

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
    local file="${TRAFFIC_DIR}/${user}.txt"
    if [ -f "$file" ]; then
        local val=$(cat "$file" 2>/dev/null | tr -d '\n\r')
        [[ "$val" =~ ^[0-9]+$ ]] && echo "$val" || echo "0"
    else
        echo "0"
    fi
}

make_config() {
    local user=$1
    local pass=$2
    local server=$(get_server)
    local used=$(get_traffic "$user")
    local total=$(grep "^$user:" "$CONFIG_FILE" | cut -d: -f3)
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

# ==================== منو ====================

menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        🚀 SHADOW SSH v11.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "   ${GREEN}Monitor:${NC} $(systemctl is-active traffic-monitor 2>/dev/null)"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${GREEN}✅${NC} ${YELLOW}1${NC}) Create User"
    echo -e "   ${BLUE}📋${NC} ${YELLOW}2${NC}) List Users"
    echo -e "   ${CYAN}📄${NC} ${YELLOW}3${NC}) Show Config"
    echo -e "   ${GREEN}📊${NC} ${YELLOW}4${NC}) User Stats"
    echo -e "   ${RED}🗑️${NC} ${YELLOW}5${NC}) Delete User"
    echo -e "   ${CYAN}🌐${NC} ${YELLOW}6${NC}) Set Domain"
    echo -e "   ${YELLOW}🔙${NC} ${YELLOW}7${NC}) Remove Domain"
    echo -e "   ${CYAN}🔄${NC} ${YELLOW}8${NC}) Manual Refresh"
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
    
    echo -n "🔑 Password: "
    read password
    [ -z "$password" ] && { echo -e "\n${RED}❌ Required!${NC}"; sleep 2; return; }
    
    echo -n "📊 Traffic (MB): "
    read traffic
    ! is_number "$traffic" && { echo -e "\n${RED}❌ Must be number!${NC}"; sleep 2; return; }
    
    echo -n "📅 Days: "
    read days
    ! is_number "$days" && { echo -e "\n${RED}❌ Must be number!${NC}"; sleep 2; return; }

    grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null && { echo -e "\n${RED}❌ Exists!${NC}"; sleep 2; return; }

    local expiry=$(date -d "+$days days" +%s)
    
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    echo "0" > "${TRAFFIC_DIR}/${username}.txt"
    
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
    echo -e "${YELLOW}⚠️  Traffic is monitored every 10 seconds!${NC}"
    echo -e "${YELLOW}   User will be auto-disconnected when limit reached.${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

list_users() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 USERS LIST${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ No users${NC}"
    else
        printf "   %-15s %-10s %-10s %-10s %-10s\n" "USER" "TOTAL" "USED" "REMAIN" "STATUS"
        echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
        
        while IFS=: read -r user pass total expiry _; do
            local used=$(get_traffic "$user")
            local remain=$((total - used))
            [ $remain -lt 0 ] && remain=0
            local days_left=$(( (expiry - $(date +%s)) / 86400 ))
            
            if [ $days_left -lt 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s %-10s${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB" "EXPIRED"
            elif [ $remain -eq 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s %-10s${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB" "LIMIT"
            else
                printf "   ${GREEN}✅${NC} ${GREEN}%-13s${NC} ${YELLOW}%-10s${NC} %-10s ${CYAN}%-10s${NC} ${GREEN}ACTIVE${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB"
            fi
        done < "$CONFIG_FILE"
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
    
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ Not found!${NC}"
        sleep 2
        return
    fi
    
    local pass=$(grep "^$username:" "$CONFIG_FILE" | cut -d: -f2)
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
    
    local line=$(grep "^$username:" "$CONFIG_FILE" 2>/dev/null)
    if [ -z "$line" ]; then
        echo -e "\n${RED}❌ Not found!${NC}"
        sleep 2
        return
    fi
    
    local total=$(echo "$line" | cut -d: -f3)
    local expiry_ts=$(echo "$line" | cut -d: -f4)
    local used=$(get_traffic "$username")
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
    
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    echo -ne "   Progress: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((bar_len - filled))s" | tr ' ' '░'
    echo "] ${percent}%"
    
    if [ $remain -lt 50 ] && [ $remain -gt 0 ]; then
        echo -e "\n${YELLOW}⚠️  Low traffic: ${remain} MB left${NC}"
    elif [ $remain -eq 0 ]; then
        echo -e "\n${RED}❌ LIMIT REACHED! User will be disconnected.${NC}"
    fi
    
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
    sed -i "/^$username:/d" "$CONFIG_FILE"
    rm -f "${TRAFFIC_DIR}/${username}.txt"
    
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

manual_refresh() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🔄 MANUAL REFRESH${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    systemctl restart traffic-monitor
    echo -e "${GREEN}✅ Monitor restarted!${NC}"
    sleep 2
}

# ==================== اجرا ====================

while true; do
    menu
    echo -n "👉 Choose [0-8]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) user_stats ;;
        5) delete_user ;;
        6) set_domain ;;
        7) remove_domain ;;
        8) manual_refresh ;;
        0) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE! v11.0${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e ""
echo -e "${YELLOW}✨ HOW IT WORKS:${NC}"
echo -e "   ${GREEN}✅${NC} Traffic monitored every 10 seconds"
echo -e "   ${GREEN}✅${NC} User disconnected when limit reached"
echo -e "   ${GREEN}✅${NC} Real-time traffic display"
echo -e "   ${GREEN}✅${NC} No manual traffic update needed"
echo -e ""
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
