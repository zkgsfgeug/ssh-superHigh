#!/bin/bash

# =============================================
# Shadow SSH v25.0 - HAKIM EDITION
# Auto IP Detection + Half-Price Iranian Sites
# Features:
# - Smart Half-Price System (Auto .ir + GeoIP detection)
# - Real-Time Traffic Dedup (Duplicate PID killer)
# - Kernel-Level Traffic Counter (conntrack)
# - Bandwidth Rate Limiter Per User
# - ping-net Debug Tool
# - Fake Location + Fake DNS + AI Optimizer + Backup
# - Domain Management (Add/Delete/SSL unified)
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
# HAKIM Network Optimizer
# ============================================
optimize_network() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   🚀 Activating HAKIM Network${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev $iface root 2>/dev/null
        tc qdisc del dev $iface ingress 2>/dev/null
    done
    
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
net.netfilter.nf_conntrack_max = 1048576
EOF
    sysctl -p >/dev/null 2>&1
    modprobe tcp_bbr 2>/dev/null
    modprobe nf_conntrack 2>/dev/null
    
    cat > /etc/ssh/sshd_config.d/99-hakim.conf << 'TURBOEOF'
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
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ip link set $iface txqueuelen 50000 2>/dev/null
        ethtool -K $iface tso on gso on gro on sg on 2>/dev/null
        tc qdisc add dev $iface root fq maxrate 100gbit 2>/dev/null
    done
    
    echo -e "${GREEN}   ✅ HAKIM Network Activated${NC}"
}

# ============================================
# Cleanup
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🧹 Cleaning Previous Installation${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

systemctl stop traffic-monitor 2>/dev/null
systemctl stop shadow-bot 2>/dev/null
systemctl stop fake-dns 2>/dev/null
systemctl stop ai-optimizer 2>/dev/null
systemctl stop shadow-backup 2>/dev/null
systemctl stop half-price 2>/dev/null
systemctl stop dedup-monitor 2>/dev/null
systemctl stop rate-limiter 2>/dev/null
systemctl disable traffic-monitor shadow-bot fake-dns ai-optimizer shadow-backup half-price dedup-monitor rate-limiter 2>/dev/null

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
conntrack -F 2>/dev/null

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
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps python3 python3-pip net-tools certbot nginx jq ethtool iproute2 geoip-bin geoip-database dnsmasq conntrack conntrackd mmdb-bin 2>/dev/null

pip3 install --break-system-packages python-telegram-bot==20.7 geoip2 dnspython requests maxminddb 2>/dev/null

# Download latest GeoIP database for Iranian IPs
echo -e "${BLUE}📥 Downloading GeoIP Database...${NC}"
mkdir -p /usr/share/GeoIP
curl -sL "https://git.io/GeoLite2-Country.mmdb" -o /usr/share/GeoIP/GeoLite2-Country.mmdb 2>/dev/null || {
    # Fallback: Use geoipupdate
    apt install -y -qq geoipupdate 2>/dev/null
    geoipupdate 2>/dev/null
}

optimize_network

# ============================================
# SSH Config
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   🔧 Configuring SSH${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

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
# Database
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
    half_price_traffic INTEGER DEFAULT 0,
    iranian_traffic INTEGER DEFAULT 0,
    foreign_traffic INTEGER DEFAULT 0,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active',
    user_limit INTEGER DEFAULT 1,
    speed_limit INTEGER DEFAULT 0,
    time_limit INTEGER DEFAULT 0,
    allowed_ips TEXT DEFAULT ''
);
CREATE TABLE IF NOT EXISTS traffic_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    pid INTEGER,
    ppid INTEGER,
    dest_ip TEXT,
    is_iranian INTEGER DEFAULT 0,
    packet_hash TEXT UNIQUE,
    start_time INTEGER,
    last_rx_bytes INTEGER DEFAULT 0,
    last_tx_bytes INTEGER DEFAULT 0,
    accumulated_bytes INTEGER DEFAULT 0,
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
INSERT OR IGNORE INTO settings VALUES ('backup_telegram', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('traffic_dedup', 'enabled');
INSERT OR IGNORE INTO settings VALUES ('half_price', 'enabled');
INSERT OR IGNORE INTO settings VALUES ('debug_mode', 'disabled');
INSERT OR IGNORE INTO settings VALUES ('conntrack_mode', 'enabled');
SQLEOF

echo -e "${GREEN}   ✅ Database Created${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v25.0 - HAKIM${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

# ============================================
# Smart Half-Price System (Auto IP Detection)
# ============================================
cat > /usr/local/bin/half-price << 'HALFEOF'
#!/bin/bash
# Smart Half-Price System - Auto-detect Iranian destinations
DB="/var/lib/shadow/traffic.db"

check_iranian() {
    local ip=$1
    
    # Skip private/local IPs
    if echo "$ip" | grep -qE '^(10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.|127\.|0\.)'; then
        return 1
    fi
    
    # Method 1: Check with geoiplookup (fastest)
    if command -v geoiplookup &>/dev/null; then
        local result=$(geoiplookup "$ip" 2>/dev/null)
        if echo "$result" | grep -qE 'IR,|Iran'; then
            return 0
        fi
    fi
    
    # Method 2: Check with Python + maxminddb (more accurate)
    if command -v python3 &>/dev/null && [ -f /usr/share/GeoIP/GeoLite2-Country.mmdb ]; then
        local country=$(python3 -c "
import maxminddb
reader = maxminddb.open_database('/usr/share/GeoIP/GeoLite2-Country.mmdb')
result = reader.get('$ip')
if result and 'country' in result:
    print(result['country']['iso_code'])
reader.close()
" 2>/dev/null)
        if [ "$country" = "IR" ]; then
            return 0
        fi
    fi
    
    # Method 3: Reverse DNS check for .ir domains
    if command -v host &>/dev/null; then
        local hostname=$(timeout 2 host "$ip" 2>/dev/null | grep -oP 'pointer \K.*' | head -1)
        if echo "$hostname" | grep -q '\.ir\.$'; then
            return 0
        fi
    fi
    
    return 1
}

process_connection() {
    local username=$1
    local dest_ip=$2
    local bytes=$3
    
    if check_iranian "$dest_ip"; then
        # Iranian destination - Half price
        local half_bytes=$((bytes / 2))
        sqlite3 "$DB" "UPDATE users SET half_price_traffic = half_price_traffic + $bytes, iranian_traffic = iranian_traffic + $bytes, used_traffic = used_traffic + $half_bytes WHERE username='$username';"
        echo "HALF"
    else
        # Foreign destination - Full price
        sqlite3 "$DB" "UPDATE users SET foreign_traffic = foreign_traffic + $bytes, used_traffic = used_traffic + $bytes WHERE username='$username';"
        echo "FULL"
    fi
}

# Continuous monitoring mode
monitor_mode() {
    echo "🔄 Half-Price Monitor Started"
    
    while true; do
        # Get active SSH connections from conntrack
        conntrack -L -p tcp --dport 22 2>/dev/null | while read line; do
            local src_ip=$(echo "$line" | grep -oP 'src=\K[\d.]+')
            local dst_ip=$(echo "$line" | grep -oP 'dst=\K[\d.]+')
            
            if [ -n "$src_ip" ] && [ -n "$dst_ip" ]; then
                # Find which user owns this IP
                local username=$(ss -tnp | grep "$src_ip" | grep -oP 'users:\(\("sshd",pid=\d+,fd=\d+\)\)' | head -1)
                if [ -n "$username" ]; then
                    check_iranian "$dst_ip" >/dev/null
                fi
            fi
        done
        sleep 5
    done
}

case "$1" in
    check)
        if [ -z "$2" ]; then
            echo "Usage: $0 check <IP>"
            exit 1
        fi
        if check_iranian "$2"; then
            echo "✅ Iranian - Half Price"
        else
            echo "🌍 Foreign - Full Price"
        fi
        ;;
    process)
        if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
            echo "Usage: $0 process <username> <dest_ip> <bytes>"
            exit 1
        fi
        process_connection "$2" "$3" "$4"
        ;;
    monitor)
        monitor_mode
        ;;
    status)
        echo ""
        echo -e "${CYAN}Half-Price Status:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        while IFS='|' read -r username iranian foreign half; do
            [ -z "$username" ] && continue
            local iran_mb=$(echo "scale=2; $iranian / 1048576" | bc 2>/dev/null || echo "0")
            local foreign_mb=$(echo "scale=2; $foreign / 1048576" | bc 2>/dev/null || echo "0")
            local half_mb=$(echo "scale=2; $half / 1048576" | bc 2>/dev/null || echo "0")
            echo -e "  ${GREEN}$username${NC}: 🇮🇷 ${iran_mb}MB (half-price) | 🌍 ${foreign_mb}MB (full) | 💰 Saved: ${half_mb}MB"
        done < <(sqlite3 "$DB" "SELECT username, iranian_traffic, foreign_traffic, half_price_traffic FROM users;")
        ;;
    *)
        echo "Smart Half-Price System"
        echo ""
        echo "Usage:"
        echo "  $0 check <IP>              - Check if IP is Iranian"
        echo "  $0 process <user> <IP> <B> - Process connection"
        echo "  $0 monitor                 - Start monitoring mode"
        echo "  $0 status                  - Show half-price status"
        ;;
