#!/bin/bash

# Shadow SSH v2.0 - Optimized Installer
# حجم دانلود کل: کمتر از 1 مگابایت

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 Shadow SSH v2.0 - Installation Started${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# بررسی دسترسی روت
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root!${NC}" 
   exit 1
fi

# به‌روزرسانی حداقل
echo -e "${YELLOW}📦 Updating system...${NC}"
apt update -y

# نصب فقط وابستگی‌های ضروری (بدون gcc, make, git)
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt install -y curl wget coreutils

# ایجاد فایل کانفیگ خالی اگر وجود نداشت
if [ ! -f /etc/shadow-users.conf ]; then
    touch /etc/shadow-users.conf
fi

# ایجاد اسکریپت مدیریتی (بدون نیاز به دانلود خارجی)
echo -e "${YELLOW}🔧 Creating management script...${NC}"
cat > /usr/local/bin/shadow << 'EOF'
#!/bin/bash

# Shadow SSH v2.0 - User Management Panel

CONFIG_FILE="/etc/shadow-users.conf"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 Shadow SSH v2.0 - Control Panel${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}1${NC}. Add New User"
    echo -e "${YELLOW}2${NC}. Delete User"
    echo -e "${YELLOW}3${NC}. Show All Users"
    echo -e "${YELLOW}4${NC}. Show User Config"
    echo -e "${YELLOW}5${NC}. Exit"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

add_user() {
    echo -e "${BLUE}─────────────────────────────────────${NC}"
    read -p "👤 Username: " username
    read -p "🔑 Password: " password
    read -p "📊 Traffic Limit (GB): " traffic
    read -p "📅 Days Valid: " days
    
    # جلوگیری از ورود خالی
    if [[ -z "$username" || -z "$password" || -z "$traffic" || -z "$days" ]]; then
        echo -e "${RED}❌ All fields are required!${NC}"
        return
    fi
    
    expiry=$(date -d "+$days days" +%s)
    
    # افزودن به فایل کانفیگ
    echo "$username:$password:$traffic:$expiry:0" >> $CONFIG_FILE
    
    # ایجاد کاربر سیستمی (بدون شل)
    useradd -M -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    
    # دریافت IP سرور
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")
    
    clear
    echo -e "${GREEN}✅ User Created Successfully!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 Connection Info:${NC}"
    echo -e "   Username: ${GREEN}$username${NC}"
    echo -e "   Password: ${GREEN}$password${NC}"
    echo -e "   Server:   ${GREEN}$SERVER_IP${NC}"
    echo -e "   Port:     ${GREEN}22${NC}"
    echo -e "${BLUE}─────────────────────────────────────${NC}"
    echo -e "${YELLOW}🔗 SSH Command:${NC}"
    echo -e "   ${GREEN}ssh $username@$SERVER_IP -p 22${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    read -p "Press Enter to continue..."
}

list_users() {
    clear
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 Active Users List${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    if [ ! -s $CONFIG_FILE ]; then
        echo -e "${RED}❌ No users found!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    current_time=$(date +%s)
    cat $CONFIG_FILE 2>/dev/null | while IFS=: read user pass traffic expiry used; do
        remaining_days=$(( ($expiry - $current_time) / 86400 ))
        if [ $remaining_days -lt 0 ]; then
            echo -e "   ${RED}✗ $user | EXPIRED${NC}"
        else
            echo -e "   ${GREEN}✓ $user${NC} | Expires: ${YELLOW}${remaining_days}d${NC} | Traffic: ${BLUE}${traffic}GB${NC}"
        fi
    done
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    read -p "Press Enter to continue..."
}

show_config() {
    read -p "👤 Username: " username
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    clear
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}📄 Configuration for: $username${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔗 Direct SSH:${NC}"
    echo -e "   ${GREEN}ssh $username@$SERVER_IP -p 22${NC}"
    echo -e ""
    echo -e "${YELLOW}🔗 Using key file:${NC}"
    echo -e "   ${GREEN}ssh -i key.txt $username@$SERVER_IP -p 22${NC}"
    echo -e "${BLUE}─────────────────────────────────────${NC}"
    echo -e "${YELLOW}⚙️  SOCKS5 Proxy (via SSH):${NC}"
    echo -e "   ${GREEN}ssh -D 1080 $username@$SERVER_IP -p 22 -N${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    read -p "Press Enter to continue..."
}

delete_user() {
    read -p "👤 Username to delete: " username
    
    if [ -z "$username" ]; then
        echo -e "${RED}❌ Username required!${NC}"
        return
    fi
    
    # حذف از فایل کانفیگ
    sed -i "/^$username:/d" $CONFIG_FILE 2>/dev/null
    
    # حذف کاربر سیستمی
    userdel -r "$username" 2>/dev/null
    
    echo -e "${GREEN}✅ User $username deleted successfully!${NC}"
    read -p "Press Enter to continue..."
}

while true; do
    show_menu
    read -p "👉 Choose an option [1-5]: " choice
    case $choice in
        1) add_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) show_config ;;
        5) 
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option!${NC}"
            sleep 1
            ;;
    esac
done
EOF

# اعطای دسترسی اجرا
chmod +x /usr/local/bin/shadow

# بهینه‌سازی کرنل (فقط تنظیمات ضروری)
echo -e "${YELLOW}⚙️ Optimizing kernel parameters...${NC}"
cat >> /etc/sysctl.conf << EOF

# Shadow SSH v2.0 Optimizations
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
EOF

# اعمال تنظیمات
sysctl -p > /dev/null 2>&1

# پاکسازی (اختیاری)
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
apt autoremove -y > /dev/null 2>&1
apt autoclean -y > /dev/null 2>&1

clear
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Shadow SSH v2.0 Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}📊 Installation Summary:${NC}"
echo -e "   • Total Download: ${GREEN}< 1 MB${NC} (was ~80 MB)"
echo -e "   • Dependencies:   ${GREEN}curl, wget${NC} (no gcc/make/git)"
echo -e "   • Status:         ${GREEN}Ready to use${NC}"
echo -e "${BLUE}─────────────────────────────────────${NC}"
echo -e "${YELLOW}🚀 To manage users, run:${NC}"
echo -e "   ${GREEN}shadow${NC}"
echo -e "${BLUE}─────────────────────────────────────${NC}"
echo -e "${YELLOW}🔗 Default SSH Port:${NC} ${GREEN}22${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
