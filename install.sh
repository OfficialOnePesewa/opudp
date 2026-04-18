#!/bin/bash
# OFFICIAL ONEPESEWA DUAL PROTOCOL INSTALLER – Builds UDP Custom from Source
# Works on Debian 10/11/12 & Ubuntu 20.04/22.04/24.04
# One-liner: bash <(curl -fsSL https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/install.sh)

set -e

G='\e[1;32m' R='\e[1;31m' Y='\e[1;33m' C='\e[1;36m' NC='\e[0m'
[ "$EUID" -ne 0 ] && echo -e "${R}Run as root.${NC}" && exit 1

echo -e "${Y}[+] Updating system & installing dependencies...${NC}"
apt-get update -qq
apt-get install -y -qq curl wget jq iptables-persistent netfilter-persistent openssl vnstat bc python3 python3-pip git unzip golang-go

OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
echo -e "${G}[+] OS: $OS${NC}"

GEO=$(curl -4 -s --max-time 8 https://ipapi.co/json/ 2>/dev/null)
if [ -z "$GEO" ] || ! echo "$GEO" | grep -q '"ip"'; then
    IP="N/A"; CITY="Unknown"; COUNTRY="Unknown"; ISP="Unknown"
else
    IP=$(echo "$GEO" | grep -oP '"ip":\s*"\K[^"]+')
    CITY=$(echo "$GEO" | grep -oP '"city":\s*"\K[^"]+')
    COUNTRY=$(echo "$GEO" | grep -oP '"country_name":\s*"\K[^"]+')
    ISP=$(echo "$GEO" | grep -oP '"org":\s*"\K[^"]+')
    [ -z "$IP" ] && IP="N/A"
    [ -z "$CITY" ] && CITY="Unknown"
    [ -z "$COUNTRY" ] && COUNTRY="Unknown"
    [ -z "$ISP" ] && ISP="Unknown"
fi

clear
echo -e "${G}"
echo "   ___  _   _ ______ _____  ______ ______ _    _ ______          _    _ ______ _____  "
echo "  / _ \| \ | |  ____|  __ \|  ____|  ____| |  | |  ____|   /\   | |  | |  __ \|  __ \ "
echo " | | | |  \| | |__  | |__) | |__  | |__  | |  | | |__     /  \  | |  | | |__) | |__) |"
echo " | | | |     |  __| |  ___/|  __| |  __| | |  | |  __|   / /\ \ | |  | |  ___/|  ___/ "
echo " | |_| | |\  | |____| |    | |____| |____| |__| | |____ / ____ \| |__| | |    | |     "
echo "  \___/|_| \_|______|_|    |______|______|\____/|______/_/    \_\\____/|_|    |_|     "
echo -e "${NC}"
echo "---------------------------------------------------"
echo "  OS       : $OS"
echo "  Location : $CITY, $COUNTRY"
echo "  IP       : $IP"
echo "  ISP      : $ISP"
echo "  Admin    : @OfficialOnePesewa"
echo "---------------------------------------------------"

systemctl stop zivpn 2>/dev/null || true
systemctl stop udp-custom 2>/dev/null || true

# ------------------ Install ZIVPN ------------------
echo -e "${Y}[1/6] Installing ZIVPN...${NC}"
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) BIN="amd64" ;;
    aarch64|arm64) BIN="arm64" ;;
    *) echo -e "${R}Unsupported: $ARCH${NC}"; exit 1 ;;
esac

rm -f /usr/local/bin/zivpn
wget -q --show-progress -O /usr/local/bin/zivpn \
    "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-$BIN"
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn
cat <<EOF > /etc/zivpn/config.json
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "onepesewa",
  "auth": {
    "mode": "passwords",
    "config": []
  }
}
EOF
touch /etc/zivpn/users.db /etc/zivpn/usage.db /etc/zivpn/telegram.db /etc/zivpn/admins.db /etc/zivpn/last_sent.db

openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=GH/ST=Accra/L=Accra/O=OnePesewa/CN=onepesewa" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ------------------ Build UDP Custom from Source ------------------
echo -e "${Y}[2/6] Building UDP Custom from source...${NC}"
mkdir -p /root/udp
cd /root

# Clone the repository
rm -rf udp-custom-build
git clone https://github.com/http-custom/udp-custom udp-custom-build
cd udp-custom-build

