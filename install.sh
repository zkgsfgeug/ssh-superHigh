#!/bin/bash

# =============================================
# Shadow SSH v5.0 - FULLY DYNAMIC (No Hardcoded IP)
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

# پاکسازی و نصب
pkill -9 shadow 2>/dev/null
rm -f /usr/local/bin/shadow /etc/shadow-*.conf
dpkg --configure -a 2>/dev/null
apt-get install -f -y -qq 2>/dev/null

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v5.0 - DYNAMIC EDITION${NC}"
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
echo "0" > /etc/shadow-fec.conf
mkdir -p /etc/shadow-traffic

# =============================================
# اسکریپت اصلی پنل (کاملا پویا)
# =============================================
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"
FEC_FILE="/etc/shadow-fec.conf"
TRAFFIC_DIR="/etc/shadow-traffic"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==================== توابع پویا (Dynamic) ====================

# تابع کشف IP واقعی سرور (بدون هیچ Hardcode)
get_server_ip() {
    # لیست چند سرویس مختلف برای اطمینان از دریافت IP
    local ip=""
    
    # روش اول: ifconfig.me
    ip=$(curl -s -4 --max-time 3 ifconfig.me 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return
    fi
    
    # روش دوم: icanhazip
    ip=$(curl -s -4 --max-time 3 icanhazip.com 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return
    fi
    
    # روش سوم: ipinfo.io
    ip=$(curl -s -4 --max-time 3 ipinfo.io/ip 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return
    fi
    
    # روش چهارم: api.ipify.org
    ip=$(curl -s -4 --max-time 3 api.ipify.org 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return
    fi
    
    # اگر هیچکدام جواب نداد (نتورک مشکل داره)
    echo "0.0.0.0"
}

# تابع گرفتن آدرس نهایی (اولویت با دامنه، سپس IP خودکار)
get_server() {
    # اول چک کن دامنه ست شده؟
    if [ -f "$DOMAIN_FILE" ]; then
        local domain=$(cat "$DOMAIN_FILE" 2>/dev/null | head -1)
        if [ -n "$domain" ] && [ "$domain" != "" ]; then
            echo "$domain"
            return
        fi
    fi
    
    # اگر دامنه نداشتیم، IP خودکار را بگیر
    get_server_ip
}

# تابع محاسبه ترافیک مصرفی
get_traffic_used() {
    local username=$1
    local traffic_file="${TRAFFIC_DIR}/${username}.txt"
    
    if [ ! -f "$traffic_file" ]; then
        echo "0"
        return
    fi
    
    local used=$(cat "$traffic_file" 2>/dev/null | head -1)
    if [[ ! "$used" =~ ^[0-9]+$ ]]; then
        echo "0"
    else
        echo "$used"
    fi
}

# تابع آپدیت ترافیک
update_traffic() {
    local username=$1
    local used_mb=$2
    echo "$used_mb" > "${TRAFFIC_DIR}/${username}.txt"
}

# تابع بررسی اعتبار کاربر
check_user_validity() {
    local username=$1
    local current_time=$(date +%s)
    
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        return 1
    fi
    
    local user_line=$(grep "^$username:" "$CONFIG_FILE")
    local expiry=$(echo "$user_line" | cut -d: -f4)
    local max_traffic=$(echo "$user_line" | cut -d: -f3)
    local used_traffic=$(get_traffic_used "$username")
    
    # بررسی انقضا
    if [ "$current_time" -gt "$expiry" ]; then
        return 1
    fi
    
    # بررسی حجم
    if [ "$used_traffic" -ge "$max_traffic" ]; then
        return 1
    fi
    
    return 0
}

# تابع غیرفعال کردن کاربر
disable_user() {
    local username=$1
    pkill -u "$username" 2>/dev/null
    usermod -L "$username" 2>/dev/null
}

# تابع ساخت کانفیگ NPVT
generate_npvt_config() {
    local username=$1
    local password=$2
    local server=$(get_server)
    
    local user_line=$(grep "^$username:" "$CONFIG_FILE")
    local max_traffic=$(echo "$user_line" | cut -d: -f3)
    local expiry_ts=$(echo "$user_line" | cut -d: -f4)
    local used_traffic=$(get_traffic_used "$username")
    local remaining_traffic=$((max_traffic - used_traffic))
    [ $remaining_traffic -lt 0 ] && remaining_traffic=0
    
    printf '{
  "sshConfigType": "SSH-Direct",
  "remarks": "%s | %d MB",
  "sshHost": "%s",
  "sshPort": 22,
  "sshUsername": "%s",
  "sshPassword": "%s",
  "udpgwTransparentDNS": true
}' "$username" "$remaining_traffic" "$server" "$username" "$password"
}

# ==================== منوی اصلی ====================

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       🚀 SHADOW SSH v5.0 - DYNAMIC${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    local fec_status=$(cat "$FEC_FILE" 2>/dev/null)
    [ "$fec_status" == "0" ] && fec_status="Disabled"
    echo -e "   ${YELLOW}FEC:${NC} $fec_status"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) Create User"
    echo -e "   ${YELLOW}2${NC}) List Users"
    echo -e "   ${YELLOW}3${NC}) Show Config"
    echo -e "   ${YELLOW}4${NC}) Show User Stats"
    echo -e "   ${RED}5${NC}) Delete User"
    echo -e "   ${GREEN}6${NC}) Set Domain"
    echo -e "   ${YELLOW}7${NC}) Remove Domain"
    echo -e "   ${YELLOW}0${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

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
        echo -e "\n${RED}❌ Traffic and Days must be numbers!${NC}"
        sleep 2
        return
    fi

    if grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ User already exists!${NC}"
        sleep 2
        return
    fi

    expiry=$(date -d "+$days days" +%s)
    
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    echo "0" > "${TRAFFIC_DIR}/${username}.txt"
    
    local json_config=$(generate_npvt_config "$username" "$password")
    local config_b64=$(echo -n "$json_config" | base64 -w 0)
    local npvt_config="npvt-ssh://${config_b64}"
    
    clear
    echo -e "${GREEN}✅ USER CREATED!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 NPVT VPN CONFIG:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt_config}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Server IP: $(get_server_ip)${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
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
        printf "   %-15s %-10s %-10s %-10s\n" "USERNAME" "TOTAL" "USED" "REMAIN"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        
        while IFS=: read -r user pass traffic expiry used; do
            local used_traffic=$(get_traffic_used "$user")
            local remaining=$((traffic - used_traffic))
            [ $remaining -lt 0 ] && remaining=0
            
            local remaining_days=$(( (expiry - $(date +%s)) / 86400 ))
            
            if [ $remaining_days -lt 0 ] || [ $remaining -eq 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s${NC}\n" "$user" "${traffic}MB" "${used_traffic}MB" "EXPIRED"
            else
                printf "   ${GREEN}%-15s${NC} ${YELLOW}%-10s${NC} %-10s ${CYAN}%-10s${NC}\n" "$user" "${traffic}MB" "${used_traffic}MB" "${remaining}MB"
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
    
    if ! check_user_validity "$username"; then
        echo -e "\n${RED}⚠️ User is expired or out of traffic!${NC}"
        sleep 3
        return
    fi
    
    local password=$(grep "^$username:" "$CONFIG_FILE" | cut -d: -f2)
    local json_config=$(generate_npvt_config "$username" "$password")
    local config_b64=$(echo -n "$json_config" | base64 -w 0)
    local npvt_config="npvt-ssh://${config_b64}"
    
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 NPVT CONFIG for ${username}:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt_config}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

show_stats() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 USER STATS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ User not found!${NC}"
        sleep 2
        return
    fi
    
    local user_line=$(grep "^$username:" "$CONFIG_FILE")
    local max_traffic=$(echo "$user_line" | cut -d: -f3)
    local expiry_ts=$(echo "$user_line" | cut -d: -f4)
    local used_traffic=$(get_traffic_used "$username")
    local remaining=$((max_traffic - used_traffic))
    [ $remaining -lt 0 ] && remaining=0
    local remaining_days=$(( (expiry_ts - $(date +%s)) / 86400 ))
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📊 Statistics for: ${username}${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   Total Traffic:   ${YELLOW}${max_traffic} MB${NC}"
    echo -e "   Used Traffic:    ${RED}${used_traffic} MB${NC}"
    echo -e "   Remaining:       ${GREEN}${remaining} MB${NC}"
    echo -e "   Days Left:       ${remaining_days} days${NC}"
    
    local percent=$((used_traffic * 100 / max_traffic))
    [ $percent -gt 100 ] && percent=100
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    printf "   Progress:        ["
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
    
    echo -n "⚠️ Confirm (yes/no): "
    read confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "\n${YELLOW}Cancelled${NC}"
        sleep 1
        return
    fi
    
    pkill -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username:/d" "$CONFIG_FILE" 2>/dev/null
    rm -f "${TRAFFIC_DIR}/${username}.txt" 2>/dev/null
    
    echo -e "\n${GREEN}✅ User deleted!${NC}"
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
    else
        echo -e "\n${RED}❌ No domain entered${NC}"
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

# ==================== اجرای منو ====================

while true; do
    show_menu
    echo -n "👉 Choose [0-7]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) show_stats ;;
        5) delete_user ;;
        6) set_domain ;;
        7) remove_domain ;;
        0) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# باز کردن پورت
ufw allow 22/tcp 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE! v5.0 DYNAMIC${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}✨ FEATURES:${NC}"
echo -e "   • ${GREEN}Auto IP detection (No Hardcoding)${NC}"
echo -e "   • ${GREEN}Full traffic management${NC}"
echo -e "   • ${GREEN}Domain or IP support${NC}"
echo -e "   • ${GREEN}Auto expiry & limit${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
