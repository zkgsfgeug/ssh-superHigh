#!/bin/bash

# =============================================
# Shadow SSH v13.0 - FINAL WORKING (NO IPTABLES)
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Must be root!${NC}" 
   exit 1
fi

# پاکسازی کامل
echo -e "${YELLOW}🧹 Cleaning...${NC}"
systemctl stop traffic-monitor 2>/dev/null
systemctl disable traffic-monitor 2>/dev/null
pkill -9 -f "traffic-monitor" 2>/dev/null
pkill -9 -f "shadow" 2>/dev/null

# حذف کاربران قبلی
if [ -f /etc/shadow-users.conf ]; then
    for user in $(cut -d: -f1 /etc/shadow-users.conf 2>/dev/null); do
        # Kill all processes of user first
        pkill -9 -u "$user" 2>/dev/null
        userdel -r "$user" 2>/dev/null
    done
fi

# پاکسازی فایل‌ها
rm -rf /usr/local/bin/shadow /usr/local/bin/traffic-monitor /etc/shadow-* /var/lib/shadow /etc/systemd/system/traffic-monitor.service 2>/dev/null

# نصب پیش‌نیازها
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -qq
apt install -y -qq curl wget openssh-server sqlite3 bc lsof procps 2>/dev/null

# تنظیمات SSH
if ! grep -q "^Port 22" /etc/ssh/sshd_config; then
    # Keep default SSH port or set custom
    sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
    sed -i 's/^Port [0-9]*/Port 22/' /etc/ssh/sshd_config
fi

# اطمینان از فعال بودن PasswordAuthentication
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

