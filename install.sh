#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║     OFFICIAL ONEPESEWA UDP Installer                        ║
# ║     Debian/Ubuntu  –  ZIVPN v1.4.9  –  @OfficialOnePesewa  ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

RED='\e[1;31m'  GRN='\e[1;32m'  YLW='\e[1;33m'  BLU='\e[1;34m'
MAG='\e[1;35m'  CYN='\e[1;36m'  WHT='\e[1;37m'  RST='\e[0m'
BOLD='\e[1m'    DIM='\e[2m'

[ "$EUID" -ne 0 ] && echo -e "${RED}Run as root.${RST}" && exit 1

ADMIN_HANDLE="@OfficialOnePesewa"
TG_CHANNEL="https://t.me/officialonepesewatech"
PANEL_VERSION="2.0.0"

# ── Logo ───────────────────────────────────────────────────────
print_logo() {
    echo ""
    echo -e "\e[38;5;196m\e[1m  ██████╗ ██████╗     ██╗   ██╗██████╗ ██████╗ \e[0m"
    echo -e "\e[38;5;202m\e[1m ██╔═══██╗██╔══██╗    ██║   ██║██╔══██╗██╔══██╗\e[0m"
    echo -e "\e[38;5;208m\e[1m ██║   ██║██████╔╝    ██║   ██║██║  ██║██████╔╝\e[0m"
    echo -e "\e[38;5;214m\e[1m ██║   ██║██╔═══╝     ██║   ██║██║  ██║██╔═══╝ \e[0m"
    echo -e "\e[38;5;220m\e[1m ╚██████╔╝██║         ╚██████╔╝██████╔╝██║     \e[0m"
    echo -e "\e[38;5;226m\e[1m  ╚═════╝ ╚═╝          ╚═════╝ ╚═════╝ ╚═╝     \e[0m"
    echo ""
    echo -e "  \e[38;5;208m▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓\e[0m"
    echo -e "  \e[38;5;196m\e[1m ⚡ OP UDP VPS PANEL  –  Installer\e[0m  \e[38;5;208m|\e[0m  \e[38;5;220m${ADMIN_HANDLE}\e[0m"
    echo -e "  \e[38;5;208m▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓\e[0m"
    echo ""
}

step() { echo -e "\n  ${CYN}${BOLD}[${1}/${2}]${RST}  ${WHT}${3}${RST}\n  ${DIM}────────────────────────────────────────────────${RST}"; }
ok()   { echo -e "  ${GRN}✔  $*${RST}"; }
warn() { echo -e "  ${YLW}⚠  $*${RST}"; }
err()  { echo -e "  ${RED}✘  $*${RST}"; }
info() { echo -e "  ${DIM}   $*${RST}"; }

# ── Bootstrap ──────────────────────────────────────────────────
echo -e "${DIM}Bootstrapping...${RST}"
apt-get update -qq
apt-get install -y -qq curl wget

OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -o)

# ── Geo fetch: curl → wget fallback, 3-API chain ───────────────
printf "${DIM}  Fetching server location...${RST}\r"
GEO=""
for api in \
    "https://ipapi.co/json/" \
    "https://ip-api.com/json/?fields=status,message,country,countryCode,city,zip,isp,query" \
    "https://ipinfo.io/json"; do
    GEO=$(curl -4 -s --max-time 8 "$api" 2>/dev/null)
    [ -z "$GEO" ] && GEO=$(wget -q -O- --timeout=8 "$api" 2>/dev/null)
    [ -n "$GEO" ] && echo "$GEO" | grep -qE '"ip"|"query"' && break
    GEO=""
done
printf "\r\033[K"

if [ -z "$GEO" ]; then
    IP="N/A"; CITY="Unknown"; COUNTRY="Unknown"; ISP="Unknown"
