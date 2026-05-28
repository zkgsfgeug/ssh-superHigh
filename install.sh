#!/bin/bash

# Shadow SSH v2.0 - Final Version with Domain Support + Port 22 Only

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 Shadow SSH v2.0 - Final Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# kill any hanging apt
killall apt apt-get 2>/dev/null
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock

echo -e "${YELLOW}📦 Updating system...${NC}"
apt update -y
apt install -y curl wget coreutils

# Remove port 8388 from SSH config completely
echo -e "${YELLOW}🚫 Removing port 8388...${NC}"
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/Port 8389/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/^#Port 22/a Port 22' /etc/ssh/sshd_config
systemctl restart sshd

# Create config file for domain
DOMAIN_FILE="/etc/shadow-domain.conf"
if [ ! -f $DOMAIN_FILE ]; then
    echo "IP_MODE" > $DOMAIN_FILE
fi

echo -e "${YELLOW}🔧 Creating management script...${NC}"
cat > /usr/local/bin/shadow << 'EOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

get_server_addr() {
    if [ -f $DOMAIN_FILE ]; then
        local stored=$(cat $DOMAIN_FILE)
        if [ "$stored" != "IP_MODE" ] && [ -n "$stored" ]; then
            echo "$stored"
            return
        fi
    fi
    curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "SERVER_IP"
}

show_menu() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 Shadow SSH v2.0 - Control Panel${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}1${NC}. Add New User"
    echo -e "${YELLOW}2${NC}. Delete User"
    echo -e "${YELLOW}3${NC}. Show All Users"
    echo -e "${YELLOW}4${NC}. Show User Config"
    echo -e "${YELLOW}5${NC}. Exit"
    echo -e "${YELLOW}6${NC}. Set Domain (Hide Server IP) ⭐ NEW"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    local current_addr=$(get_server_addr)
    if [ "$current_addr" != "IP_MODE" ] && [ "$current_addr" != "$(curl -s -4 ifconfig.me 2>/dev/null)" ]; then
        echo -e "${GREEN}🌐 Current Mode: DOMAIN → $current_addr${NC}"
    else
        echo -e "${YELLOW}🌐 Current Mode: IP → $current_addr${NC}"
    fi
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

set_domain() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 Set Domain for Configs${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}💡 If your server is behind a domain,${NC}"
    echo -e "${YELLOW}   enter it here to hide your server IP.${NC}"
    echo -e "${BLUE}─────────────────────────────────────${NC}"
    read -p "👉 Enter your domain (e.g., panel.yourdomain.com): " user_domain
    
    if [ -z "$user_domain" ]; then
        echo -e "${RED}❌ Domain cannot be empty!${NC}"
        read -p "Press Enter..."
        return
    fi
    
    # Verify domain resolves to this server
    echo -e "${YELLOW}🔍 Checking if domain points to this server...${NC}"
    domain_ip=$(dig +short $user_domain | head -1)
    server_ip=$(curl -s -4 ifconfig.me 2>/dev/null)
    
    if [ -z "$domain_ip" ]; then
        echo -e "${RED}❌ Domain does not resolve! Check DNS.${NC}"
        echo -e "${YELLOW}⚠️ Still saving domain, but verify it points to: $server_ip${NC}"
    elif [ "$domain_ip" != "$server_ip" ]; then
        echo -e "${RED}❌ Domain points to $domain_ip, but server IP is $server_ip${NC}"
        echo -e "${YELLOW}⚠️ Configs will use domain anyway, but may not work!${NC}"
    else
        echo -e "${GREEN}✅ Domain verified! Points to this server.${NC}"
    fi
    
    echo "$user_domain" > $DOMAIN_FILE
    echo -e "${GREEN}✅ Domain saved! All new configs will use: $user_domain${NC}"
    read -p "Press Enter..."
}