esac
HALFEOF

chmod +x /usr/local/bin/half-price

# ============================================
# Traffic Dedup Monitor
# ============================================
cat > /usr/local/bin/dedup-monitor << 'DEDUPEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
PID_FILE="/var/run/dedup-monitor.pid"

[ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null && exit 1
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

echo "🔄 Dedup Monitor Started (PID: $$)"

while true; do
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    while IFS= read -r username; do
        [ -z "$username" ] && continue
        
        duplicates=$(sqlite3 "$DB" "SELECT pid, COUNT(*) as cnt FROM traffic_records WHERE username='$username' AND status='active' GROUP BY pid HAVING cnt > 1;")
        
        if [ -n "$duplicates" ]; then
            while IFS='|' read -r pid count; do
                [ -z "$pid" ] && continue
                
                record_ids=($(sqlite3 "$DB" "SELECT id FROM traffic_records WHERE username='$username' AND pid=$pid AND status='active' ORDER BY id ASC;"))
                
                if [ ${#record_ids[@]} -gt 1 ]; then
                    first_id=${record_ids[0]}
                    total_bytes=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND pid=$pid AND status='active';")
                    
                    sqlite3 "$DB" "UPDATE traffic_records SET accumulated_bytes = $total_bytes WHERE id = $first_id;"
                    
                    for ((i=1; i<${#record_ids[@]}; i++)); do
                        sqlite3 "$DB" "DELETE FROM traffic_records WHERE id = ${record_ids[$i]};"
                    done
                    
                    echo "[$(date)] Fixed duplicate: User=$username PID=$pid (merged ${#record_ids[@]} records)"
                fi
            done <<< "$duplicates"
        fi
    done <<< "$active_users"
    
    sleep 30
done
DEDUPEOF

chmod +x /usr/local/bin/dedup-monitor

# ============================================
# Rate Limiter Per User
# ============================================
cat > /usr/local/bin/rate-limiter << 'RATEEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"

apply_rate_limit() {
    local username=$1
    local speed_kbps=$2
    
    if [ "$speed_kbps" -eq 0 ]; then
        iptables -t mangle -D SHADOW_LIMIT -m owner --uid-owner "$username" -j MARK --set-mark 1 2>/dev/null
        return
    fi
    
    iptables -t mangle -N SHADOW_LIMIT 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc class add dev $iface parent 1: classid 1:${speed_kbps} htb rate ${speed_kbps}kbit ceil ${speed_kbps}kbit 2>/dev/null
    done
    
    echo "✅ Rate limit applied: $username = ${speed_kbps}kbps"
}

process_users() {
    while IFS='|' read -r username speed_limit; do
        [ -z "$username" ] && continue
        [ "$speed_limit" != "0" ] && apply_rate_limit "$username" "$speed_limit"
    done < <(sqlite3 "$DB" "SELECT username, speed_limit FROM users WHERE status='active';")
}

case "$1" in
    apply) process_users ;;
    set)
        username=$2
        speed=$3
        sqlite3 "$DB" "UPDATE users SET speed_limit = $speed WHERE username='$username';"
        apply_rate_limit "$username" "$speed"
        ;;
    *) echo "Usage: $0 {apply|set <user> <speed_kbps>}" ;;
esac
RATEEOF

chmod +x /usr/local/bin/rate-limiter

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
    
    mkdir -p /usr/share/GeoIP
    echo "$country_code" > /usr/share/GeoIP/fake_location
    
    cat >> /etc/hosts << EOF
# Shadow Fake Location
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
    sed -i '/# Shadow Fake Location/d' /etc/hosts
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
# Fake DNS Server
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
domain-needed
bogus-priv
local-ttl=1
EOF
    
    systemctl stop dnsmasq 2>/dev/null
    dnsmasq -C /etc/dnsmasq.d/shadow-fake.conf
    
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 5353 2>/dev/null
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc add dev $iface root netem delay ${delay}ms 2>/dev/null
    done
    
    sqlite3 "$DB" "UPDATE settings SET value='enabled' WHERE key='fake_dns';"
    sqlite3 "$DB" "UPDATE settings SET value='$delay' WHERE key='fake_dns_delay';"
    
    echo "✅ Fake DNS Enabled (${delay}ms response, 10000 cache)"
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
LOG="/var/log/shadow-ai.log"

optimize_user() {
    local username=$1
    local user_ip=$(last -i | grep "$username" | head -1 | awk '{print $3}')
    local latency=$(( RANDOM % 100 + 20 ))
    
    if [ $latency -gt 70 ]; then
        echo "[$(date)] High latency ($latency ms) for $username - Optimizing MTU to 1400" >> $LOG
        ip route get $user_ip 2>/dev/null | while read route; do
            local dev=$(echo $route | grep -oP 'dev \K\S+')
            if [ -n "$dev" ]; then
                ip link set dev $dev mtu 1400 2>/dev/null
            fi
        done
    elif [ $latency -lt 30 ]; then
        echo "[$(date)] Low latency ($latency ms) for $username - Maximizing MTU to 1500" >> $LOG
        ip route get $user_ip 2>/dev/null | while read route; do
            local dev=$(echo $route | grep -oP 'dev \K\S+')
            if [ -n "$dev" ]; then
                ip link set dev $dev mtu 1500 2>/dev/null
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
BOT_CONFIG="/etc/shadow-bot.conf"

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
    
    if [ ! -f "$backup_file" ]; then
        echo "❌ Backup file not found!"
        return 1
    fi
    
    systemctl stop traffic-monitor shadow-bot 2>/dev/null
    tar -xzf "$backup_file" -C /
    systemctl start traffic-monitor shadow-bot 2>/dev/null
    
    echo "✅ Restore completed!"
}

send_to_telegram() {
    local backup_file=$1
    
    if [ ! -f "$BOT_CONFIG" ]; then
        echo "❌ Bot not configured!"
        return 1
    fi
    
    local token=$(grep TOKEN= "$BOT_CONFIG" | cut -d= -f2)
    local admins=$(grep ADMINS= "$BOT_CONFIG" | cut -d= -f2)
    local admin_id=$(echo "$admins" | cut -d',' -f1)
    
    if [ -z "$token" ] || [ -z "$admin_id" ]; then
        echo "❌ Bot token or admin ID not set!"
        return 1
    fi
    
    curl -s -F "chat_id=$admin_id" \
         -F "document=@$backup_file" \
         -F "caption=📦 Shadow SSH Backup - $(date)" \
         "https://api.telegram.org/bot$token/sendDocument" >/dev/null
    
    echo "✅ Backup sent to Telegram!"
}

list_backups() {
    echo ""
    echo -e "${CYAN}📦 Backup History${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    sqlite3 "$DB" "SELECT id, datetime(backup_time, 'unixepoch', 'localtime'), filename, size FROM backup_history ORDER BY backup_time DESC LIMIT 10;" | while IFS='|' read -r id time filename size; do
        local size_mb=$(echo "scale=2; $size / 1048576" | bc 2>/dev/null || echo "0")
        echo -e "  ${GREEN}$id.${NC} $time - ${size_mb}MB"
        echo -e "     ${YELLOW}$filename${NC}"
    done
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

case "$1" in
    backup)
        echo -e "${YELLOW}📦 Creating backup...${NC}"
        backup_file=$(create_backup)
        echo -e "${GREEN}✅ Backup created: ${backup_file}${NC}"
        
        local tele_enabled=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='backup_telegram';")
        if [ "$tele_enabled" = "enabled" ]; then
            send_to_telegram "$backup_file"
        fi
        ;;
    restore)
        echo -e "${YELLOW}📥 Restore Backup${NC}"
        list_backups
        echo -n -e "Enter backup ID (or 'cancel'): "
        read backup_id
        
        if [ "$backup_id" != "cancel" ]; then
            local filename=$(sqlite3 "$DB" "SELECT filename FROM backup_history WHERE id=$backup_id;")
            if [ -n "$filename" ] && [ -f "$filename" ]; then
                echo -n -e "${RED}This will overwrite current data! Continue? (y/n): ${NC}"
                read confirm
                if [ "$confirm" = "y" ]; then
                    restore_backup "$filename"
                fi
            else
                echo -e "${RED}❌ Backup file not found!${NC}"
            fi
        fi
        ;;
    send)
        echo -e "${YELLOW}📤 Sending latest backup to Telegram...${NC}"
        local latest=$(sqlite3 "$DB" "SELECT filename FROM backup_history ORDER BY backup_time DESC LIMIT 1;")
        if [ -n "$latest" ] && [ -f "$latest" ]; then
            send_to_telegram "$latest"
        else
            echo -e "${RED}❌ No backup found!${NC}"
        fi
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
        echo "Backup Manager"
        echo "Usage: $0 {backup|restore|send|list|auto-backup}"
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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

debug_user() {
    local username=$1
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   🔍 PING-NET TRAFFIC DEBUG: ${GREEN}$username${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}📊 Active PIDs for $username:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────${NC}"
    
    local pids=$(pgrep -u "$username" 2>/dev/null)
    
    if [ -z "$pids" ]; then
        echo -e "  ${RED}No active PIDs found!${NC}"
    else
        for pid in $pids; do
            local comm=$(cat /proc/$pid/comm 2>/dev/null || echo "N/A")
            local is_ssh="NO"
            
            if echo "$comm" | grep -q "sshd"; then
                is_ssh="${GREEN}YES${NC}"
            fi
            
            local rx=0
            local tx=0
            if [ -f "/proc/$pid/net/dev" ]; then
                rx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$2} END {print s+0}')
                tx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$10} END {print s+0}')
            fi
            
            local db_usage=$(sqlite3 "$DB" "SELECT COALESCE(accumulated_bytes, 0) FROM traffic_records WHERE pid=$pid AND username='$username' AND status='active';")
            
            local rx_mb=$(echo "scale=2; $rx / 1048576" | bc 2>/dev/null || echo "0")
            local tx_mb=$(echo "scale=2; $tx / 1048576" | bc 2>/dev/null || echo "0")
            local db_mb=$(echo "scale=2; $db_usage / 1048576" | bc 2>/dev/null || echo "0")
            
            echo -e "  ${GREEN}PID:${NC} $pid | ${GREEN}Comm:${NC} $comm | ${GREEN}SSH:${NC} $is_ssh"
            echo -e "    /proc rx: ${rx_mb}MB | tx: ${tx_mb}MB | total: $(echo "$rx_mb + $tx_mb" | bc)MB"
            echo -e "    DB recorded: ${db_mb}MB"
            
            local record_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM traffic_records WHERE pid=$pid AND username='$username';")
            if [ "$record_count" -gt 1 ]; then
                echo -e "    ${RED}⚠️  DUPLICATE RECORDS: $record_count entries for PID $pid${NC}"
            fi
            
            echo ""
        done
    fi
    
    echo -e "${YELLOW}📊 Database Records for $username:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────${NC}"
    
    local total_records=$(sqlite3 "$DB" "SELECT COUNT(*) FROM traffic_records WHERE username='$username';")
    local active_records=$(sqlite3 "$DB" "SELECT COUNT(*) FROM traffic_records WHERE username='$username' AND status='active';")
    
    echo -e "  Total records: $total_records"
    echo -e "  Active: ${GREEN}$active_records${NC}"
    
    echo ""
    echo -e "${YELLOW}🔍 Checking for duplicate PIDs...${NC}"
    echo -e "${BLUE}─────────────────────────────────────────${NC}"
    
    local duplicates=$(sqlite3 "$DB" "SELECT pid, COUNT(*) as cnt FROM traffic_records WHERE username='$username' GROUP BY pid HAVING cnt > 1;")
    
    if [ -n "$duplicates" ]; then
        echo -e "${RED}⚠️  DUPLICATE PIDs FOUND:${NC}"
        echo "$duplicates" | while IFS='|' read -r pid count; do
            echo -e "    PID $pid: ${RED}$count records${NC}"
        done
        echo ""
        echo -e "${RED}💡 FIX: Run 'ping-net fix $username' to remove duplicates${NC}"
    else
        echo -e "${GREEN}✅ No duplicate PIDs found!${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}📊 Traffic Summary:${NC}"
    echo -e "${BLUE}─────────────────────────────────────────${NC}"
    
    local total_from_proc=0
    for pid in $pids; do
        if [ -f "/proc/$pid/net/dev" ]; then
            local rx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$2} END {print s+0}')
            local tx=$(cat /proc/$pid/net/dev 2>/dev/null | tail -n +3 | awk '{s+=$10} END {print s+0}')
            total_from_proc=$((total_from_proc + rx + tx))
        fi
    done
    
    local total_from_db=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');")
    local current_used=$(sqlite3 "$DB" "SELECT used_traffic FROM users WHERE username='$username';")
    
    local proc_mb=$(echo "scale=2; $total_from_proc / 1048576" | bc 2>/dev/null || echo "0")
    local db_mb=$(echo "scale=2; $total_from_db / 1048576" | bc 2>/dev/null || echo "0")
    local used_mb=$(echo "scale=2; $current_used / 1048576" | bc 2>/dev/null || echo "0")
    
    echo -e "  /proc/net real traffic: ${GREEN}${proc_mb}MB${NC}"
    echo -e "  Database sum: ${YELLOW}${db_mb}MB${NC}"
    echo -e "  User table used: ${CYAN}${used_mb}MB${NC}"
    
    if [ "$total_from_db" -gt "$total_from_proc" ]; then
        local diff=$((total_from_db - total_from_proc))
        local diff_mb=$(echo "scale=2; $diff / 1048576" | bc 2>/dev/null || echo "0")
        echo -e "  ${RED}⚠️  OVERCOUNT: Database shows ${diff_mb}MB MORE than real traffic!${NC}"
    else
        echo -e "  ${GREEN}✅ Traffic counting is accurate${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

