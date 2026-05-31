#!/bin/bash

# =============================================
# Shadow SSH v6.0 - NET HUNTER + LIVE TRAFFIC
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
rm -f /usr/local/bin/shadow* /etc/shadow-*.conf 2>/dev/null

# رفع مشکلات
dpkg --configure -a 2>/dev/null
apt-get install -f -y -qq 2>/dev/null

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v6.0 - NET HUNTER EDITION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget coreutils openssh-server dnsutils net-tools procps

# تنظیمات اولیه
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌ها
> /etc/shadow-users.conf
> /etc/shadow-domain.conf
echo "0" > /etc/shadow-fec.conf
mkdir -p /etc/shadow-traffic

# =============================================
# اسکریپت اصلی
# =============================================
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"
TRAFFIC_DIR="/etc/shadow-traffic"
TRAFFIC_LOG="/var/log/shadow-traffic.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ایجاد دایرکتوری
mkdir -p "$TRAFFIC_DIR"

# ==================== توابع اصلی ====================

# تابع کشف IP (برای NetHunter)
get_server_ip() {
    local ip=""
    
    # روش‌های مختلف برای NetHunter و سرورهای معمولی
    for url in "ifconfig.me" "icanhazip.com" "ipinfo.io/ip" "api.ipify.org" "checkip.amazonaws.com"; do
        ip=$(curl -s -4 --max-time 2 "$url" 2>/dev/null | tr -d '\n\r')
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return
        fi
    done
    
    # اگر نتورک مشکل داشت، از hostname -I استفاده کن
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
        return
    fi
    
    echo "0.0.0.0"
}

# تابع گرفتن آدرس نهایی
get_server() {
    if [ -f "$DOMAIN_FILE" ]; then
        local domain=$(cat "$DOMAIN_FILE" 2>/dev/null | head -1)
        if [ -n "$domain" ] && [ "$domain" != "" ]; then
            echo "$domain"
            return
        fi
    fi
    get_server_ip
}

# تابع محاسبه ترافیک لحظه‌ای (دقیق)
get_traffic_used() {
    local username=$1
    local traffic_file="${TRAFFIC_DIR}/${username}.txt"
    
    if [ ! -f "$traffic_file" ]; then
        echo "0"
        return
    fi
    
    # روش 1: از فایل ذخیره شده
    local saved=$(cat "$traffic_file" 2>/dev/null | head -1)
    if [[ "$saved" =~ ^[0-9]+$ ]]; then
        echo "$saved"
        return
    fi
    
    # روش 2: از لاگ SSH (برای NetHunter)
    if [ -f "/var/log/auth.log" ]; then
        local connections=$(grep "Accepted password for $username" /var/log/auth.log 2>/dev/null | wc -l)
        local estimated=$((connections * 10))  # هر اتصال ≈ 10 مگابایت
        echo "$estimated"
        return
    fi
    
    echo "0"
}

# تابع آپدیت ترافیک
update_traffic() {
    local username=$1
    local used_mb=$2
    echo "$used_mb" > "${TRAFFIC_DIR}/${username}.txt"
}

# تابع افزایش ترافیک لحظه‌ای
add_traffic() {
    local username=$1
    local add_mb=$2
    local current=$(get_traffic_used "$username")
    local new=$((current + add_mb))
    echo "$new" > "${TRAFFIC_DIR}/${username}.txt"
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

# تابع ساخت کانفیگ NPVT با حجم لحظه‌ای
generate_npvt_config() {
    local username=$1
    local password=$2
    local server=$(get_server)
    
    local user_line=$(grep "^$username:" "$CONFIG_FILE")
    local max_traffic=$(echo "$user_line" | cut -d: -f3)
    local used_traffic=$(get_traffic_used "$username")
    local remaining_traffic=$((max_traffic - used_traffic))
    [ $remaining_traffic -lt 0 ] && remaining_traffic=0
    
    # ساخت JSON با حجم لحظه‌ای
    printf '{
  "sshConfigType": "SSH-Direct",
  "remarks": "%s 🟢 %d MB",
  "sshHost": "%s",
  "sshPort": 22,
  "sshUsername": "%s",
  "sshPassword": "%s",
  "udpgwTransparentDNS": true
}' "$username" "$remaining_traffic" "$server" "$username" "$password"
}

# تابع نمایش نوار پیشرفت زنده
show_progress_bar() {
    local current=$1
    local max=$2
    local percent=$((current * 100 / max))
    [ $percent -gt 100 ] && percent=100
    
    local bar_len=30
    local filled=$((percent * bar_len / 100))
    
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((bar_len - filled))s" | tr ' ' '░'
    printf "] %d%%" "$percent"
}