else
    IP=$(echo "$GEO"      | grep -oP '"(?:ip|query)":\s*"\K[^"]+' | head -1)
    CITY=$(echo "$GEO"    | grep -oP '"city":\s*"\K[^"]+')
    COUNTRY=$(echo "$GEO" | grep -oP '"(?:country_name|country)":\s*"\K[^"]+' | head -1)
    ISP=$(echo "$GEO"     | grep -oP '"(?:org|isp)":\s*"\K[^"]+' | head -1)
    [ -z "$IP" ]      && IP="N/A"
    [ -z "$CITY" ]    && CITY="Unknown"
    [ -z "$COUNTRY" ] && COUNTRY="Unknown"
    [ -z "$ISP" ]     && ISP="Unknown"
fi
LOC="$CITY, $COUNTRY"

# ── Banner ─────────────────────────────────────────────────────
clear
print_logo

echo -e "  ${WHT}╔═══════════════════════════════════════════════════════════════╗${RST}"
printf  "  ${WHT}║${RST}  ${CYN}🌐 IP        :${RST}  ${WHT}%-47s${RST}${WHT}║${RST}\n" "$IP"
printf  "  ${WHT}║${RST}  ${YLW}📍 Location  :${RST}  ${WHT}%-47s${RST}${WHT}║${RST}\n" "$LOC"
printf  "  ${WHT}║${RST}  ${BLU}🏢 ISP       :${RST}  ${WHT}%-47s${RST}${WHT}║${RST}\n" "$ISP"
printf  "  ${WHT}║${RST}  ${GRN}💻 OS        :${RST}  ${WHT}%-47s${RST}${WHT}║${RST}\n" "$OS"
printf  "  ${WHT}║${RST}  ${MAG}👤 Admin     :${RST}  ${WHT}%-47s${RST}${WHT}║${RST}\n" "$ADMIN_HANDLE"
printf  "  ${WHT}║${RST}  ${CYN}📢 Channel   :${RST}  ${WHT}%-47s${RST}${WHT}║${RST}\n" "$TG_CHANNEL"
echo -e "  ${WHT}╚═══════════════════════════════════════════════════════════════╝${RST}"
echo ""

# ══════════════════════════════════════════════════════════════
#  STEP 1 – Dependencies
# ══════════════════════════════════════════════════════════════
step 1 6 "Installing dependencies"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    jq iptables-persistent netfilter-persistent openssl vnstat bc 2>/dev/null
ok "jq  bc  openssl  vnstat  iptables-persistent  installed"

# ══════════════════════════════════════════════════════════════
#  STEP 2 – Architecture
# ══════════════════════════════════════════════════════════════
step 2 6 "Detecting system architecture"
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)  BIN="amd64" ;;
    aarch64|arm64) BIN="arm64" ;;
    *)
        err "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac
ok "Architecture: ${ARCH} → ${BIN}"

# ══════════════════════════════════════════════════════════════
#  STEP 3 – Download ZIVPN binary
# ══════════════════════════════════════════════════════════════
step 3 6 "Downloading ZIVPN v1.4.9"
systemctl stop zivpn 2>/dev/null || true
rm -f /usr/local/bin/zivpn

ZIVPN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-${BIN}"
info "Source: $ZIVPN_URL"

if wget -q --show-progress -O /usr/local/bin/zivpn "$ZIVPN_URL"; then
    chmod +x /usr/local/bin/zivpn
    ok "ZIVPN binary installed → /usr/local/bin/zivpn"
else
    err "Failed to download ZIVPN binary."
    exit 1
fi

# ══════════════════════════════════════════════════════════════
#  STEP 4 – Config, SSL & kernel tuning
# ══════════════════════════════════════════════════════════════
step 4 6 "Setting up config, SSL & kernel"

mkdir -p /etc/zivpn
touch /etc/zivpn/users.db /etc/zivpn/usage.db

# Write config only if missing
if [ ! -f /etc/zivpn/config.json ]; then
    cat > /etc/zivpn/config.json <<'JSONEOF'
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key":  "/etc/zivpn/zivpn.key",
  "auth": {
    "mode": "passwords",
    "config": []
  }
}
JSONEOF
    ok "ZIVPN config created → /etc/zivpn/config.json"
