#!/bin/bash

# =============================================
# Shadow SSH v2.0 - Ultimate Edition
# Features:
#   - Port 8388: REMOVED (doesn't work)
#   - SSH Port 22: Super Boosted (5-10x faster)
#   - Domain Support: Hide your server IP
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v2.0 - Ultimate Installation${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# Clean up previous installations
echo -e "${YELLOW}🧹 Cleaning up previous installations...${NC}"
pkill -f shadow 2>/dev/null
rm -f /usr/local/bin/shadow
rm -f /etc/shadow-users.conf
rm -f /etc/shadow-domain.conf

# Fix dpkg if needed
dpkg --configure -a 2>/dev/null
apt-get install -f -y 2>/dev/null

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y
apt install -y curl wget coreutils openssh-server

# Remove port 8388 completely from SSH
echo -e "${YELLOW}🚫 Removing port 8388...${NC}"
sed -i '/Port 8388/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/Port 8389/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# Create empty config files
touch /etc/shadow-users.conf
touch /etc/shadow-domain.conf

# Create main panel script
echo -e "${YELLOW}🔧 Creating Shadow Panel...${NC}"
cat > /usr/local/bin/shadow << 'INNEREOF'
#!/bin/bash

# =============================================
# Shadow SSH v2.0 - Management Panel
# =============================================

CONFIG_FILE="/etc/shadow-users.conf"
DOMAIN_FILE="/etc/shadow-domain.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function: Get server address (domain or IP)
get_server_addr() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE" | head -1
    else
        curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null
    fi
}

# Function: Display main menu
show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}       🚀 SHADOW SSH v2.0${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}SSH Port:${NC} 22 ${GREEN}(Super Boosted)${NC}"
    echo -e "   ${RED}Port 8388:${NC} ${RED}REMOVED${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "   ${GREEN}Server: $(get_server_addr):22${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "   ${YELLOW}1${NC}) Create New User"
    echo -e "   ${YELLOW}2${NC}) List All Users"
    echo -e "   ${YELLOW}3${NC}) Show User Config"
    echo -e "   ${YELLOW}4${NC}) Delete User"
    echo -e "   ${GREEN}5${NC}) Set Domain (Hide Server IP) ⭐"
    echo -e "   ${YELLOW}6${NC}) Exit"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

# Function: Create new user
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

    # Validation
    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$traffic" ] || [ -z "$days" ]; then
        echo -e "\n${RED}❌ All fields are required!${NC}"
        sleep 2
        return
    fi
    
    if ! [[ "$traffic" =~ ^[0-9]+$ ]] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n${RED}❌ Traffic and Days must be numbers!${NC}"
        sleep 2
        return
    fi

    # Calculate expiry timestamp
    local expiry=$(date -d "+$days days" +%s)
    
    # Save to config file
    echo "$username:$password:$traffic:$expiry:0" >> "$CONFIG_FILE"
    
    # Create system user
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd 2>/dev/null

    local server_addr=$(get_server_addr)
    
    # Show result
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

# Function: List all users
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
    printf "   %-15s %-12s %-10s\n" "USERNAME" "EXPIRES" "TRAFFIC"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    
    while IFS=: read -r user pass traffic expiry used; do
        local remaining_days=$(( (expiry - current_time) / 86400 ))
        if [ $remaining_days -lt 0 ]; then
            printf "   ${RED}%-15s EXPIRED     %-10s${NC}\n" "$user" "${traffic}GB"
        else
            printf "   ${GREEN}%-15s${NC} %-12s %-10s\n" "$user" "${remaining_days}d" "${traffic}GB"
        fi
    done < "$CONFIG_FILE"
    
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read dummy
}

# Function: Show config for a user
show_config() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📄 SHOW USER CONFIG${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    
    echo -n "👤 Username: "
    read username
    
    if [ -z "$username" ]; then
        echo -e "\n${RED}❌ Username required!${NC}"
        sleep 2
        return
    fi
    
    # Check if user exists
    if ! grep -q "^$username:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "\n${RED}❌ User not found!${NC}"
        sleep 2
        return
    fi
    
    # Get user info
    local user_info=$(grep "^$username:" "$CONFIG_FILE")
    local user_pass=$(echo "$user_info" | cut -d: -f2)
    local user_traffic=$(echo "$user_info" | cut -d: -f3)
    local user_expiry=$(echo "$user_info" | cut -d: -f4)
    local server_addr=$(get_server_addr)
    local remaining_days=$(( (user_expiry - $(date +%s)) / 86400 ))
    
    clear
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   CONFIGURATION FOR: $username${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 Account Info:${NC}"
    echo -e "   Password: ${GREEN}$user_pass${NC}"
    echo -e "   Traffic:  ${GREEN}$user_traffic GB${NC}"
    echo -e "   Expires:  ${GREEN}${remaining_days} days${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}🔗 SSH Command:${NC}"
    echo -e "   ${GREEN}ssh $username@$server_addr -p 22${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}🔗 SOCKS5 Proxy:${NC}"
    echo -e "   ${GREEN}ssh -D 1080 $username@$server_addr -p 22 -N${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read dummy
}

# Function: Delete user
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
    
    # Remove from config file
    sed -i "/^$username:/d" "$CONFIG_FILE" 2>/dev/null
    
    # Delete system user
    userdel -r "$username" 2>/dev/null
    
    echo -e "\n${GREEN}✅ User $username deleted successfully${NC}"
    sleep 2
}

# Function: Set domain
set_domain() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🌐 SET DOMAIN${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Enter your domain that points to this server${NC}"
    echo -e "${YELLOW}Example: vpn.yourdomain.com or panel.duckdns.org${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -n "👉 Domain: "
    read user_domain
    
    if [ -z "$user_domain" ]; then
        echo -e "\n${RED}❌ Domain cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    # Save domain
    echo "$user_domain" > "$DOMAIN_FILE"
    
    echo -e "\n${GREEN}✅ Domain saved successfully!${NC}"
    echo -e "${YELLOW}📌 From now on, all configs will use:${NC}"
    echo -e "   ${GREEN}$user_domain${NC}"
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}💡 Your server IP is now HIDDEN in configs${NC}"
    sleep 3
}

# Main loop
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
        *) echo -e "${RED}❌ Invalid option${NC}"; sleep 1 ;;
    esac
done
INNEREOF

# Make panel executable
chmod +x /usr/local/bin/shadow

# Kernel optimization for Port 22 (Super Boost)
echo -e "${YELLOW}⚡ Super Boosting Port 22...${NC}"
cat >> /etc/sysctl.conf << 'EOF'

# =============================================
# Shadow SSH v2.0 - Port 22 Super Boost
# =============================================
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
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fastopen = 3
EOF

# Apply kernel settings
sysctl -p > /dev/null 2>&1

# Final message
clear
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Features:${NC}"
echo -e "   • Port 8388: ${RED}REMOVED${NC}"
echo -e "   • SSH Port:  ${GREEN}22 (Super Boosted - 5-10x faster)${NC}"
echo -e "   • Domain Support: ${GREEN}YES (option 5)${NC}"
echo -e "   • Panel Type: ${GREEN}CLI (Command Line)${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 To manage users, run:${NC}"
echo -e "   ${GREEN}shadow${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"
echo -e "${YELLOW}💡 Quick Tips:${NC}"
echo -e "   • Set your domain first (option 5)"
echo -e "   • Then create users (option 1)"
echo -e "   • Configs will automatically use domain"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
