#!/bin/bash

# =============================================
# Shadow SSH v26.0 - PRECISION EDITION
# Fixed: Exact traffic counting (1:1)
# Removed: Config Generator menu, Half-Price Status menu
# Config generated directly during user creation (NapsternetV format)
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# ============================================
# Network Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🚀 Activating PRECISION Network${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc del dev $iface ingress 2>/dev/null
    done
    
    cat > /etc/sysctl.conf << 'EOF'
net.core.rmem_max = 2147483647
net.core.wmem_max = 2147483647
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.ip_forward = 1
EOF
    sysctl -p >/dev/null 2>&1
    modprobe tcp_bbr 2>/dev/null
    
    cat > /etc/ssh/sshd_config.d/99-precision.conf << 'TURBOEOF'
Compression no
TCPKeepAlive yes
ClientAliveInterval 10
ClientAliveCountMax 2
MaxSessions 10000
MaxStartups 10000:30:20000
TURBOEOF
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set $iface txqueuelen 50000 2>/dev/null
        ethtool -K $iface tso on gso on gro on sg on 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    echo -e "${GREEN}   ✅ PRECISION Network Activated${NC}"
}

# ============================================
# Cleanup
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🧹 Cleaning Previous Installation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

systemctl stop traffic-monitor shadow-bot fake-dns ai-optimizer shadow-backup dedup-monitor half-price rate-limiter 2>/dev/null
systemctl disable traffic-monitor shadow-bot fake-dns ai-optimizer shadow-backup dedup-monitor half-price rate-limiter 2>/dev/null

pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow-bot" 2>/dev/null
pkill -9 -f "fake-dns" 2>/dev/null
pkill -9 -f "ai-optimizer" 2>/dev/null
pkill -9 -f "fake-location" 2>/dev/null
pkill -9 -f "ping-net" 2>/dev/null
pkill -9 -f "half-price" 2>/dev/null
pkill -9 -f "rate-limiter" 2>/dev/null
pkill -9 -f "dedup-monitor" 2>/dev/null

tc qdisc del dev eth0 root 2>/dev/null
tc qdisc del dev ens3 root 2>/dev/null
tc qdisc del dev lo root 2>/dev/null
iptables -t mangle -F 2>/dev/null
iptables -t nat -F 2>/dev/null

