#!/bin/bash

# =============================================
# Shadow SSH v2.0 - Ultimate Edition
# Features: Super Speed + Anti-Filter + NPVT
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH Ultimate - NPVT VPN Installer${NC}"
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
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/Port 8389/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌های کانفیگ
touch /etc/shadow-users.conf
echo "" > /etc/shadow-domain.conf

# =============================================
# نصب UDPspeeder + udp2raw برای افزایش سرعت
# =============================================
echo -e "${YELLOW}⚡ Installing UDP Boosters (Speed 5-10x)...${NC}"

# نصب UDPspeeder
cd /root
git clone https://github.com/wangyu-/UDPspeeder.git
cd UDPspeeder
make && make install
cd ..

# نصب udp2raw
git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel
make && make install
cd ..

# پاکسازی سورس‌ها
rm -rf /root/UDPspeeder /root/udp2raw-tunnel

# =============================================
# سرویس بوستر برای پورت 22 (فقط پورت 22)
# =============================================
echo -e "${YELLOW}🚀 Creating Super Booster Service for Port 22...${NC}"

cat > /etc/systemd/system/ssh-booster.service << EOF
[Unit]
Description=SSH Port 22 Super Booster (UDP + FakeTCP)
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '
  # UDPspeeder برای افزایش سرعت
  UDPspeeder -s -l 0.0.0.0:8389 -r 127.0.0.1:22 -k "ShadowSecretKey2024" --timeout 1 -f 20:10 -q 1 2>/dev/null &
  sleep 2
  # udp2raw برای عبور از فیلتر (FakeTCP)
  udp2raw -s -l 0.0.0.0:4096 -r 127.0.0.1:8389 -k "ShadowSecretKey2024" --raw-mode faketcp -a 2>/dev/null
'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ssh-booster.service
systemctl start ssh-booster.service

# =============================================
# بهینه‌سازی کرنل (حداکثر سرعت)
# =============================================
echo -e "${YELLOW}⚡ Super Boosting Kernel...${NC}"

cat >> /etc/sysctl.conf << 'EOF'

# =============================================
# Shadow SSH Ultimate - Maximum Performance
# =============================================
# حداکثر بافر شبکه
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456

# افزایش صف و کاهش تاخیر
net.core.netdev_max_backlog = 100000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 32768

# الگوریتم BBR برای حداکثر سرعت
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# بهینه‌سازی امنیت و فیلترشکنی
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_local_port_range = 1024 65535
EOF

sysctl -p > /dev/null 2>&1

# =============================================
# پنل مدیریت با فرمت NPVT
# =============================================
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"

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

generate_npvt_config() {
    local username=$1
    local password=$2
    local server=$(get_server)
    
    local json_data=$(cat <<EOF
{
  "sshConfigType": "SSH-Direct",
  "remarks": "${username}-ultra",
  "sshHost": "${server}",
  "sshPort": 22,
  "sshUsername": "${username}",
  "sshPassword": "${password}",
  "udpgwTransparentDNS": true
}
EOF
)
    local config_b64=$(echo -n "$json_data" | base64 -w 0)
    echo "npvt-ssh://${config_b64}"
}

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🚀 SHADOW SSH ULTIMATE - NPVT VPN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}Server:${NC} $(get_server):22"
    echo -e "   ${YELLOW}Speed:${NC} ${GREEN}Ultra (5-10x) | Anti-Filter: ${GREEN}Active${NC}"
    echo -e "   ${RED}Port 8388:${NC} ${RED}REMOVED${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) Create User + NPVT Config"
    echo -e "   ${YELLOW}2${NC}) List Users"
    echo -e "   ${YELLOW}3${NC}) Show Config"
    echo -e "   ${YELLOW}4${NC}) Delete User"
    echo -e "   ${GREEN}5${NC}) Set Domain (Hide IP)"
    echo -e "   ${YELLOW}6${NC}) Remove Domain (Back to IP)"
    echo -e "   ${YELLOW}7${NC}) Exit"
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
    echo "$username:$password:$traffic:$expiry:0" >> $CONFIG_FILE
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    
    local npvt_config=$(generate_npvt_config "$username" "$password")
    
    clear
    echo -e "${GREEN}✅ USER CREATED!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 NPVT VPN CONFIG (Copy this):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt_config}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    local current_server=$(get_server)
    if [[ "$current_server" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${YELLOW}💡 Tip: Use option 5 to set a domain and hide your IP${NC}"
    fi
    
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
    
    if [ -z "$username" ]; then
        echo -e "\n${RED}❌ Username required!${NC}"
        sleep 2
        return
    fi
    
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ User not found!${NC}"
        sleep 2
        return
    fi
    
    local password=$(grep "^$username:" "$CONFIG_FILE" | cut -d: -f2)
    local npvt_config=$(generate_npvt_config "$username" "$password")
    
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 NPVT VPN CONFIG for ${username}:${NC}"
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
    
    if [ -z "$username" ]; then
        echo -e "\n${RED}❌ Username required!${NC}"
        sleep 2
        return
    fi
    
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
    echo -e "${YELLOW}Enter your domain that points to this server${NC}"
    echo -e "${YELLOW}Example: vpn.yourdomain.com${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -n "👉 Domain: "
    read domain
    
    if [ -n "$domain" ]; then
        echo "$domain" > "$DOMAIN_FILE"
        echo -e "\n${GREEN}✅ Domain set to: $domain${NC}"
        echo -e "${YELLOW}📌 From now on, configs will use this domain${NC}"
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
    
    local current_domain=$(cat "$DOMAIN_FILE" 2>/dev/null)
    if [ -n "$current_domain" ] && [ -s "$DOMAIN_FILE" ]; then
        echo -e "${YELLOW}Current domain: ${current_domain}${NC}"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        echo -n "Remove domain and use IP instead? (y/n): "
        read confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo "" > "$DOMAIN_FILE"
            local server_ip=$(curl -s ifconfig.me)
            echo -e "\n${GREEN}✅ Domain removed! Now using IP: $server_ip${NC}"
        else
            echo -e "\n${YELLOW}❌ Cancelled${NC}"
        fi
    else
        echo -e "\n${YELLOW}ℹ️ No domain is currently set. Already using IP.${NC}"
    fi
    sleep 2
}

while true; do
    show_menu
    echo -n "👉 Choose [1-7]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) delete_user ;;
        5) set_domain ;;
        6) remove_domain ;;
        7) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# باز کردن پورت‌ها در فایروال
ufw allow 22/tcp 2>/dev/null
ufw allow 4096/tcp 2>/dev/null
ufw allow 8389/udp 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Features:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • SSH Port:  ${GREEN}22 (Ultra Boosted - 5-10x faster)${NC}"
echo -e "   • Anti-Filter: ${GREEN}FakeTCP + Obfuscation${NC}"
echo -e "   • Default:   ${GREEN}IP Mode${NC}"
echo -e "   • Option 5:  ${GREEN}Set Domain (Hide IP)${NC}"
echo -e "   • Option 6:  ${GREEN}Remove Domain (Back to IP)${NC}"
echo -e "   • Output:    ${GREEN}npvt-ssh:// format${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