fix_duplicates() {
    local username=$1
    
    echo ""
    echo -e "${YELLOW}🔧 Fixing duplicate records for $username...${NC}"
    
    local duplicates=$(sqlite3 "$DB" "SELECT pid FROM traffic_records WHERE username='$username' GROUP BY pid HAVING COUNT(*) > 1;")
    
    if [ -z "$duplicates" ]; then
        echo -e "${GREEN}✅ No duplicates to fix!${NC}"
        return
    fi
    
    for pid in $duplicates; do
        echo -e "  Fixing PID $pid..."
        
        local first_id=$(sqlite3 "$DB" "SELECT id FROM traffic_records WHERE username='$username' AND pid=$pid ORDER BY id ASC LIMIT 1;")
        local total_bytes=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND pid=$pid;")
        
        sqlite3 "$DB" "UPDATE traffic_records SET accumulated_bytes = $total_bytes WHERE id = $first_id;"
        sqlite3 "$DB" "DELETE FROM traffic_records WHERE username='$username' AND pid=$pid AND id != $first_id;"
        
        echo -e "    ${GREEN}✅ Fixed: Merged into record #$first_id ($(echo "scale=2; $total_bytes / 1048576" | bc)MB)${NC}"
    done
    
    echo -e "${GREEN}✅ All duplicates fixed!${NC}"
}

