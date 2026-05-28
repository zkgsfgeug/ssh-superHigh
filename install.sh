#!/bin/bash

# Shadow SSH v2.0 - Clean Version (No Port 8388 + Domain Support)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 Shadow SSH v2.0 - Clean Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# Kill any hanging processes
killall apt apt-get 2>/dev/null
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock

echo -e "${YELLOW}📦 Updating system...${NC}"
apt update -y
apt install -y curl wget coreutils

# Remove port 8388 completely from SSH config
echo -e "${YELLOW}🚫 Removing port 8388...${NC}"
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/Port 8389/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart sshd

# Create domain config file
DOMAIN_FILE="/etc/shadow-domain.conf"
if [ ! -f $DOMAIN_FILE ]; then
    echo "" > $DOMAIN_FILE
fi

# Create main panel script
echo -e "${YELLOW}🔧 Creating management panel...${NC}"
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
    local domain=$(cat $DOMAIN_FILE 2>/dev/null | head -1)
    if [ -n "$domain" ] && [ "$domain" != "" ]; then
        echo "$domain"
    else
        curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "SERVER_IP"
    fi
}

show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       🚀 SHADOW SSH v2.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}   SSH Port:${NC} 22 ${GREEN}(Super Boosted)${NC}"
    echo -e "${RED}   Port 8388:${NC} ${RED}REMOVED${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}1${NC}) Create New User"
    echo -e "${YELLOW}2${NC}) Show User Usage"
    echo -e "${YELLOW}3${NC}) List All Users"
    echo -e "${YELLOW}4${NC}) Delete User"
    echo -e "${GREEN}5${NC}) Set Domain (Hide Server IP) ⭐"
    echo -e "${YELLOW}6${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    local current_domain=$(cat $DOMAIN_FILE 2>/dev/null | head -1)
    if [ -n "$current_domain" ] && [ "$current_domain" != "" ]; then
        echo -e "${GREEN}🌐 Domain Mode: $current_domain${NC}"
    else
        echo -e "${YELLOW}🌐 IP Mode: $(curl -s -4 ifconfig.me 2>/dev/null)${NC}"
        echo -e "${YELLOW}   Select option 5 to set a domain${NC}"
    fi
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

set_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 SET DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Enter your domain that points to this server${NC}"
    echo -e "${YELLOW}All configs will use DOMAIN instead of IP${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    read -p "👉 Domain: " user_domain
    
    if [ -z "$user_domain" ]; then
        echo -e "${RED}❌ Domain cannot be empty!${NC}"
        read -p "Press Enter..."
        return
    fi
    
    echo "$user_domain" > $DOMAIN_FILE
    echo -e "${GREEN}✅ Domain saved: $user_domain${NC}"
    echo -e "${YELLOW}📌 New configs will use this domain${NC}"
    read -p "Press Enter..."
}

create_user() {
    clear
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    read -p "👤 Username: " username
    read -p "🔑 Password: " password
    read -p "📊 Traffic (GB): " traffic
    read -p "📅 Days: " days

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
    echo -e "${GREEN}✅ USER CREATED!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 Connection Info:${NC}"
    echo -e "   Username: ${GREEN}$username${NC}"
    echo -e "   Password: ${GREEN}$password${NC}"
    echo -e "   Server:   ${GREEN}$SERVER_ADDR${NC}"
    echo -e "   Port:     ${GREEN}22${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}🔗 SSH Command:${NC}"
    echo -e "   ${GREEN}ssh $username@$SERVER_ADDR -p 22${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    read -p "Press Enter..."
}

list_users() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 ACTIVE USERS${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"

    if [ ! -s $CONFIG_FILE ]; then
        echo -e "${RED}❌ No users found${NC}"
        read -p "Press Enter..."
        return
    fi

    current_time=$(date +%s)
    while IFS=: read user pass traffic expiry used; do
        remaining_days=$(( ($expiry - $current_time) / 86400 ))
        if [ $remaining_days -lt 0 ]; then
            echo -e "   ${RED}✗ $user | EXPIRED${NC}"
        else
            echo -e "   ${GREEN}✓ $user${NC} | ${remaining_days}d left | ${traffic}GB"
        fi
    done < $CONFIG_FILE
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
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
    echo -e "${GREEN}✅ User $username deleted${NC}"
    read -p "Press Enter..."
}

show_usage() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📊 USER USAGE${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    if [ ! -s $CONFIG_FILE ]; then
        echo -e "${RED}❌ No users found${NC}"
        read -p "Press Enter..."
        return
    fi
    
    while IFS=: read user pass traffic expiry used; do
        echo -e "   ${GREEN}$user${NC} - ${used}/${traffic} GB used"
    done < $CONFIG_FILE
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    read -p "Press Enter..."
}

while true; do
    show_menu
    read -p "👉 Choose [1-6]: " choice
    case $choice in
        1) create_user ;;
        2) show_usage ;;
        3) list_users ;;
        4) delete_user ;;
        5) set_domain ;;
        6) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
    esac
done
EOF

chmod +x /usr/local/bin/shadow

# Optimize kernel for Port 22 only
echo -e "${YELLOW}⚡ Optimizing kernel for Port 22...${NC}"
cat >> /etc/sysctl.conf << EOF

# Shadow SSH - Port 22 Only
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
EOF

sysctl -p > /dev/null 2>&1

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Features:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • SSH Port:  ${GREEN}22 (Super Boosted)${NC}"
echo -e "   • Domain Support: ${GREEN}YES${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run this command to start:${NC}"
echo -e "   ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
