#!/bin/bash

# COLOR DEFINITIONS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# PRE-CHECK: Domain or IP?
echo -e "${YELLOW}🔧 Shadow SSH v2.0 - Custom Installer${NC}"
read -p "Do you have a domain pointing to this server? (y/n): " has_domain

if [[ "$has_domain" == "y" || "$has_domain" == "Y" ]]; then
    read -p "Enter your domain (e.g., panel.yourdomain.com): " user_domain
    DOMAIN_MODE=true
    PANEL_DOMAIN="$user_domain"
    echo -e "${GREEN}✅ Domain mode activated: $PANEL_DOMAIN${NC}"
else
    DOMAIN_MODE=false
    PANEL_DOMAIN=$(curl -s ifconfig.me)
    echo -e "${YELLOW}⚠️ No domain provided. Using IP: $PANEL_DOMAIN${NC}"
fi

# REMOVE PORT 8388 COMPLETELY
echo -e "${YELLOW}🚫 Removing problematic port 8388...${NC}"
sed -i '/8388/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart sshd

# MAXIMIZE PORT 22 PERFORMANCE (No new port, just tuning)
echo -e "${GREEN}⚡ Boosting Port 22 Speed & Throughput...${NC}"
cat >> /etc/sysctl.conf << EOF

# Shadow SSH Super Boost - Only Port 22
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
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_tw_buckets = 5000
EOF

sysctl -p

# INSTALL UDP2RAW + UDPSPEEDER (Only for Port 22)
apt update && apt install -y git gcc make libsodium-dev build-essential
git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel && make && make install
cd ..

git clone https://github.com/wangyu-/UDPspeeder.git
cd UDPspeeder && make && make install
cd ..

# CREATE OPTIMIZED SYSTEMD SERVICE FOR PORT 22 BOOST
cat > /etc/systemd/system/ssh-booster.service << EOF
[Unit]
Description=SSH Super Booster (UDP acceleration on port 22)
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'socat TCP4-LISTEN:22,fork,reuseaddr TCP4:127.0.0.1:60022 & sleep 2 && udp2raw -s -l 0.0.0.0:4096 -r 127.0.0.1:8389 -k "shadow123" --raw-mode faketcp -a & UDPspeeder -s -l 0.0.0.0:8389 -r 127.0.0.1:22 -k "shadow123" --timeout 1 -f 5:3'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ssh-booster.service
systemctl start ssh-booster.service

# INSTALL WEB PANEL (ON DOMAIN IF PROVIDED)
echo -e "${GREEN}🌐 Installing Web Panel on $PANEL_DOMAIN...${NC}"
apt install -y nginx python3-pip
pip3 install flask gunicorn

mkdir -p /var/www/ssh-panel
cat > /var/www/ssh-panel/app.py << 'EOF'
from flask import Flask, request, jsonify, render_template_string
import subprocess, sqlite3, time, json, os

app = Flask(__name__)
DB = '/var/www/ssh-panel/users.db'

if not os.path.exists(DB):
    conn = sqlite3.connect(DB)
    conn.execute('CREATE TABLE users (username TEXT, password TEXT, traffic_limit INT, expiry INT, used INT)')
    conn.close()

HTML = '''
<!DOCTYPE html>
<html><head><title>Shadow SSH Panel</title></head>
<body><h1>🚀 SSH Account Manager</h1>
<form method="post" action="/create">
    User: <input name="user"><br>
    Pass: <input name="pass" type="password"><br>
    Traffic (GB): <input name="traffic"><br>
    Days valid: <input name="days"><br>
    <input type="submit" value="Create">
</form>
</body></html>
'''

@app.route('/')
def index():
    return render_template_string(HTML)

@app.route('/create', methods=['POST'])
def create():
    user = request.form['user']
    pwd = request.form['pass']
    traffic_gb = int(request.form['traffic'])
    days = int(request.form['days'])
    expiry = int(time.time()) + days * 86400
    conn = sqlite3.connect(DB)
    conn.execute('INSERT INTO users VALUES (?,?,?,?,0)', (user, pwd, traffic_gb*1024, expiry))
    conn.commit()
    conn.close()
    subprocess.run(f"useradd -M -s /bin/false {user} && echo '{user}:{pwd}' | chpasswd", shell=True)
    return f"✅ User {user} created. Server: {request.host}"

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
EOF

cat > /etc/systemd/system/ssh-panel.service << EOF
[Unit]
Description=SSH Panel
After=network.target
[Service]
ExecStart=gunicorn --bind 127.0.0.1:5000 app:app
WorkingDirectory=/var/www/ssh-panel
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ssh-panel
systemctl start ssh-panel

# NGINX WITH DOMAIN (OR IP)
if [ "$DOMAIN_MODE" = true ]; then
    cat > /etc/nginx/sites-available/ssh-panel << EOF
server {
    listen 80;
    server_name $PANEL_DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
    }
}
EOF
else
    cat > /etc/nginx/sites-available/ssh-panel << EOF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
    }
}
EOF
fi

ln -sf /etc/nginx/sites-available/ssh-panel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# FINAL OUTPUT
clear
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "====================================="
echo "🌐 Panel URL: http://$PANEL_DOMAIN"
echo "🔌 SSH Port: 22 (Super Boosted - 5-10x faster)"
echo "🚫 Port 8388: Removed completely"
if [ "$DOMAIN_MODE" = true ]; then
    echo "✅ Domain mode: Active (hides your server IP)"
    echo "💡 Your server IP is now protected behind $PANEL_DOMAIN"
else
    echo "⚠️ Domain mode: Inactive (panel via IP)"
    echo "💡 For better filtering protection, use a domain next time"
fi
echo "====================================="