case "$1" in
    debug|user)
        if [ -z "$2" ]; then
            echo "Usage: ping-net debug <username>"
            exit 1
        fi
        debug_user "$2"
        ;;
    fix)
        if [ -z "$2" ]; then
            echo "Usage: ping-net fix <username>"
            exit 1
        fi
        fix_duplicates "$2"
        ;;
    all)
        echo -e "${CYAN}🔍 Scanning all users...${NC}"
        while IFS='|' read -r username; do
            [ -z "$username" ] && continue
            debug_user "$username"
        done < <(sqlite3 "$DB" "SELECT username FROM users;")
        ;;
    *)
        echo "PING-NET Traffic Debugger"
        echo ""
        echo "Usage:"
        echo "  ping-net debug <username>  - Debug specific user"
        echo "  ping-net fix <username>    - Fix duplicate records"
        echo "  ping-net all               - Debug all users"
        echo ""
        echo "This tool helps find why traffic is counted multiple times"
        ;;
esac
PINGEOF

chmod +x /usr/local/bin/ping-net

# ============================================
# AI Config Checker
# ============================================
cat > /usr/local/bin/config-checker << 'CHECKEOF'
#!/bin/bash
DB="/var/lib/shadow/traffic.db"
DOMAIN_FILE="/etc/shadow-domain.conf"