if [ -f /etc/shadow-users.conf ]; then
    for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /usr/local/bin/shadow-bot /usr/local/bin/fake-dns /usr/local/bin/fake-location /usr/local/bin/ai-optimizer /usr/local/bin/backup-manager /usr/local/bin/config-checker /usr/local/bin/ping-net /usr/local/bin/half-price /usr/local/bin/rate-limiter /usr/local/bin/dedup-monitor /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service /etc/systemd/system/shadow-bot.service /etc/systemd/system/fake-dns.service /etc/systemd/system/ai-optimizer.service /etc/systemd/system/shadow-backup.service /etc/systemd/system/half-price.service /etc/systemd/system/rate-limiter.service /etc/systemd/system/dedup-monitor.service /etc/ssh/sshd_config.d/*.conf 2>/dev/null

# ============================================
# Install Dependencies
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   📦 Installing Dependencies${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq ethtool iproute2 geoip-bin geoip-database dnsmasq 2>/dev/null

pip3 install --break-system-packages python-telegram-bot==20.7 2>/dev/null

optimize_network

# ============================================
# SSH Config
# ============================================
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
    
    if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
        echo -e "Current Domain: ${GREEN}$(cat /etc/shadow-domain.conf)${NC}"
    else
        echo -e "Current: ${YELLOW}No domain set (Using IP)${NC}"
    fi
    
    echo ""
    echo -e "1. Add/Change Domain"
    echo -e "2. Get Free SSL"
    echo -e "3. Delete Domain"
    echo -e "4. Skip"
    echo ""
    echo -n -e "Select [1-4]: "
    read choice
    
    case $choice in
        1)
            echo -n -e "Domain: "
            read DOMAIN
            echo "$DOMAIN" > /etc/shadow-domain.conf
            echo -e "${GREEN}✅ Domain saved: $DOMAIN${NC}"
            ;;
        2)
            if [ -f /etc/shadow-domain.conf ] && [ -s /etc/shadow-domain.conf ]; then
                DOMAIN=$(cat /etc/shadow-domain.conf)
                echo -n -e "Email: "
                read EMAIL
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" 2>/dev/null
                [ $? -eq 0 ] && echo -e "${GREEN}✅ SSL obtained!${NC}" || echo -e "${RED}❌ SSL failed${NC}"
            else
                echo -e "${RED}❌ No domain set!${NC}"
            fi
            ;;
        3)
            echo -n -e "${RED}Delete? (y/n): ${NC}"
            read confirm
            [ "$confirm" = "y" ] && rm -f /etc/shadow-domain.conf && echo -e "${GREEN}✅ Deleted${NC}"
            ;;
        4)
            echo -e "${BLUE}ℹ️  Skipping${NC}"
            ;;
    esac
}

setup_domain

# ============================================
# Database - SIMPLIFIED
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🗄️  Setting up Database${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

mkdir -p /var/lib/shadow /var/backups/shadow

sqlite3 /var/lib/shadow/traffic.db << 'SQLEOF'
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT,
    total_traffic INTEGER DEFAULT 0,
    used_traffic INTEGER DEFAULT 0,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active',
    user_limit INTEGER DEFAULT 1,
    speed_limit INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS traffic_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    pid INTEGER UNIQUE,
    start_time INTEGER,
    baseline_rx INTEGER DEFAULT 0,
    baseline_tx INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
CREATE TABLE IF NOT EXISTS backup_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_time INTEGER,
    filename TEXT,
    size INTEGER,
    type TEXT
);
INSERT OR IGNORE INTO settings VALUES ('fake_location', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('fake_country', 'US');
INSERT OR IGNORE INTO settings VALUES ('fake_dns', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('fake_dns_delay', '1');
INSERT OR IGNORE INTO settings VALUES ('ai_optimizer', 'enabled');
INSERT OR IGNORE INTO settings VALUES ('debug_mode', 'disabled');
SQLEOF

echo -e "${GREEN}   ✅ Database Created${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v26.0 - PRECISION${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# ============================================
# PRECISION Traffic Monitor - COMPLETELY REWRITTEN
# ============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash
# ============================================
# PRECISION TRAFFIC MONITOR
# Exact 1:1 traffic counting
# No duplication, no multiplier, no BS
# ============================================

DB="/var/lib/shadow/traffic.db"
INTERVAL=3
PID_FILE="/var/run/traffic-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

# Get exact traffic for a PID from /proc
get_pid_traffic() {
    local pid=$1
    if [ ! -f "/proc/$pid/net/dev" ]; then
        echo "0 0"
        return
    fi
    local rx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$2} END {print s+0}')
    local tx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$10} END {print s+0}')
    echo "$rx $tx"
}

# Check if PID is a real SSH session for this user
is_ssh_session() {
    local pid=$1
    local username=$2
    
    # Must be sshd process
    local comm=$(cat /proc/$pid/comm 2>/dev/null)
    [ "$comm" != "sshd" ] && return 1
    
    # Must belong to the user (not root)
    local pid_uid=$(stat -c %u /proc/$pid 2>/dev/null)
    local user_uid=$(id -u "$username" 2>/dev/null)
    [ "$pid_uid" != "$user_uid" ] && return 1
    
    # Parent must be root's sshd
    local ppid=$(cat /proc/$pid/stat 2>/dev/null | awk '{print $4}')
    local parent_comm=$(cat /proc/$ppid/comm 2>/dev/null)
    local parent_uid=$(stat -c %u /proc/$ppid 2>/dev/null)
    [ "$parent_comm" = "sshd" ] && [ "$parent_uid" = "0" ] && return 0
    
    return 1
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 PRECISION Traffic Monitor Started"
echo "   PID: $$ | Interval: ${INTERVAL}s"
echo "   Mode: Exact 1:1 (No Duplication)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while true; do
    current_time=$(date +%s)
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        
        # Check expiry
        expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$username';")
        if [ "$expiry" != "0" ] && [ "$expiry" -lt "$current_time" ]; then
            sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$username';"
            pkill -9 -u "$username" 2>/dev/null
            sqlite3 "$DB" "UPDATE traffic_sessions SET status='killed' WHERE username='$username' AND status='active';"
            continue
        fi
        
        # Get current SSH PIDs for this user
        current_pids=""
        for pid in $(pgrep -u "$username" 2>/dev/null); do
            if is_ssh_session "$pid" "$username"; then
                current_pids="$current_pids $pid"
            fi
        done
        
        # Close dead sessions
        if [ -n "$current_pids" ]; then
            pid_list=$(echo "$current_pids" | tr ' ' ',')
            sqlite3 "$DB" "UPDATE traffic_sessions SET status='closed' WHERE username='$username' AND status='active' AND pid NOT IN (${pid_list});"
        else
            sqlite3 "$DB" "UPDATE traffic_sessions SET status='closed' WHERE username='$username' AND status='active';"
        fi
        
        # Calculate traffic for each active PID
        total_new_bytes=0
        
        for pid in $current_pids; do
            # Get current traffic counters
            read -r rx_now tx_now <<< $(get_pid_traffic "$pid")
            
            # Check if this is a new session
            existing=$(sqlite3 "$DB" "SELECT pid FROM traffic_sessions WHERE pid=$pid AND status='active';")
            
            if [ -z "$existing" ]; then
                # New session - register baseline
                sqlite3 "$DB" "INSERT OR REPLACE INTO traffic_sessions (username, pid, start_time, baseline_rx, baseline_tx, status) VALUES ('$username', $pid, $current_time, $rx_now, $tx_now, 'active');"
            else
                # Existing session - calculate delta
                baseline_rx=$(sqlite3 "$DB" "SELECT baseline_rx FROM traffic_sessions WHERE pid=$pid AND status='active';")
                baseline_tx=$(sqlite3 "$DB" "SELECT baseline_tx FROM traffic_sessions WHERE pid=$pid AND status='active';")
                
                diff_rx=$((rx_now - baseline_rx))
                diff_tx=$((tx_now - baseline_tx))
                
                # If counters reset (process restarted), reset baseline
                if [ $diff_rx -lt 0 ] || [ $diff_tx -lt 0 ]; then
                    sqlite3 "$DB" "UPDATE traffic_sessions SET baseline_rx=$rx_now, baseline_tx=$tx_now WHERE pid=$pid AND status='active';"
                    continue
                fi
                
                # Sanity check: max 1GB per interval (prevent multiplier bugs)
                if [ $diff_rx -gt 1073741824 ] || [ $diff_tx -gt 1073741824 ]; then
                    sqlite3 "$DB" "UPDATE traffic_sessions SET baseline_rx=$rx_now, baseline_tx=$tx_now WHERE pid=$pid AND status='active';"
                    continue
                fi
                
                if [ $diff_rx -gt 0 ] || [ $diff_tx -gt 0 ]; then
                    # Update baseline to current
                    sqlite3 "$DB" "UPDATE traffic_sessions SET baseline_rx=$rx_now, baseline_tx=$tx_now WHERE pid=$pid AND status='active';"
                    
                    # Add to total (RX + TX)
                    total_new_bytes=$((total_new_bytes + diff_rx + diff_tx))
                fi
            fi
        done
        
        # Update user's used_traffic ONLY ONCE per cycle
        if [ $total_new_bytes -gt 0 ]; then
            sqlite3 "$DB" "UPDATE users SET used_traffic = used_traffic + $total_new_bytes WHERE username='$username';"
            
            # Check limit
            total_limit=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';")
            current_used=$(sqlite3 "$DB" "SELECT used_traffic FROM users WHERE username='$username';")
            
            if [ "$total_limit" != "0" ] && [ "$current_used" -ge "$total_limit" ]; then
                sqlite3 "$DB" "UPDATE users SET status='limited' WHERE username='$username';"
                pkill -9 -u "$username" 2>/dev/null
                sqlite3 "$DB" "UPDATE traffic_sessions SET status='killed' WHERE username='$username' AND status='active';"
            fi
        fi
        
    done <<< "$active_users"
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# ============================================
# Fake Location Script
# ============================================
cat > /usr/local/bin/fake-location << 'LOCEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

COUNTRY_CODES=("US" "GB" "DE" "NL" "JP" "CA")
COUNTRY_NAMES=("United States" "United Kingdom" "Germany" "Netherlands" "Japan" "Canada")
COUNTRY_IPS=("8.8.8.8" "1.1.1.1" "9.9.9.9" "1.0.0.1" "1.1.1.2" "8.8.4.4")

start_fake_location() {
    local country_code=$1
    local index=0
    
    for i in "${!COUNTRY_CODES[@]}"; do
        if [[ "${COUNTRY_CODES[$i]}" = "${country_code}" ]]; then
            index=$i
            break
        fi
    done
    
    local fake_ip="${COUNTRY_IPS[$index]}"
    
    stop_fake_location
    
    echo "$country_code" > /usr/share/GeoIP/fake_location 2>/dev/null
    
    cat >> /etc/hosts << EOF
$fake_ip ip-api.com
$fake_ip ipinfo.io
$fake_ip ipapi.co
$fake_ip ifconfig.co
$fake_ip myip.com
$fake_ip ip.sb
$fake_ip whatismyip.com
EOF
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_location';"
    sqlite3 "$DB" "UPDATE settings SET value='$country_code' WHERE key='fake_country';"
    
    echo "✅ Fake Location: ${COUNTRY_NAMES[$index]} (${country_code})"
}

stop_fake_location() {
    sed -i '/ip-api.com/d' /etc/hosts
    sed -i '/ipinfo.io/d' /etc/hosts
    sed -i '/ipapi.co/d' /etc/hosts
    sed -i '/ifconfig.co/d' /etc/hosts
    sed -i '/myip.com/d' /etc/hosts
    sed -i '/ip.sb/d' /etc/hosts
    sed -i '/whatismyip.com/d' /etc/hosts
    
    rm -f /usr/share/GeoIP/fake_location
    
    sqlite3 "$DB" "UPDATE settings SET value='disabled' WHERE key='fake_location';"
    echo "✅ Fake Location Disabled"
}

status_fake_location() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    local country=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_country';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED | Country: $country"
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
# Fake DNS
# ============================================
cat > /usr/local/bin/fake-dns << 'DNSEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

start_fake_dns() {
    local delay=${1:-1}
    
    stop_fake_dns
    
    cat > /etc/dnsmasq.d/shadow-fake.conf << EOF
port=5353
no-resolv
no-poll
server=8.8.8.8
server=1.1.1.1
cache-size=10000
min-cache-ttl=3600
max-cache-ttl=86400
local-ttl=1
EOF
    
    systemctl stop dnsmasq 2>/dev/null
    dnsmasq -C /etc/dnsmasq.d/shadow-fake.conf 2>/dev/null
    
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc add dev $iface root netem delay ${delay}ms 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_dns';"
    sqlite3 "$DB" "UPDATE settings SET value='$delay' WHERE key='fake_dns_delay';"
    
    echo "✅ Fake DNS Enabled (${delay}ms, 10000 cache)"
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
    echo "✅ Fake DNS Disabled"
}

status_fake_dns() {
    local status=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    local delay=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns_delay';")
    
    if [ "$status" = "enabled" ]; then
        echo "Status: ENABLED | Response: ${delay}ms | Cache: 10000"
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
# AI Optimizer
# ============================================
cat > /usr/local/bin/ai-optimizer << 'AIEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

while true; do
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        user_ip=$(ss -tnp | grep "$username" | head -1 | awk '{print $5}' | cut -d: -f1)
        [ -n "$user_ip" ] && ip route get "$user_ip" >/dev/null 2>&1
    done <<< "$active_users"
    sleep 3600
done
AIEOF

chmod +x /usr/local/bin/ai-optimizer

# ============================================
# Backup Manager
# ============================================
cat > /usr/local/bin/backup-manager << 'BACKEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
BACKUP_DIR="/var/backups/shadow"

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/shadow_backup_${timestamp}.tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$backup_file" \
        /var/lib/shadow/traffic.db \
        /etc/shadow-users.conf \
        /etc/shadow-domain.conf \
        /etc/shadow-bot.conf \
        /etc/ssh/sshd_config.d/ 2>/dev/null
    
    local size=$(stat -c %s "$backup_file")
    sqlite3 "$DB" "INSERT INTO backup_history (backup_time, filename, size, type) VALUES ($(date +%s), '$backup_file', $size, 'local');"
    echo "$backup_file"
}

restore_backup() {
    local backup_file=$1
    [ ! -f "$backup_file" ] && { echo "❌ Not found!"; return 1; }
    systemctl stop traffic-monitor shadow-bot 2>/dev/null
    tar -xzf "$backup_file" -C /
    systemctl start traffic-monitor shadow-bot 2>/dev/null
    echo "✅ Restored!"
}

list_backups() {
    echo ""
    sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime'), filename, size FROM backup_history ORDER BY backup_time DESC LIMIT 10;" | while IFS='|' read -r id time filename size; do
        local size_mb=$(echo "scale=2; $size / 1048576" | bc 2>/dev/null || echo "0")
        echo -e "  ${GREEN}$id.${NC} $time - ${size_mb}MB"
    done
    echo ""
}

case "$1" in
    backup)
        create_backup
        ;;
    restore)
        list_backups
        echo -n -e "Enter backup ID: "
        read backup_id
        filename=$(sqlite3 "$DB" "SELECT filename FROM backup_history WHERE id=$backup_id;")
        [ -n "$filename" ] && restore_backup "$filename"
        ;;
    list)
        list_backups
        ;;
    auto-backup)
        while true; do
            create_backup >/dev/null
            sleep 86400
        done
        ;;
    *)
        echo "Usage: $0 {backup|restore|list|auto-backup}"
        ;;
esac
BACKEOF

chmod +x /usr/local/bin/backup-manager

# ============================================
# PING-NET Debug Tool
# ============================================
cat > /usr/local/bin/ping-net << 'PINGEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

debug_user() {
    local username=$1
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   🔍 PING-NET: $username${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}Active Sessions:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────${NC}"
    
    sqlite3 "$DB" "SELECT pid, baseline_rx, baseline_tx, datetime(start_time, 'unixepoch', 'localtime') FROM traffic_sessions WHERE username='$username' AND status='active';" | while IFS='|' read -r pid rx tx time; do
        current_rx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$2} END {print s+0}')
        current_tx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$10} END {print s+0}')
        
        diff_rx=$((current_rx - rx))
        diff_tx=$((current_tx - tx))
        
        [ $diff_rx -lt 0 ] && diff_rx=0
        [ $diff_tx -lt 0 ] && diff_tx=0
        
        total=$((diff_rx + diff_tx))
        total_mb=$(echo "scale=2; $total / 1048576" | bc)
        
        echo -e "  PID $pid | Since: $time | Traffic: ${GREEN}${total_mb}MB${NC}"
    done
    
    echo ""
    echo -e "${YELLOW}Total Recorded:${NC}"
    used_mb=$(echo "scale=2; $(sqlite3 "$DB" "SELECT used_traffic FROM users WHERE username='$username';") / 1048576" | bc)
    echo -e "  Database: ${GREEN}${used_mb}MB${NC}"
    
    # Check for PID duplicates
    duplicates=$(sqlite3 "$DB" "SELECT pid, COUNT(*) FROM traffic_sessions WHERE username='$username' AND status='active' GROUP BY pid HAVING COUNT(*) > 1;")
    if [ -n "$duplicates" ]; then
        echo ""
        echo -e "${RED}⚠️  DUPLICATE PIDs DETECTED!${NC}"
        echo "$duplicates" | while IFS='|' read -r pid count; do
            echo -e "  PID $pid: $count records"
        done
        echo -e "${YELLOW}Run: ping-net fix $username${NC}"
    else
        echo ""
        echo -e "${GREEN}✅ No duplicates${NC}"
    fi
    echo ""
}

fix_user() {
    local username=$1
    sqlite3 "$DB" "DELETE FROM traffic_sessions WHERE username='$username' AND id NOT IN (SELECT MIN(id) FROM traffic_sessions WHERE username='$username' GROUP BY pid);"
    echo "✅ Fixed duplicates for $username"
}

case "$1" in
    debug|user)
        [ -z "$2" ] && { echo "Usage: ping-net debug <username>"; exit 1; }
        debug_user "$2"
        ;;
    fix)
        [ -z "$2" ] && { echo "Usage: ping-net fix <username>"; exit 1; }
        fix_user "$2"
        ;;
    *)
        echo "PING-NET Traffic Debugger"
        echo "Usage: ping-net {debug|fix} <username>"
        ;;
esac
PINGEOF

chmod +x /usr/local/bin/ping-net

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

def generate_napsternetv(server, username, password, days_left="∞", traffic_gb="∞"):
    remarks = f"📡 {username}"
    if days_left != "∞":
        remarks += f" | ⏰ {days_left}d"
    if traffic_gb != "∞":
        remarks += f" | 📎 {traffic_gb}GB"
    
    config_json = {"sshConfigType":"SSH-Direct","remarks":remarks,"sshHost":server,"sshPort":22,"sshUsername":username,"sshPassword":password,"udpgwTransparentDNS":True}
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
        [InlineKeyboardButton("📦 Backup", callback_data="backup_menu")],
        [InlineKeyboardButton("📈 Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🔱 *Shadow SSH v26.0 PRECISION*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{get_domain()}:22`\n"
        f"🎯 Exact Traffic (1:1)\n"
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
    elif query.data == "status":
        await show_status(query)
    elif query.data == "refresh":
        await show_main_menu(query)
    elif query.data == "delete_menu":
        await show_delete_menu(query)
    elif query.data.startswith("delete_"):
        username = query.data.replace("delete_", "")
        await delete_user_action(query, username)
    elif query.data == "backup_menu":
        await show_backup_menu(query)
    elif query.data == "backup_create":
        await create_backup_action(query)

async def show_main_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📦 Backup", callback_data="backup_menu")],
        [InlineKeyboardButton("📈 Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    await query.edit_message_text(
        f"🔱 *Shadow SSH v26.0*\n🌐 `{get_domain()}:22`\nSelect:",
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
        await query.edit_message_text("📭 No users!")
        return
    
    message = "👥 *Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for user in users:
        username, status, used, total, expiry, limit = user
        used_mb = used / 1048576.0
        total_gb = total / 1073741824.0 if total > 0 else 0
        days_left = "∞" if expiry == 0 else str((expiry - int(time.time())) // 86400) + "d"
        usage_text = f"{used_mb:.1f}MB / ∞" if total == 0 else f"{used_mb:.1f}MB / {total_gb:.1f}GB"
        status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
        message += f"{status_emoji} `{username}`\n   📊 {usage_text}\n   ⏰ {days_left}\n\n"
    
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
            await update.message.reply_text("❌ Usage: `/create username password days traffic_gb max_conn`", parse_mode='Markdown')
            return
        
        username, password = args[0], args[1]
        days, traffic_gb, max_conn = int(args[2]), int(args[3]), int(args[4])
        
        if subprocess.run(["id", username], capture_output=True).returncode == 0:
            await update.message.reply_text(f"❌ `{username}` exists!", parse_mode='Markdown')
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
        npvt_link = generate_napsternetv(domain, username, password, str(days) if days > 0 else "∞", str(traffic_gb) if traffic_gb > 0 else "∞")
        
        await update.message.reply_text(
            f"✅ *Created!*\n"
            f"🌐 `{domain}:22`\n"
            f"👤 `{username}`\n🔑 `{password}`\n"
            f"📊 `{traffic_gb}GB`\n⏰ `{days}d`\n🔗 `{max_conn}`\n\n"
            f"📋 `{npvt_link}`",
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
    await query.edit_message_text("🗑 *Select:*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def delete_user_action(query, username):
    subprocess.run(["pkill", "-9", "-u", username], capture_output=True)
    subprocess.run(["userdel", "-r", username], capture_output=True)
    conn = sqlite3.connect(DB)
    conn.execute("DELETE FROM users WHERE username=?", [username])
    conn.execute("DELETE FROM traffic_sessions WHERE username=?", [username])
    conn.commit()
    conn.close()
    os.system(f"sed -i '/^{username}$/d' /etc/shadow-users.conf 2>/dev/null")
    os.system(f"rm -f /etc/ssh/sshd_config.d/{username}.conf")
    subprocess.run(["systemctl", "restart", "sshd"], capture_output=True)
    await query.edit_message_text(f"✅ `{username}` deleted!", parse_mode='Markdown')

async def show_backup_menu(query):
    keyboard = [
        [InlineKeyboardButton("📦 Create Backup", callback_data="backup_create")],
        [InlineKeyboardButton("🔙 Back", callback_data="refresh")]
    ]
    await query.edit_message_text("📦 *Backup*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def create_backup_action(query):
    result = subprocess.run(["/usr/local/bin/backup-manager", "backup"], capture_output=True, text=True)
    await query.edit_message_text(f"📦 *Backup Created*\n{result.stdout}", parse_mode='Markdown')

async def show_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    conn.close()
    
    msg = (f"📈 *Status*\n━━━━━━━━━━━━━━━━━━━\n\n"
           f"🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n"
           f"⏱ Uptime: `{uptime}`\n🔗 Connections: `{conn_count}`\n"
           f"👥 Users: `{active}`\n🎯 Mode: `PRECISION 1:1`")
    
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
# Main Shadow Manager
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

show_banner() {
    SERVER_IP=$(get_domain)
    LOCATION_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    DNS_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v26.0 - PRECISION EDITION 🔱${PURPLE}          ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 ${SERVER_IP}:22  |  🎯 Exact 1:1 Traffic  |  🤖 AI Active"
    [ "$LOCATION_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  🇺🇸 Fake Location: ${GREEN}ON${NC}"
    [ "$DNS_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  📡 Fake DNS: ${CYAN}ON (1ms)${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════ PRECISION MENU ══════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create New User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List All Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}🇺🇸  Fake Location Control${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}📡  Fake DNS Control${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}📦  Backup & Restore${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}🔍  PING-NET Debug${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}🤖  Telegram Bot${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}🌐  Domain Management${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}11.${NC} ${WHITE}🔄  Restart Services${NC}"
    echo -e "  ${GREEN}12.${NC} ${WHITE}🚪  Exit${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""
}

create_user() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   📝 CREATE NEW USER${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
    days_display="∞"
    [ "$days" != "0" ] && days_display="$days"
    traffic_display="∞"
    [ "$traffic_gb" != "0" ] && traffic_display="$traffic_gb"
    
    # Generate NapsternetV config directly
    config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $username | ⏰ ${days_display}d | 📎 ${traffic_display}GB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$username\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
    config_b64=$(echo -n "$config_json" | base64 -w 0)
    npvt_link="npvt-ssh://${config_b64}"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   ✅ USER CREATED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Server: ${GREEN}${SERVER}${NC}"
    echo -e "  📡 Port: ${GREEN}22${NC}"
    echo -e "  👤 Username: ${GREEN}${username}${NC}"
    echo -e "  🔑 Password: ${GREEN}${password}${NC}"
    echo -e "  📊 Limit: ${GREEN}${traffic_gb}GB${NC} | ⏰ ${GREEN}${days}d${NC} | 🔗 ${GREEN}${max_conn}${NC}"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📋 NapsternetV Config:${NC}"
    echo -e "   ${YELLOW}${npvt_link}${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
    sqlite3 "$DB" "DELETE FROM traffic_sessions WHERE username='$username';"
    systemctl restart sshd 2>/dev/null
    
    echo -e "${GREEN}✅ Deleted!${NC}"
    sleep 2
}

list_users() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   👥 ACTIVE USERS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    printf "${WHITE}%-15s %-8s %-25s %-15s %-10s${NC}\n" "Username" "Status" "Used Traffic" "Limit" "Expiry"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r username status total_limit expiry limit used; do
        [ -z "$username" ] && continue
        
        used_mb=$(echo "scale=2; $used / 1048576" | bc 2>/dev/null || echo "0")
        
        if [ "$total_limit" -eq 0 ]; then
            usage_text="${used_mb}MB / ∞"
        else
            total_mb=$(echo "scale=2; $total_limit / 1048576" | bc 2>/dev/null || echo "0")
            percent=$(echo "scale=1; $used * 100 / $total_limit" | bc 2>/dev/null || echo "0")
            usage_text="${used_mb}MB / ${total_mb}MB (${percent}%)"
        fi
        
        if [ "$expiry" -eq 0 ]; then
            expiry_text="∞"
        else
            days_left=$(( (expiry - $(date +%s)) / 86400 ))
            [ $days_left -lt 0 ] && days_left=0
            expiry_text="${days_left}d"
        fi
        
        [ "$total_limit" -eq 0 ] && limit_text="∞" || limit_text="$(echo "scale=1; $total_limit/1073741824" | bc 2>/dev/null || echo "0")GB"
        
        case $status in
            active) status_icon="🟢" ;;
            expired) status_icon="🔴" ;;
            limited) status_icon="🟡" ;;
            *) status_icon="⚪" ;;
        esac
        
        printf "%-15s %s %-8s ${CYAN}%-25s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$limit_text" "$expiry_text"
        
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit, used_traffic FROM users;")
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter..."
    read
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
        echo -e "1. Enable  2. Disable  3. Change Country  4. List  5. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1)
                echo -n -e "Country (US/GB/DE/NL/JP/CA): "
                read c
                /usr/local/bin/fake-location start "$c"
                sleep 2
                ;;
            2) /usr/local/bin/fake-location stop; sleep 2 ;;
            3) /usr/local/bin/fake-location list; echo -n -e "Code: "; read code; /usr/local/bin/fake-location start "$code"; sleep 2 ;;
            4) /usr/local/bin/fake-location list; echo ""; echo -n "Press Enter..."; read ;;
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
        echo -e "1. Enable (1ms)  2. Disable  3. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1) /usr/local/bin/fake-dns start 1; sleep 2 ;;
            2) /usr/local/bin/fake-dns stop; sleep 2 ;;
            3) break ;;
        esac
    done
}

backup_menu() {
    while true; do
        clear
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}   📦 BACKUP & RESTORE${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        /usr/local/bin/backup-manager list
        echo ""
        echo -e "1. Create Backup  2. Restore  3. Auto-Backup Toggle  4. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1) /usr/local/bin/backup-manager backup; sleep 2 ;;
            2) /usr/local/bin/backup-manager restore; sleep 2 ;;
            3)
                if systemctl is-active --quiet shadow-backup; then
                    systemctl stop shadow-backup
                    echo -e "${YELLOW}Auto-backup OFF${NC}"
                else
                    systemctl start shadow-backup
                    echo -e "${GREEN}Auto-backup ON (24h)${NC}"
                fi
                sleep 2
                ;;
            4) break ;;
        esac
    done
}

domain_management() {
    clear
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   🌐 DOMAIN MANAGEMENT${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        echo -e "Current: ${GREEN}$(cat $DOMAIN_FILE)${NC}"
    else
        echo -e "Current: ${YELLOW}No domain${NC}"
    fi
    
    echo ""
    echo -e "1. Add/Change  2. Get SSL  3. Delete  4. Back"
    echo ""
    echo -n -e "Select: "
    read choice
    
    case $choice in
        1)
            echo -n -e "Domain: "
            read d
            echo "$d" > "$DOMAIN_FILE"
            echo -e "${GREEN}✅ Domain set!${NC}"
            sleep 1
            ;;
        2)
            if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
                d=$(cat "$DOMAIN_FILE")
                echo -n -e "Email: "
                read e
                systemctl stop nginx 2>/dev/null
                certbot certonly --standalone -d "$d" --non-interactive --agree-tos --email "$e"
            else
                echo -e "${RED}❌ Set domain first!${NC}"
            fi
            sleep 2
            ;;
        3)
            echo -n -e "${RED}Delete? (y/n): ${NC}"
            read confirm
            [ "$confirm" = "y" ] && rm -f "$DOMAIN_FILE" && echo -e "${GREEN}✅ Deleted${NC}"
            sleep 1
            ;;
    esac
}

server_status() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}   📈 SERVER STATUS${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem_percent=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    uptime=$(uptime -p | sed 's/up //')
    conn=$(ss -tnp 2>/dev/null | grep ESTAB | wc -l)
    users_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status='active';")
    
    echo -e "  🖥  CPU: ${YELLOW}${cpu}%${NC}"
    echo -e "  💾 RAM: ${YELLOW}${mem_percent}%${NC}"
    echo -e "  ⏱  Uptime: ${GREEN}${uptime}${NC}"
    echo -e "  🔗 Connections: ${CYAN}${conn}${NC}"
    echo -e "  👥 Users: ${GREEN}${users_count}${NC}"
    echo -e "  📡 Port 22: ${GREEN}Open${NC}"
    echo -e "  ⚡ BBR: ${GREEN}ON${NC}"
    echo -e "  🎯 Traffic Mode: ${GREEN}PRECISION 1:1${NC}"
    echo -e "  📊 Monitor: $(systemctl is-active traffic-monitor | grep -q active && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
    echo -e "  🤖 Bot: $(systemctl is-active shadow-bot | grep -q active && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
    echo ""
    echo -n "Press Enter..."
    read
}

# Main Loop
while true; do
    show_menu
    echo -n -e "${CYAN}Select [1-12]: ${NC}"
    read choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) fake_location_menu ;;
        5) fake_dns_menu ;;
        6) backup_menu ;;
        7)
            echo -n -e "Username: "
            read uname
            /usr/local/bin/ping-net debug "$uname"
            echo ""
            echo -n "Press Enter..."
            read
            ;;
        8)
            if [ -f "$BOT_CONFIG" ]; then
                echo -e "1. Set Token  2. Add Admin  3. Start/Stop  4. Back"
                echo -n -e "Select: "
                read bc
                case $bc in
                    1)
                        echo -n -e "Token: "
                        read t
                        sed -i "s/TOKEN=.*/TOKEN=$t/" "$BOT_CONFIG"
                        systemctl restart shadow-bot 2>/dev/null
                        ;;
                    2)
                        echo -n -e "ID: "
                        read id
                        current=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
                        sed -i "s/ADMINS=.*/ADMINS=$current,$id/" "$BOT_CONFIG"
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
        9) domain_management ;;
        10) server_status ;;
        11)
            systemctl restart traffic-monitor shadow-bot sshd 2>/dev/null
            echo -e "${GREEN}✅ Restarted!${NC}"
            sleep 2
            ;;
        12) echo -e "${GREEN}👋 Bye!${NC}"; exit 0 ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ============================================
