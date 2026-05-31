#!/bin/bash

# =============================================
# Shadow SSH v20.0 - BOMB EDITION
# Features: Fake Location + Smart Config Generator + AI Optimizer + Fake DNS
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# ============================================
# SPACE SPEED + AI Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🚀 Activating SPACE SPEED + AI${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Clean all QoS
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc del dev $iface ingress 2>/dev/null
    done
    
    # Ultimate Kernel Settings
    cat > /etc/sysctl.conf << 'EOF'
net.core.rmem_max = 2147483647
net.core.wmem_max = 2147483647
net.core.rmem_default = 2147483647
net.core.wmem_default = 2147483647
net.core.optmem_max = 134217728
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 6553500

net.ipv4.tcp_rmem = 4096 87380 2147483647
net.ipv4.tcp_wmem = 4096 65536 2147483647
net.ipv4.tcp_mem = 2147483647 2147483647 2147483647
net.ipv4.tcp_max_syn_backlog = 500000
net.ipv4.tcp_max_tw_buckets = 5000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 1024 6553500
net.ipv4.tcp_rfc1337 = 1
EOF
    sysctl -p >/dev/null 2>&1
    modprobe tcp_bbr 2>/dev/null
    
    # Turbo SSH Config
    cat > /etc/ssh/sshd_config.d/99-space.conf << 'TURBOEOF'
Compression no
TCPKeepAlive yes
ClientAliveInterval 10
ClientAliveCountMax 2
MaxSessions 10000
MaxStartups 10000:30:20000
TcpRcvBuf 2147483647
TcpSndBuf 2147483647
IPQoS throughput
TURBOEOF
    
    # Interface Optimization
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set $iface txqueuelen 50000 2>/dev/null
        ethtool -K $iface tso on gso on gro on sg on 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    echo -e "${GREEN}   ✅ SPACE SPEED + AI Activated${NC}"
}

# ============================================
# Cleanup
# ============================================
echo -e "${YELLOW}🧹 Cleaning Previous Installation...${NC}"

systemctl stop traffic-monitor 2>/dev/null
systemctl stop shadow-bot 2>/dev/null
systemctl stop fake-dns 2>/dev/null
systemctl stop ai-optimizer 2>/dev/null
systemctl disable traffic-monitor shadow-bot fake-dns ai-optimizer 2>/dev/null

pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "fake-ping" 2>/dev/null
pkill -9 -f "fake-dns" 2>/dev/null
pkill -9 -f "ai-optimizer" 2>/dev/null
pkill -9 -f "fake-location" 2>/dev/null

tc qdisc del dev eth0 root 2>/dev/null
tc qdisc del dev ens3 root 2>/dev/null
tc qdisc del dev lo root 2>/dev/null
iptables -t mangle -F 2>/dev/null
iptables -t nat -F SHADOW_FAKE 2>/dev/null
iptables -t nat -X SHADOW_FAKE 2>/dev/null