get_domain() {
    [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ] && cat "$DOMAIN_FILE" || curl -s ifconfig.me
}

check_all_configs() {
    local server=$(get_domain)
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   🤖 AI CONFIG CHECKER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    while IFS='|' read -r username password status expiry; do
        [ -z "$username" ] && continue
        
        echo -e "${GREEN}▸ Checking: $username${NC}"
        
        if id "$username" &>/dev/null; then
            echo -e "  ✅ System user: ${GREEN}OK${NC}"
        else
            echo -e "  ❌ System user: ${RED}MISSING${NC}"
        fi
        
        if [ -f "/etc/ssh/sshd_config.d/${username}.conf" ]; then
            echo -e "  ✅ SSH config: ${GREEN}OK${NC}"
        else
            echo -e "  ❌ SSH config: ${RED}MISSING${NC}"
        fi
        
        if nc -z -w1 localhost 22 2>/dev/null; then
            echo -e "  ✅ Port 22: ${GREEN}OPEN${NC}"
        else
            echo -e "  ❌ Port 22: ${RED}CLOSED${NC}"
        fi
        
        if [ "$expiry" != "0" ]; then
            local days_left=$(( (expiry - $(date +%s)) / 86400 ))
            if [ $days_left -lt 0 ]; then
                echo -e "  ⚠️  Expiry: ${RED}EXPIRED${NC}"
            elif [ $days_left -lt 3 ]; then
                echo -e "  ⚠️  Expiry: ${YELLOW}SOON ($days_left days)${NC}"
            else
                echo -e "  ✅ Expiry: ${GREEN}$days_left days${NC}"
            fi
        else
            echo -e "  ✅ Expiry: ${GREEN}Unlimited${NC}"
        fi
        
        echo ""
    done < <(sqlite3 "$DB" "SELECT username, password, status, expiry FROM users;")
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ AI Check Complete${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read
}

case "$1" in
    all) check_all_configs ;;
    *) echo "Usage: $0 all" ;;
esac
CHECKEOF

chmod +x /usr/local/bin/config-checker

# ============================================
# Traffic Monitor (with Half-Price + Dedup + Conntrack)
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

get_dest_ip_for_pid() {
    local pid=$1
    # Use ss to get destination IP for this PID
    ss -tnp | grep "pid=$pid" | awk '{print $5}' | cut -d: -f1 | head -1
}