add_user() {
    clear
    echo -e "${BLUE}─────────────────────────────────────${NC}"
    read -p "👤 Username: " username
    read -p "🔑 Password: " password
    read -p "📊 Traffic Limit (GB): " traffic
    read -p "📅 Days Valid: " days

    if [[ -z "$username" || -z "$password" || -z "$traffic" || -z "$days" ]]; then
        echo -e "${RED}❌ All fields required!${NC}"
        read -p "Press Enter..."
        return
    fi

    expiry=$(date -d "+$days days" +%s)
    echo "$username:$password:$traffic:$expiry:0" >> $CONFIG_FILE
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd

    SERVER_ADDR=$(get_server_addr)
    
    clear
    echo -e "${GREEN}✅ User Created!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 Connection Info:${NC}"
    echo -e "   Username: ${GREEN}$username${NC}"
    echo -e "   Password: ${GREEN}$password${NC}"
    echo -e "   Server:   ${GREEN}$SERVER_ADDR${NC}"
    echo -e "   Port:     ${GREEN}22${NC}"
    echo -e "${BLUE}─────────────────────────────────────${NC}"
    echo -e "${YELLOW}🔗 SSH Command:${NC}"
    echo -e "   ${GREEN}ssh $username@$SERVER_ADDR -p 22${NC}"
    echo -e "${BLUE}─────────────────────────────────────${NC}"
    
    if [[ "$SERVER_ADDR" != *"."* ]]; then
        echo -e "${YELLOW}⚠️ You're using IP mode. Run option 6 to set a domain and hide your IP!${NC}"
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    read -p "Press Enter..."
}

list_users() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 Active Users${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"

    if [ ! -s $CONFIG_FILE ]; then
        echo -e "${RED}❌ No users found!${NC}"
        read -p "Press Enter..."
        return
    fi

    current_time=$(date +%s)
    cat $CONFIG_FILE 2>/dev/null | while IFS=: read user pass traffic expiry used; do
        remaining_days=$(( ($expiry - $current_time) / 86400 ))
        if [ $remaining_days -lt 0 ]; then
            echo -e "   ${RED}✗ $user | EXPIRED${NC}"
        else
            echo -e "   ${GREEN}✓ $user${NC} | Expires: ${YELLOW}${remaining_days}d${NC} | Traffic: ${BLUE}${traffic}GB${NC}"
        fi
    done
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    read -p "Press Enter..."
}

show_config() {
    read -p "👤 Username: " username
    SERVER_ADDR=$(get_server_addr)

    clear
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}📄 Config for: $username${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔗 Direct SSH:${NC}"
    echo -e "   ${GREEN}ssh $username@$SERVER_ADDR -p 22${NC}"
    echo -e ""
    echo -e "${YELLOW}⚙️ SOCKS5 Proxy:${NC}"
    echo -e "   ${GREEN}ssh -D 1080 $username@$SERVER_ADDR -p 22 -N${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    read -p "Press Enter..."
}

delete_user() {
    read -p "👤 Username to delete: " username
    if [ -z "$username" ]; then
        echo -e "${RED}❌ Username required!${NC}"
        return
    fi
    sed -i "/^$username:/d" $CONFIG_FILE 2>/dev/null
    userdel -r "$username" 2>/dev/null
    echo -e "${GREEN}✅ User $username deleted!${NC}"
    read -p "Press Enter..."
}

while true; do
    show_menu
    read -p "👉 Choose [1-6]: " choice
    case $choice in
        1) add_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) show_config ;;
        5) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        6) set_domain ;;
        *) echo -e "${RED}❌ Invalid!${NC}"; sleep 1 ;;
    esac
done
EOF

chmod +x /usr/local/bin/shadow

# Kernel optimization (only port 22)
echo -e "${YELLOW}⚙️ Optimizing kernel for Port 22...${NC}"
cat >> /etc/sysctl.conf << EOF

# Shadow SSH v2.0 - Port 22 only
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF

sysctl -p > /dev/null 2>&1

clear
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Summary:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • SSH Port:  ${GREEN}22 (Super Boosted)${NC}"
echo -e "   • Domain support: ${GREEN}YES (option 6)${NC}"
echo -e "${BLUE}─────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run 'shadow' to manage users${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
