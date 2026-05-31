#!/bin/bash

# =============================================
# Shadow SSH v10.0 - FINAL STABLE
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
rm -rf /usr/local/bin/shadow /etc/shadow-* /etc/shadow-traffic 2>/dev/null
pkill -9 shadow 2>/dev/null

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
echo -e "${GREEN}   Shadow SSH v10.0 - FINAL STABLE${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# =============================================
# اسکریپت اصلی
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

# ==================== توابع اعتبارسنجی ====================

# بررسی اینکه آیا متن فقط حروف انگلیسی و اعداد است
is_valid_username() {
    local username=$1
    if [[ "$username" =~ ^[a-z0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# بررسی اینکه آیا متن فقط عدد است
is_number() {
    local num=$1
    if [[ "$num" =~ ^[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# ==================== توابع اصلی ====================

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
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            echo "$val"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

set_traffic() {
    local user=$1
    local used=$2
    echo "$used" > "${TRAFFIC_DIR}/${user}.txt"
}

check_user() {
    local user=$1
    local now=$(date +%s)
    
    local line=$(grep "^$user:" "$CONFIG_FILE" 2>/dev/null)
    [ -z "$line" ] && return 1
    
    local expiry=$(echo "$line" | cut -d: -f4)
    local max_traffic=$(echo "$line" | cut -d: -f3)
    local used_traffic=$(get_traffic "$user")
    
    [ "$now" -gt "$expiry" ] && return 1
    [ "$used_traffic" -ge "$max_traffic" ] && return 1
    
    return 0
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
    echo -e "${GREEN}        🚀 SHADOW SSH v10.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
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
    
    echo -e "${YELLOW}⚠️  Username can ONLY contain:${NC}"
    echo -e "   ${GREEN}• Lowercase letters (a-z)${NC}"
    echo -e "   ${GREEN}• Numbers (0-9)${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    
    echo -n "👤 Username: "
    read username
    
    # اعتبارسنجی نام کاربری
    if ! is_valid_username "$username"; then
        echo -e "\n${RED}❌ ERROR: Invalid username!${NC}"
        echo -e "${YELLOW}   Username must contain ONLY:${NC}"
        echo -e "   • Lowercase letters (a-z)"
        echo -e "   • Numbers (0-9)"
        echo -e "${RED}   No spaces, no Persian/Arabic letters, no uppercase!${NC}"
        sleep 3
        return
    fi
    
    echo -n "🔑 Password: "
    read password
    
    if [ -z "$password" ]; then
        echo -e "\n${RED}❌ Password cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    echo -n "📊 Traffic (MB): "
    read traffic
    
    if ! is_number "$traffic"; then
        echo -e "\n${RED}❌ Traffic must be a number!${NC}"
        sleep 2
        return
    fi
    
    echo -n "📅 Days: "
    read days
    
    if ! is_number "$days"; then
        echo -e "\n${RED}❌ Days must be a number!${NC}"
        sleep 2
        return
    fi

    if grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ User already exists!${NC}"
        sleep 2
        return
    fi

    local expiry=$(date -d "+$days days" +%s)
    
    # ذخیره اطلاعات
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    
    # ساخت کاربر سیستمی
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    
    # مقدار اولیه ترافیک
    echo "0" > "${TRAFFIC_DIR}/${username}.txt"
    
    # ساخت کانفیگ
    local config=$(make_config "$username" "$password")
    local b64=$(echo -n "$config" | base64 -w 0)
    local npvt="npvt-ssh://${b64}"
    
    clear
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ USER CREATED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e "${YELLOW}📱 NPVT CONFIG:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt}${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e ""
    echo -e "${CYAN}📋 Connection Details:${NC}"
    echo -e "   ${GREEN}✅ Server:${NC} $(get_server)"
    echo -e "   ${GREEN}✅ Port:${NC} 22"
    echo -e "   ${GREEN}✅ Username:${NC} $username"
    echo -e "   ${GREEN}✅ Password:${NC} $password"
    echo -e "   ${GREEN}✅ Traffic:${NC} $traffic MB"
    echo -e "   ${GREEN}✅ Expiry:${NC} $days days"
    echo -e ""
    echo -e "${YELLOW}Press Enter...${NC}"
    read dummy
}

list_users() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 USERS LIST${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ No users found${NC}"
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
                printf "   ${RED}%-15s %-10s %-10s %-10s %-10s${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB" "NO DATA"
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
        echo -e "\n${RED}❌ User not found!${NC}"
        sleep 2
        return
    fi
    
    if ! check_user "$username"; then
        echo -e "\n${RED}⚠️ User is expired or out of traffic!${NC}"
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
    
    # نمایش وضعیت
    local total=$(grep "^$username:" "$CONFIG_FILE" | cut -d: -f3)
    local used=$(get_traffic "$username")
    local remain=$((total - used))
    [ $remain -lt 0 ] && remain=0
    echo -e "\n${CYAN}📊 Status: ${GREEN}${remain} MB remaining${NC}"
    
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
        echo -e "\n${RED}❌ User not found!${NC}"
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
    echo -e "${CYAN}📊 Statistics for: ${GREEN}${username}${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}Total Traffic:${NC}   ${total} MB"
    echo -e "   ${RED}Used Traffic:${NC}    ${used} MB"
    echo -e "   ${GREEN}Remaining:${NC}       ${remain} MB"
    echo -e "   ${CYAN}Days Left:${NC}       ${days_left} days"
    
    # نوار پیشرفت
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    echo -ne "   ${YELLOW}Progress:${NC}        ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((bar_len - filled))s" | tr ' ' '░'
    echo "] ${percent}%"
    
    if [ $remain -lt 50 ] && [ $remain -gt 0 ]; then
        echo -e "\n${YELLOW}⚠️  Warning: Low traffic! (${remain} MB left)${NC}"
    elif [ $remain -eq 0 ]; then
        echo -e "\n${RED}❌ No traffic left! User will be disabled.${NC}"
    fi
    
    if [ $days_left -lt 3 ] && [ $days_left -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Warning: Account expires in ${days_left} days!${NC}"
    elif [ $days_left -le 0 ]; then
        echo -e "${RED}❌ Account expired!${NC}"
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
    
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ User not found!${NC}"
        sleep 2
        return
    fi
    
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
    
    echo -e "\n${GREEN}✅ User deleted successfully!${NC}"
    sleep 2
}

set_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 SET DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -n "👉 Domain (e.g., example.com): "
    read domain
    
    if [ -n "$domain" ]; then
        echo "$domain" > "$DOMAIN_FILE"
        echo -e "\n${GREEN}✅ Domain set to: $domain${NC}"
        echo -e "${YELLOW}ℹ️  New configs will use this domain${NC}"
    else
        echo -e "\n${RED}❌ Invalid domain${NC}"
    fi
    sleep 2
}

remove_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔙 REMOVE DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo "" > "$DOMAIN_FILE"
    echo -e "${GREEN}✅ Domain removed. Back to IP mode.${NC}"
    sleep 2
}

# ==================== اجرا ====================

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
        *) echo -e "${RED}❌ Invalid choice!${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# پاکسازی فایل‌های اضافی
rm -f /usr/local/bin/shadow-monitor 2>/dev/null
rm -f /etc/systemd/system/shadow-monitor.service 2>/dev/null
systemctl daemon-reload 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE! v10.0${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e ""
echo -e "${YELLOW}✨ FEATURES:${NC}"
echo -e "   ${GREEN}✅${NC} Username validation (only a-z, 0-9)"
echo -e "   ${GREEN}✅${NC} No Persian/Arabic letters allowed"
echo -e "   ${GREEN}✅${NC} Error message for invalid input"
echo -e "   ${GREEN}✅${NC} Beautiful icons in config name"
echo -e "   ${GREEN}✅${NC} Traffic management"
echo -e "   ${GREEN}✅${NC} Domain support"
echo -e ""
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