# دیتابیس
mkdir -p /var/lib/shadow
sqlite3 /var/lib/shadow/traffic.db << 'SQLEOF'
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT,
    total_traffic INTEGER,
    expiry INTEGER,
    created INTEGER,
    status TEXT DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS traffic_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    timestamp INTEGER,
    rx_bytes INTEGER,
    tx_bytes INTEGER,
    total_mb REAL
);
CREATE TABLE IF NOT EXISTS traffic_cache (
    username TEXT PRIMARY KEY,
    last_rx INTEGER DEFAULT 0,
    last_tx INTEGER DEFAULT 0,
    last_check INTEGER DEFAULT 0
);
SQLEOF

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Shadow SSH v13.0 - FINAL${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"

# =============================================
# مانیتورینگ بهینه با /proc (رفع باگ‌ها)
# =============================================
cat > /usr/local/bin/traffic-monitor << 'MONITOREOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
INTERVAL=15
PID_FILE="/var/run/traffic-monitor.pid"

# جلوگیری از اجرای همزمان
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Monitor is already running (PID: $OLD_PID)"
        exit 1
    fi
fi
echo $$ > "$PID_FILE"

# پاکسازی PID فایل در هنگام خروج
trap "rm -f $PID_FILE" EXIT

# تابع محاسبه ترافیک واقعی یک کاربر
get_user_traffic() {
    local user=$1
    local total_rx=0
    local total_tx=0
    
    # دریافت همه PIDهای کاربر
    local pids=$(pgrep -u "$user" 2>/dev/null)
    
    if [ -z "$pids" ]; then
        echo "0 0"
        return
    fi
    
    # روش دقیق: خواندن /proc/[pid]/net/dev برای هر پروسه
    for pid in $pids; do
        if [ -f "/proc/$pid/net/dev" ]; then
            # استخراج rx_bytes و tx_bytes از اینترفیس‌های شبکه
            local proc_data=$(cat "/proc/$pid/net/dev" 2>/dev/null | tail -n +3)
            if [ -n "$proc_data" ]; then
                local rx=$(echo "$proc_data" | awk '{sum += $2} END {print sum+0}')
                local tx=$(echo "$proc_data" | awk '{sum += $10} END {print sum+0}')
                total_rx=$((total_rx + rx))
                total_tx=$((total_tx + tx))
            fi
        fi
    done
    
    echo "$total_rx $total_tx"
}

# تابع بروزرسانی مصرف کاربر
update_user_usage() {
    local username=$1
    local current_time=$(date +%s)
    
    # دریافت ترافیک فعلی
    read -r rx_bytes tx_bytes <<< $(get_user_traffic "$username")
    local total_bytes=$((rx_bytes + tx_bytes))
    local total_mb=$(echo "scale=4; $total_bytes / 1048576" | bc)
    
    # دریافت آخرین مقادیر از کش
    local cache_data=$(sqlite3 "$DB" "SELECT last_rx, last_tx, last_check FROM traffic_cache WHERE username='$username';")
    
    if [ -n "$cache_data" ]; then
        local last_rx=$(echo "$cache_data" | cut -d'|' -f1)
        local last_tx=$(echo "$cache_data" | cut -d'|' -f2)
        local last_check=$(echo "$cache_data" | cut -d'|' -f3)
        
        # محاسبه ترافیک جدید (تفاضل)
        local new_rx=$((rx_bytes - last_rx))
        local new_tx=$((tx_bytes - last_tx))
        
        # اگر مقادیر منفی شدن (احتمال restart پروسه)، از صفر استفاده کن
        if [ "$new_rx" -lt 0 ]; then new_rx=0; fi
        if [ "$new_tx" -lt 0 ]; then new_tx=0; fi
        
        local new_total=$((new_rx + new_tx))
        local new_total_mb=$(echo "scale=4; $new_total / 1048576" | bc)
        
        # فقط اگر ترافیک جدید مثبت بود، لاگ کن
        if [ "$new_total" -gt 0 ]; then
            # ثبت در لاگ
            sqlite3 "$DB" "INSERT INTO traffic_log (username, timestamp, rx_bytes, tx_bytes, total_mb) VALUES ('$username', $current_time, $new_rx, $new_tx, $new_total_mb);"
            
            # بروزرسانی مصرف کل
            sqlite3 "$DB" "UPDATE users SET total_traffic = total_traffic + $new_total WHERE username='$username';"
        fi
    fi
    
    # بروزرسانی کش
    sqlite3 "$DB" "INSERT OR REPLACE INTO traffic_cache (username, last_rx, last_tx, last_check) VALUES ('$username', $rx_bytes, $tx_bytes, $current_time);"
}

# حلقه اصلی مانیتورینگ
echo "🔄 Traffic Monitor Started (PID: $$)"
echo "📊 Checking every ${INTERVAL}s"

while true; do
    # دریافت لیست کاربران فعال
    active_users=$(sqlite3 "$DB" "SELECT username FROM users WHERE status='active';")
    
    if [ -n "$active_users" ]; then
        while IFS= read -r user; do
            # چک کردن وضعیت اکانت
            expiry=$(sqlite3 "$DB" "SELECT expiry FROM users WHERE username='$user';")
            current_time=$(date +%s)
            
            if [ "$expiry" -lt "$current_time" ] && [ "$expiry" != "0" ]; then
                # غیرفعال کردن اکانت منقضی شده
                sqlite3 "$DB" "UPDATE users SET status='expired' WHERE username='$user';"
                pkill -9 -u "$user" 2>/dev/null
                continue
            fi
            
            # بروزرسانی مصرف
            update_user_usage "$user"
        done <<< "$active_users"
    fi
    
    sleep "$INTERVAL"
done
MONITOREOF

chmod +x /usr/local/bin/traffic-monitor

# =============================================
# سرویس systemd برای مانیتور
# =============================================
cat > /etc/systemd/system/traffic-monitor.service << SERVICEEOF
[Unit]
Description=Shadow SSH Traffic Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-monitor
Restart=always
RestartSec=5
User=root
PIDFile=/var/run/traffic-monitor.pid

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable traffic-monitor
systemctl start traffic-monitor

# =============================================
# اسکریپت اصلی shadow
# =============================================
cat > /usr/local/bin/shadow << 'MAINEOF'
#!/bin/bash

DB="/var/lib/shadow/traffic.db"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# تابع نمایش منو
show_menu() {
    clear
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        Shadow SSH Manager v13.0${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}1.${NC} Create User"
    echo -e "${BLUE}2.${NC} Delete User"
    echo -e "${BLUE}3.${NC} List Users"
    echo -e "${BLUE}4.${NC} Show User Traffic"
    echo -e "${BLUE}5.${NC} Monitor Status"
    echo -e "${BLUE}6.${NC} Exit"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
}

# تابع ساخت کاربر
create_user() {
    echo -e "${YELLOW}📝 Create New User${NC}"
    read -p "Username: " username
    
    # چک وجود کاربر
    if id "$username" &>/dev/null || grep -q "^$username:" /etc/shadow-users.conf 2>/dev/null; then
        echo -e "${RED}❌ User already exists!${NC}"
        return
    fi
    
    read -p "Password: " password
    read -p "Traffic Limit (GB, 0=unlimited): " traffic_gb
    read -p "Days Valid (0=unlimited): " days
    
    # تبدیل GB به Byte
    if [ "$traffic_gb" -eq 0 ]; then
        traffic_bytes=0
    else
        traffic_bytes=$((traffic_gb * 1073741824))
    fi
    
    # محاسبه تاریخ انقضا
    if [ "$days" -eq 0 ]; then
        expiry=0
    else
        expiry=$(date -d "+${days} days" +%s)
    fi
    
    # ساخت کاربر سیستم
    useradd -m -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    # ذخیره در کانفیگ
    echo "$username" >> /etc/shadow-users.conf
    
    # ذخیره در دیتابیس
    sqlite3 "$DB" "INSERT INTO users (username, password, total_traffic, expiry, created) VALUES ('$username', '$password', 0, $expiry, $(date +%s));"
    
    echo -e "${GREEN}✅ User $username created successfully!${NC}"
    sleep 2
}

# تابع حذف کاربر
delete_user() {
    echo -e "${RED}🗑️  Delete User${NC}"
    read -p "Username to delete: " username
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}❌ User doesn't exist!${NC}"
        return
    fi
    
    # Kill processes
    pkill -9 -u "$username" 2>/dev/null
    
    # حذف کاربر
    userdel -r "$username" 2>/dev/null
    
    # حذف از کانفیگ
    sed -i "/^$username$/d" /etc/shadow-users.conf 2>/dev/null
    
    # بروزرسانی دیتابیس
    sqlite3 "$DB" "DELETE FROM users WHERE username='$username';"
    sqlite3 "$DB" "DELETE FROM traffic_cache WHERE username='$username';"
    
    echo -e "${GREEN}✅ User $username deleted!${NC}"
    sleep 2
}

