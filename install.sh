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
echo -e "${MAGENTA}     ARVIN SHADOW SSH v2.0${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}[*] Installing Ultra Speed Shadow SSH...${NC}"

# ============ KERNEL OPTIMIZATIONS ============
echo -e "${YELLOW}[1/6] Applying Kernel Optimizations...${NC}"
cat >> /etc/sysctl.conf << EOF
# Arvin Shadow SSH Optimizations
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 1200
EOF
sysctl -p > /dev/null 2>&1
echo -e "${GREEN}[✓] Kernel optimized (BBR+FQ)${NC}"

# ============ INSTALL BOOSTER ============
echo -e "${YELLOW}[2/6] Installing UDP Booster...${NC}"
apt update -qq 2>/dev/null
apt install -y -qq udp2raw-tunnel udpspeeder net-tools 2>/dev/null

# ============ AUTO BOOSTER SERVICE ============
echo -e "${YELLOW}[3/6] Creating Auto Booster Service...${NC}"
cat > /etc/systemd/system/arvin-booster.service << EOF
[Unit]
Description=Arvin Shadow SSH Booster
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/arvin-booster start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/bin/arvin-booster << 'BOOSTER'
#!/bin/bash
start() {
    # UDPspeeder on port 8388
    nohup udpspeeder -l 0.0.0.0:8388 -r 127.0.0.1:22 -k "ArvinShadow2024" -c -f 20:10 --mode 0 --mtu 1500 --log-level 0 > /dev/null 2>&1 &
    # UDP2RAW on port 8389
    nohup udp2raw -s -l 0.0.0.0:8389 -r 127.0.0.1:8388 -k "ArvinShadow2024" --raw-mode faketcp -a > /dev/null 2>&1 &
    echo "[✓] Booster Active: Port 8388 (UDP) + Port 8389 (TCP)"
}
stop() {
    pkill -f udpspeeder 2>/dev/null
    pkill -f udp2raw 2>/dev/null
    echo "[✓] Booster Stopped"
}
case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    *) echo "Usage: arvin-booster {start|stop|restart}" ;;
esac
BOOSTER
chmod +x /usr/local/bin/arvin-booster

systemctl daemon-reload
systemctl enable arvin-booster
systemctl start arvin-booster
echo -e "${GREEN}[✓] Booster service active${NC}"

# ============ OPEN FIREWALL ============
echo -e "${YELLOW}[4/6] Configuring Firewall...${NC}"
iptables -A INPUT -p udp --dport 8388 -j ACCEPT 2>/dev/null
iptables -A INPUT -p tcp --dport 8389 -j ACCEPT 2>/dev/null
iptables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null