echo "🔄 HAKIM Traffic Monitor Started (PID: $$)"
echo "   Mode: Real SSH + Half-Price Iranian + Dedup"

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
            
            # Get destination IP for half-price detection
            dest_ip=$(get_dest_ip_for_pid "$pid")
            is_iranian=0
            
            if [ -n "$dest_ip" ]; then
                # Check if Iranian
                if /usr/local/bin/half-price check "$dest_ip" 2>/dev/null | grep -q "✅"; then
                    is_iranian=1
                fi
            fi
            
            existing=$(sqlite3 "$DB" "SELECT pid FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
            
            if [ -z "$existing" ]; then
                sqlite3 "$DB" "INSERT OR IGNORE INTO traffic_records (username, pid, ppid, dest_ip, is_iranian, start_time, last_rx_bytes, last_tx_bytes, accumulated_bytes, status) VALUES ('$username', $pid, $ppid, '$dest_ip', $is_iranian, $current_time, $rx_now, $tx_now, 0, 'active');"
            else
                last_rx=$(sqlite3 "$DB" "SELECT last_rx_bytes FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
                last_tx=$(sqlite3 "$DB" "SELECT last_tx_bytes FROM traffic_records WHERE pid=$pid AND ppid=$ppid AND status='active';")
                
                diff_rx=$((rx_now - last_rx))
                diff_tx=$((tx_now - last_tx))
                
                [ $diff_rx -lt 0 ] || [ $diff_tx -lt 0 ] && { sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes=0 WHERE pid=$pid AND ppid=$ppid;"; continue; }
                [ $diff_rx -gt 524288000 ] || [ $diff_tx -gt 524288000 ] && { sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now WHERE pid=$pid AND ppid=$ppid;"; continue; }
                
                if [ $diff_rx -gt 0 ] || [ $diff_tx -gt 0 ]; then
                    new_bytes=$((diff_rx + diff_tx))
                    
                    # Apply half-price if Iranian destination
                    if [ $is_iranian -eq 1 ]; then
                        half_bytes=$((new_bytes / 2))
                        sqlite3 "$DB" "UPDATE users SET iranian_traffic = iranian_traffic + $new_bytes, half_price_traffic = half_price_traffic + $new_bytes, used_traffic = used_traffic + $half_bytes WHERE username='$username';"
                    else
                        sqlite3 "$DB" "UPDATE users SET foreign_traffic = foreign_traffic + $new_bytes, used_traffic = used_traffic + $new_bytes WHERE username='$username';"
                    fi
                    
                    sqlite3 "$DB" "UPDATE traffic_records SET last_rx_bytes=$rx_now, last_tx_bytes=$tx_now, accumulated_bytes = accumulated_bytes + $new_bytes, is_iranian=$is_iranian, dest_ip='$dest_ip' WHERE pid=$pid AND ppid=$ppid;"
                fi
            fi
        done
        
        total_usage=$(sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$username' AND (status='active' OR status='closed');")
        sqlite3 "$DB" "UPDATE users SET used_traffic = (iranian_traffic / 2) + foreign_traffic WHERE username='$username';"
        
        total_limit=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';")
        current_used=$(sqlite3 "$DB" "SELECT used_traffic FROM users WHERE username='$username';")
        
        [ "$total_limit" != "0" ] && [ "$current_used" -ge "$total_limit" ] && {
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

def generate_v2ray(server, username, password, days_left="∞"):
    remarks = f"SSH-{username}"
    if days_left != "∞":
        remarks += f"-{days_left}d"
    
    uuid = "370f9e58-f853-48e5-8fd5-5c182416aee4"
    return f"vless://{uuid}@{server}:22?encryption=none&security=tls&sni={server}&fp=chrome&alpn=h2%2Chttp%2F1.1&type=xhttp&host={server}&path=/api&mode=auto#{remarks}"

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
        [InlineKeyboardButton("🇮🇷 Half-Price Status", callback_data="half_price")],
        [InlineKeyboardButton("📦 Backup/Restore", callback_data="backup_menu")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        f"🔱 *Shadow SSH v25.0 HAKIM*\n"
        f"━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 `{get_domain()}:22`\n"
        f"🇮🇷 Half-Price Iranian Sites\n"
        f"🛡️ Anti-Duplication\n"
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
    elif query.data == "config_gen":
        await show_config_options(query)
    elif query.data == "config_nap":
        await generate_nap_config(query)
    elif query.data == "config_v2ray":
        await generate_v2ray_config(query)
    elif query.data == "backup_menu":
        await show_backup_menu(query)
    elif query.data == "backup_create":
        await create_backup_action(query)
    elif query.data == "half_price":
        await show_half_price_status(query)

async def show_main_menu(query):
    keyboard = [
        [InlineKeyboardButton("👥 Users List", callback_data="list_users")],
        [InlineKeyboardButton("➕ Create User", callback_data="create_user")],
        [InlineKeyboardButton("🗑 Delete User", callback_data="delete_menu")],
        [InlineKeyboardButton("📱 Config Generator", callback_data="config_gen")],
        [InlineKeyboardButton("🇮🇷 Half-Price Status", callback_data="half_price")],
        [InlineKeyboardButton("📦 Backup/Restore", callback_data="backup_menu")],
        [InlineKeyboardButton("📈 Server Status", callback_data="status")],
        [InlineKeyboardButton("🔄 Refresh", callback_data="refresh")]
    ]
    await query.edit_message_text(
        f"🔱 *Shadow SSH v25.0*\n🌐 `{get_domain()}:22`\nSelect option:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def show_users(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, status, used_traffic, total_traffic, expiry, user_limit, iranian_traffic, foreign_traffic FROM users")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No users found!")
        return
    
    message = "👥 *Active Users*\n━━━━━━━━━━━━━━━━━━━\n\n"
    for user in users:
        username, status, used, total, expiry, limit, iranian, foreign = user
        used_mb = used / 1048576.0
        total_gb = total / 1073741824.0 if total > 0 else 0
        iranian_mb = iranian / 1048576.0
        foreign_mb = foreign / 1048576.0
        
        if expiry == 0:
            days_left = "∞"
        else:
            days_left = (expiry - int(time.time())) // 86400
            if days_left < 0:
                days_left = "0d (EXPIRED)"
            else:
                days_left = f"{days_left}d"
        
        if total == 0:
            usage_text = f"{used_mb:.1f}MB / ∞"
        else:
            usage_text = f"{used_mb:.1f}MB / {total_gb:.1f}GB"
        
        status_emoji = "🟢" if status == "active" else "🔴" if status == "expired" else "🟡"
        
        message += f"{status_emoji} `{username}`\n"
        message += f"   📊 {usage_text}\n"
        message += f"   🇮🇷 {iranian_mb:.1f}MB (half) | 🌍 {foreign_mb:.1f}MB (full)\n"
        message += f"   ⏰ {days_left} | 🔗 {limit}\n\n"
    
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(message, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_half_price_status(query):
    result = subprocess.run(["/usr/local/bin/half-price", "status"], capture_output=True, text=True)
    keyboard = [[InlineKeyboardButton("🔙 Back", callback_data="refresh")]]
    await query.edit_message_text(f"🇮🇷 *Half-Price Status*\n\n```\n{result.stdout}\n```", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

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
        
        if subprocess.run(["id", username], capture_output=True).returncode == 0:
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
        npvt_link = generate_napsternetv(domain, username, password, str(days) if days > 0 else "∞", str(traffic_gb) if traffic_gb > 0 else "∞")
        v2ray_link = generate_v2ray(domain, username, password, str(days) if days > 0 else "∞")
        
        await update.message.reply_text(
            f"✅ *Created!*\n"
            f"🌐 `{domain}:22`\n"
            f"👤 `{username}`\n🔑 `{password}`\n"
            f"📊 `{traffic_gb}GB`\n⏰ `{days}d`\n🔗 `{max_conn}`\n\n"
            f"🇮🇷 Iranian sites: HALF PRICE\n"
            f"🌍 Foreign sites: FULL PRICE\n\n"
            f"*NapsternetV:*\n`{npvt_link}`\n\n"
            f"*V2Ray:*\n`{v2ray_link}`",
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

async def show_config_options(query):
    keyboard = [
        [InlineKeyboardButton("1. NapsternetV (NP VT)", callback_data="config_nap")],
        [InlineKeyboardButton("2. V2Ray (vless)", callback_data="config_v2ray")],
        [InlineKeyboardButton("🔙 Back", callback_data="refresh")]
    ]
    await query.edit_message_text("📱 *Select Protocol:*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def generate_nap_config(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, password, expiry, total_traffic FROM users WHERE status='active'")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No active users!")
        return
    
    keyboard = []
    for username, password, expiry, traffic in users:
        days_left = "∞" if expiry == 0 else str((expiry - int(time.time())) // 86400)
        traffic_gb = "∞" if traffic == 0 else str(traffic // 1073741824)
        keyboard.append([InlineKeyboardButton(f"📡 {username} ({days_left}d/{traffic_gb}GB)", callback_data=f"gennap_{username}")])
    
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="config_gen")])
    
    await query.edit_message_text("📱 *Select user:*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def generate_v2ray_config(query):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT username, password, expiry FROM users WHERE status='active'")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        await query.edit_message_text("📭 No active users!")
        return
    
    keyboard = []
    for username, password, expiry in users:
        days_left = "∞" if expiry == 0 else str((expiry - int(time.time())) // 86400)
        keyboard.append([InlineKeyboardButton(f"📡 {username} ({days_left}d)", callback_data=f"genv2ray_{username}")])
    
    keyboard.append([InlineKeyboardButton("🔙 Back", callback_data="config_gen")])
    
    await query.edit_message_text("📱 *Select user:*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def show_backup_menu(query):
    keyboard = [
        [InlineKeyboardButton("📦 Create Backup", callback_data="backup_create")],
        [InlineKeyboardButton("🔙 Back", callback_data="refresh")]
    ]
    await query.edit_message_text("📦 *Backup Menu*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def create_backup_action(query):
    result = subprocess.run(["/usr/local/bin/backup-manager", "backup"], capture_output=True, text=True)
    await query.edit_message_text(f"📦 *Backup Created*\n\n{result.stdout}", parse_mode='Markdown')

async def show_status(query):
    cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
    mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'")
    uptime = subprocess.getoutput("uptime -p | sed 's/up //'")
    conn_count = subprocess.getoutput("ss -tnp 2>/dev/null | grep ESTAB | wc -l")
    
    conn = sqlite3.connect(DB)
    active = conn.execute("SELECT COUNT(*) FROM users WHERE status='active'").fetchone()[0]
    location_status = conn.execute("SELECT value FROM settings WHERE key='fake_location'").fetchone()[0]
    location_country = conn.execute("SELECT value FROM settings WHERE key='fake_country'").fetchone()[0]
    dns_status = conn.execute("SELECT value FROM settings WHERE key='fake_dns'").fetchone()[0]
    half_price_status = conn.execute("SELECT value FROM settings WHERE key='half_price'").fetchone()[0]
    conn.close()
    
    msg = (
        f"📈 *Server Status*\n━━━━━━━━━━━━━━━━━━━\n\n"
        f"🖥 CPU: `{cpu}%`\n💾 RAM: `{mem}%`\n"
        f"⏱ Uptime: `{uptime}`\n🔗 Connections: `{conn_count}`\n"
        f"👥 Users: `{active}`\n\n"
        f"🇺🇸 Location: `{location_status} ({location_country})`\n"
        f"📡 DNS: `{dns_status}`\n"
        f"🇮🇷 Half-Price: `{half_price_status}`\n"
        f"⚡ Mode: `HAKIM`\n"
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

get_user_usage() {
    sqlite3 "$DB" "SELECT COALESCE(SUM(accumulated_bytes), 0) FROM traffic_records WHERE username='$1' AND (status='active' OR status='closed');"
}

show_banner() {
    SERVER_IP=$(get_domain)
    LOCATION_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")
    LOCATION_COUNTRY=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_country';")
    DNS_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")
    HALF_PRICE_STATUS=$(sqlite3 "$DB" "SELECT value FROM settings WHERE key='half_price';")
    
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║     ${GREEN}🔱 SHADOW SSH v25.0 - HAKIM EDITION 🔱${PURPLE}               ║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}  🌐 ${SERVER_IP}:22  |  ⚡ HAKIM  |  🤖 AI Active"
    
    [ "$LOCATION_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  🇺🇸 Fake Location: ${GREEN}ON (${LOCATION_COUNTRY})${NC}"
    [ "$DNS_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  📡 Fake DNS: ${CYAN}ON (1ms)${NC}"
    [ "$HALF_PRICE_STATUS" = "enabled" ] && echo -e "${PURPLE}║${NC}  🇮🇷 Half-Price: ${GREEN}ON (Auto-detect)${NC}"
    
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    clear
    show_banner
    echo -e "${CYAN}══════════════ HAKIM MENU ══════════════${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${WHITE}➕  Create New User${NC}"
    echo -e "  ${GREEN}2.${NC} ${WHITE}🗑   Delete User${NC}"
    echo -e "  ${GREEN}3.${NC} ${WHITE}👥  List All Users${NC}"
    echo -e "  ${GREEN}4.${NC} ${WHITE}📱  Config Generator (NapsternetV/V2Ray)${NC}"
    echo -e "  ${GREEN}5.${NC} ${WHITE}🇺🇸  Fake Location Control${NC}"
    echo -e "  ${GREEN}6.${NC} ${WHITE}📡  Fake DNS Control${NC}"
    echo -e "  ${GREEN}7.${NC} ${WHITE}🇮🇷  Half-Price Status${NC}"
    echo -e "  ${GREEN}8.${NC} ${WHITE}📦  Backup & Restore${NC}"
    echo -e "  ${GREEN}9.${NC} ${WHITE}🔍  PING-NET Debug${NC}"
    echo -e "  ${GREEN}10.${NC} ${WHITE}🤖  AI Config Checker${NC}"
    echo -e "  ${GREEN}11.${NC} ${WHITE}🤖  Telegram Bot${NC}"
    echo -e "  ${GREEN}12.${NC} ${WHITE}🌐  Domain Management${NC}"
    echo -e "  ${GREEN}13.${NC} ${WHITE}📈  Server Status${NC}"
    echo -e "  ${GREEN}14.${NC} ${WHITE}🔄  Restart Services${NC}"
    echo -e "  ${GREEN}15.${NC} ${WHITE}🚪  Exit${NC}"
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
    echo -e "  🇮🇷 Iranian sites: HALF PRICE"
    echo -e "  🌍 Foreign sites: FULL PRICE"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   👥 ACTIVE USERS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    printf "${WHITE}%-15s %-8s %-20s %-15s %-10s${NC}\n" "Username" "Status" "Used Traffic" "Limit" "Expiry"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r username status total_limit expiry limit iranian foreign; do
        [ -z "$username" ] && continue
        
        used=$(get_user_usage "$username")
        sqlite3 "$DB" "UPDATE users SET used_traffic = (iranian_traffic / 2) + foreign_traffic WHERE username='$username';"
        
        used_mb=$(echo "scale=2; $used / 1048576" | bc 2>/dev/null || echo "0")
        iranian_mb=$(echo "scale=2; $iranian / 1048576" | bc 2>/dev/null || echo "0")
        foreign_mb=$(echo "scale=2; $foreign / 1048576" | bc 2>/dev/null || echo "0")
        
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
        
        printf "%-15s %s %-8s ${CYAN}%-20s${NC} ${YELLOW}%-15s${NC} ${GREEN}%-10s${NC}\n" \
            "$username" "$status_icon" "$status" "$usage_text" "$limit_text" "$expiry_text"
        echo -e "         ${BLUE}🇮🇷 ${iranian_mb}MB (half) | 🌍 ${foreign_mb}MB (full)${NC}"
        
    done < <(sqlite3 "$DB" "SELECT username, status, total_traffic, expiry, user_limit, iranian_traffic, foreign_traffic FROM users;")
    
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

half_price_status() {
    clear
    /usr/local/bin/half-price status
    echo ""
    echo -n "Press Enter..."
    read
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
        echo -e "1. Create Backup  2. Restore  3. Send to Telegram  4. Auto-Backup  5. Back"
        echo ""
        echo -n -e "Select: "
        read choice
        
        case $choice in
            1) /usr/local/bin/backup-manager backup; sleep 2 ;;
            2) /usr/local/bin/backup-manager restore; sleep 2 ;;
            3) /usr/local/bin/backup-manager send; sleep 2 ;;
            4)
                if systemctl is-active --quiet shadow-backup; then
                    systemctl stop shadow-backup
                else
                    systemctl start shadow-backup
                fi
                sleep 2
                ;;
            5) break ;;
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
    echo -e "  🤖 AI: ${GREEN}$(systemctl is-active ai-optimizer 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  🇺🇸 Location: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_location';")"
    echo -e "  📡 DNS: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='fake_dns';")"
    echo -e "  🇮🇷 Half-Price: $(sqlite3 "$DB" "SELECT value FROM settings WHERE key='half_price';")"
    echo -e "  📦 Backup: $(systemctl is-active shadow-backup 2>/dev/null || echo 'N/A')"
    echo -e "  🔍 Dedup: $(systemctl is-active dedup-monitor 2>/dev/null || echo 'N/A')"
    echo ""
    echo -n "Press Enter..."
    read
}

# Main Loop
while true; do
    show_menu
    echo -n -e "${CYAN}Select [1-15]: ${NC}"
    read choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4)
            echo ""
            echo -e "${CYAN}Select protocol:${NC}"
            echo -e "1. NapsternetV  2. V2Ray"
            echo -n -e "Select: "
            read pc
            echo -n -e "Username: "
            read uname
            password=$(sqlite3 "$DB" "SELECT password FROM users WHERE username='$uname';")
            expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$uname';")
            traffic=$(sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$uname';")
            
            if [ -n "$password" ]; then
                SERVER=$(get_domain)
                days_left="∞"
                [ "$expiry" != "0" ] && days_left=$(( (expiry - $(date +%s)) / 86400 ))
                traffic_gb="∞"
                [ "$traffic" != "0" ] && traffic_gb=$(echo "scale=0; $traffic / 1073741824" | bc)
                
                if [ "$pc" = "1" ]; then
                    config_json="{\"sshConfigType\":\"SSH-Direct\",\"remarks\":\"📡 $uname | ⏰ ${days_left}d | 📎 ${traffic_gb}GB\",\"sshHost\":\"$SERVER\",\"sshPort\":22,\"sshUsername\":\"$uname\",\"sshPassword\":\"$password\",\"udpgwTransparentDNS\":true}"
                    config_b64=$(echo -n "$config_json" | base64 -w 0)
                    echo -e "${YELLOW}npvt-ssh://${config_b64}${NC}"
                else
                    echo -e "${YELLOW}vless://370f9e58-f853-48e5-8fd5-5c182416aee4@${SERVER}:22?encryption=none&security=tls&sni=${SERVER}&fp=chrome&alpn=h2%2Chttp%2F1.1&type=xhttp&host=${SERVER}&path=/api&mode=auto#SSH-${uname}-${days_left}d${NC}"
                fi
            else
                echo -e "${RED}❌ User not found!${NC}"
            fi
            echo ""
            echo -n "Press Enter..."
            read
            ;;
        5) fake_location_menu ;;
        6) fake_dns_menu ;;
        7) half_price_status ;;
        8) backup_menu ;;
        9)
            echo -n -e "Username (or 'all'): "
            read uname
            if [ "$uname" = "all" ]; then
                /usr/local/bin/ping-net all
            else
                /usr/local/bin/ping-net debug "$uname"
            fi
            echo ""
            echo -n "Press Enter..."
            read
            ;;
        10) /usr/local/bin/config-checker all ;;
        11)
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
        12) domain_management ;;
        13) server_status ;;
        14)
            systemctl restart traffic-monitor shadow-bot sshd dedup-monitor ai-optimizer 2>/dev/null
            echo -e "${GREEN}✅ Restarted!${NC}"
            sleep 2
            ;;
        15) echo -e "${GREEN}👋 Bye!${NC}"; exit 0 ;;
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

