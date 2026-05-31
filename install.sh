#!/bin/bash

# =============================================
# Shadow SSH v7.0 - FULLY WORKING
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
pkill -9 shadow 2>/dev/null
rm -f /usr/local/bin/shadow 2>/dev/null

# رفع مشکلات
dpkg --configure -a 2>/dev/null
apt-get install -f -y -qq 2>/dev/null

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v7.0 - WORKING EDITION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget coreutils openssh-server dnsutils net-tools

# تنظیمات اولیه
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌ها
> /etc/shadow-users.conf
> /etc/shadow-domain.conf
mkdir -p /etc/shadow-traffic

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

# ==================== توابع ساده ====================

# گرفتن IP سرور
get_server_ip() {
    local ip=$(curl -s -4 --max-time 3 ifconfig.me 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -s -4 --max-time 3 icanhazip.com 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -s -4 --max-time 3 ipinfo.io/ip 2>/dev/null)
    [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip="0.0.0.0"
    echo "$ip"
}

# گرفتن آدرس نهایی (اولویت با دامنه)
get_server() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        local domain=$(cat "$DOMAIN_FILE" | head -1)
        [ -n "$domain" ] && echo "$domain" && return
    fi
    get_server_ip
}

# گرفتن ترافیک مصرفی (فقط از فایل)
get_traffic() {
    local user=$1
    local file="${TRAFFIC_DIR}/${user}.txt"
    if [ -f "$file" ]; then
        cat "$file" 2>/dev/null | tr -d '\n'
    else
        echo "0"
    fi
}

# ذخیره ترافیک مصرفی
set_traffic() {
    local user=$1
    local used=$2
    echo "$used" > "${TRAFFIC_DIR}/${user}.txt"
}

# بررسی اعتبار کاربر
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

# غیرفعال کردن کاربر
disable_user() {
    local user=$1
    pkill -u "$user" 2>/dev/null
    usermod -L "$user" 2>/dev/null
}

# ساخت کانفیگ
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
  "remarks": "$user | ${remain}MB",
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
    echo -e "${GREEN}        🚀 SHADOW SSH v7.0${NC}"
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
    echo -e "   ${YELLOW}0${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

# ایجاد کاربر
create_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✨ CREATE USER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
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
    echo -e "${GREEN}✅ USER CREATED!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 NPVT CONFIG:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

# لیست کاربران
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
            
            if [ $days_left -lt 0 ] || [ $remain -eq 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s${NC}\n" "$user" "${total}MB" "${used}MB" "EXPIRED"
            else
                printf "   ${GREEN}%-15s${NC} ${YELLOW}%-10s${NC} %-10s ${CYAN}%-10s${NC}\n" "$user" "${total}MB" "${used}MB" "${remain}MB"
            fi
        done < "$CONFIG_FILE"
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

# نمایش کانفیگ
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

# آمار کاربر
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
    local percent=$((used * 100 / total))
    [ $percent -gt 100 ] && percent=100
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📊 Stats for: ${username}${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   Total:   ${YELLOW}${total} MB${NC}"
    echo -e "   Used:    ${RED}${used} MB${NC}"
    echo -e "   Remain:  ${GREEN}${remain} MB${NC}"
    echo -e "   Days:    ${days_left} days left${NC}"
    echo -e "   Progress: ${percent}%"
    
    # نوار پیشرفت
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    echo -ne "   ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((bar_len - filled))s" | tr ' ' '░'
    echo "] ${percent}%"
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

# حذف کاربر
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

# ست دامنه
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

# حذف دامنه
remove_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔙 REMOVE DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo "" > "$DOMAIN_FILE"
    echo -e "${GREEN}✅ Domain removed${NC}"
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
        *) echo -e "${RED}❌ Invalid${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE! v7.0${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