# ============ MAIN PANEL ============
echo -e "${YELLOW}[5/6] Installing Shadow Panel...${NC}"
cat > /usr/local/bin/arvin-shadow << 'PANEL'
#!/bin/bash
RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; BLUE="\033[1;34m"; CYAN="\033[1;36m"; MAGENTA="\033[1;35m"; NC="\033[0m"
IP=$(curl -s ifconfig.me)
show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${MAGENTA}          ARVIN SHADOW SSH v2.0 - GOD MODE              ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${GREEN} Server IP:${NC} $IP"
    echo -e "${CYAN}║${GREEN} Shadow Port:${NC} 8388 (UDP Accelerated)"
    echo -e "${CYAN}║${GREEN} Regular Port:${NC} 22"
    echo -e "${CYAN}║${GREEN} Booster:${NC} Active (UDPspeeder + UDP2RAW)"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${NC}"
}
create_user() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Username: " u
    if id "$u" &>/dev/null; then echo -e "${RED}User exists!${NC}"; return; fi
    read -p "Password (Enter=auto): " p
    [ -z "$p" ] && p=$(openssl rand -base64 12 | tr -d '/+=' | cut -c1-10)
    read -p "Limit GB (0=unlimited): " l
    read -p "Days (0=unlimited): " d
    if [ "$d" != "0" ]; then exp=$(date -d "+${d} days" +%Y-%m-%d); useradd -m -s /bin/bash -e "$exp" "$u"; else useradd -m -s /bin/bash "$u"; fi
    echo "$u:$p" | chpasswd
    if [ "$l" != "0" ]; then q=$((l * 1073741824)); iptables -N "${u}_limit" 2>/dev/null; iptables -F "${u}_limit" 2>/dev/null; iptables -A "${u}_limit" -m quota --quota "$q" -j ACCEPT; iptables -A "${u}_limit" -j DROP; iptables -I OUTPUT -m owner --uid-owner $(id -u "$u") -j "${u}_limit"; fi
    # Regular Config (Port 22)
    json1="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"${u}-regular\",\"sshHost\":\"$IP\",\"sshPort\":22,\"sshUsername\":\"$u\",\"sshPassword\":\"$p\",\"udpgwTransparentDNS\":true}"
    enc1=$(echo -n "$json1" | base64 -w 0)
    # Shadow Config (Port 8388 - Ultra Speed)
    json2="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"${u}-shadow-ultra\",\"sshHost\":\"$IP\",\"sshPort\":8388,\"sshUsername\":\"$u\",\"sshPassword\":\"$p\",\"udpgwTransparentDNS\":true}"
    enc2=$(echo -n "$json2" | base64 -w 0)
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}[✓] USER CREATED SUCCESSFULLY${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Username:${NC} $u"
    echo -e "${YELLOW}Password:${NC} $p"
    [ "$d" != "0" ] && echo -e "${YELLOW}Expiry:${NC} +${d} days"
    [ "$l" != "0" ] && echo -e "${YELLOW}Limit:${NC} ${l}GB"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}[1] REGULAR SSH (Port 22):${NC}"
    echo -e "${CYAN}npvt-ssh://$enc1${NC}"
    echo -e "${MAGENTA}[2] SHADOW SSH ULTRA SPEED (Port 8388) - 5-10x Faster:${NC}"
    echo -e "${CYAN}npvt-ssh://$enc2${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "$enc1" > "/root/${u}_regular.txt"
    echo "$enc2" > "/root/${u}_shadow.txt"
}
show_usage() { read -p "Username: " u; if ! id "$u" &>/dev/null; then echo -e "${RED}Not found!${NC}"; return; fi; exp=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2); echo -e "${GREEN}User: $u - Expires: $exp${NC}"; }
list_users() { echo -e "${GREEN}Users:${NC}" && ls /home; }
delete_user() { read -p "Username: " u; if ! id "$u" &>/dev/null; then echo -e "${RED}Not found!${NC}"; return; fi; iptables -D OUTPUT -m owner --uid-owner $(id -u "$u") -j "${u}_limit" 2>/dev/null; iptables -F "${u}_limit" 2>/dev/null; iptables -X "${u}_limit" 2>/dev/null; userdel -r "$u" 2>/dev/null; echo -e "${GREEN}Deleted!${NC}"; }
while true; do show_header; echo -e "1) Create Shadow Config (2 Links)"; echo -e "2) Show User Usage"; echo -e "3) List Users"; echo -e "4) Delete User"; echo -e "5) Exit"; read -p "Choose: " c; case $c in 1) create_user;; 2) show_usage;; 3) list_users;; 4) delete_user;; 5) exit 0;; esac; read -p "Press Enter..."; done
PANEL
chmod +x /usr/local/bin/arvin-shadow

# ============ ALIAS ============
echo -e "${YELLOW}[6/6] Creating Aliases...${NC}"
echo "alias arvin=\"/usr/local/bin/arvin-shadow\"" >> ~/.bashrc
echo "alias shadow=\"/usr/local/bin/arvin-shadow\"" >> ~/.bashrc

# ============ FINAL ============
echo -e "${GREEN}========================================${NC}"
echo -e "${MAGENTA}   ✅ SHADOW SSH v2.0 INSTALLED!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${CYAN}Commands:${NC} arvin-shadow or arvin or shadow"
echo -e "${CYAN}Shadow Port:${NC} 8388 (Ultra Speed - 5-10x Faster)"
echo -e "${CYAN}Regular Port:${NC} 22"
echo -e "${CYAN}Booster Status:${NC} $(systemctl is-active arvin-booster)"
echo -e "${GREEN}========================================${NC}"