# Build the binary (the repository contains a Makefile or build script)
if [ -f "Makefile" ]; then
    make
    cp udp-custom /root/udp/
elif [ -f "build.sh" ]; then
    chmod +x build.sh && ./build.sh
    cp udp-custom /root/udp/
else
    # Fallback: build the main Go file directly
    go build -o udp-custom main.go || go build -o udp-custom .
    cp udp-custom /root/udp/
fi

cd /root
chmod +x /root/udp/udp-custom
rm -rf udp-custom-build

# Generate random port between 50000 and 55000
UDPC_PORT=$((50000 + RANDOM % 5000))
echo -e "${G}[*] UDP Custom port: $UDPC_PORT${NC}"

cat <<EOF > /root/udp/config.json
{
  "listen": ":$UDPC_PORT",
  "gateway": ":7800",
  "cert": "/root/udp/server.crt",
  "key": "/root/udp/server.key"
}
EOF

if [ ! -f /root/udp/server.crt ]; then
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -subj "/C=GH/ST=Accra/L=Accra/O=OnePesewa/CN=udp-custom" \
        -keyout "/root/udp/server.key" -out "/root/udp/server.crt" 2>/dev/null
fi

[ ! -f /root/udp/users.json ] && echo '{}' > /root/udp/users.json

cat <<EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/udp
ExecStart=/root/udp/udp-custom server --config /root/udp/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "$UDPC_PORT" > /root/udp/udp_port.txt

# ------------------ Firewall ------------------
echo -e "${Y}[3/6] Configuring firewall...${NC}"
iptables -I INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 6000:19999 -j ACCEPT 2>/dev/null || true
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true

iptables -I INPUT -p udp --dport $UDPC_PORT -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 7800 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p tcp --dport 7800 -j ACCEPT 2>/dev/null || true

netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

# ------------------ Install Panel ------------------
echo -e "${Y}[4/6] Installing OP UDP Panel...${NC}"
for i in 1 2 3; do
    wget -qO /usr/local/bin/onepesewa https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/onepesewa && break
    sleep 2
done
chmod +x /usr/local/bin/onepesewa
ln -sf /usr/local/bin/onepesewa /usr/local/bin/udp

# ------------------ Telegram Bot (Optional) ------------------
echo -e "${Y}[5/6] Setting up Telegram bot (optional)...${NC}"
set +e
pip3 install --quiet python-telegram-bot==20.3 2>/dev/null || \
pip3 install --break-system-packages --quiet python-telegram-bot==20.3 2>/dev/null || true
set -e

wget -qO /usr/local/bin/opudp_bot.py https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/opudp_bot.py
chmod +x /usr/local/bin/opudp_bot.py

cat <<EOF > /etc/systemd/system/opudp-bot.service
[Unit]
Description=OP UDP Telegram Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/opudp_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

if python3 -c "import telegram" 2>/dev/null; then
    systemctl enable opudp-bot
    systemctl start opudp-bot 2>/dev/null || true
fi

# ------------------ Start Services ------------------
echo -e "${Y}[6/6] Starting services...${NC}"
systemctl daemon-reload
systemctl enable zivpn udp-custom
systemctl start zivpn
systemctl start udp-custom

sleep 3

echo -e "\n${C}====================================================${NC}"
echo -e "${G}         INSTALLATION COMPLETE!${NC}"
echo -e "${C}====================================================${NC}"
echo -e "${G} Server IP   :${NC} $IP"
echo -e "${G} Location    :${NC} $CITY, $COUNTRY"
echo -e "${G} ISP         :${NC} $ISP"
echo -e "${G} ZIVPN Port  :${NC} 5667 (NAT 6000-19999)"
echo -e "${G} UDP Custom  :${NC} $UDPC_PORT (Gateway 7800)"
echo -e "${C}====================================================${NC}"

if systemctl is-active --quiet zivpn; then
    echo -e "${G}✅ ZIVPN is running${NC}"
else
    echo -e "${R}❌ ZIVPN failed to start.${NC}"
fi

if systemctl is-active --quiet udp-custom; then
    echo -e "${G}✅ UDP Custom is running${NC}"
else
    echo -e "${R}❌ UDP Custom failed to start.${NC}"
fi

echo -e "${C}====================================================${NC}"
echo -e "${Y} Type 'onepesewa' to open the control panel.${NC}"
echo -e "${C}====================================================${NC}"
