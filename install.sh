#!/bin/bash

# Shadow SSH v2.0 - Original GitHub Version
# Source: https://github.com/zkgsfgeug/ssh-superHigh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Shadow SSH v2.0 Installation Starting...${NC}"

# Update system
apt update -y && apt upgrade -y

# Install dependencies
apt install -y git gcc make libsodium-dev build-essential python3

# Clone UDP tools
git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel
make && make install
cd ..

git clone https://github.com/wangyu-/UDPspeeder.git
cd UDPspeeder
make && make install
cd ..

# Create main management script
cat > /usr/local/bin/shadow << 'EOF'
#!/bin/bash

CONFIG_FILE="/etc/shadow-users.conf"

show_menu() {
    clear
    echo "====================================="
    echo "🚀 Shadow SSH v2.0 - Control Panel"
    echo "====================================="
    echo "1. Add New User"
    echo "2. Delete User"
    echo "3. Show All Users"
    echo "4. Show User Config"
    echo "5. Exit"
    echo "====================================="
}

add_user() {
    read -p "Username: " username
    read -p "Password: " password
    read -p "Traffic Limit (GB): " traffic
    read -p "Days Valid: " days
    
    expiry=$(date -d "+$days days" +%s)
    echo "$username:$password:$traffic:$expiry:0" >> $CONFIG_FILE
    
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "\n✅ User Created Successfully!"
    echo "─────────────────────────────────"
    echo "SSH Command: ssh $username@$SERVER_IP -p 22"
    echo "─────────────────────────────────"
}

list_users() {
    echo "📋 Active Users:"
    cat $CONFIG_FILE 2>/dev/null | while IFS=: read user pass traffic expiry used; do
        remaining=$(( ($expiry - $(date +%s)) / 86400 ))
        echo "• $user | Expires: ${remaining}d | Traffic: ${traffic}GB"
    done
}

while true; do
    show_menu
    read -p "Choose: " choice
    case $choice in
        1) add_user ;;
        2) echo "Delete user - Coming soon" ;;
        3) list_users; read -p "Press Enter..." ;;
        4) echo "Show config - Coming soon" ;;
        5) exit 0 ;;
    esac
done
EOF

chmod +x /usr/local/bin/shadow

# Optimize kernel
cat >> /etc/sysctl.conf << EOF
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF

sysctl -p

clear
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "====================================="
echo "Run 'shadow' to manage users"
echo "SSH Port: 22"
echo "====================================="