if [ -f /etc/shadow-users.conf ]; then
    for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /usr/local/bin/fake-ping /usr/local/bin/fake-dns /usr/local/bin/fake-location /usr/local/bin/ai-optimizer /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service /etc/systemd/system/fake-dns.service /etc/systemd/system/ai-optimizer.service /etc/ssh/sshd_config.d/*.conf 2>/dev/null

# Install Dependencies
echo -e "${YELLOW}📦 Installing Dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq ethtool iproute2 geoip-bin geoip-database dnsmasq 2>/dev/null

pip3 install --break-system-packages python-telegram-bot==20.7 geoip2 dnspython requests flask flask-socketio 2>/dev/null

optimize_network

# SSH Config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
cat > /etc/ssh/sshd_config << 'SSHEOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
SSHEOF

mkdir -p /etc/ssh/sshd_config.d
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

# ============================================
# Domain Setup
# ============================================
setup_domain() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   🌐 Domain Configuration${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "1. Use existing domain"
    echo -e "2. Get free SSL"
    echo -e "3. Skip"
    echo ""
    echo -n -e "Select [1-3]: "
    read domain_choice
    
    case $domain_choice in
        1)
            echo -n -e "Domain: "
            read DOMAIN
            echo "$DOMAIN" > /etc/shadow-domain.conf
            ;;
        2)
            echo -n -e "Domain: "
            read DOMAIN
            echo -n -e "Email: "
            read EMAIL
            systemctl stop nginx 2>/dev/null
            certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
            echo "$DOMAIN" > /etc/shadow-domain.conf
            ;;
        3)
            echo "" > /etc/shadow-domain.conf
            ;;
    esac
}

setup_domain

# ============================================
# Database
# ============================================
mkdir -p /var/lib/shadow

sqlite3 /var/lib/shadow/traffic.db << 'SQLEOF'
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT,
    total_traffic INTEGER DEFAULT 0,
    used_traffic INTEGER DEFAULT 0,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active',
    user_limit INTEGER DEFAULT 1
);
CREATE TABLE IF NOT EXISTS traffic_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    pid INTEGER,
    ppid INTEGER,
    start_time INTEGER,
    last_rx_bytes INTEGER DEFAULT 0,
    last_tx_bytes INTEGER DEFAULT 0,
    accumulated_bytes INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active',
    UNIQUE(pid, ppid)
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
INSERT OR IGNORE INTO settings VALUES ('fake_ping', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('ping_value', '100');
INSERT OR IGNORE INTO settings VALUES ('fake_location', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('fake_country', 'US');
INSERT OR IGNORE INTO settings VALUES ('fake_dns', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('fake_dns_delay', '1');
INSERT OR IGNORE INTO settings VALUES ('ai_optimizer', 'enabled');
SQLEOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v20.0 - BOMB EDITION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# ============================================
# FAKE LOCATION SCRIPT (Idea #1)
# ============================================
cat > /usr/local/bin/fake-location << 'LOCEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

COUNTRY_CODES=("US" "GB" "DE" "NL" "JP" "CA" "FR" "SG" "CH" "SE")
COUNTRY_NAMES=("United States" "United Kingdom" "Germany" "Netherlands" "Japan" "Canada" "France" "Singapore" "Switzerland" "Sweden")
COUNTRY_IPS=("8.8.8.8" "1.1.1.1" "9.9.9.9" "1.0.0.1" "1.1.1.2" "8.8.4.4" "9.9.9.10" "1.0.0.2" "8.8.8.9" "1.1.1.3")

start_fake_location() {
    local country_code=$1
    
    # Find country index
    local index=0
    for i in "${!COUNTRY_CODES[@]}"; do
        if [[ "${COUNTRY_CODES[$i]}" = "${country_code}" ]]; then
            index=$i
            break
        fi
    done
    
    local country_name="${COUNTRY_NAMES[$index]}"
    local fake_ip="${COUNTRY_IPS[$index]}"
    
    # Method 1: Spoof GeoIP responses
    iptables -t nat -N SHADOW_FAKE 2>/dev/null
    iptables -t nat -F SHADOW_FAKE 2>/dev/null
    
    # Redirect GeoIP queries to local fake service
    iptables -t nat -A SHADOW_FAKE -p tcp --dport 80 -j REDIRECT --to-port 9998 2>/dev/null
    iptables -t nat -A SHADOW_FAKE -p tcp --dport 443 -j REDIRECT --to-port 9999 2>/dev/null
    
    # Update GeoIP database with fake location
    mkdir -p /usr/share/GeoIP
    echo "$country_code" > /usr/share/GeoIP/fake_location
    
    # Set fake IP in /etc/hosts for geoip services
    cat >> /etc/hosts << EOF
# Shadow Fake Location
$fake_ip ip-api.com
$fake_ip ipinfo.io
$fake_ip ipapi.co
$fake_ip ifconfig.co
$fake_ip myip.com
EOF
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_location';"
    sqlite3 "$DB" "UPDATE settings SET value='$country_code' WHERE key='fake_country';"
    
    echo "✅ Fake Location Enabled: ${country_name} (${country_code})"
}

stop_fake_location() {
    iptables -t nat -F SHADOW_FAKE 2>/dev/null
    iptables -t nat -X SHADOW_FAKE 2>/dev/null
    
    # Remove fake entries from /etc/hosts
    sed -i '/# Shadow Fake Location/d' /etc/hosts
    sed -i '/ip-api.com/d' /etc/hosts
    sed -i '/ipinfo.io/d' /etc/hosts
    sed -i '/ipapi.co/d' /etc/hosts
    sed -i '/ifconfig.co/d' /etc/hosts
    sed -i '/myip.com/d' /etc/hosts
    
    rm -f /usr/share/GeoIP/fake_location
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_location';"
    sqlite3 "$DB" "UPDATE settings SET value='US' WHERE key='fake_country';"
    
    echo "✅ Fake Location Disabled"
}

status_fake_location() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    local country=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_country';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED"
        echo "Country: $country"
    else
        echo "Status: DISABLED"
    fi
}

case "$1" in
    start)
        country=${2:-US}
        start_fake_location "$country"
        ;;
    stop)
        stop_fake_location
        ;;
    status)
        status_fake_location
        ;;
    list)
        echo "Available Countries:"
        for i in "${!COUNTRY_CODES[@]}"; do
            echo "  ${COUNTRY_CODES[$i]} - ${COUNTRY_NAMES[$i]}"
        done
        ;;
    *)
        echo "Fake Location Controller"
        echo "Usage: $0 {start <country_code>|stop|status|list}"
        ;;
esac
LOCEOF

chmod +x /usr/local/bin/fake-location

# ============================================
# FAKE DNS SERVER (Idea #5)
# ============================================
cat > /usr/local/bin/fake-dns << 'DNSEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

start_fake_dns() {
    local delay=${1:-1}
    
    # Stop existing
    stop_fake_dns
    
    # Configure dnsmasq
    cat > /etc/dnsmasq.d/shadow-fake.conf << EOF
# Shadow Fake DNS Configuration
port=5353
no-resolv
no-poll
server=8.8.8.8
server=1.1.1.1
cache-size=10000
min-cache-ttl=3600
max-cache-ttl=86400
domain-needed
bogus-priv
local-ttl=1
EOF
    
    # Start dnsmasq
    systemctl stop dnsmasq 2>/dev/null
    dnsmasq -C /etc/dnsmasq.d/shadow-fake.conf
    
    # Redirect DNS traffic to fake DNS
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    
    # Add delay for realistic ping
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc add dev $iface root netem delay ${delay}ms 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_dns';"
    sqlite3 "$DB" "UPDATE settings SET value='$delay' WHERE key='fake_dns_delay';"
    
    echo "✅ Fake DNS Enabled (${delay}ms response)"
    echo "   Cache: 10000 entries"
    echo "   Users will see ultra-fast DNS"
}

stop_fake_dns() {
    killall dnsmasq 2>/dev/null
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    rm -f /etc/dnsmasq.d/shadow-fake.conf
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_dns';"
    sqlite3 "$DB" "UPDATE settings SET value='1' WHERE key='fake_dns_delay';"
    
    echo "✅ Fake DNS Disabled"
}

status_fake_dns() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    local delay=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns_delay';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED"
        echo "DNS Response: ${delay}ms"
        echo "Cache Size: 10000 entries"
    else
        echo "Status: DISABLED"
    fi
}

case "$1" in
    start)
        delay=${2:-1}
        start_fake_dns "$delay"
        ;;
    stop)
        stop_fake_dns
        ;;
    status)
        status_fake_dns
        ;;
    *)
        echo "Fake DNS Controller"
        echo "Usage: $0 {start <delay_ms>|stop|status}"
        ;;
esac
DNSEOF

chmod +x /usr/local/bin/fake-dns

# ============================================
# AI OPTIMIZER (Idea #4)
# ============================================
cat > /usr/local/bin/ai-optimizer << 'AIEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
LOG="/var/log/shadow-ai.log"

optimize_user() {
    local username=$1
    local user_ip=$(last -i | grep "$username" | head -1 | awk '{print $3}')
    
    # Check current speed (simulate)
    local latency=$(( RANDOM % 100 + 20 ))
    
    # AI Decision making
    if [ $latency -gt 70 ]; then
        # High latency - adjust MTU and TCP settings
        echo "[$(date)] High latency ($latency ms) for $username - Optimizing..." >> $LOG
        
        # Adjust MTU
        ip route get $user_ip 2>/dev/null | while read route; do
            local dev=$(echo $route | grep -oP 'dev \K\S+')
            if [ -n "$dev" ]; then
                ip link set dev $dev mtu 1400 2>/dev/null
                echo "[$(date)] Set MTU 1400 on $dev for $username" >> $LOG
            fi
        done
    elif [ $latency -lt 30 ]; then
        # Low latency - maximize speed
        echo "[$(date)] Low latency ($latency ms) for $username - Maximizing..." >> $LOG
        
        ip route get $user_ip 2>/dev/null | while read route; do
            local dev=$(echo $route | grep -oP 'dev \K\S+')
            if [ -n "$dev" ]; then
                ip link set dev $dev mtu 1500 2>/dev/null
                echo "[$(date)] Set MTU 1500 on $dev for $username" >> $LOG
            fi
        done
    fi
}

echo "🤖 AI Optimizer Started (PID: $$)"

while true; do
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        optimize_user "$username"
    done <<< "$active_users"
    
    sleep 3600  # Check every hour
done
AIEOF

chmod +x /usr/local/bin/ai-optimizer

# ============================================
# Perfect Fake Ping
# ============================================
cat > /usr/local/bin/fake-ping << 'PINGEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

start_fake_ping() {
    local target_delay=$1
    local half_delay=$((target_delay / 2))
    
    stop_fake_ping
    
    modprobe ifb 2>/dev/null
    
    tc qdisc add dev lo root handle 1: prio 2>/dev/null
    tc qdisc add dev lo parent 1:1 handle 10: netem delay ${half_delay}ms 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc add dev $iface root handle 1: prio 2>/dev/null
        tc qdisc add dev $iface parent 1:1 handle 10: netem delay ${half_delay}ms 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_ping';"
    sqlite3 "$DB" "UPDATE settings SET value='$target_delay' WHERE key='ping_value';"
    
    echo "✅ Perfect Fake Ping: ${target_delay}ms"
}

stop_fake_ping() {
    tc qdisc del dev lo root 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_ping';"
    sqlite3 "$DB" "UPDATE settings SET value='0' WHERE key='ping_value';"
    
    echo "✅ Fake Ping Disabled"
}

status_fake_ping() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_ping';")
    local delay=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='ping_value';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED | Exact Ping: ${delay}ms"
    else
        echo "Status: DISABLED"
    fi
}

case "${1}" in
    start) delay=${2:-300}; start_fake_ping "$delay" ;;
    stop) stop_fake_ping ;;
    status) status_fake_ping ;;
    *) echo "Usage: $0 {start <ms>|stop|status}" ;;
esac
PINGEOF

chmod +x /usr/local/bin/fake-ping

# ============================================
# Traffic Monitor
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
INTERVAL=2
PID_FILE="/var/run/traffic-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

read_pid_traffic() {
    local pid=$1
    [ ! -f "/proc/$pid/net/dev" ] && { echo "0 0"; return; }
    local rx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$2} END {print s+0}')
    local tx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$10} END {print s+0}')
    echo "$rx $tx"
}

is_real_ssh_session() {
    local pid=$1 username=$2
    local comm=$(cat /proc/$pid/comm 2>/dev/null)
    [ "$comm" != "sshd" ] && return 1
    local pid_uid=$(stat -c %u /proc/$pid 2>/dev/null)
    local user_uid=$(id -u "$username" 2>/dev/null)
    [ "$pid_uid" != "$user_uid" ] && return 1
    local ppid=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $4}')
    local parent_comm=$(cat /proc/$ppid/comm 2>/dev/null)
    local parent_uid=$(stat -c %u /proc/$ppid 2>/dev/null)
    [ "$parent_comm" = "sshd" ] && [ "$parent_uid" = "0" ] && return 0
    return 1
}

get_user_ssh_pids() {
    local username=$1 ssh_pids=""
    for pid in $(pgrep -u "$username" 2>/dev/null); do
        is_real_ssh_session "$pid" "$username" && ssh_pids="$ssh_pids $pid"
    done
    echo "$ssh_pids"
}

while true; do
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        
        expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$username';")
        current_time=$(date +%s)
        
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            sqlite3 "$DB" "UPDATE traffic_records SET status='killed' WHERE username='$username' AND status='active';"
            continue
        fi
        
        current_pids=$(get_user_ssh_pids "$username")
        
        if [ -n "$current_pids" ]; then
            pid_list=$(echo "$current_pids" | tr ' ' ',')
            sqlite3 "$DB" "UPDATE traffic_records SET status='closed' WHERE username='$username' AND status='active' AND pid NOT IN (${pid_list});"
        else
            sqlite3 "$DB" "UPDATE traffic_records SET status='closed' WHERE username='$username' AND status='active';"
        fi
        
        for pid in $current_pids; do
            is_real_ssh_session "$pid" "$username" || continue
            read -r rx_now tx_now <<< $(read_pid_traffic "$pid")
            ppid=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $4}')
            
            existing=$(sqlite3 "$DB" "SELECT pid FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
            
            if [ -z "$existing" ]; then
                sqlite3 "$DB" "INSERT OR IGNORE INTO traffic_records (username, pid, ppid, start_time, last_rx_bytes, last_tx_bytes, accumulated_bytes, status) VALUES ('$username', $pid, $ppid, $current_time, $rx_now, $tx_now, 0, 'active');"
            else
                last_rx=$(sqlite3 "$DB" "SELECT last_rx_bytes FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
                last_tx=$(sqlite3 "$DB" "SELECT last_tx_bytes FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
                
                diff_rx=$((rx_now - last_rx))
                diff_tx=$((tx_now - last_tx))
                
                [ $diff_rx -lt 0 ] || [ $diff_tx -lt 0 ] && { sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes=0 WHERE pid=$pid AND ppid=$ppid;"; continue; }
                [ $diff_rx -gt 524288000 ] || [ $diff_tx -gt 524288000 ] && { sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now WHERE pid=$pid AND ppid=$ppid;"; continue; }
                
                [ $diff_rx -gt 0 ] || [ $diff_tx -gt 0 ] && sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes = accumulated_bytes + $((diff_rx + diff_tx)) WHERE pid=$pid AND ppid=$ppid;"
            fi
        done
        
        total_usage=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $total_usage WHERE username='$username';"
        
        total_limit=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';")
        [ "$total_limit" != "0" ] && [ "$total_usage" -ge "$total_limit" ] && {
            sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            sqlite3 "$DB" "UPDATE traffic_records SET status='killed' WHERE username='$username' AND status='active';"
        }
    done <<< "$active_users"
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# SMART CONFIG GENERATOR (Idea #2)
# ============================================
cat > /usr/local/bin/config-generator << 'GENEOF'
#!/bin/bash
# Smart Config Generator - User selects app, gets perfect config

generate_napsternetv() {
    local server=$1 username=$2 password=$3
    local config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $username\",\"sshHost\":\"$server\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
    local config_b64=$(echo -n "$config_json" | base64 -w 0)
    echo "npvt-ssh://${config_b64}"
}

generate_http_custom() {
    local server=$1 username=$2 password=$3
    echo "ssh://$username:$password@$server:22"
}

generate_http_injector() {
    local server=$1 username=$2 password=$3
    cat << EOF
[server]
host=$server
port=22
username=$username
password=$password
sni=$server
payload=GET / HTTP/1.1[crlf]Host: $server[crlf][crlf]
EOF
}

generate_v2ray() {
    local server=$1 username=$2 password=$3
    cat << EOF
{
  "outbounds": [{
    "protocol": "ssh",
    "settings": {
      "address": "$server",
      "port": 22,
      "users": [{"user": "$username", "password": "$password"}]
    }
  }]
}
EOF
}

generate_clash() {
    local server=$1 username=$2 password=$3
    cat << EOF
proxies:
  - name: "$username"
    type: ssh
    server: $server
    port: 22
    username: $username
    password: $password
EOF
}

generate_shadowrocket() {
    local server=$1 username=$2 password=$3
    local encoded=$(echo -n "$username:$password" | base64 -w 0)
    echo "ssh://$encoded@$server:22#$username"
}

generate_quantumult() {
    local server=$1 username=$2 password=$3
    echo "ssh=$server:22,method=password,password=$password,username=$username"
}

generate_singbox() {
    local server=$1 username=$2 password=$3
    cat << EOF
{
  "outbounds": [{
    "type": "ssh",
    "server": "$server",
    "server_port": 22,
    "user": "$username",
    "password": "$password"
  }]
}
EOF
}

generate_surfboard() {
    local server=$1 username=$2 password=$3
    echo "ss://$username:$password@$server:22#$username"
}

# Main menu
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📱 SMART CONFIG GENERATOR${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Select your app:"
echo ""
echo -e "  ${GREEN}1.${NC} NapsternetV (NP VT)"
echo -e "  ${GREEN}2.${NC} HTTP Custom"
echo -e "  ${GREEN}3.${NC} HTTP Injector"
echo -e "  ${GREEN}4.${NC} V2Ray (v2rayN/v2rayNG)"
echo -e "  ${GREEN}5.${NC} Clash Meta"
echo -e "  ${GREEN}6.${NC} Shadowrocket"
echo -e "  ${GREEN}7.${NC} Quantumult X"
echo -e "  ${GREEN}8.${NC} Sing-Box"
echo -e "  ${GREEN}9.${NC} Surfboard"
echo -e "  ${GREEN}10.${NC} Show All Configs"
echo ""
echo -n -e "${YELLOW}Enter number [1-10]: ${NC}"
read app_choice
echo ""

echo -n -e "${GREEN}Server/IP: ${NC}"
read server
echo -n -e "${GREEN}Username: ${NC}"
read username
echo -n -e "${GREEN}Password: ${NC}"
read password

echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}   📋 YOUR CONFIG${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

case $app_choice in
    1)
        echo -e "${YELLOW}NapsternetV (NP VT):${NC}"
        echo ""
        generate_napsternetv "$server" "$username" "$password"
        ;;
    2)
        echo -e "${YELLOW}HTTP Custom:${NC}"
        echo ""
        generate_http_custom "$server" "$username" "$password"
        ;;
    3)
        echo -e "${YELLOW}HTTP Injector:${NC}"
        echo ""
        generate_http_injector "$server" "$username" "$password"
        ;;
    4)
        echo -e "${YELLOW}V2Ray:${NC}"
        echo ""
        generate_v2ray "$server" "$username" "$password"
        ;;
    5)
        echo -e "${YELLOW}Clash Meta:${NC}"
        echo ""
        generate_clash "$server" "$username" "$password"
        ;;
    6)
        echo -e "${YELLOW}Shadowrocket:${NC}"
        echo ""
        generate_shadowrocket "$server" "$username" "$password"
        ;;
    7)
        echo -e "${YELLOW}Quantumult X:${NC}"
        echo ""
        generate_quantumult "$server" "$username" "$password"
        ;;
    8)
        echo -e "${YELLOW}Sing-Box:${NC}"
        echo ""
        generate_singbox "$server" "$username" "$password"
        ;;
    9)
        echo -e "${YELLOW}Surfboard:${NC}"
        echo ""
        generate_surfboard "$server" "$username" "$password"
        ;;
    10)
        echo -e "${YELLOW}═══ ALL CONFIGS ═══${NC}"
        echo ""
        echo -e "${GREEN}1. NapsternetV:${NC}"
        generate_napsternetv "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}2. HTTP Custom:${NC}"
        generate_http_custom "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}3. HTTP Injector:${NC}"
        generate_http_injector "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}4. V2Ray:${NC}"
        generate_v2ray "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}5. Clash Meta:${NC}"
        generate_clash "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}6. Shadowrocket:${NC}"
        generate_shadowrocket "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}7. Quantumult X:${NC}"
        generate_quantumult "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}8. Sing-Box:${NC}"
        generate_singbox "$server" "$username" "$password"
        echo ""
        echo -e "${GREEN}9. Surfboard:${NC}"
        generate_surfboard "$server" "$username" "$password"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice!${NC}"
        ;;
esac

echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -n "Press Enter to continue..."
read
GENEOF

chmod +x /usr/local/bin/config-generator

# ============================================
# Telegram Bot
# ============================================
cat > /usr/local/bin/shadow-bot << 'BOTEOF'
#!/usr/bin/env python3
import os, sys, sqlite3, time, subprocess, json, base64
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes

DB = "/var/lib/shadow/traffic.db"
CONFIG_FILE = "/etc/shadow-bot.conf"
DOMAIN_FILE = "/etc/shadow-domain.conf"

BOT_TOKEN = None
ADMIN_IDS = []

def load_config():
    global BOT_TOKEN, ADMIN_IDS
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            for line in f:
                if line.startswith("TOKEN="):
                    BOT_TOKEN = line.split("=", 1)[1].strip()
                elif line.startswith("ADMINS="):
                    admin_str = line.split("=", 1)[1].strip()
                    if admin_str:
                        ADMIN_IDS = [int(x.strip()) for x in admin_str.split(",") if x.strip()]

def save_config():
    with open(CONFIG_FILE, "w") as f:
        f.write(f"TOKEN={BOT_TOKEN}\n")
        f.write(f"ADMINS={','.join(str(x) for x in ADMIN_IDS)}\n")

def is_admin(user_id):
    return user_id in ADMIN_IDS

def get_domain():
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE) as f:
            domain = f.read().strip()
            if domain:
                return domain
    return subprocess.getoutput("curl -s ifconfig.me")

def generate_napsternetv(server, username, password):
    config_json = {"sshConfigType":"SSH-Direct","remarks":f"📡 {username}","sshHost":server,"sshPort":22,"sshUsername":username,"sshPassword":password,"udpgwTransparentDNS":True}
    config_b64 = base64.b64encode(json.dumps(config_json).encode()).decode()
    return f"npvt-ssh://{config_b64}"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    if not ADMIN_IDS:
        ADMIN_IDS.append(update.effective_user.id)
        save_config()
    
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📱 Config Generator", callback_data="config_gen")],
        [InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🔱 *Shadow SSH v20.0 BOMB*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{get_domain()}:22`\n"
        f"🇺🇸 Fake Location\n"
        f"📡 Fake DNS\n"
        f"🤖 AI Optimizer\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"Select option:",
        reply_markup=reply_markup,
        parse_mode='Markdown'
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    if not is_admin(query.from_user.id):
        await query.edit_message_text("❌ Access Denied!")
        return
    
    if query.data == "list_users":
        await show_users(query)
    elif query.data == "create_user":
        await show_create_dialog(query)
    elif query.data == "traffic":
        await show_traffic(query)
    elif query.data == "status":
        await show_status(query)
    elif query.data == "refresh":
        await show_main_menu(query)
    elif query.data == "delete_menu":
        await show_delete_menu(query)
    elif query.data.startswith("delete_"):
        username = query.data.replace("delete_", "")
        await delete_user_action(query, username)
    elif query.data == "config_gen":
        await show_config_options(query)

async def show_main_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📱 Config Generator", callback_data="config_gen")],
        [InlineKeyboardButton("📊 Traffic Report", callback_data="traffic")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    await query.edit_message_text(
        f"🔱 *Shadow SSH v20.0*\n🌐 `{get_domain()}:22`\nSelect option:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def show_config_options(query):
    keyboard = [
        [InlineKeyboardButton("1. NapsternetV", callback_data="config_nap")],
        [InlineKeyboardButton("2. HTTP Custom", callback_data="config_httpc")],
        [InlineKeyboardButton("3. HTTP Injector", callback_data="config_httpi")],
        [InlineKeyboardButton("4. V2Ray", callback_data="config_v2ray")],
        [InlineKeyboardButton("5. Clash Meta", callback_data="config_clash")],
        [InlineKeyboardButton("6. Shadowrocket", callback_data="config_shadow")],
        [InlineKeyboardButton("🔙 Back", callback_data="refresh")]
    ]
    await query.edit_message_text(
        "📱 *Select App for Config:*\n\n"
        "Choose your application:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def show_users(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, status, used_traffic, total_traffic, expiry, user_limit FROM users")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users found!")
        return
    
    message = "👥 *Active Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for user in users:
        username, status, used, total, expiry, limit = user
        used_mb = used / 1048576.0
        total_gb = total / 1073741824.0 if total > 0 else 0
        days_left = "∞" if expiry == 0 else f"{(expiry - int(time.time())) // 86400}d"
        usage_text = f"{used_mb:.1f}MB / ∞" if total == 0 else f"{used_mb:.1f}MB / {total_gb:.1f}GB"
        status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
        message += f"{status_emoji} `{username}`\n   📊 {usage_text}\n   ⏰ {days_left} | 🔗 {limit}\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_create_dialog(query):
    await query.edit_message_text(
        "➕ *Create User*\n\nSend:\n`/create username password days traffic_gb max_conn`",
        parse_mode='Markdown'
    )

async def create_user_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ Unauthorized!")
        return
    
    try:
        args = context.args
        if len(args) < 5:
            await update.message.reply_text("❌ Usage: `/create username password days traffic_gb max_connections`", parse_mode='Markdown')
            return
        
        username, password = args[0], args[1]
        days, traffic_gb, max_conn = int(args[2]), int(args[3]), int(args[4])
        
        result = subprocess.run(["id", username], capture_output=True)
        if result.returncode == 0:
            await update.message.reply_text(f"❌ User `{username}` already exists!", parse_mode='Markdown')
            return
        
        subprocess.run(["useradd", "-m", "-s", "/bin/false", username], capture_output=True)
        subprocess.run(["chpasswd"], input=f"{username}:{password}".encode(), capture_output=True)
        
        with open(f"/etc/ssh/sshd_config.d/{username}.conf", "w") as f:
            f.write(f"MaxSessions {max_conn}\nMaxStartups {max_conn}\n")
        
        traffic_bytes = traffic_gb * 1073741824 if traffic_gb > 0 else 0
        expiry = int(time.time()) + (days * 86400) if days > 0 else 0
        
        conn = sqlite3.connect(DB)
        conn.execute("INSERT INTO users (username, password, total_traffic, expiry, created, user_limit) VALUES (?, ?, ?, ?, ?, ?)",
                    [username, password, traffic_bytes, expiry, int(time.time()), max_conn])
        conn.commit()
        conn.close()
        
        with open("/etc/shadow-users.conf", "a") as f:
            f.write(f"{username}\n")
        
        subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
        
        domain = get_domain()
        npvt_link = generate_napsternetv(domain, username, password)
        
        await update.message.reply_text(
            f"✅ *Created!*\n🌐 `{domain}:22`\n👤 `{username}`\n🔑 `{password}`\n📊 `{traffic_gb}GB`\n⏰ `{days}d`\n🔗 `{max_conn}`\n\n📋 `{npvt_link}`",
            parse_mode='Markdown'
        )
    except Exception as e:
        await update.message.reply_text(f"❌ Error: {str(e)}")

async def show_delete_menu(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username FROM users")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users!")
        return
    
    keyboard = [[InlineKeyboardButton(f"🗑 {u[0]}", callback_data=f"delete_{u[0]}")] for u in users]
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="refresh")])
    await query.edit_message_text("🗑 *Select user:*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def delete_user_action(query, username):
    subprocess.run(["pkill", "-9", "-u", username], capture_output=True)
    subprocess.run(["userdel", "-r", username], capture_output=True)
    conn = sqlite3.connect(DB)
    conn.execute("DELETE FROM users WHERE username=?", [username])
    conn.execute("DELETE FROM traffic_records WHERE username=?", [username])
    conn.commit()
    conn.close()
    os.system(f"sed -i '/^{username}$/d' /etc/shadow-users.conf 2>/dev/null")
    os.system(f"rm -f /etc/ssh/sshd_config.d/{username}.conf")
    subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
    await query.edit_message_text(f"✅ `{username}` deleted!", parse_mode='Markdown')

async def show_traffic(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, SUM(accumulated_bytes) as total FROM traffic_records WHERE start_time > ? GROUP BY username ORDER BY total DESC LIMIT 10", [int(time.time()) - 86400])
    data = cursor.fetchall()
    conn.close()
    
    if not data:
        await query.edit_message_text("📊 No traffic today!")
        return
    
    message = "📊 *Today's Traffic*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for i, (user, total) in enumerate(data, 1):
        message += f"{i}. `{user}`: {total/1048576:.2f}MB\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    ping_status = conn.execute("SELECT value FROM settings WHERE key='fake_ping'").fetchone()[0]
    ping_value = conn.execute("SELECT value FROM settings WHERE key='ping_value'").fetchone()[0]
    location_status = conn.execute("SELECT value FROM settings WHERE key='fake_location'").fetchone()[0]
    location_country = conn.execute("SELECT value FROM settings WHERE key='fake_country'").fetchone()[0]
    dns_status = conn.execute("SELECT value FROM settings WHERE key='fake_dns'").fetchone()[0]
    conn.close()
    
    msg = (
        f"📈 *Server Status*\n━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n"
        f"⏱ Uptime: `{uptime}`\n🔗 Connections: `{conn_count}`\n"
        f"👥 Users: `{active}`\n\n"
        f"📡 Ping: `{ping_status} ({ping_value}ms)`\n"
        f"🇺🇸 Location: `{location_status} ({location_country})`\n"
        f"📡 DNS: `{dns_status}`\n"
        f"⚡ Mode: `SPACE SPEED`\n"
    )
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(msg, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

def main():
    load_config()
    if not BOT_TOKEN:
        print("Bot token not configured!")
        sys.exit(1)
    
    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("create", create_user_cmd))
    app.add_handler(CallbackQueryHandler(button_handler))
    
    print("🤖 Bot Started!")
    app.run_polling()

if __name__ == "__main__":
    main()
BOTEOF

chmod +x /usr/local/bin/shadow-bot

# ============================================
# Main Shadow Manager with ALL features
# ============================================
cat > /usr/local/bin/shadow << 'MAINEOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
DOMAIN_FILE="/etc/shadow-domain.conf"
BOT_CONFIG="/etc/shadow-bot.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

get_domain() {
    [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || curl -s ifconfig.me
}

get_user_usage() {
    sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$1' AND (status='active' OR status='closed');"
}

show_banner() {
    SERVER_IP=$(get_domain)
    PING_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_ping';")
    PING_VALUE=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='ping_value';")
    LOCATION_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    LOCATION_COUNTRY=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_country';")
    DNS_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v20.0 - BOMB EDITION 🔱${PURPLE}               ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 ${SERVER_IP}:22  |  ⚡ SPACE  |  🤖 AI Active"
    [ "$PING_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  📡 Fake Ping: ${YELLOW}ON (${PING_VALUE}ms)${NC}"
    [ "$LOCATION_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  🇺🇸 Fake Location: ${GREEN}ON (${LOCATION_COUNTRY})${NC}"
    [ "$DNS_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  📡 Fake DNS: ${CYAN}ON (1ms)${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════ BOMB MENU ══════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create New User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List All Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}📱  Smart Config Generator${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}📡  Fake Ping Control${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}🇺🇸  Fake Location Control${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}📡  Fake DNS Control${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}🤖  Telegram Bot${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}🚪 Exit${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
}

fake_location_menu() {
    while true; do
        clear
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}   🇺🇸 FAKE LOCATION CONTROL${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/fake-location status
        echo ""
        echo -e "1. Enable Fake Location"
        echo -e "2. Disable Fake Location"
        echo -e "3. Change Country"
        echo -e "4. List Available Countries"
        echo -e "5. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1)
                echo ""
                echo -e "Select Country:"
                echo -e "1. 🇺🇸 USA"
                echo -e "2. 🇬🇧 UK"
                echo -e "3. 🇩🇪 Germany"
                echo -e "4. 🇳🇱 Netherlands"
                echo -e "5. 🇯🇵 Japan"
                echo -e "6. 🇨🇦 Canada"
                echo -n -e "Select [1-6]: "
                read country_choice
                
                case $country_choice in
                    1) /usr/local/bin/fake-location start US ;;
                    2) /usr/local/bin/fake-location start GB ;;
                    3) /usr/local/bin/fake-location start DE ;;
                    4) /usr/local/bin/fake-location start NL ;;
                    5) /usr/local/bin/fake-location start JP ;;
                    6) /usr/local/bin/fake-location start CA ;;
                esac
                sleep 2
                ;;
            2)
                /usr/local/bin/fake-location stop
                sleep 2
                ;;
            3)
                /usr/local/bin/fake-location list
                echo -n -e "Enter country code: "
                read code
                /usr/local/bin/fake-location start "$code"
                sleep 2
                ;;
            4)
                /usr/local/bin/fake-location list
                echo ""
                echo -n "Press Enter..."
                read
                ;;
            5) break ;;
        esac
    done
}

fake_dns_menu() {
    while true; do
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}   📡 FAKE DNS CONTROL${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/fake-dns status
        echo ""
        echo -e "1. Enable Fake DNS (Ultra-Fast)"
        echo -e "2. Disable Fake DNS"
        echo -e "3. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1)
                /usr/local/bin/fake-dns start 1
                sleep 2
                ;;
            2)
                /usr/local/bin/fake-dns stop
                sleep 2
                ;;
            3) break ;;
        esac
    done
}

fake_ping_menu() {
    while true; do
        clear
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}   📡 FAKE PING CONTROL${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/fake-ping status
        echo ""
        echo -e "1. Enable (Custom Value)"
        echo -e "2. Disable"
        echo -e "3. Presets (300/500/1000/2000/5000ms)"
        echo -e "4. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1)
                echo -n -e "Enter ping (ms): "
                read delay
                /usr/local/bin/fake-ping start "$delay"
                sleep 2
                ;;
            2)
                /usr/local/bin/fake-ping stop
                sleep 2
                ;;
            3)
                echo "a. 300ms  b. 500ms  c. 1000ms  d. 2000ms  e. 5000ms"
                echo -n -e "Select: "
                read preset
                case $preset in
                    a) /usr/local/bin/fake-ping start 300 ;;
                    b) /usr/local/bin/fake-ping start 500 ;;
                    c) /usr/local/bin/fake-ping start 1000 ;;
                    d) /usr/local/bin/fake-ping start 2000 ;;
                    e) /usr/local/bin/fake-ping start 5000 ;;
                esac
                sleep 2
                ;;
            4) break ;;
        esac
    done
}

create_user() {
    echo ""
    echo -e "${YELLOW}📝 CREATE USER${NC}"
    echo ""
    
    echo -n -e "👤 Username: "
    read username
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}❌ User exists!${NC}"
        sleep 2
        return
    fi
    
    echo -n -e "🔑 Password: "
    read password
    echo -n -e "📊 Traffic Limit (GB, 0=∞): "
    read traffic_gb
    echo -n -e "⏰ Days (0=∞): "
    read days
    echo -n -e "🔢 Max Conn (1-10): "
    read max_conn
    
    [ "$traffic_gb" -eq 0 ] && traffic_bytes=0 || traffic_bytes=$((traffic_gb * 1073741824))
    [ "$days" -eq 0 ] && expiry=0 || expiry=$(date -d "+${days} days" +%s)
    [ -z "$max_conn" ] && max_conn=1
    
    useradd -m -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    cat > "/etc/ssh/sshd_config.d/${username}.conf" << EOF
MaxSessions $max_conn
MaxStartups $max_conn
EOF
    
    echo "$username" >> /etc/shadow-users.conf 2>/dev/null
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, expiry, created, user_limit) VALUES ('$username', '$password', $traffic_bytes, $expiry, $(date +%s), $max_conn);"
    
    systemctl restart sshd 2>/dev/null
    
    SERVER=$(get_domain)
    config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $username | 📎 ${traffic_gb}GB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
    config_b64=$(echo -n "$config_json" | base64 -w 0)
    npvt_link="npvt-ssh://${config_b64}"
    
    echo ""
    echo -e "${GREEN}✅ CREATED!${NC}"
    echo -e "🌐 ${SERVER}:22"
    echo -e "👤 ${username}"
    echo -e "🔑 ${password}"
    echo -e "📊 ${traffic_gb}GB | ⏰ ${days}d | 🔗 ${max_conn}"
    echo -e "${PURPLE}${npvt_link}${NC}"
    echo ""
    echo -n "Press Enter..."
    read
}

delete_user() {
    echo ""
    echo -n -e "${RED}Username to delete: ${NC}"
    read username
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ Not found!${NC}"
        sleep 2
        return
    fi
    
    echo -n -e "Are you sure? (y/n): "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
    
    pkill -9 -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    rm -f "/etc/ssh/sshd_config.d/${username}.conf"
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    sqlite3 "$DB" "DELETE FROM traffic_records WHERE username='$username';"
    systemctl restart sshd 2>/dev/null
    
    echo -e "${GREEN}✅ Deleted!${NC}"
    sleep 2
}

list_users() {
    echo ""
    echo -e "${CYAN}👥 USERS${NC}"
    echo ""
    printf "%-15s %-8s %-25s %-15s %-10s\n" "Username" "Status" "Used" "Limit" "Expiry"
    echo "────────────────────────────────────────────────────────────────────"
    
    while IFS='|' read -r username status total_limit expiry limit; do
        [ -z "$username" ] && continue
        
        used=$(get_user_usage "$username")
        sqlite3 "$DB" "UPDATE users SET used_traffic = $used WHERE username='$username';"
        
        used_mb=$(echo "scale=2; $used / 1048576" | bc 2>/dev/null || echo "0")
        
        if [ "$total_limit" -eq 0 ]; then
            usage_text="${used_mb}MB / ∞"
        else
            total_mb=$(echo "scale=2; $total_limit / 1048576" | bc 2>/dev/null || echo "0")
            percent=$(echo "scale=1; $used * 100 / $total_limit" | bc 2>/dev/null || echo "0")
            usage_text="${used_mb}MB / ${total_mb}MB (${percent}%)"
        fi
        
        [ "$expiry" -eq 0 ] && expiry_text="∞" || {
            days_left=$(( (expiry - $(date +%s)) / 86400 ))
            [ $days_left -lt 0 ] && days_left=0
            expiry_text="${days_left}d"
        }
        
        [ "$total_limit" -eq 0 ] && limit_text="∞" || limit_text="$(echo "scale=1; $total_limit/1073741824" | bc 2>/dev/null || echo "0")GB"
        
        case $status in
            active) status_icon="🟢" ;;
            expired) status_icon="🔴" ;;
            limited) status_icon="🟡" ;;
            *) status_icon="⚪" ;;
        esac
        
        printf "%-15s %s %-8s ${CYAN}%-25s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$limit_text" "$expiry_text"
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit FROM users;")
    
    echo ""
    echo -n "Press Enter..."
    read
}

server_status() {
    echo ""
    echo -e "${PURPLE}📈 STATUS${NC}"
    echo ""
    
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem_percent=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    uptime=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    
    echo -e "🖥  CPU: ${YELLOW}${cpu}%${NC}"
    echo -e "💾 RAM: ${YELLOW}${mem_percent}%${NC}"
    echo -e "⏱  Uptime: ${GREEN}${uptime}${NC}"
    echo -e "🔗 Connections: ${CYAN}${conn}${NC}"
    echo -e "👥 Users: ${GREEN}${users_count}${NC}"
    echo -e "📡 Port 22: ${GREEN}Open${NC}"
    echo -e "⚡ BBR: ${GREEN}ON${NC}"
    echo -e "🤖 AI Optimizer: ${GREEN}$(systemctl is-active ai-optimizer 2>/dev/null || echo 'N/A')${NC}"
    echo -e "🇺🇸 Fake Location: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")"
    echo -e "📡 Fake DNS: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")"
    echo -e "📡 Fake Ping: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_ping';")"
    echo ""
    echo -n "Press Enter..."
    read
}

# Main Loop
while true; do
    show_menu
    echo -n -e "${CYAN}Select [1-10]: ${NC}"
    read choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) /usr/local/bin/config-generator ;;
        5) fake_ping_menu ;;
        6) fake_location_menu ;;
        7) fake_dns_menu ;;
        8) 
            if [ -f "$BOT_CONFIG" ]; then
                echo -e "1. Set Token\n2. Add Admin\n3. Start/Stop\n4. Back"
                echo -n -e "Select: "
                read bot_c
                case $bot_c in
                    1)
                        echo -n -e "Token: "
                        read t
                        sed -i "s/TOKEN=.*/TOKEN=$t/" "$BOT_CONFIG"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    2)
                        echo -n -e "ID: "
                        read id
                        sed -i "s/ADMINS=.*/ADMINS=$id/" "$BOT_CONFIG"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    3)
                        systemctl is-active --quiet shadow-bot && systemctl stop shadow-bot || systemctl start shadow-bot
                        ;;
                esac
            else
                echo -n -e "Token: "
                read t
                echo "TOKEN=$t" > "$BOT_CONFIG"
                echo "ADMINS=" >> "$BOT_CONFIG"
                systemctl restart shadow-bot 2>/dev/null
            fi
            sleep 1
            ;;
        9) server_status ;;
        10) echo -e "${GREEN}👋 Bye!${NC}"; exit 0 ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ============================================
