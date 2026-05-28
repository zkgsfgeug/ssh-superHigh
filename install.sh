#!/bin/bash

# =============================================
# Shadow SSH v2.0 - Nezha Config Edition
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v2.0 - Nezha Config Edition${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# Clean previous
pkill -9 shadow 2>/dev/null
rm -f /usr/local/bin/shadow /etc/shadow-*.conf

# Fix dpkg
dpkg --configure -a 2>/dev/null
apt-get install -f -y 2>/dev/null

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y
apt install -y curl wget coreutils openssh-server ufw

# Remove port 8388
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/Port 8389/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# Create config files
touch /etc/shadow-users.conf
touch /etc/shadow-domain.conf

# Set default domain
echo "arvinam.duckdns.org" > /etc/shadow-domain.conf

# Install UDP2RAW + UDPspeeder for speed boost
echo -e "${YELLOW}⚡ Installing speed boosters...${NC}"
apt install -y git gcc make libsodium-dev
git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel && make && make install && cd ..
git clone https://github.com/wangyu-/UDPspeeder.git
cd UDPspeeder && make && make install && cd ..
rm -rf udp2raw-tunnel UDPspeeder

# Create booster service for port 22
cat > /etc/systemd/system/ssh-booster.service << EOF
[Unit]
Description=SSH Port 22 Booster
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'socat TCP4-LISTEN:22,fork,reuseaddr TCP4:127.0.0.1:60022 & udp2raw -s -l 0.0.0.0:4096 -r 127.0.0.1:8389 -k "shadow123" --raw-mode faketcp -a & UDPspeeder -s -l 0.0.0.0:8389 -r 127.0.0.1:22 -k "shadow123" --timeout 1 -f 5:3'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ssh-booster.service
systemctl start ssh-booster.service

# Create main panel
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
        curl -s ifconfig.me
    fi
}

# Generate Nezha/Sing-Box config
generate_config() {
    local user=$1
    local pass=$2
    local server=$(get_server)
    
    # Base64 encode for Nezha format
    local config_raw="${user}:${pass}@${server}:22"
    local config_b64=$(echo -n "$config_raw" | base64 -w 0)
    
    cat << EOF

${BLUE}════════════════════════════════════════════${NC}
${GREEN}📱 NEZHA / SING-BOX CONFIG${NC}
${BLUE}════════════════════════════════════════════${NC}

${YELLOW}🔗 SSH Direct:${NC}
   ssh ${user}@${server} -p 22

${YELLOW}📦 Nezha Config (Base64):${NC}
   ${GREEN}${config_b64}${NC}

${YELLOW}📦 Nezha Config (Raw):${NC}
   ${GREEN}${config_raw}${NC}

${YELLOW}📱 Sing-Box JSON:${NC}
${GREEN}{
  "outbounds": [
    {
      "type": "ssh",
      "tag": "ssh-${user}",
      "server": "${server}",
      "server_port": 22,
      "user": "${user}",
      "password": "${pass}"
    }
  ]
}${NC}

${YELLOW}🔗 Clash Meta:${NC}
   ssh://${config_raw}

${BLUE}════════════════════════════════════════════${NC}
EOF
}

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       🚀 SHADOW SSH v2.0 - NEZHA EDITION${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}SSH Port:${NC} 22 ${GREEN}(Super Boosted - UDP Accelerated)${NC}"
    echo -e "   ${RED}Port 8388:${NC} ${RED}REMOVED${NC}"
    echo -e "   ${GREEN}Domain: $(get_server)${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${YELLOW}1${NC}) Create New User + Get Config"
    echo -e "   ${YELLOW}2${NC}) List All Users"
    echo -e "   ${YELLOW}3${NC}) Show Config for Existing User"
    echo -e "   ${YELLOW}4${NC}) Delete User"
    echo -e "   ${GREEN}5${NC}) Change Domain"
    echo -e "   ${YELLOW}6${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

create_user() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✨ CREATE NEW USER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    echo -n "🔑 Password: "
    read password
    echo -n "📊 Traffic Limit (GB): "
    read traffic
    echo -n "📅 Days Valid: "
    read days

    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$traffic" ] || [ -z "$days" ]; then
        echo -e "\n${RED}❌ All fields required!${NC}"
        sleep 2
        return
    fi
    
    if ! [[ "$traffic" =~ ^[0-9]+$ ]] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n${RED}❌ Must be numbers!${NC}"
        sleep 2
        return
    fi

    local expiry=$(date -d "+$days days" +%s)
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null
    
    clear
    echo -e "${GREEN}✅ USER CREATED SUCCESSFULLY!${NC}"
    generate_config "$username" "$password"
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read dummy
}

list_users() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 ACTIVE USERS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"

    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ No users found${NC}"
        echo -e "\n${YELLOW}Press Enter...${NC}"
        read dummy
        return
    fi

    local current_time=$(date +%s)
    printf "   %-15s %-12s %-10s\n" "USER" "EXPIRES" "TRAFFIC"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    
    while IFS=: read -r user pass traffic expiry used; do
        local remaining=$(( (expiry - current_time) / 86400 ))
        if [ $remaining -lt 0 ]; then
            printf "   ${RED}%-15s EXPIRED     %-10s${NC}\n" "$user" "${traffic}GB"
        else
            printf "   ${GREEN}%-15s${NC} %-12s %-10s\n" "$user" "${remaining}d" "${traffic}GB"
        fi
    done < "$CONFIG_FILE"
    
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
    
    local user_info=$(grep "^$username:" "$CONFIG_FILE")
    local user_pass=$(echo "$user_info" | cut -d: -f2)
    
    clear
    generate_config "$username" "$user_pass"
    echo -e "\n${YELLOW}Press Enter...${NC}"
    read dummy
}

delete_user() {
    read -p "👤 Username to delete: " username
    if [ -z "$username" ]; then
        echo -e "${RED}❌ Required!${NC}"
        sleep 2
        return
    fi
    sed -i "/^$username:/d" "$CONFIG_FILE"
    userdel -r "$username" 2>/dev/null
    echo -e "${GREEN}✅ Deleted${NC}"
    sleep 2
}

set_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 CHANGE DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -n "👉 New domain: "
    read domain
    if [ -n "$domain" ]; then
        echo "$domain" > "$DOMAIN_FILE"
        echo -e "${GREEN}✅ Domain changed to: $domain${NC}"
    else
        echo -e "${RED}❌ Invalid${NC}"
    fi
    sleep 2
}

while true; do
    show_menu
    echo -n "👉 Choose [1-6]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) show_config ;;
        4) delete_user ;;
        5) set_domain ;;
        6) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# Super kernel boost
echo -e "${YELLOW}⚡ Super boosting kernel...${NC}"
cat >> /etc/sysctl.conf << 'EOF'

# Shadow SSH - Maximum Performance
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 100000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
EOF

sysctl -p > /dev/null 2>&1

# Open firewall
ufw allow 22/tcp 2>/dev/null
ufw allow 4096/udp 2>/dev/null

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Features:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • SSH Port:  ${GREEN}22 (UDP Boosted - 5-10x faster)${NC}"
echo -e "   • Domain:    ${GREEN}arvinam.duckdns.org${NC}"
echo -e "   • Config:    ${GREEN}Nezha / Sing-Box / Clash ready${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run:${NC} ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
