#!/bin/bash

# =============================================
# Shadow SSH v2.0 - FINAL WORKING EDITION
# Auto: IP if no domain, Domain if set
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH - FINAL WORKING EDITION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# پاکسازی اولیه
pkill -9 shadow 2>/dev/null
rm -f /usr/local/bin/shadow /etc/shadow-*.conf

# رفع مشکلات
dpkg --configure -a 2>/dev/null
apt-get install -f -y 2>/dev/null

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y
apt install -y curl wget coreutils openssh-server

# حذف پورت 8388
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌ها
touch /etc/shadow-users.conf
echo "" > /etc/shadow-domain.conf
echo "0" > /etc/shadow-fec.conf

# گرفتن IP سرور
SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s -4 icanhazip.com 2>/dev/null)
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="157.10.52.88"
fi

# =============================================
# پنل نهایی با تابع get_server درست
# =============================================
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"
FEC_FILE="/etc/shadow-fec.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# تابع مطمئن برای گرفتن آدرس سرور
get_server() {
    # اول چک کن دامنه تنظیم شده؟
    if [ -f "$DOMAIN_FILE" ]; then
        local domain=$(cat "$DOMAIN_FILE" 2>/dev/null | head -1)
        if [ -n "$domain" ] && [ "$domain" != "" ]; then
            echo "$domain"
            return
        fi
    fi
    
    # دامنه نداریم -> برو سراغ IP
    local ip=$(curl -s -4 ifconfig.me 2>/dev/null)
    if [ -n "$ip" ] && [ "$ip" != "" ]; then
        echo "$ip"
        return
    fi
    
    # آخرین راه: IP هاردکد شده
    echo "SERVER_IP_PLACEHOLDER"
}

get_fec_status() {
    local ratio=$(cat "$FEC_FILE" 2>/dev/null)
    if [ -z "$ratio" ] || [ "$ratio" == "0" ]; then
        echo -e "${RED}Disabled${NC}"
    else
        echo -e "${GREEN}Active (${ratio}:10)${NC}"
    fi
}

generate_npvt_config() {
    local username=$1
    local password=$2
    local server=$(get_server)
    
    # JSON ساده و درست
    printf '{
  "sshConfigType": "SSH-Direct",
  "remarks": "%s-fec",
  "sshHost": "%s",
  "sshPort": 22,
  "sshUsername": "%s",
  "sshPassword": "%s",
  "udpgwTransparentDNS": true
}' "$username" "$server" "$username" "$password"
}

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       🚀 SHADOW SSH - FINAL EDITION${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "   ${YELLOW}FEC:${NC} $(get_fec_status)"
    echo -e "   ${RED}Port 8388:${NC} ${RED}REMOVED${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) Create User"
    echo -e "   ${YELLOW}2${NC}) List Users"
    echo -e "   ${YELLOW}3${NC}) Show Config"
    echo -e "   ${YELLOW}4${NC}) Delete User"
    echo -e "   ${GREEN}5${NC}) Set Domain"
    echo -e "   ${YELLOW}6${NC}) Remove Domain"
    echo -e "   ${CYAN}7${NC}) Set FEC Ratio (2-100)"
    echo -e "   ${RED}8${NC}) Disable FEC"
    echo -e "   ${YELLOW}9${NC}) Exit"
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
    echo -n "📊 Traffic GB: "
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

    expiry=$(date -d "+$days days" +%s)
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    
    local json_config=$(generate_npvt_config "$username" "$password")
    local config_b64=$(echo -n "$json_config" | base64 -w 0)
    local npvt_config="npvt-ssh://${config_b64}"
    
    clear
    echo -e "${GREEN}✅ USER CREATED!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 NPVT VPN CONFIG (Copy this):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt_config}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    # نمایش اطلاعات برای اطمینان
    echo -e "\n${YELLOW}📋 Connection Details:${NC}"
    echo -e "   Server: $(get_server)"
    echo -e "   Port: 22"
    echo -e "   Username: $username"
    echo -e "   Password: $password"
    
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
        printf "   %-15s %-10s %-10s\n" "USERNAME" "EXPIRE" "TRAFFIC"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        
        local current_time=$(date +%s)
        while IFS=: read -r user pass traffic expiry used; do
            local remaining_days=$(( (expiry - current_time) / 86400 ))
            if [ $remaining_days -lt 0 ]; then
                printf "   ${RED}%-15s EXPIRED   %-10s${NC}\n" "$user" "${traffic}GB"
            else
                printf "   ${GREEN}%-15s${NC} %-10s %-10s\n" "$user" "${remaining_days}d" "${traffic}GB"
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

delete_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🗑️ DELETE USER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    
    sed -i "/^$username:/d" "$CONFIG_FILE" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    
    echo -e "\n${GREEN}✅ Deleted${NC}"
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
        echo -e "\n${GREEN}✅ Domain set to: $domain${NC}"
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
    echo -e "${GREEN}✅ Domain removed. Back to IP mode.${NC}"
    sleep 2
}

set_fec_ratio() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}⚡ SET FEC RATIO${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -n "👉 Ratio (2-100): "
    read ratio
    
    if [[ "$ratio" =~ ^[0-9]+$ ]] && [ "$ratio" -ge 2 ] && [ "$ratio" -le 100 ]; then
        echo "$ratio" > "$FEC_FILE"
        echo -e "\n${GREEN}✅ FEC set to ${ratio}:10${NC}"
        
        cat > /etc/systemd/system/ssh-booster.service << EOF
[Unit]
Description=SSH Booster - FEC ${ratio}:10
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'UDPspeeder -s -l 0.0.0.0:8389 -r 127.0.0.1:22 -k "ShadowSecretKey2024" --timeout 1 -f ${ratio}:10 -q 1 2>/dev/null & sleep 2 && udp2raw -s -l 0.0.0.0:4096 -r 127.0.0.1:8389 -k "ShadowSecretKey2024" --raw-mode faketcp -a 2>/dev/null'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable ssh-booster 2>/dev/null
        systemctl restart ssh-booster 2>/dev/null
    else
        echo -e "\n${RED}❌ Invalid! Must be 2-100${NC}"
    fi
    sleep 2
}

disable_fec() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${RED}🛑 DISABLE FEC${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -n "Confirm? (y/n): "
    read confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "0" > "$FEC_FILE"
        systemctl stop ssh-booster 2>/dev/null
        systemctl disable ssh-booster 2>/dev/null
        echo -e "\n${GREEN}✅ FEC Disabled${NC}"
    else
        echo -e "\n${YELLOW}Cancelled${NC}"
    fi
    sleep 2
}

while true; do
    show_menu
    echo -n "👉 Choose [1-9]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) delete_user ;;
        5) set_domain ;;
        6) remove_domain ;;
        7) set_fec_ratio ;;
        8) disable_fec ;;
        9) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid${NC}"; sleep 1 ;;
    esac
done
INNEREOF

# جایگزینی placeholder با IP واقعی
sed -i "s/SERVER_IP_PLACEHOLDER/${SERVER_IP}/g" /usr/local/bin/shadow

chmod +x /usr/local/bin/shadow

# باز کردن پورت
ufw allow 22/tcp 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Features:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • Default Mode: ${GREEN}IP Address (${SERVER_IP})${NC}"
echo -e "   • Option 5: ${GREEN}Set Domain${NC}"
echo -e "   • Option 6: ${GREEN}Remove Domain (Back to IP)${NC}"
echo -e "   • Option 7: ${GREEN}Set FEC Ratio (2-100)${NC}"
echo -e "   • Option 8: ${RED}Disable FEC${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
