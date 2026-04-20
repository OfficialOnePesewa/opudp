#!/bin/bash
# OFFICIAL ONEPESEWA UDP Installer – Debian/Ubuntu with VoIP Support
# Based on the original script by zahidbd2, optimized for OnePesewa.

set -e

# Colors
G='\e[1;32m' R='\e[1;31m' Y='\e[1;33m' C='\e[1;36m' NC='\e[0m'

# Root check
[ "$EUID" -ne 0 ] && echo -e "${R}Run as root.${NC}" && exit 1

# Update system and install dependencies
echo -e "${Y}[+] Updating system and installing curl/wget...${NC}"
apt-get update -qq
apt-get install -y -qq curl wget

# Get OS info
OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
echo -e "${G}[+] OS: $OS${NC}"

# Fetch server info
echo -e "${Y}[+] Fetching server info...${NC}"
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

# Display banner
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

# Install required packages
echo -e "${Y}[1/5] Installing dependencies...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq iptables-persistent netfilter-persistent openssl vnstat bc

# Detect system architecture
echo -e "${Y}[2/5] Detecting architecture...${NC}"
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) BIN="amd64" ;;
    aarch64|arm64) BIN="arm64" ;;
    *) echo -e "${R}Unsupported: $ARCH${NC}"; exit 1 ;;
esac
echo -e "${G}   Architecture: $ARCH -> $BIN${NC}"

# Stop old service and download the new ZIVPN binary
echo -e "${Y}[*] Stopping old ZIVPN service & removing binary...${NC}"
systemctl stop zivpn 2>/dev/null || true
rm -f /usr/local/bin/zivpn

echo -e "${Y}[3/5] Downloading ZIVPN binary...${NC}"
wget -q --show-progress -O /usr/local/bin/zivpn \
    "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-$BIN" || {
    echo -e "${R}Failed to download binary.${NC}"; exit 1
}
chmod +x /usr/local/bin/zivpn

# Create configuration and data directories
echo -e "${Y}[4/5] Setting up config and data...${NC}"
mkdir -p /etc/zivpn
touch /etc/zivpn/users.db
touch /etc/zivpn/usage.db

# Generate SSL certificate
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=GH/ST=Accra/L=Accra/O=OnePesewa/CN=onepesewa" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

# Optimize kernel for UDP traffic
sysctl -w net.core.rmem_max=16777216 1>/dev/null 2>&1
sysctl -w net.core.wmem_max=16777216 1>/dev/null 2>&1

# Configure firewall for VoIP and UDP forwarding
echo -e "${Y}[5/5] Configuring firewall...${NC}"
command -v ufw &>/dev/null && ufw disable &>/dev/null

# Get main network interface
INTERFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

# Allow essential ports
iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 5060 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 7300 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 6000:19999 -j ACCEPT 2>/dev/null || true

# UDP forwarding rules
iptables -t nat -A PREROUTING -i $INTERFACE -p udp --dport 7300 -j DNAT --to-destination :5667 2>/dev/null || true
iptables -t nat -A PREROUTING -i $INTERFACE -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true

# Save iptables rules
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save
elif command -v iptables-save &>/dev/null; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

# Create and enable the systemd service
cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Start the service
systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

# Download and install the onepesewa dashboard
echo -e "${Y}[+] Installing onepesewa dashboard...${NC}"
PANEL_URL="https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/onepesewa"
wget -qO /usr/local/bin/onepesewa "$PANEL_URL" || {
    echo -e "${R}Failed to download panel from $PANEL_URL${NC}"; exit 1
}
chmod +x /usr/local/bin/onepesewa

# Final message
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

# Optional Optimizations
echo ""
echo -e "${Y}Do you want to install BBR + TCP Optimizer? (y/n)${NC}"
read -r answer_bbr
if [[ "$answer_bbr" =~ ^[Yy]$ ]]; then
    echo -e "${Y}[+] Installing BBR + TCP Optimizer...${NC}"
    apt install curl -y
    bash <(curl -s https://raw.githubusercontent.com/opiran-club/VPS-Optimizer/main/optimizer.sh --ipv4)
    echo -e "${G}BBR Optimization completed.${NC}"
else
    echo -e "${C}Skipped BBR installation.${NC}"
fi

echo ""
echo -e "${Y}Do you want to install BadVPN (UDP Gateway)? (y/n)${NC}"
read -r answer_badvpn
if [[ "$answer_badvpn" =~ ^[Yy]$ ]]; then
    echo -e "${Y}[+] Installing BadVPN UDP Gateway...${NC}"
    wget -N https://raw.githubusercontent.com/opiran-club/VPS-Optimizer/main/Install/udpgw.sh && bash udpgw.sh
    echo -e "${G}BadVPN installation finished.${NC}"
else
    echo -e "${C}Skipped BadVPN installation.${NC}"
fi

echo ""
echo -e "${G}All done! Type 'onepesewa' to manage your users.${NC}"
