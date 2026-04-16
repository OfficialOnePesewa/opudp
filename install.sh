#!/bin/bash
# OFFICIAL ONEPESEWA UDP Installer – Debian/Ubuntu with Device Binding Guard
set -e

G='\e[1;32m' R='\e[1;31m' Y='\e[1;33m' C='\e[1;36m' NC='\e[0m'
[ "$EUID" -ne 0 ] && echo -e "${R}Run as root.${NC}" && exit 1

echo -e "${Y}[+] Updating & installing curl/wget...${NC}"
apt-get update -qq
apt-get install -y -qq curl wget tcpdump

OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
echo -e "${G}[+] OS: $OS${NC}"

# Geo IP
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
LOC="$CITY, $COUNTRY"

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
echo "  Location : $LOC"
echo "  IP       : $IP"
echo "  ISP      : $ISP"
echo "  Admin    : @OfficialOnePesewa"
echo "---------------------------------------------------"

# Dependencies
echo -e "${Y}[1/6] Installing dependencies...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq iptables-persistent netfilter-persistent openssl vnstat bc

# Architecture
echo -e "${Y}[2/6] Detecting architecture...${NC}"
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) BIN="amd64" ;;
    aarch64|arm64) BIN="arm64" ;;
    *) echo -e "${R}Unsupported: $ARCH${NC}"; exit 1 ;;
esac
echo -e "${G}   Architecture: $ARCH -> $BIN${NC}"

# Stop old services & remove binary
echo -e "${Y}[*] Stopping old ZIVPN & guard...${NC}"
systemctl stop zivpn 2>/dev/null || true
systemctl stop onepesewa-guard 2>/dev/null || true
rm -f /usr/local/bin/zivpn

# Download ZIVPN binary
echo -e "${Y}[3/6] Downloading ZIVPN binary...${NC}"
wget -q --show-progress -O /usr/local/bin/zivpn \
    "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-$BIN" || {
    echo -e "${R}Failed to download binary.${NC}"; exit 1
}
chmod +x /usr/local/bin/zivpn

# Config & DB
echo -e "${Y}[4/6] Setting up config...${NC}"
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
touch /etc/zivpn/users.db

# SSL cert
echo -e "${Y}[5/6] Generating SSL certificate...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=GH/ST=Accra/L=Accra/O=OnePesewa/CN=onepesewa" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

# Firewall & NAT
echo -e "${Y}[6/6] Configuring firewall...${NC}"
command -v ufw &>/dev/null && ufw disable &>/dev/null
iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 6000:19999 -j ACCEPT 2>/dev/null || true
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true
netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

# Systemd service for ZIVPN
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

# Install panel
echo -e "${Y}[+] Installing onepesewa panel...${NC}"
wget -qO /usr/local/bin/onepesewa \
    https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/onepesewa || {
    echo -e "${R}Failed to download panel.${NC}"; exit 1
}
chmod +x /usr/local/bin/onepesewa

# Install Device Binding Guard
echo -e "${Y}[+] Installing Device Binding Guard...${NC}"
wget -qO /usr/local/bin/onepesewa-guard \
    https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/onepesewa-guard || {
    echo -e "${R}Failed to download guard.${NC}"; exit 1
}
chmod +x /usr/local/bin/onepesewa-guard

# Guard service
cat <<EOF > /etc/systemd/system/onepesewa-guard.service
[Unit]
Description=ONEPESEWA Device Binding Guard
After=zivpn.service
Requires=zivpn.service

[Service]
ExecStart=/usr/local/bin/onepesewa-guard
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn
systemctl enable onepesewa-guard
systemctl start onepesewa-guard

# Final summary
echo -e "\n${C}====================================================${NC}"
echo -e "${G}         INSTALLATION COMPLETE!${NC}"
echo -e "${C}====================================================${NC}"
echo -e "${G} Server IP  :${NC} $IP"
echo -e "${G} Location   :${NC} $LOC"
echo -e "${G} ISP        :${NC} $ISP"
echo -e "${G} ZIVPN Port :${NC} 5667 (UDP)"
echo -e "${G} NAT Range  :${NC} 6000 - 19999"
echo -e "${G} Device Binding Guard :${NC} ACTIVE (blocks mismatched Device IDs)"
echo -e "${C}====================================================${NC}"
echo -e "${Y} Type 'onepesewa' to open the panel.${NC}"
echo -e "${C}====================================================${NC}"
