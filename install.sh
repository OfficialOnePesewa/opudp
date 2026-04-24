#!/bin/bash
# OFFICIAL ONEPESEWA UDP Installer – Debian/Ubuntu with VoIP Support
set -e

G='\e[1;32m' R='\e[1;31m' Y='\e[1;33m' C='\e[1;36m' M='\e[1;35m' W='\e[1;37m' NC='\e[0m'
BOLD='\e[1m'
[ "$EUID" -ne 0 ] && echo -e "${R}Run as root.${NC}" && exit 1

# ── Update & basic tools ──────────────────────────────────────────────────────
echo -e "${Y}[+] Updating packages...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl wget

OS_INFO=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
echo -e "${G}[+] OS: $OS_INFO${NC}"

# ── Fetch server location ────────────────────────────────────────────────────
echo -e "${Y}[+] Fetching server info...${NC}"
GEO=$(curl -4 -s --max-time 8 https://ipapi.co/json/ 2>/dev/null || echo "")
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

# ── Header ────────────────────────────────────────────────────────────────────
clear
echo -e "${W}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${W}║${NC}                           ${M}${BOLD}█▀█ █▀█ █▀█ █▀█ █▀█${NC}                            ${W}║${NC}"
echo -e "${W}║${NC}                           ${M}${BOLD}█▄█ █▀▀ █▄█ █▀▀ █▀▀${NC}                            ${W}║${NC}"
echo -e "${W}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${W}║${NC}                      ${G}${BOLD}Professional UDP Tunnel Installer${NC}                      ${W}║${NC}"
echo -e "${W}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${G}  OS       :${NC} $OS_INFO"
echo -e "${G}  Location :${NC} $LOC"
echo -e "${G}  IP       :${NC} $IP"
echo -e "${G}  ISP      :${NC} $ISP"
echo -e "${G}  Admin    :${NC} @OfficialOnePesewa"
echo ""

# ── 1. Dependencies ───────────────────────────────────────────────────────────
echo -e "${Y}[1/6] Installing core dependencies...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    jq iptables-persistent netfilter-persistent openssl vnstat bc

# Speedtest
echo -e "${Y}[+] Installing speedtest-cli...${NC}"
command -v speedtest-cli &>/dev/null || \
    { DEBIAN_FRONTEND=noninteractive apt-get install -y -qq speedtest-cli 2>/dev/null || \
      { wget -qO /usr/local/bin/speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py && chmod +x /usr/local/bin/speedtest-cli; }; }

# Python (needed for Telegram bot)
echo -e "${Y}[+] Installing Python3 & pip...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-pip

# ── 2. Architecture ───────────────────────────────────────────────────────────
echo -e "${Y}[2/6] Detecting architecture...${NC}"
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) BIN="amd64" ;;
    aarch64|arm64) BIN="arm64" ;;
    *) echo -e "${R}Unsupported: $ARCH${NC}"; exit 1 ;;
esac
echo -e "${G}   Architecture: $ARCH -> $BIN${NC}"

# ── 3. Download ZIVPN binary ─────────────────────────────────────────────────
echo -e "${Y}[*] Stopping old ZIVPN service...${NC}"
systemctl stop zivpn 2>/dev/null || true
rm -f /usr/local/bin/zivpn

echo -e "${Y}[3/6] Downloading ZIVPN binary...${NC}"
wget -q --show-progress -O /usr/local/bin/zivpn \
    "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-$BIN" || {
    echo -e "${R}Failed to download binary. Check internet or URL.${NC}"; exit 1
}
chmod +x /usr/local/bin/zivpn

# ── 4. Create config & certificates ──────────────────────────────────────────
echo -e "${Y}[4/6] Setting up config...${NC}"
mkdir -p /etc/zivpn

# ⭐ THIS WAS MISSING – main cause of "inactive" service
cat <<'EOF' > /etc/zivpn/config.json
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
touch /etc/zivpn/usage.db

echo -e "${Y}[5/6] Generating SSL certificate...${NC}"
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/C=GH/ST=Accra/L=Accra/O=OnePesewa/CN=onepesewa" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" 2>/dev/null

# ── 5. Firewall ──────────────────────────────────────────────────────────────
echo -e "${Y}[6/6] Configuring firewall (VoIP ready)...${NC}"
command -v ufw &>/dev/null && ufw disable &>/dev/null

iptables -I INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 7300 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 5060 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp --dport 6000:19999 -j ACCEPT 2>/dev/null || true

iptables -t nat -A PREROUTING -p udp --dport 7300 -j DNAT --to-destination :5667 2>/dev/null || true
iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || true

if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save
elif command -v iptables-save &>/dev/null; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

# ── 6. Systemd service ───────────────────────────────────────────────────────
cat <<'EOF' > /etc/systemd/system/zivpn.service
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

systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn
sleep 2

# ── 7. Download panel ────────────────────────────────────────────────────────
echo -e "${Y}[+] Installing onepesewa dashboard...${NC}"
PANEL_URL="https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/onepesewa"
wget -qO /usr/local/bin/onepesewa "$PANEL_URL" || {
    echo -e "${R}Failed to download panel from $PANEL_URL${NC}"; exit 1
}
chmod +x /usr/local/bin/onepesewa

# Also download Telegram bot script
wget -qO /usr/local/bin/opudp_bot.py \
    "https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/opudp_bot.py" 2>/dev/null || true
chmod +x /usr/local/bin/opudp_bot.py 2>/dev/null || true

# ── Final message ────────────────────────────────────────────────────────────
echo -e "\n${C}====================================================${NC}"
echo -e "${G}         INSTALLATION COMPLETE!${NC}"
echo -e "${C}====================================================${NC}"
echo -e "${G} Server IP  :${NC} $IP"
echo -e "${G} Location   :${NC} $LOC"
echo -e "${G} ISP        :${NC} $ISP"
echo -e "${G} ZIVPN Port :${NC} 5667 (UDP) + 7300 forwarded"
echo -e "${G} NAT Range  :${NC} 6000 - 19999 (inc. VoIP RTP)"
echo -e "${G} VoIP SIP   :${NC} 5060 (UDP)"
echo -e "${C}====================================================${NC}"
echo -e "${Y} Type 'onepesewa' to open the panel.${NC}"
echo -e "${C}====================================================${NC}"

# ── Optional BBR ─────────────────────────────────────────────────────────────
echo ""
echo -ne "${Y}Do you want to install BBR + TCP Optimizer? (y/n) ${NC}"
read -r answer_bbr
if [[ "$answer_bbr" =~ ^[Yy]$ ]]; then
    echo -e "${Y}[+] Installing BBR + TCP Optimizer...${NC}"
    bash <(curl -s https://raw.githubusercontent.com/opiran-club/VPS-Optimizer/main/optimizer.sh --ipv4)
    echo -e "${G}BBR Optimization completed.${NC}"
else
    echo -e "${C}Skipped BBR installation.${NC}"
fi

# ── Optional BadVPN ──────────────────────────────────────────────────────────
echo ""
echo -ne "${Y}Do you want to install BadVPN (UDP Gateway)? (y/n) ${NC}"
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