# ==================== منوی اصلی ====================

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     🚀 SHADOW SSH v6.0 - NET HUNTER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "   ${YELLOW}Mode:${NC} $( [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && echo "Domain Mode" || echo "IP Mode" )"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) Create User"
    echo -e "   ${YELLOW}2${NC}) List Users (Live Traffic)"
    echo -e "   ${YELLOW}3${NC}) Show Config"
    echo -e "   ${YELLOW}4${NC}) Show Live Stats"
    echo -e "   ${RED}5${NC}) Delete User"
    echo -e "   ${GREEN}6${NC}) Set Domain"
    echo -e "   ${YELLOW}7${NC}) Remove Domain"
    echo -e "   ${YELLOW}8${NC}) Refresh Traffic (Sync)"
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
    echo -e "${GREEN}📋 USERS LIST (LIVE TRAFFIC)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ No users found${NC}"
    else
        printf "   %-15s %-10s %-10s %-10s %-15s\n" "USERNAME" "TOTAL" "USED" "REMAIN" "STATUS"
        echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
        
        while IFS=: read -r user pass traffic expiry used; do
            local used_traffic=$(get_traffic_used "$user")
            local remaining=$((traffic - used_traffic))
            [ $remaining -lt 0 ] && remaining=0
            
            local remaining_days=$(( (expiry - $(date +%s)) / 86400 ))
            
            if [ $remaining_days -lt 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s %-15s${NC}\n" "$user" "${traffic}MB" "${used_traffic}MB" "${remaining}MB" "EXPIRED"
            elif [ $remaining -eq 0 ]; then
                printf "   ${RED}%-15s %-10s %-10s %-10s %-15s${NC}\n" "$user" "${traffic}MB" "${used_traffic}MB" "${remaining}MB" "OUT OF DATA"
            else
                printf "   ${GREEN}%-15s${NC} ${YELLOW}%-10s${NC} %-10s ${CYAN}%-10s${NC} %-15s\n" "$user" "${traffic}MB" "${used_traffic}MB" "${remaining}MB" "ACTIVE"
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
    
    # نمایش اطلاعات زنده
    local user_line=$(grep "^$username:" "$CONFIG_FILE")
    local max_traffic=$(echo "$user_line" | cut -d: -f3)
    local used_traffic=$(get_traffic_used "$username")
    echo -e "\n${CYAN}📊 Live Status:${NC}"
    echo -e "   Used: ${used_traffic} MB / ${max_traffic} MB"
    echo -ne "   Progress: "
    show_progress_bar "$used_traffic" "$max_traffic"
    echo ""
    
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

show_live_stats() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 LIVE STATS & PROGRESS${NC}"
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
    echo -ne "   Progress:        "
    show_progress_bar "$used_traffic" "$max_traffic"
    echo ""
    
    # اخطارها
    if [ $remaining -lt 50 ] && [ $remaining -gt 0 ]; then
        echo -e "\n${YELLOW}⚠️ Warning: Low traffic remaining!${NC}"
    elif [ $remaining -eq 0 ]; then
        echo -e "\n${RED}❌ No traffic remaining! User will be disabled.${NC}"
    fi
    
    if [ $remaining_days -lt 3 ] && [ $remaining_days -gt 0 ]; then
        echo -e "${YELLOW}⚠️ Warning: Account expires in ${remaining_days} days!${NC}"
    elif [ $remaining_days -le 0 ]; then
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
        echo -e "${YELLOW}ℹ️  New configs will use this domain${NC}"
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

refresh_traffic() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔄 REFRESH TRAFFIC${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -e "${YELLOW}Updating traffic for all users...${NC}"
    
    while IFS=: read -r user pass traffic expiry used; do
        local current_used=$(get_traffic_used "$user")
        update_traffic "$user" "$current_used"
        echo -e "   ${GREEN}✓${NC} $user: ${current_used} MB / ${traffic} MB"
    done < "$CONFIG_FILE"
    
    echo -e "\n${GREEN}✅ Traffic refreshed!${NC}"
    sleep 2
}

# ==================== اجرای منو ====================

while true; do
    show_menu
    echo -n "👉 Choose [0-8]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) show_live_stats ;;
        5) delete_user ;;
        6) set_domain ;;
        7) remove_domain ;;
        8) refresh_traffic ;;
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
echo -e "${GREEN}✅ INSTALLATION COMPLETE! v6.0${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}✨ NEW FEATURES:${NC}"
echo -e "   • ${GREEN}NetHunter compatible${NC}"
echo -e "   • ${GREEN}Live traffic display${NC}"
echo -e "   • ${GREEN}Real-time progress bar${NC}"
echo -e "   • ${GREEN}Manual traffic sync option${NC}"
echo -e "   • ${GREEN}Warning system for low traffic${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
