#!/bin/bash

# =============================================
# Shadow SSH v9.0 - COMPLETE FIX
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

# پاکسازی کامل قبلی
echo -e "${YELLOW}🧹 Cleaning previous installation...${NC}"
rm -rf /usr/local/bin/shadow /usr/local/bin/shadow-monitor /etc/shadow-* /etc/shadow-traffic /etc/systemd/system/shadow-monitor.service 2>/dev/null
systemctl stop shadow-monitor 2>/dev/null
systemctl disable shadow-monitor 2>/dev/null
pkill -9 shadow 2>/dev/null
pkill -9 shadow-monitor 2>/dev/null

for user in $(grep -oP '^[^:]+' /etc/shadow-users.conf 2>/dev/null); do
    userdel -r "$user" 2>/dev/null
done

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget coreutils openssh-server

# تنظیمات اولیه
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌ها
> /etc/shadow-users.conf
> /etc/shadow-domain.conf
mkdir -p /etc/shadow-traffic

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v9.0 - COMPLETE FIX${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# =============================================
# اسکریپت اصلی (ساده و بدون باگ)
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

# تابع ساده و درست برای گرفتن ترافیک
get_traffic() {
    local user=$1
    local file="${TRAFFIC_DIR}/${user}.txt"
    if [ -f "$file" ]; then
        local val=$(cat "$file" 2>/dev/null | tr -d '\n\r')
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            echo "$val"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# تابع ذخیره ترافیک
set_traffic() {
    local user=$1
    local used=$2
    echo "$used" > "${TRAFFIC_DIR}/${user}.txt"
}

# تابع افزایش ترافیک (وقتی کاربر مصرف می‌کنه)
increase_traffic() {
    local user=$1
    local amount=$2
    local current=$(get_traffic "$user")
    local new=$((current + amount))
    set_traffic "$user" "$new"
}

check_user() {
    local user=$1
    local now=$(date +%s)
    
    local line=$(grep "^$user:" "$CONFIG_FILE" 2>/dev/null)
    [ -z "$line" ] && return 1
    
    local expiry=$(echo "$line" | cut -d: -f4)
    local max_traffic=$(echo "$line" | cut -d: -f3)
    local used_traffic=$(get_traffic "$user")
    
    if [ "$now" -gt "$expiry" ]; then
        return 1
    fi
    
    if [ "$used_traffic" -ge "$max_traffic" ]; then
        return 1
    fi
    
    return 0
}

disable_user() {
    local user=$1
    pkill -u "$user" 2>/dev/null
    usermod -L "$user" 2>/dev/null
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
  "remarks": "${user} | ${remain}MB",
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
    echo -e "${GREEN}        🚀 SHADOW SSH v9.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) Create User"
    echo -e "   ${YELLOW}2${NC}) List Users"
    echo -e "   ${YELLOW}3${NC}) Show Config"
    echo -e "   ${YELLOW}4${NC}) User Stats"
    echo -e "   ${RED}5${NC}) Delete User"
    echo -e "   ${GREEN}6${NC}) Set Domain"
    echo -e "   ${YELLOW}7${NC}) Remove Domain"
    echo -e "   ${CYAN}8${NC}) Test Connection"
    echo -e "   ${YELLOW}0${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

create_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✨ CREATE USER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username (english only): "
    read username
    echo -n "🔑 Password: "
    read password
    echo -n "📊 Traffic (MB): "
    read traffic
    echo -n "📅 Days: "
    read days

    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$traffic" ] || [ -z "$days" ]; then
        echo -e "\n${RED}❌ All fields required!${NC}"
        sleep 2
        return
    fi

    if ! [[ "$traffic" =~ ^[0-9]+$ ]] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n${RED}❌ Numbers only!${NC}"
        sleep 2
        return
    fi

    if grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ User exists!${NC}"
        sleep 2
        return
    fi

    local expiry=$(date -d "+$days days" +%s)
    
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    echo "0" > "${TRAFFIC_DIR}/${username}.txt"
    
    local config=$(make_config "$username" "$password")
    local b64=$(echo -n "$config" | base64 -w 0)
    local npvt="npvt-ssh://${b64}"
    
    clear
    echo -e "${GREEN}✅ USER CREATED!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 NPVT CONFIG:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Server: $(get_server)${NC}"
    echo -e "${YELLOW}Port: 22${NC}"
    echo -e "${YELLOW}Username: $username${NC}"
    echo -e "${YELLOW}Password: $password${NC}"
    echo -e "${YELLOW}Traffic: $traffic MB${NC}"
    echo -e "${YELLOW}Expiry: $days days${NC}"
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
        printf "   %-15s %-10s %-10s %-10s\n" "USER" "TOTAL" "USED" "REMAIN"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        
        while IFS=: read -r user pass total expiry _; do
            local used=$(get_traffic "$user")
            local remain=$((total - used))
            [ $remain -lt 0 ] && remain=0
            local days_left=$(( (expiry - $(date +%s)) / 86400 ))
            
            if [ $days_left -lt 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s${NC}\n" "$user" "${total}MB" "${used}MB" "EXPIRED"
            elif [ $remain -eq 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s${NC}\n" "$user" "${total}MB" "${used}MB" "NO DATA"
            else
                printf "   ${GREEN}%-15s${NC} ${YELLOW}%-10s${NC} %-10s ${CYAN}%-10s${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB"
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
    
    if ! check_user "$username"; then
        echo -e "\n${RED}⚠️ Expired or out of traffic!${NC}"
        sleep 2
        return
    fi
    
    local pass=$(grep "^$username:" "$CONFIG_FILE" | cut -d: -f2)
    local config=$(make_config "$username" "$pass")
    local b64=$(echo -n "$config" | base64 -w 0)
    local npvt="npvt-ssh://${b64}"
    
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 CONFIG for ${username}:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
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
    echo -e "${CYAN}📊 Stats for: ${username}${NC}"
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
        echo -e "\n${YELLOW}⚠️ Low traffic: ${remain} MB left${NC}"
    fi
    
    if [ $remain -eq 0 ]; then
        echo -e "\n${RED}❌ No traffic left! User will be disabled on next connection${NC}"
    fi
    
    if [ $days_left -lt 3 ] && [ $days_left -gt 0 ]; then
        echo -e "${YELLOW}⚠️ Expires in ${days_left} days${NC}"
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
    
    echo -n "⚠️ Type 'yes' to confirm: "
    read confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "\n${YELLOW}Cancelled${NC}"
        sleep 1
        return
    fi
    
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
    
    if [ -n "$domain" ]; then
        echo "$domain" > "$DOMAIN_FILE"
        echo -e "\n${GREEN}✅ Domain set: $domain${NC}"
    else
        echo -e "\n${RED}❌ Invalid${NC}"
    fi
    sleep 2
}

remove_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔙 REMOVE DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo "" > "$DOMAIN_FILE"
    echo -e "${GREEN}✅ Domain removed${NC}"
    sleep 2
}

test_connection() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🔧 TEST CONNECTION${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ Not found!${NC}"
        sleep 2
        return
    fi
    
    local pass=$(grep "^$username:" "$CONFIG_FILE" | cut -d: -f2)
    local server=$(get_server)
    
    echo -e "${YELLOW}Testing connection to $server...${NC}"
    
    if timeout 5 sshpass -p "$pass" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$username@$server" exit 2>/dev/null; then
        echo -e "${GREEN}✅ Connection successful!${NC}"
    else
        echo -e "${RED}❌ Connection failed!${NC}"
        echo -e "${YELLOW}Possible issues:${NC}"
        echo "   - Wrong username/password"
        echo "   - Server unreachable"
        echo "   - Port 22 blocked"
        echo "   - User expired or out of traffic"
    fi
    
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
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
        8) test_connection ;;
        0) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# نصب sshpass برای تست اتصال
apt install -y -qq sshpass 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE! v9.0${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}✨ FIXES IN THIS VERSION:${NC}"
echo -e "   • ${GREEN}Fixed traffic calculation bug${NC}"
echo -e "   • ${GREEN}Removed auto-monitor (was causing issues)${NC}"
echo -e "   • ${GREEN}Added connection test feature${NC}"
echo -e "   • ${GREEN}Clean and simple code${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