else
    info "Existing config preserved."
fi

# SSL certificate
if [ ! -f /etc/zivpn/zivpn.crt ] || [ ! -f /etc/zivpn/zivpn.key ]; then
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
        -subj "/C=GH/ST=Accra/L=Accra/O=OnePesewa/CN=onepesewa" \
        -keyout /etc/zivpn/zivpn.key \
        -out    /etc/zivpn/zivpn.crt 2>/dev/null
    ok "SSL certificate generated (RSA 4096, 365 days)"
else
    info "Existing SSL cert preserved."
fi

# Kernel UDP tuning
sysctl -w net.core.rmem_max=67108864     >/dev/null 2>&1 || true
sysctl -w net.core.wmem_max=67108864     >/dev/null 2>&1 || true
sysctl -w net.core.rmem_default=16777216 >/dev/null 2>&1 || true
sysctl -w net.core.wmem_default=16777216 >/dev/null 2>&1 || true
sysctl -w net.ipv4.udp_mem="65536 131072 262144" >/dev/null 2>&1 || true
ok "Kernel UDP buffers tuned (64MB)"

cat > /etc/sysctl.d/99-opudp.conf <<'SYSCTL'
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.ipv4.udp_mem=65536 131072 262144
SYSCTL
ok "Sysctl persisted → /etc/sysctl.d/99-opudp.conf"

# ══════════════════════════════════════════════════════════════
#  STEP 5 – Firewall
# ══════════════════════════════════════════════════════════════
step 5 6 "Configuring firewall"

command -v ufw &>/dev/null && ufw disable &>/dev/null && info "UFW disabled"

INTERFACE=$(ip -4 route ls | grep default | grep -oP '(?<=dev )(\S+)' | head -1)
[ -z "$INTERFACE" ] && INTERFACE="eth0"
info "Primary interface: $INTERFACE"

iptables -I INPUT -p tcp  --dport 22           -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp  --dport 5667         -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp  --dport 5060         -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp  --dport 7300         -j ACCEPT 2>/dev/null || true
iptables -I INPUT -p udp  --dport 6000:19999   -j ACCEPT 2>/dev/null || true

iptables -t nat -A PREROUTING -i "$INTERFACE" -p udp --dport 7300 \
    -j DNAT --to-destination :5667 2>/dev/null || true
iptables -t nat -A PREROUTING -i "$INTERFACE" -p udp --dport 6000:19999 \
    -j DNAT --to-destination :5667 2>/dev/null || true

if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save 2>/dev/null
elif command -v iptables-save &>/dev/null; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi
ok "Firewall rules applied and saved"
info "Open: 22/TCP  5060  5667  7300  6000-19999 (UDP)"

# ── Systemd service ────────────────────────────────────────────
cat > /etc/systemd/system/zivpn.service <<'SERVICE'
[Unit]
Description=ZIVPN UDP Server – OP UDP Panel
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
SERVICE

systemctl daemon-reload
systemctl enable zivpn 2>/dev/null
systemctl start  zivpn 2>/dev/null

if systemctl is-active --quiet zivpn; then
    ok "ZIVPN service started and enabled"
else
    warn "ZIVPN failed to start – check: journalctl -u zivpn -n 30"
fi

# ══════════════════════════════════════════════════════════════
#  STEP 6 – Download OPUDP Panel
# ══════════════════════════════════════════════════════════════
step 6 6 "Installing OPUDP Panel"

PANEL_URL="https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/opudp"
if wget -qO /usr/local/bin/opudp "$PANEL_URL" 2>/dev/null; then
    chmod +x /usr/local/bin/opudp
    ok "Panel installed → /usr/local/bin/opudp"
    info "Command: opudp"
else
    warn "Could not download panel. Install manually later."
fi

# Legacy alias
ln -sf /usr/local/bin/opudp /usr/local/bin/onepesewa 2>/dev/null || true
ok "Legacy alias: onepesewa → opudp"