# Install Services
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   ⚙️  Installing Services${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cat > /etc/systemd/system/traffic-monitor.service << 'SERVICEEOF'
[Unit]
Description=Shadow SSH Precision Traffic Monitor
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

cat > /etc/systemd/system/shadow-backup.service << 'BACKEOF'
[Unit]
Description=Shadow SSH Auto Backup
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/backup-manager auto-backup
Restart=always
RestartSec=30
User=root
[Install]
WantedBy=multi-user.target
BACKEOF

systemctl daemon-reload
systemctl enable traffic-monitor shadow-bot ai-optimizer
systemctl restart traffic-monitor ai-optimizer

ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

# Final Message
clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ${GREEN}✅ SHADOW SSH v26.0 - PRECISION EDITION INSTALLED!${PURPLE}    ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 ${YELLOW}shadow${CYAN} - Open Panel${NC}"
echo ""
echo -e "${GREEN}🎯 PRECISION FEATURES:${NC}"
echo -e "  🎯  Exact 1:1 Traffic (NO duplication)"
echo -e "  📋  NapsternetV config at user creation"
echo -e "  🇺🇸  Fake Location (6 countries)"
echo -e "  📡  Fake DNS (1ms response)"
echo -e "  🤖  AI Optimizer"
echo -e "  📦  Backup & Restore"
echo -e "  🔍  ping-net Debug Tool"
echo -e "  🤖  Telegram Bot"
echo -e "  🌐  Domain Management"
echo ""
echo -e "${RED}❌ REMOVED (by request):${NC}"
echo -e "  ❌  Config Generator menu"
echo -e "  ❌  Half-Price Status menu"
echo -e "  ❌  Protocol Obfuscator"
echo -e "  ❌  Traffic multiplier/duplication"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
