#!/bin/bash
set -e
G='\e[1;32m' R='\e[1;31m' Y='\e[1;33m' NC='\e[0m'
UDPC_DIR="/root/udp"
BIN="$UDPC_DIR/udp-custom"
CFG="$UDPC_DIR/config.json"
SVC="/etc/systemd/system/udp-custom.service"
ARCH=$(uname -m)
case $ARCH in x86_64|amd64) S="amd64";; aarch64|arm64) S="arm64";; armv7l) S="arm";; *) S="amd64";; esac

echo -e "${Y}[*] Checking current state...${NC}"
echo "--- Binary ---"; ls -la "$BIN" 2>/dev/null || echo "MISSING"
echo "--- Last journal errors ---"
journalctl -u udp-custom -n 20 --no-pager 2>/dev/null || echo "No journal"
echo "---"

# Stop service
systemctl stop udp-custom 2>/dev/null || true

# Re-download binary — try every known URL
echo -e "${Y}[*] Re-downloading UDP Custom binary...${NC}"
rm -f "$BIN"
URLS=(
  "https://github.com/http-custom/udp-custom/releases/latest/download/udp-custom-linux-$S"
  "https://github.com/http-custom/udp-custom/releases/download/v2.0.0/udp-custom-linux-$S"
  "https://github.com/http-custom/udp-custom/releases/download/v1.0.0/udp-custom-linux-$S"
  "https://github.com/http-custom/udp-custom/releases/download/v1.4.9/udp-custom-linux-$S"
)
OK=0
for url in "${URLS[@]}"; do
  echo -e "  Trying $url"
  wget -q -L -O "$BIN" "$url" 2>/dev/null || curl -fsSL -o "$BIN" "$url" 2>/dev/null || true
  if file "$BIN" 2>/dev/null | grep -qE "ELF|executable"; then
    echo -e "${G}  ✔ Downloaded OK${NC}"; OK=1; break
  else
    echo -e "  ✘ Not a valid binary"
    rm -f "$BIN"
  fi
done

if [ "$OK" -eq 0 ]; then
  echo -e "${Y}[*] Trying build from source...${NC}"
  apt-get install -y -qq golang-go git 2>/dev/null || true
  rm -rf /tmp/ucs
  git clone --depth 1 https://github.com/http-custom/udp-custom /tmp/ucs 2>/dev/null && \
  cd /tmp/ucs && go build -o "$BIN" . && cd / && rm -rf /tmp/ucs && OK=1 || true
fi

if [ "$OK" -eq 0 ]; then
  echo -e "${R}[!] Could not obtain UDP Custom binary from any source.${NC}"
  echo -e "${Y}    Please share your VPS OS/arch so we can find the right binary.${NC}"
  exit 1
fi

chmod +x "$BIN"
echo -e "${G}Binary ready: $(file $BIN)${NC}"

# Auto-detect correct startup command
echo -e "${Y}[*] Auto-detecting correct startup command...${NC}"
WORKING_CMD=""
CMDS=(
  "$BIN server -c $CFG"
  "$BIN -config $CFG"
  "$BIN --config $CFG"
  "$BIN $CFG"
)

for cmd in "${CMDS[@]}"; do
  echo -e "  Testing: $cmd"
  $cmd &>/dev/null &
  PID=$!
  sleep 2
  if kill -0 $PID 2>/dev/null; then
    WORKING_CMD="$cmd"
    kill $PID 2>/dev/null
    wait $PID 2>/dev/null
    echo -e "${G}  ✔ Works: $cmd${NC}"
    break
  else
    echo -e "  ✘ Failed"
    wait $PID 2>/dev/null
  fi
done

if [ -z "$WORKING_CMD" ]; then
  echo -e "${R}[!] No startup command worked. Showing binary help:${NC}"
  "$BIN" --help 2>&1 | head -30 || "$BIN" -h 2>&1 | head -30 || echo "No help output"
  echo -e "${Y}    Please paste the output above so we can fix the command.${NC}"
  exit 1
fi

# Rewrite service with working command
cat > "$SVC" <<EOF
[Unit]
Description=UDP Custom Server (OnePesewa)
After=network.target

[Service]
Type=simple
WorkingDirectory=$UDPC_DIR
ExecStart=$WORKING_CMD
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl start udp-custom
sleep 3

if systemctl is-active --quiet udp-custom; then
  echo -e "${G}✅ UDP Custom is now RUNNING${NC}"
  echo -e "${G}   Command: $WORKING_CMD${NC}"
else
  echo -e "${R}❌ Still failing. Run: journalctl -u udp-custom -n 30 --no-pager${NC}"
fi
