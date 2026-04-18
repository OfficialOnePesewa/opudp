#!/bin/bash
# OFFICIAL ONEPESEWA UDP Installer – Debian/Ubuntu with VoIP Support
set -e

G='\e[1;32m' R='\e[1;31m' Y='\e[1;33m' C='\e[1;36m' NC='\e[0m'
[ "$EUID" -ne 0 ] && echo -e "${R}Run as root.${NC}" && exit 1

echo -e "${Y}[+] Updating & installing curl/wget...${NC}"
apt-get update -qq
apt-get install -y -qq curl wget

OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
echo -e "${G}[+] OS: $OS${NC}"

# Geo IP (ipdata.co) with your API key
echo -e "${Y}[+] Fetching server info...${NC}"
IPDATA_API_KEY="f137ae4e341fc34e13dbdd7d24c3d483b4b4818a0c766749bf3b2608"
GEO=$(curl -4 -s --max-time 8 "https://api.ipdata.co/?api-key=${IPDATA_API_KEY}" 2>/dev/null)
if [ -z "$GEO" ] || ! echo "$GEO" | grep -q '"ip"'; then
    IP="N/A"; CITY="Unknown"; COUNTRY="Unknown"; ISP="Unknown"
else
    IP=$(echo "$GEO" | grep -oP '"ip":\s*"\K[^"]+')
    CITY=$(echo "$GEO" | grep -oP '"city":\s*"\K[^"]+')
    COUNTRY=$(echo "$GEO" | grep -oP '"country_name":\s*"\K[^"]+')
    ISP=$(echo "$GEO" | grep -oP '"organisation":\s*"\K[^"]+')
    [ -z "$IP" ] && IP="N/A"
    [ -z "$CITY" ] && CITY="Unknown"
    [ -z "$COUNTRY" ] && COUNTRY="Unknown"
    [ -z "$ISP" ] && ISP="Unknown"
fi
LOC="$CITY, $COUNTRY"

clear
echo -e "${G}=======================================${NC}"
echo -e "${G}      ONEPESEWA UDP INSTALLER${NC}"
echo -e "${G}=======================================${NC}"
echo -e "  OS       : $OS"
echo -e "  Location : $LOC"
echo -e "  IP       : $IP"
echo -e "  ISP      : $ISP"
echo -e "  Admin    : @OfficialOnePesewa"
echo -e "${G}=======================================${NC}"

echo -e "${Y}[1/6] Installing dependencies...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq iptables-persistent netfilter-persistent openssl vnstat bc

echo -e "${Y}[2/6] Detecting architecture...${NC}"
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) BIN="amd64" ;;
    aarch64|arm64) BIN="arm64" ;;
    *) echo -e "${R}Unsupported: $ARCH${NC}"; exit 1 ;;
esac
echo -e "${G}   Architecture: $ARCH -> $BIN${NC}"

echo -e "${Y}[*] Stopping old ZIVPN service & removing binary...${NC}"
systemctl stop zivpn 2>/dev/null || true
rm -f /usr/local/bin/zivpn

echo -e "${Y}[3/6] Downloading ZIVPN binary...${NC}"
wget -q --show-progress -O /usr/local/bin/zivpn \
    "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-$BIN" || {
    echo -e "${R}Failed to download binary.${NC}"; exit 1
}
chmod +x /usr/local/bin/zivpn

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

echo -e "${Y}[5/6] Generating SSL certificate...${NC}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=GH/ST=Accra/L=Accra/O=OnePesewa/CN=onepesewa" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

echo -e "${Y}[6/6] Configuring firewall (VoIP ready)...${NC}"
command -v ufw &>/dev/null && ufw disable &>/dev/null
iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 5060 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 6000:19999 -j ACCEPT 2>/dev/null || true
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true
netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

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

systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

echo -e "${Y}[+] Installing onepesewa panel...${NC}"
wget -qO /usr/local/bin/onepesewa \
    https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/onepesewa || {
    echo -e "${R}Failed to download panel.${NC}"; exit 1
}
chmod +x /usr/local/bin/onepesewa

echo -e "\n${C}====================================================${NC}"
echo -e "${G}         INSTALLATION COMPLETE!${NC}"
echo -e "${C}====================================================${NC}"
echo -e "${G} Server IP  :${NC} $IP"
echo -e "${G} Location   :${NC} $LOC"
echo -e "${G} ISP        :${NC} $ISP"
echo -e "${G} ZIVPN Port :${NC} 5667 (UDP)"
echo -e "${G} NAT Range  :${NC} 6000 - 19999 (inc. VoIP RTP)"
echo -e "${G} VoIP SIP   :${NC} 5060 (UDP)"
echo -e "${C}====================================================${NC}"
echo -e "${Y} Type 'onepesewa' to open the panel.${NC}"
echo -e "${C}====================================================${NC}"