# ══════════════════════════════════════════════════════════════
#  COMPLETION
# ══════════════════════════════════════════════════════════════
echo ""
echo -e "  ${WHT}╔═══════════════════════════════════════════════════════════════╗${RST}"
echo -e "  ${WHT}║${RST}  ${GRN}${BOLD}🎉  INSTALLATION COMPLETE!${RST}                                   ${WHT}║${RST}"
echo -e "  ${WHT}╠═══════════════════════════════════════════════════════════════╣${RST}"
printf  "  ${WHT}║${RST}  ${CYN}🌐 Server IP   :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "$IP"
printf  "  ${WHT}║${RST}  ${YLW}📍 Location    :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "$LOC"
printf  "  ${WHT}║${RST}  ${BLU}🏢 ISP         :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "$ISP"
echo -e "  ${WHT}╠═══════════════════════════════════════════════════════════════╣${RST}"
printf  "  ${WHT}║${RST}  ${GRN}🔌 ZIVPN Port  :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "5667 (UDP)"
printf  "  ${WHT}║${RST}  ${GRN}🎯 NAT Range   :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "6000–19999  +  7300  → 5667"
printf  "  ${WHT}║${RST}  ${GRN}📞 VoIP SIP    :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "5060 (UDP)"
printf  "  ${WHT}║${RST}  ${MAG}📋 Panel cmd   :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "opudp   (or: onepesewa)"
echo -e "  ${WHT}╠═══════════════════════════════════════════════════════════════╣${RST}"
printf  "  ${WHT}║${RST}  ${MAG}👤 Admin       :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "$ADMIN_HANDLE"
printf  "  ${WHT}║${RST}  ${CYN}📢 Channel     :${RST}  ${WHT}%-44s${RST}${WHT}║${RST}\n" "$TG_CHANNEL"
echo -e "  ${WHT}╚═══════════════════════════════════════════════════════════════╝${RST}"
echo ""

# ── Optional: BBR ──────────────────────────────────────────────
echo -e "  ${YLW}${BOLD}▸ Install BBR + TCP Optimizer?${RST}  ${DIM}(recommended)${RST}"
echo -ne "  ${CYN}  [y/N]: ${RST}"; read -r answer_bbr
if [[ "$answer_bbr" =~ ^[Yy]$ ]]; then
    echo -e "\n  ${YLW}▸ Running BBR optimizer...${RST}\n"
    apt-get install -y curl -qq 2>/dev/null
    bash <(curl -4 -s \
        "https://raw.githubusercontent.com/opiran-club/VPS-Optimizer/main/optimizer.sh" \
        --ipv4)
    echo -e "\n  ${GRN}✔  BBR optimization complete.${RST}"
else
    echo -e "  ${DIM}  Skipped.${RST}"
fi

echo ""

# ── Optional: BadVPN ───────────────────────────────────────────
echo -e "  ${YLW}${BOLD}▸ Install BadVPN UDP Gateway?${RST}  ${DIM}(for VoIP/WS tunneling)${RST}"
echo -ne "  ${CYN}  [y/N]: ${RST}"; read -r answer_badvpn
if [[ "$answer_badvpn" =~ ^[Yy]$ ]]; then
    echo -e "\n  ${YLW}▸ Installing BadVPN UDPGW...${RST}\n"
    wget -qN \
        "https://raw.githubusercontent.com/opiran-club/VPS-Optimizer/main/Install/udpgw.sh" \
        && bash udpgw.sh
    echo -e "\n  ${GRN}✔  BadVPN installed.${RST}"
else
    echo -e "  ${DIM}  Skipped.${RST}"
fi

echo ""
echo -e "  ${GRN}${BOLD}✔  All done!  Type ${CYN}opudp${GRN} to open the management panel.${RST}"
echo -e "  ${DIM}  ${ADMIN_HANDLE}  |  ${TG_CHANNEL}${RST}\n"