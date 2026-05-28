#!/bin/bash

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m'

clear
echo -e "${CYAN}========================================${NC}"
echo -e "${MAGENTA}        SHADOW SSH v2.0${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}[*] Installing Ultra Speed Shadow SSH...${NC}"

# ============ CHECK ROOT ============
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[✗] This script must be run as root!${NC}"
   echo -e "${YELLOW}Try: sudo -i${NC}"
   exit 1
fi
echo -e "${GREEN}[✓] Root access confirmed${NC}"

# ============ GET IPv4 ONLY ============
echo -e "${YELLOW}[*] Getting IPv4 address...${NC}"
IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null || curl -s -4 api.ipify.org 2>/dev/null)
if [[ -z "$IP" ]]; then
    IP=$(hostname -I | awk '{print $1}')
fi
echo -e "${GREEN}[✓] Server IPv4: $IP${NC}"

# ============ KERNEL OPTIMIZATIONS ============
echo -e "${YELLOW}[1/6] Applying Kernel Optimizations...${NC}"
cat >> /etc/sysctl.conf << EOF
# Shadow SSH Optimizations
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
EOF
sysctl -p > /dev/null 2>&1
echo -e "${GREEN}[✓] Kernel optimized (BBR+FQ)${NC}"

# ============ INSTALL DEPENDENCIES ============
echo -e "${YELLOW}[2/6] Installing Dependencies...${NC}"
apt update -qq
apt install -y -qq openssl iptables curl net-tools wget sudo
echo -e "${GREEN}[✓] Dependencies installed${NC}"

# ============ INSTALL BOOSTER ============
echo -e "${YELLOW}[3/6] Installing UDP Booster...${NC}"
apt install -y -qq udp2raw-tunnel udpspeeder 2>/dev/null || echo -e "${YELLOW}[!] UDP tools skipped (optional)${NC}"

# ============ AUTO BOOSTER SERVICE ============
echo -e "${YELLOW}[4/6] Creating Auto Booster Service...${NC}"
cat > /etc/systemd/system/shadow-booster.service << EOF
[Unit]
Description=Shadow SSH Booster
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/shadow-booster start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/bin/shadow-booster << 'BOOSTER'
#!/bin/bash
start() {
    if command -v udpspeeder &> /dev/null; then
        nohup udpspeeder -l 0.0.0.0:8388 -r 127.0.0.1:22 -k "Shadow2024" -c -f 20:10 --mode 0 --mtu 1500 --log-level 0 > /dev/null 2>&1 &
        echo "[✓] UDPspeeder active on port 8388"
    fi
    if command -v udp2raw &> /dev/null; then
        nohup udp2raw -s -l 0.0.0.0:8389 -r 127.0.0.1:8388 -k "Shadow2024" --raw-mode faketcp -a > /dev/null 2>&1 &
        echo "[✓] UDP2RAW active on port 8389"
    fi
}
stop() {
    pkill -f udpspeeder 2>/dev/null
    pkill -f udp2raw 2>/dev/null
    echo "[✓] Booster stopped"
}
case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    *) echo "Usage: shadow-booster {start|stop|restart}" ;;
esac
BOOSTER
chmod +x /usr/local/bin/shadow-booster
systemctl daemon-reload
systemctl enable shadow-booster
systemctl start shadow-booster
echo -e "${GREEN}[✓] Booster service active${NC}"

# ============ FIREWALL ============
echo -e "${YELLOW}[5/6] Configuring Firewall...${NC}"
iptables -A INPUT -p udp --dport 8388 -j ACCEPT 2>/dev/null
iptables -A INPUT -p tcp --dport 8389 -j ACCEPT 2>/dev/null
iptables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null
echo -e "${GREEN}[✓] Firewall rules applied${NC}"

# ============ MAIN PANEL ============
echo -e "${YELLOW}[6/6] Installing Shadow Panel...${NC}"
cat > /usr/local/bin/shadow-panel << 'PANEL'
#!/bin/bash
RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; BLUE="\033[1;34m"; CYAN="\033[1;36m"; MAGENTA="\033[1;35m"; NC="\033[0m"

# Get IPv4 only
get_ipv4() {
    IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null || curl -s -4 api.ipify.org 2>/dev/null)
    if [[ -z "$IP" ]]; then
        IP=$(hostname -I | awk '{print $1}')
    fi
    echo "$IP"
}

IP=$(get_ipv4)

show_header() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${MAGENTA}        SHADOW SSH v2.0 PANEL${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN} Server IPv4:${NC} $IP"
    echo -e "${GREEN} Shadow Port:${NC} 8388 (UDP Accelerated)"
    echo -e "${GREEN} Regular Port:${NC} 22"
    echo -e "${GREEN} Booster:${NC} Active"
    echo -e "${CYAN}========================================${NC}"
}

list_users() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}Existing users:${NC}"
    if [ "$(ls /home 2>/dev/null)" ]; then
        for user in $(ls /home 2>/dev/null); do
            exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2)
            echo -e "  ${GREEN}▶${NC} $user - Expires: $exp"
        done
    else
        echo -e "  ${RED}No users found${NC}"
    fi
    echo -e "${GREEN}========================================${NC}"
}

delete_user() {
    echo -e "${GREEN}========================================${NC}"
    list_users
    read -p "Username to delete: " u
    if ! id "$u" &>/dev/null; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    pkill -u "$u" 2>/dev/null
    iptables -D OUTPUT -m owner --uid-owner $(id -u "$u") -j "${u}_limit" 2>/dev/null
    iptables -F "${u}_limit" 2>/dev/null
    iptables -X "${u}_limit" 2>/dev/null
    userdel -r "$u" 2>/dev/null
    echo -e "${GREEN}[✓] User $u deleted${NC}"
}