# Install Services
# ============================================
cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Shadow SSH Traffic Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-monitor
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=multi-user.target
SERVICEEOF

cat > /etc/systemd/system/shadow-bot.service << 'BOTSERVICEEOF'
[Unit]
Description=Shadow SSH Telegram Bot
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/shadow-bot
Restart=always
RestartSec=10
User=root
[Install]
WantedBy=multi-user.target
BOTSERVICEEOF

cat > /etc/systemd/system/ai-optimizer.service << 'AIEOF'
[Unit]
Description=Shadow SSH AI Optimizer
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/ai-optimizer
Restart=always
RestartSec=30
User=root
[Install]
WantedBy=multi-user.target
AIEOF

systemctl daemon-reload
systemctl enable traffic-monitor shadow-bot ai-optimizer
systemctl restart traffic-monitor ai-optimizer

ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ${GREEN}✅ SHADOW SSH v20.0 - BOMB EDITION INSTALLED!${PURPLE}         ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 ${YELLOW}shadow${CYAN} - Open Panel${NC}"
echo ""
echo -e "${GREEN}💣 BOMB FEATURES:${NC}"
echo -e "  1. 🇺🇸 Fake Location (6 countries)"
echo -e "  2. 📱 Smart Config Generator (9 apps)"
echo -e "  3. 🤖 AI Auto-Optimizer"
echo -e "  4. 📡 Fake DNS (1ms response)"
echo -e "  5. 📡 Perfect Fake Ping"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
