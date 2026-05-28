cat > install.sh << 'EOF'
#!/bin/bash

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

# Kill any hanging processes
killall apt apt-get 2>/dev/null
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock

echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y
apt install -y curl wget coreutils

# Remove port 8388 completely
echo -e "${YELLOW}🚫 Removing port 8388...${NC}"
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/Port 8389/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart sshd

# Create domain config file
echo "" > /etc/shadow-domain.conf

# Create main panel script
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

get_server_addr() {
    if [ -f "$DOMAIN_FILE" ]; then
        local domain=$(cat "$DOMAIN_FILE" 2>/dev/null | head -1)
        if [ -n "$domain" ] && [ "$domain" != "" ]; then
            echo "$domain"
            return
        fi
    fi
    curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "SERVER_IP"
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
    echo -e "${YELLOW}2${NC}) List All Users"
    echo -e "${YELLOW}3${NC}) Delete User"
    echo -e "${GREEN}4${NC}) Set Domain (Hide Server IP) ⭐"
    echo -e "${YELLOW}5${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    if [ -f "$DOMAIN_FILE" ]; then
        local current_domain=$(cat "$DOMAIN_FILE" 2>/dev/null | head -1)
        if [ -n "$current_domain" ] && [ "$current_domain" != "" ]; then
            echo -e "${GREEN}🌐 Domain Mode: $current_domain${NC}"
        else
            echo -e "${YELLOW}🌐 IP Mode: $(curl -s -4 ifconfig.me 2>/dev/null)${NC}"
        fi
    fi
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

set_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 SET DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Enter your domain (e.g., vpn.example.com)${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -n "👉 Domain: "
    read user_domain
    
    if [ -z "$user_domain" ]; then
        echo -e "${RED}❌ Domain cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    echo "$user_domain" > "$DOMAIN_FILE"
    echo -e "${GREEN}✅ Domain saved: $user_domain${NC}"
    echo -e "${YELLOW}📌 New users will get configs with this domain${NC}"
    sleep 2
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
        echo -e "\n${RED}❌ ERROR: All fields are required!${NC}"
        sleep 2
        return
    fi

    if ! [[ "$traffic" =~ ^[0-9]+$ ]] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n${RED}❌ ERROR: Traffic and Days must be numbers!${NC}"
        sleep 2
        return
    fi

    local expiry=$(date -d "+$days days" +%s)
    
    # Save to config file
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    
    # Create system user
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd

    local server_addr=$(get_server_addr)
    
    clear
    echo -e "${GREEN}✅ USER CREATED SUCCESSFULLY!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 Connection Details:${NC}"
    echo -e "   Username: ${GREEN}$username${NC}"
    echo -e "   Password: ${GREEN}$password${NC}"
    echo -e "   Server:   ${GREEN}$server_addr${NC}"
    echo -e "   Port:     ${GREEN}22${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}🔗 SSH Command:${NC}"
    echo -e "   ${GREEN}ssh $username@$server_addr -p 22${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
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
        echo -e "\n${YELLOW}Press Enter to continue...${NC}"
        read dummy
        return
    fi

    local current_time=$(date +%s)
    while IFS=: read -r user pass traffic expiry used; do
        local remaining_days=$(( (expiry - current_time) / 86400 ))
        if [ $remaining_days -lt 0 ]; then
            echo -e "   ${RED}✗ $user | EXPIRED${NC}"
        else
            echo -e "   ${GREEN}✓ $user${NC} | ${remaining_days} days left | ${traffic} GB limit"
        fi
    done < "$CONFIG_FILE"
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
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
        echo -e "${RED}❌ Username required!${NC}"
        sleep 2
        return
    fi
    
    # Remove from config file
    sed -i "/^$username:/d" "$CONFIG_FILE" 2>/dev/null
    
    # Delete system user
    userdel -r "$username" 2>/dev/null
    
    echo -e "${GREEN}✅ User $username deleted successfully${NC}"
    sleep 2
}

# Main loop
while true; do
    show_menu
    echo -n "👉 Choose [1-5]: "
    read choice
    case $choice in
        1) create_user ;;
        2) list_users ;;
        3) delete_user ;;
        4) set_domain ;;
        5) echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
    esac
done
INNEREOF

chmod +x /usr/local/bin/shadow

# Kernel optimization
echo -e "${YELLOW}⚡ Optimizing kernel for Port 22...${NC}"
cat >> /etc/sysctl.conf << EOF

# Shadow SSH - Port 22 Only
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF

sysctl -p > /dev/null 2>&1

clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Features:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • SSH Port:  ${GREEN}22 (Super Boosted)${NC}"
echo -e "   • Domain Support: ${GREEN}YES (option 4)${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 Run this command to start:${NC}"
echo -e "   ${GREEN}shadow${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
EOF

# Run the installer
chmod +x install.sh
./install.sh