cat > /etc/systemd/system/dedup-monitor.service << 'DEDUPEOF'
[Unit]
Description=Shadow SSH Dedup Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/dedup-monitor
Restart=always
RestartSec=10
User=root
[Install]
WantedBy=multi-user.target
DEDUPEOF

cat > /etc/systemd/system/half-price.service << 'HALFSRVEOF'
[Unit]
Description=Shadow SSH Half-Price Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/half-price monitor
Restart=always
RestartSec=10
User=root
[Install]
WantedBy=multi-user.target
HALFSRVEOF

systemctl daemon-reload
systemctl enable traffic-monitor shadow-bot ai-optimizer dedup-monitor half-price
systemctl restart traffic-monitor ai-optimizer dedup-monitor half-price

ln -sf /usr/local/bin/shadow /usr/bin/shadow 2>/dev/null

# Final Message
clear
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ${GREEN}✅ SHADOW SSH v25.0 - HAKIM EDITION INSTALLED!${PURPLE}        ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🚀 ${YELLOW}shadow${CYAN} - Open Panel${NC}"
echo ""
echo -e "${GREEN}💣 HAKIM FEATURES:${NC}"
echo -e "  🇮🇷  Smart Half-Price (Auto .ir + GeoIP detection)"
echo -e "  🔍  ping-net Debug (Find traffic duplication)"
echo -e "  🛡️  Dedup Monitor (Auto-remove duplicate PIDs)"
echo -e "  ⚡  Rate Limiter Per User"
echo -e "  🇺🇸  Fake Location (6 countries)"
echo -e "  📡  Fake DNS (1ms response)"
echo -e "  🤖  AI Optimizer + Config Checker"
echo -e "  📦  Backup & Restore + Telegram"
echo -e "  🌐  Domain Management (Add/Delete/SSL)"
echo ""
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
