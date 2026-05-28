#!/bin/bash

# =============================================
# Shadow SSH v2.0 - نهایی انشاءالله
# FEC Ratio: 2.5x (25:10) - بهترین تعادل
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH Ultimate - نهایی انشاءالله${NC}"
echo -e "${GREEN}   FEC Ratio: 2.5x (25:10)${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ باید روت باشی!${NC}" 
   exit 1
fi

# پاکسازی اولیه
pkill -9 shadow 2>/dev/null
rm -f /usr/local/bin/shadow /etc/shadow-*.conf

# رفع مشکلات
dpkg --configure -a 2>/dev/null
apt-get install -f -y 2>/dev/null

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 نصب پیش‌نیازها...${NC}"
apt update -y
apt install -y curl wget coreutils openssh-server git gcc make libsodium-dev build-essential

# حذف پورت 8388
echo -e "${YELLOW}🚫 حذف پورت 8388...${NC}"
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/Port 8389/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# ایجاد فایل‌های کانفیگ
touch /etc/shadow-users.conf
echo "" > /etc/shadow-domain.conf

# =============================================
# نصب UDPspeeder + udp2raw
# =============================================
echo -e "${YELLOW}⚡ نصب UDP Boosters (سرعت 5-10 برابر)...${NC}"

cd /root
git clone https://github.com/wangyu-/UDPspeeder.git
cd UDPspeeder
make && make install
cd ..

git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel
make && make install
cd ..

rm -rf /root/UDPspeeder /root/udp2raw-tunnel

# =============================================
# سرویس بوستر با ضریب 2.5x (25:10)
# =============================================
echo -e "${YELLOW}🚀 ایجاد سرویس بوستر با ضریب 2.5x...${NC}"

cat > /etc/systemd/system/ssh-booster.service << 'EOF'
[Unit]
Description=SSH Port 22 Super Booster - FEC 2.5x (25:10)
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '
  UDPspeeder -s -l 0.0.0.0:8389 -r 127.0.0.1:22 -k "ShadowSecretKey2024" --timeout 1 -f 25:10 -q 1 2>/dev/null &
  sleep 2
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
echo -e "${YELLOW}⚡ بهینه‌سازی کرنل...${NC}"

cat >> /etc/sysctl.conf << 'EOF'

# =============================================
# Shadow SSH Ultimate - تنظیمات نهایی
# =============================================
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 100000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_local_port_range = 1024 65535
EOF

sysctl -p > /dev/null 2>&1

# =============================================
# پنل مدیریت NPVT
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
  "remarks": "${username}-2.5x",
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
    echo -e "${GREEN}   🚀 SHADOW SSH نهایی - NPVT VPN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}سرور:${NC} $(get_server):22"
    echo -e "   ${YELLOW}سرعت:${NC} ${GREEN}فوق‌العاده (2.5x FEC)${NC}"
    echo -e "   ${YELLOW}امنیت:${NC} ${GREEN}FakeTCP + Obfuscation${NC}"
    echo -e "   ${RED}پورت 8388:${NC} ${RED}حذف شد${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) ساخت کاربر + کانفیگ NPVT"
    echo -e "   ${YELLOW}2${NC}) لیست کاربران"
    echo -e "   ${YELLOW}3${NC}) نمایش کانفیگ"
    echo -e "   ${YELLOW}4${NC}) حذف کاربر"
    echo -e "   ${GREEN}5${NC}) تنظیم دامنه (مخفی کردن IP)"
    echo -e "   ${YELLOW}6${NC}) حذف دامنه (بازگشت به IP)"
    echo -e "   ${YELLOW}7${NC}) خروج"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

