#!/bin/bash

# COLOR DEFINITIONS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔧 Shadow SSH v2.0 - Domain + Port 22 Booster (NO 8388)${NC}"
read -p "Do you have a domain pointing to this server? (y/n): " has_domain

if [[ "$has_domain" == "y" || "$has_domain" == "Y" ]]; then
    read -p "Enter your domain (e.g., panel.yourdomain.com): " user_domain
    DOMAIN_MODE=true
    PANEL_DOMAIN="$user_domain"
    echo -e "${GREEN}✅ Domain mode activated: $PANEL_DOMAIN${NC}"
else
    DOMAIN_MODE=false
    PANEL_DOMAIN=$(curl -s ifconfig.me)
    echo -e "${YELLOW}⚠️ No domain provided. Using IP: $PANEL_DOMAIN${NC}"
fi

# حذف کامل پورت 8388
echo -e "${YELLOW}🚫 Removing port 8388 completely...${NC}"
sed -i '/8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/8389/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart sshd

# بوست فوق‌العاده پورت 22
echo -e "${GREEN}⚡ Super Boosting Port 22...${NC}"
cat >> /etc/sysctl.conf << EOF

# Shadow SSH - Max Performance on Port 22
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
EOF

sysctl -p

# نصب pre-requisites
apt update && apt install -y git gcc make libsodium-dev build-essential python3

# نصب UDPspeeder و udp2raw فقط برای پورت 22
git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel && make && make install && cd ..
git clone https://github.com/wangyu-/UDPspeeder.git
cd UDPspeeder && make && make install && cd ..

# کپی اسکریپت اصلی پنل CLI با پشتیبانی از دامنه
cat > /usr/local/bin/shadow << 'EOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
PANEL_DOMAIN="[DOMAIN_PLACEHOLDER]"

# اگر دامنه وجود داشته باشد، در خروجی کانفیگ‌ها جایگزین کن
get_server_addr() {
    if [[ "$PANEL_DOMAIN" != "IP_PLACEHOLDER" ]]; then
        echo "$PANEL_DOMAIN"
    else
        curl -s ifconfig.me
    fi
}

show_menu() {
    echo "====================================="
    echo "🚀 Shadow SSH v2.0 - CLI Panel"
    echo "====================================="
    echo "1. Add new user"
    echo "2. Delete user"
    echo "3. List users"
    echo "4. Show config for user"
    echo "5. Exit"
    echo "====================================="
}

add_user() {
    read -p "Username: " username
    read -p "Password: " password
    read -p "Traffic Limit (GB): " traffic
    read -p "Days valid: " days
    
    expiry=$(date -d "+$days days" +%s)
    echo "$username:$password:$traffic:$expiry:0" >> $CONFIG_FILE
    
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    SERVER_ADDR=$(get_server_addr)
    echo -e "\n✅ User created! Connection config:"
    echo "─────────────────────────────────"
    echo "🔌 SSH Command:"
    echo "ssh -o ServerAliveInterval=60 $username@$SERVER_ADDR -p 22"
    echo ""
    echo "📱 Shadowrocket / HTTP Injection:"
    echo "$SERVER_ADDR:$username:$password"
    echo "─────────────────────────────────"
}

list_users() {
    echo "📋 Active Users:"
    cat $CONFIG_FILE 2>/dev/null | while IFS=: read user pass traffic expiry used; do
        remaining=$(( ($expiry - $(date +%s)) / 86400 ))
        echo "• $user | Expires in: ${remaining}d | Traffic: ${traffic}GB"
    done
}

case $1 in
    add) add_user ;;
    list) list_users ;;
    *) while true; do show_menu; read -p "Choose: " opt; case $opt in 1) add_user;; 2) echo "TODO";; 3) list_users;; 4) echo "TODO";; 5) break;; esac; done ;;
esac
EOF

# جایگزینی دامنه در فایل پنل CLI
if [ "$DOMAIN_MODE" = true ]; then
    sed -i "s/IP_PLACEHOLDER/$PANEL_DOMAIN/g" /usr/local/bin/shadow
    sed -i "s/\[DOMAIN_PLACEHOLDER\]/$PANEL_DOMAIN/g" /usr/local/bin/shadow
else
    sed -i "s/IP_PLACEHOLDER/$(curl -s ifconfig.me)/g" /usr/local/bin/shadow
    sed -i "s/\[DOMAIN_PLACEHOLDER\]/$(curl -s ifconfig.me)/g" /usr/local/bin/shadow
fi

chmod +x /usr/local/bin/shadow

# غیرفعال کردن سرویس وب پنل (اگر قبلاً نصب شده بود)
systemctl stop ssh-panel 2>/dev/null
systemctl disable ssh-panel 2>/dev/null
rm -f /etc/systemd/system/ssh-panel.service
rm -rf /var/www/ssh-panel

# حذف nginx (برای پنل CLI نیازی نیست)
apt remove -y nginx nginx-common 2>/dev/null

# نهایی
clear
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "====================================="
echo "🔧 PANEL COMMAND: sudo shadow"
echo "🔌 SSH Port: 22 (Super Boosted)"
echo "🚫 Port 8388: Removed"
if [ "$DOMAIN_MODE" = true ]; then
    echo "🌐 Domain: $PANEL_DOMAIN (IP hidden)"
else
    echo "🌐 Using IP: $PANEL_DOMAIN"
fi
echo "====================================="
echo -e "${YELLOW}💡 Run 'shadow' to manage users${NC}"