# تابع نمایش کاربران
list_users() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}               Active Users${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    printf "${BLUE}%-15s %-10s %-15s %-15s %-10s${NC}\n" "Username" "Status" "Used (MB)" "Limit (GB)" "Expiry"
    echo "─────────────────────────────────────────────────────"
    
    while IFS='|' read -r username password traffic expiry created status; do
        if [ -n "$username" ]; then
            # محاسبه مصرف
            traffic_mb=$(echo "scale=2; $traffic / 1048576" | bc)
            
            # وضعیت انقضا
            if [ "$expiry" -eq 0 ]; then
                expiry_text="Unlimited"
            elif [ "$expiry" -lt "$(date +%s)" ]; then
                expiry_text="${RED}Expired${NC}"
            else
                days_left=$(( (expiry - $(date +%s)) / 86400 ))
                expiry_text="${days_left}d left"
            fi
            
            # لیمیت ترافیک
            sqlite3 "$DB" "SELECT total_traffic FROM users WHERE username='$username';" | while read limit; do
                if [ "$limit" -eq 0 ]; then
                    limit_text="Unlimited"
                else
                    limit_gb=$(echo "scale=2; $limit / 1073741824" | bc)
                    limit_text="$limit_gb GB"
                fi
            done
            
            printf "%-15s %-10s %-15s %-15s %-10s\n" "$username" "$status" "${traffic_mb}MB" "$limit_text" "$expiry_text"
        fi
    done < <(sqlite3 "$DB" "SELECT * FROM users;")
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Press Enter to continue..."
}

# تابع نمایش ترافیک کاربر خاص
show_user_traffic() {
    read -p "Username: " username
    
    echo -e "${YELLOW}📊 Traffic Log for $username${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    sqlite3 "$DB" "SELECT datetime(timestamp, 'unixepoch', 'localtime'), total_mb FROM traffic_log WHERE username='$username' ORDER BY timestamp DESC LIMIT 20;"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Press Enter to continue..."
}

# تابع وضعیت مانیتور
monitor_status() {
    echo -e "${YELLOW}🔍 Monitor Status${NC}"
    
    if systemctl is-active --quiet traffic-monitor; then
        echo -e "${GREEN}✅ Traffic Monitor is Running${NC}"
        echo -e "${BLUE}PID: $(cat /var/run/traffic-monitor.pid 2>/dev/null || echo 'N/A')${NC}"
    else
        echo -e "${RED}❌ Traffic Monitor is Stopped${NC}"
    fi
    
    echo -e "\n${YELLOW}Recent Logs:${NC}"
    journalctl -u traffic-monitor --no-pager -n 5 2>/dev/null || echo "No logs available"
    
    read -p "Press Enter to continue..."
}

# منوی اصلی
while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) show_user_traffic ;;
        5) monitor_status ;;
        6) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
    esac
done
MAINEOF

chmod +x /usr/local/bin/shadow

# ایجاد لینک سمبولیک برای دسترسی آسان
ln -sf /usr/local/bin/shadow /usr/local/bin/shadow-manager 2>/dev/null

# راه‌اندازی مانیتور
echo -e "${YELLOW}🔄 Starting traffic monitor...${NC}"
systemctl restart traffic-monitor
sleep 2

if systemctl is-active --quiet traffic-monitor; then
    echo -e "${GREEN}✅ Traffic monitor is running!${NC}"
else
    echo -e "${RED}❌ Failed to start traffic monitor${NC}"
    echo -e "${YELLOW}Check logs: journalctl -u traffic-monitor${NC}"
fi

echo -e "\n${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Installation Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${CYAN}Commands:${NC}"
echo -e "  ${YELLOW}shadow${NC} - Open management menu"
echo -e "  ${YELLOW}systemctl status traffic-monitor${NC} - Check monitor"
echo -e "  ${YELLOW}journalctl -u traffic-monitor -f${NC} - View logs"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