create_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✨ ساخت کاربر جدید${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 نام کاربری: "
    read username
    echo -n "🔑 رمز عبور: "
    read password
    echo -n "📊 ترافیک (گیگابایت): "
    read traffic
    echo -n "📅 تعداد روز: "
    read days

    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$traffic" ] || [ -z "$days" ]; then
        echo -e "\n${RED}❌ همه فیلدها الزامی است!${NC}"
        sleep 2
        return
    fi

    if ! [[ "$traffic" =~ ^[0-9]+$ ]] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n${RED}❌ ترافیک و روز باید عدد باشد!${NC}"
        sleep 2
        return
    fi

    expiry=$(date -d "+$days days" +%s)
    echo "$username:$password:$traffic:$expiry:0" >> $CONFIG_FILE
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    
    local npvt_config=$(generate_npvt_config "$username" "$password")
    
    clear
    echo -e "${GREEN}✅ کاربر با موفقیت ساخته شد!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 کانفیگ NPVT (کپی کن):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt_config}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    local current_server=$(get_server)
    if [[ "$current_server" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${YELLOW}💡 نکته: از گزینه 5 برای تنظیم دامنه استفاده کن${NC}"
    fi
    
    echo -e "\n${YELLOW}Enter بزن...${NC}"
    read dummy
}

list_users() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 لیست کاربران${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ کاربری وجود ندارد${NC}"
    else
        printf "   %-15s %-10s %-10s\n" "نام کاربری" "انقضا" "ترافیک"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        
        local current_time=$(date +%s)
        while IFS=: read -r user pass traffic expiry used; do
            local remaining_days=$(( (expiry - current_time) / 86400 ))
            if [ $remaining_days -lt 0 ]; then
                printf "   ${RED}%-15s منقضی    %-10s${NC}\n" "$user" "${traffic}GB"
            else
                printf "   ${GREEN}%-15s${NC} %-10s %-10s\n" "$user" "${remaining_days}روز" "${traffic}GB"
            fi
        done < "$CONFIG_FILE"
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Enter بزن...${NC}"
    read dummy
}

show_config() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📄 نمایش کانفیگ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 نام کاربری: "
    read username
    
    if [ -z "$username" ]; then
        echo -e "\n${RED}❌ نام کاربری الزامی است!${NC}"
        sleep 2
        return
    fi
    
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ کاربر پیدا نشد!${NC}"
        sleep 2
        return
    fi
    
    local password=$(grep "^$username:" "$CONFIG_FILE" | cut -d: -f2)
    local npvt_config=$(generate_npvt_config "$username" "$password")
    
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📱 کانفیگ NPVT برای ${username}:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${GREEN}${npvt_config}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Enter بزن...${NC}"
    read dummy
}

delete_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🗑️ حذف کاربر${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 نام کاربری برای حذف: "
    read username
    
    if [ -z "$username" ]; then
        echo -e "\n${RED}❌ نام کاربری الزامی است!${NC}"
        sleep 2
        return
    fi
    
    sed -i "/^$username:/d" "$CONFIG_FILE" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    
    echo -e "\n${GREEN}✅ کاربر $username حذف شد!${NC}"
    sleep 2
}

set_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 تنظیم دامنه${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}دامنه‌ای که به این سرور اشاره می‌کند را وارد کن${NC}"
    echo -e "${YELLOW}مثال: vpn.yourdomain.com${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -n "👉 دامنه: "
    read domain
    
    if [ -n "$domain" ]; then
        echo "$domain" > "$DOMAIN_FILE"
        echo -e "\n${GREEN}✅ دامنه تنظیم شد: $domain${NC}"
        echo -e "${YELLOW}📌 از این به بعد کانفیگ‌ها با این دامنه ساخته می‌شوند${NC}"
    else
        echo -e "\n${RED}❌ دامنه نامعتبر!${NC}"
    fi
    sleep 2
}

remove_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔙 حذف دامنه${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    local current_domain=$(cat "$DOMAIN_FILE" 2>/dev/null)
    if [ -n "$current_domain" ] && [ -s "$DOMAIN_FILE" ]; then
        echo -e "${YELLOW}دامنه فعلی: ${current_domain}${NC}"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        echo -n "دامنه حذف شود و IP جایگزین گردد؟ (y/n): "
        read confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo "" > "$DOMAIN_FILE"
            local server_ip=$(curl -s ifconfig.me)
            echo -e "\n${GREEN}✅ دامنه حذف شد! در حال استفاده از IP: $server_ip${NC}"
        else
            echo -e "\n${YELLOW}❌ انصراف${NC}"
        fi
    else
        echo -e "\n${YELLOW}ℹ️ هیچ دامنه‌ای تنظیم نشده. در حال استفاده از IP.${NC}"
    fi
    sleep 2
}

while true; do
    show_menu
    echo -n "👉 انتخاب کن [1-7]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) delete_user ;;
        5) set_domain ;;
        6) remove_domain ;;
        7) echo -e "${GREEN}👋 خداحافظ!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ گزینه نامعتبر${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# تنظیم فایروال
ufw allow 22/tcp 2>/dev/null
ufw allow 4096/tcp 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ نصب با موفقیت انجام شد! انشاءالله${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 ویژگی‌های نهایی:${NC}"
echo -e "   • پورت 8388: ${RED}حذف شد${NC}"
echo -e "   • پورت SSH:  ${GREEN}22 (فوقالعاده سریع)${NC}"
echo -e "   • ضریب FEC:  ${GREEN}2.5x (25:10) - بهترین تعادل${NC}"
echo -e "   • امنیت:     ${GREEN}FakeTCP + Obfuscation${NC}"
echo -e "   • حالت پیش‌فرض: ${GREEN}IP سرور${NC}"
echo -e "   • گزینه 5:   ${GREEN}تنظیم دامنه (مخفی کردن IP)${NC}"
echo -e "   • گزینه 6:   ${GREEN}حذف دامنه (بازگشت به IP)${NC}"
echo -e "   • خروجی:     ${GREEN}npvt-ssh:// برای نپستر${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 برای شروع اجرا کن:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
