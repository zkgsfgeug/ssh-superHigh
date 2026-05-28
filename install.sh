#!/bin/bash

# =============================================
# Shadow SSH v2.0 - Dynamic FEC Ratio Edition
# Features: Manual Ratio Control (2 to 100)
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH - Dynamic FEC Ratio Installer${NC}"
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
apt install -y curl wget coreutils openssh-server git gcc make libsodium-dev build-essential

# حذف پورت 8388
echo -e "${YELLOW}🚫 Removing port 8388...${NC}"
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌های کانفیگ
touch /etc/shadow-users.conf
echo "" > /etc/shadow-domain.conf
echo "0" > /etc/shadow-fec.conf  # 0 = Disabled, otherwise stores the ratio

# =============================================
# نصب UDPspeeder + udp2raw
# =============================================
echo -e "${YELLOW}⚡ Installing UDP Boosters...${NC}"

cd /root
git clone https://github.com/wangyu-/UDPspeeder.git
cd UDPspeeder && make && make install && cd ..

git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel && make && make install && cd ..

rm -rf /root/UDPspeeder /root/udp2raw-tunnel

# =============================================
# تابع به‌روزرسانی سرویس بر اساس ضریب
# =============================================
update_booster_service() {
    local ratio=$(cat /etc/shadow-fec.conf)
    local service_file="/etc/systemd/system/ssh-booster.service"
    
    systemctl stop ssh-booster 2>/dev/null
    
    if [ "$ratio" == "0" ] || [ -z "$ratio" ]; then
        # حالت غیرفعال: فقط SSH معمولی
        cat > $service_file << 'EOF'
[Unit]
Description=SSH Standard (No Booster)
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'sleep infinity'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        echo -e "${YELLOW}🔴 Booster is DISABLED${NC}"
    else
        # حالت فعال: با ضریب انتخابی
        cat > $service_file << EOF
[Unit]
Description=SSH Port 22 Booster - FEC ${ratio}:10
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'UDPspeeder -s -l 0.0.0.0:8389 -r 127.0.0.1:22 -k "ShadowSecretKey2024" --timeout 1 -f ${ratio}:10 -q 1 2>/dev/null & sleep 2 && udp2raw -s -l 0.0.0.0:4096 -r 127.0.0.1:8389 -k "ShadowSecretKey2024" --raw-mode faketcp -a 2>/dev/null'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Booster Enabled with Ratio ${ratio}:10${NC}"
    fi
    
    systemctl daemon-reload
    systemctl enable ssh-booster
    systemctl start ssh-booster
}

# =============================================
# بهینه‌سازی کرنل
# =============================================
echo -e "${YELLOW}⚡ Optimizing kernel...${NC}"
cat >> /etc/sysctl.conf << 'EOF'

# Shadow SSH Ultimate
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 100000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
EOF
sysctl -p > /dev/null 2>&1

# تنظیم پیش‌فرض (غیرفعال)
update_booster_service

# =============================================
# پنل مدیریت با گزینه ضریب
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

get_server() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE" | head -1
    else
        curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null
    fi
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
    
    cat << EOF
{
  "sshConfigType": "SSH-Direct",
  "remarks": "${username}-fec",
  "sshHost": "${server}",
  "sshPort": 22,
  "sshUsername": "${username}",
  "sshPassword": "${password}",
  "udpgwTransparentDNS": true
}
EOF
}

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       🚀 SHADOW SSH - FEC CONTROLLER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "   ${YELLOW}FEC Status:${NC} $(get_fec_status)"
    echo -e "   ${RED}Port 8388:${NC} ${RED}REMOVED${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) Create User + Config"
    echo -e "   ${YELLOW}2${NC}) List Users"
    echo -e "   ${YELLOW}3${NC}) Show Config"
    echo -e "   ${YELLOW}4${NC}) Delete User"
    echo -e "   ${GREEN}5${NC}) Set Domain (Hide IP)"
    echo -e "   ${YELLOW}6${NC}) Remove Domain (Back to IP)"
    echo -e "   ${CYAN}7${NC}) Set FEC Ratio (2-100) ⚡"
    echo -e "   ${RED}8${NC}) Disable FEC Booster 🛑"
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

    expiry=$(date -d "+$days days" +%s)
    echo "$username:$password:$traffic:$expiry:0" >> $CONFIG_FILE
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
    
    echo -n "👤 Username to delete: "
    read username
    
    sed -i "/^$username:/d" "$CONFIG_FILE" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    
    echo -e "\n${GREEN}✅ User $username deleted!${NC}"
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
        echo -e "\n${RED}❌ Invalid domain!${NC}"
    fi
    sleep 2
}

remove_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔙 REMOVE DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo "" > "$DOMAIN_FILE"
    echo -e "${GREEN}✅ Domain removed! Back to IP mode.${NC}"
    sleep 2
}

set_fec_ratio() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}⚡ SET FEC RATIO${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Enter a ratio between 2 and 100${NC}"
    echo -e "${YELLOW}Example: 25 means 25:10 (2.5x speed boost)${NC}"
    echo -e "${YELLOW}Higher ratio = More speed but More bandwidth${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -n "👉 FEC Ratio (2-100): "
    read ratio
    
    if [[ "$ratio" =~ ^[0-9]+$ ]] && [ "$ratio" -ge 2 ] && [ "$ratio" -le 100 ]; then
        echo "$ratio" > "$FEC_FILE"
        echo -e "\n${GREEN}✅ FEC Ratio set to ${ratio}:10${NC}"
        echo -e "${YELLOW}🔄 Restarting booster service...${NC}"
        
        # به‌روزرسانی و ریستارت سرویس
        local service_file="/etc/systemd/system/ssh-booster.service"
        systemctl stop ssh-booster
        
        cat > $service_file << EOF
[Unit]
Description=SSH Port 22 Booster - FEC ${ratio}:10
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
        systemctl enable ssh-booster
        systemctl start ssh-booster
        
        echo -e "${GREEN}✅ Booster restarted with new ratio!${NC}"
    else
        echo -e "\n${RED}❌ Invalid ratio! Must be between 2 and 100.${NC}"
    fi
    sleep 2
}

disable_fec() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${RED}🛑 DISABLE FEC BOOSTER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -n "Are you sure? (y/n): "
    read confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "0" > "$FEC_FILE"
        
        # غیرفعال کردن سرویس
        systemctl stop ssh-booster
        systemctl disable ssh-booster
        
        echo -e "\n${GREEN}✅ FEC Booster disabled!${NC}"
        echo -e "${YELLOW}SSH is now running in standard mode (no speed boost).${NC}"
    else
        echo -e "\n${YELLOW}❌ Cancelled${NC}"
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
        *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# تنظیم فایروال
ufw allow 22/tcp 2>/dev/null
ufw allow 4096/tcp 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Features:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • Dynamic FEC: ${GREEN}Manual control (2-100)${NC}"
echo -e "   • Default Mode: ${GREEN}FEC Disabled${NC}"
echo -e "   • Option 7: ${GREEN}Set custom FEC ratio${NC}"
echo -e "   • Option 8: ${RED}Disable FEC booster${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