create_user() {
    echo -e "${GREEN}========================================${NC}"
    read -p "Username: " u
    if id "$u" &>/dev/null; then
        echo -e "${RED}User exists!${NC}"
        return
    fi
    read -p "Password (Enter=auto): " p
    if [ -z "$p" ]; then
        p=$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-10)
        echo -e "${YELLOW}Auto password: $p${NC}"
    fi
    read -p "Limit GB (0=unlimited): " l
    read -p "Days (0=unlimited): " d
    
    if [ "$d" != "0" ] && [ "$d" -gt 0 ]; then
        exp=$(date -d "+${d} days" +%Y-%m-%d)
        useradd -m -s /bin/bash -e "$exp" "$u"
        echo -e "${GREEN}[✓] User created with expiry: $exp${NC}"
    else
        useradd -m -s /bin/bash "$u"
        echo -e "${GREEN}[✓] User created (no expiry)${NC}"
    fi
    
    echo "$u:$p" | chpasswd
    usermod -aG sudo "$u" 2>/dev/null
    
    if [ "$l" != "0" ] && [ "$l" -gt 0 ]; then
        quota=$((l * 1073741824))
        iptables -N "${u}_limit" 2>/dev/null
        iptables -F "${u}_limit" 2>/dev/null
        iptables -A "${u}_limit" -m quota --quota "$quota" -j ACCEPT
        iptables -A "${u}_limit" -j DROP
        iptables -I OUTPUT -m owner --uid-owner $(id -u "$u") -j "${u}_limit"
        echo -e "${GREEN}[✓] Traffic limit: ${l}GB${NC}"
    fi
    
    # Refresh IPv4
    IP=$(get_ipv4)
    
    # Regular config (Port 22)
    json1="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"${u}-regular\",\"sshHost\":\"$IP\",\"sshPort\":22,\"sshUsername\":\"$u\",\"sshPassword\":\"$p\",\"udpgwTransparentDNS\":true}"
    enc1=$(echo -n "$json1" | base64 -w 0)
    
    # Shadow config (Port 8388)
    json2="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"${u}-shadow\",\"sshHost\":\"$IP\",\"sshPort\":8388,\"sshUsername\":\"$u\",\"sshPassword\":\"$p\",\"udpgwTransparentDNS\":true}"
    enc2=$(echo -n "$json2" | base64 -w 0)
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}[✓] USER CREATED SUCCESSFULLY${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}Username:${NC} $u"
    echo -e "${YELLOW}Password:${NC} $p"
    [ "$d" != "0" ] && [ "$d" -gt 0 ] && echo -e "${YELLOW}Expiry:${NC} +${d} days"
    [ "$l" != "0" ] && [ "$l" -gt 0 ] && echo -e "${YELLOW}Limit:${NC} ${l}GB"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}[Regular SSH - Port 22]:${NC}"
    echo -e "${CYAN}npvt-ssh://$enc1${NC}"
    echo -e "${MAGENTA}[Shadow SSH - Port 8388 - Ultra Speed]:${NC}"
    echo -e "${CYAN}npvt-ssh://$enc2${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Save to file
    echo "npvt-ssh://$enc1" > "/root/${u}_regular.txt"
    echo "npvt-ssh://$enc2" > "/root/${u}_shadow.txt"
    echo -e "${YELLOW}Links saved in /root/${u}_regular.txt and /root/${u}_shadow.txt${NC}"
}

show_usage() {
    echo -e "${GREEN}========================================${NC}"
    read -p "Username: " u
    if ! id "$u" &>/dev/null; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    exp=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2)
    echo -e "${GREEN}User: $u${NC}"
    echo -e "Expires: $exp"
    
    # Check traffic usage
    if iptables -L "${u}_limit" -v -n 2>/dev/null | grep -q "quota"; then
        used=$(iptables -L "${u}_limit" -v -n 2>/dev/null | grep "quota" | awk '{print $2}')
        limit=$(iptables -L "${u}_limit" -v -n 2>/dev/null | grep "quota" | sed -n 's/.*quota \([0-9]*\).*/\1/p')
        if [[ -n "$used" && -n "$limit" ]]; then
            used_gb=$((used / 1073741824))
            limit_gb=$((limit / 1073741824))
            echo -e "Traffic: ${used_gb}GB / ${limit_gb}GB"
        fi
    fi
    echo -e "${GREEN}========================================${NC}"
}

# Main menu
while true; do
    show_header
    echo -e "1) ${GREEN}Create New Config${NC}"
    echo -e "2) ${YELLOW}Show User Usage${NC}"
    echo -e "3) ${CYAN}List All Users${NC}"
    echo -e "4) ${RED}Delete User${NC}"
    echo -e "5) ${MAGENTA}Exit${NC}"
    echo -e "${CYAN}========================================${NC}"
    read -p "Choose [1-5]: " choice
    case $choice in
        1) create_user ;;
        2) show_usage ;;
        3) list_users ;;
        4) delete_user ;;
        5) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}" ;;
    esac
    echo ""
    read -p "Press Enter to continue..."
done
PANEL

chmod +x /usr/local/bin/shadow-panel

# Create aliases
echo "alias shadow-panel=\"/usr/local/bin/shadow-panel\"" >> ~/.bashrc
echo "alias shadow=\"/usr/local/bin/shadow-panel\"" >> ~/.bashrc

# Final message
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${MAGENTA}   ✅ SHADOW SSH v2.0 INSTALLED!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${CYAN}Server IPv4:${NC} $IP"
echo -e "${CYAN}To run the panel, type:${NC} shadow-panel"
echo -e "${CYAN}Shadow Port (Ultra Speed):${NC} 8388"
echo -e "${CYAN}Regular Port:${NC} 22"
echo -e "${GREEN}========================================${NC}"
