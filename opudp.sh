#!/bin/bash
# ============================================================
# OPUDP PANEL - ZIVPN Pro Multi-User UDP Tunnel
# Default port: 5667 (standard ZIVPN port)
# Author: @OfficialOnePesewa | Telegram: @OfficialOnePesewa
# Version: 2.1 (Port 5667 + GeoIP + Device Binding)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ------------------- CONFIGURATION -------------------
BASE_PORT=5667               # <-- CHANGED to standard ZIVPN port
CONF_DIR="/etc/zivpn/users"
SERVICE_DIR="/etc/systemd/system"
BIN_PATH="/usr/local/bin/udp-server"
DB_FILE="/etc/zivpn/users.db"
BACKUP_DIR="/etc/zivpn/backups"
LOG_DIR="/var/log/zivpn"
PUBLIC_IP=$(curl -s ifconfig.me || echo "127.0.0.1")

# ------------------- FETCH GEO IP INFO -------------------
get_geo_info() {
    GEO_DATA=$(curl -s ipinfo.io)
    COUNTRY=$(echo "$GEO_DATA" | grep -o '"country": "[^"]*"' | cut -d'"' -f4)
    CITY=$(echo "$GEO_DATA" | grep -o '"city": "[^"]*"' | cut -d'"' -f4)
    ISP=$(echo "$GEO_DATA" | grep -o '"org": "[^"]*"' | cut -d'"' -f4 | cut -d' ' -f1)
    [[ -z "$COUNTRY" ]] && COUNTRY="Unknown"
    [[ -z "$CITY" ]] && CITY="Unknown"
    [[ -z "$ISP" ]] && ISP="Unknown"
}

# ------------------- STYLISH HEADER -------------------
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "   ██████╗ ██████╗ ██╗   ██╗██████╗ ██████╗ "
    echo "  ██╔═══██╗██╔══██╗██║   ██║██╔══██╗██╔══██╗"
    echo "  ██║   ██║██████╔╝██║   ██║██║  ██║██████╔╝"
    echo "  ██║   ██║██╔═══╝ ██║   ██║██║  ██║██╔══██╗"
    echo "  ╚██████╔╝██║     ╚██████╔╝██████╔╝██║  ██║"
    echo "   ╚═════╝ ╚═╝      ╚═════╝ ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${NC}${BOLD}       UDP TUNNEL MANAGER (Port ${BASE_PORT})${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_server_info() {
    get_geo_info
    CURRENT_DATE=$(date "+%A, %d %B %Y - %H:%M:%S")
    echo -e "${BLUE}📅 System Time : ${YELLOW}$CURRENT_DATE${NC}"
    echo -e "${BLUE}🌍 Server IP   : ${YELLOW}$PUBLIC_IP${NC}"
    echo -e "${BLUE}📍 Location    : ${YELLOW}$CITY, $COUNTRY ($ISP)${NC}"
    echo -e "${BLUE}🔌 Default Port: ${YELLOW}$BASE_PORT (per user increments)${NC}"
    echo -e "${BLUE}👤 Author      : ${YELLOW}@OfficialOnePesewa (Telegram)${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ------------------- DEPENDENCIES -------------------
install_deps() {
    apt update -y && apt install -y iptables wget curl socat jq bc cron
    systemctl enable cron
}

fetch_binary() {
    if [[ ! -f "$BIN_PATH" ]]; then
        echo -e "${GREEN}Downloading original ZIVPN UDP server binary...${NC}"
        wget -O /tmp/udp-server https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/udp-server
        chmod +x /tmp/udp-server
        mv /tmp/udp-server "$BIN_PATH"
    fi
}

# ------------------- USER DATABASE (with Device ID binding) -------------------
init_db() {
    mkdir -p "$CONF_DIR" "$BACKUP_DIR" "$LOG_DIR"
    touch "$DB_FILE"
    chmod 600 "$DB_FILE"
}

add_user() {
    local username="$1"
    local pass="$2"
    local days="$3"
    local quota_mb="$4"
    local device_id="$5"

    local expiry=$(date -d "+$days days" +%s)
    local quota_bytes=$((quota_mb * 1024 * 1024))
    local port=$((BASE_PORT + $(wc -l < "$DB_FILE")))

    echo "$username|$pass|$expiry|$quota_bytes|0|$port|$device_id" >> "$DB_FILE"

    cat > "$CONF_DIR/$username.conf" <<EOF
PORT=$port
PASSWORD=$pass
DEVICE_ID=$device_id
EOF

    cat > "$SERVICE_DIR/zivpn-user-$username.service" <<EOF
[Unit]
Description=ZIVPN UDP Tunnel for $username
After=network.target

[Service]
Type=simple
ExecStart=$BIN_PATH -p $port -k $pass
Restart=always
RestartSec=3
User=root
StandardOutput=append:$LOG_DIR/$username.log
StandardError=append:$LOG_DIR/$username.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "zivpn-user-$username.service"
    systemctl start "zivpn-user-$username.service"

    iptables -I OUTPUT -p udp --sport $port -m quota --quota $quota_bytes -j ACCEPT
    iptables -I INPUT -p udp --dport $port -m quota --quota $quota_bytes -j ACCEPT

    echo -e "${GREEN}✔ User $username added.${NC}"
    echo -e "   Server IP : $PUBLIC_IP"
    echo -e "   Port      : $port"
    echo -e "   Password  : $pass"
    echo -e "   Expires   : $(date -d "@$expiry")"
    echo -e "   Quota     : ${quota_mb}MB"
    echo -e "   Bound Device ID : ${device_id:-Not bound}"
}

delete_user() {
    local username="$1"
    if ! grep -q "^$username|" "$DB_FILE"; then
        echo -e "${RED}User $username not found.${NC}"
        return
    fi
    local port=$(grep "^$username|" "$DB_FILE" | cut -d'|' -f6)
    systemctl stop "zivpn-user-$username.service"
    systemctl disable "zivpn-user-$username.service"
    rm -f "$SERVICE_DIR/zivpn-user-$username.service"
    rm -f "$CONF_DIR/$username.conf"
    sed -i "/^$username|/d" "$DB_FILE"
    systemctl daemon-reload
    iptables -D OUTPUT -p udp --sport $port -m quota --quota 1 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport $port -m quota --quota 1 -j ACCEPT 2>/dev/null
    echo -e "${GREEN}✔ User $username deleted.${NC}"
}

list_users() {
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No users found.${NC}"
        return
    fi
    printf "${GREEN}%-15s %-12s %-20s %-10s %-10s %-10s %-20s${NC}\n" "Username" "Password" "Expires" "QuotaMB" "UsedMB" "Port" "DeviceID"
    while IFS='|' read -r u p e q uq port dev; do
        used_mb=$((uq / 1048576))
        quota_mb=$((q / 1048576))
        exp_date=$(date -d "@$e" +"%Y-%m-%d")
        printf "%-15s %-12s %-20s %-10s %-10s %-10s %-20s\n" "$u" "$p" "$exp_date" "$quota_mb" "$used_mb" "$port" "${dev:-None}"
    done < "$DB_FILE"
}

bind_device_to_user() {
    read -p "Username: " u
    read -p "Device ID (from devinfo app): " dev
    if grep -q "^$u|" "$DB_FILE"; then
        sed -i "s/^$u|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|.*/$u|$(grep "^$u|" "$DB_FILE" | cut -d'|' -f2-6)|$dev/" "$DB_FILE"
        echo -e "${GREEN}Device ID $dev bound to $u.${NC}"
    else
        echo -e "${RED}User not found.${NC}"
    fi
}

test_user() {
    local minutes="$1"
    local temp_pass="test_$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)"
    local expiry_sec=$((minutes * 60))
    local expiry_time=$(($(date +%s) + expiry_sec))
    local port=$((BASE_PORT + $(wc -l < "$DB_FILE")))

    echo "test|$temp_pass|$expiry_time|$((100*1024*1024))|0|$port|" >> "$DB_FILE"
    cat > "$CONF_DIR/test.conf" <<EOF
PORT=$port
PASSWORD=$temp_pass
EOF

    cat > "$SERVICE_DIR/zivpn-user-test.service" <<EOF
[Unit]
Description=ZIVPN Temporary Test User
After=network.target

[Service]
Type=simple
ExecStart=$BIN_PATH -p $port -k $temp_pass
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl start "zivpn-user-test.service"

    echo -e "${GREEN}✔ Test user created for ${minutes} minutes.${NC}"
    echo -e "   Server IP : $PUBLIC_IP"
    echo -e "   Port      : $port"
    echo -e "   Password  : $temp_pass"
    echo -e "   Auto‑delete after $(date -d "@$expiry_time")"

    (sleep $((minutes*60)) && sudo systemctl stop zivpn-user-test && sudo rm -f "$SERVICE_DIR/zivpn-user-test.service" && sudo systemctl daemon-reload && sudo sed -i '/^test|/d' "$DB_FILE") &
}

cleanup_expired() {
    now=$(date +%s)
    while IFS='|' read -r u p e q uq port dev; do
        if [[ $e -lt $now ]]; then
            echo -e "${YELLOW}Removing expired user: $u${NC}"
            delete_user "$u"
        fi
    done < "$DB_FILE"
}

show_bandwidth() {
    echo -e "${GREEN}Current bandwidth usage (iptables quota):${NC}"
    iptables -L -v -n | grep -E "sport|dport" | grep "udp dpt:7" 2>/dev/null || echo "No quota data yet."
}

reset_bandwidth() {
    echo -e "${RED}Resetting all user quotas...${NC}"
    iptables -Z
    echo -e "${GREEN}Done.${NC}"
}

# ------------------- MAIN MENU -------------------
main_menu() {
    while true; do
        show_header
        show_server_info
        echo ""
        echo -e "${CYAN}${BOLD}    MAIN MENU${NC}"
        echo -e " 1) Start ZIVPN (all users)"
        echo -e " 2) Stop ZIVPN (all users)"
        echo -e " 3) Restart ZIVPN"
        echo -e " 4) Status"
        echo -e " 5) List Users + Expiry + Device ID"
        echo -e " 6) Add User"
        echo -e " 7) Remove User"
        echo -e " 8) Renew / Extend User"
        echo -e " 9) Cleanup Expired"
        echo -e "10) Connection Stats"
        echo -e "11) Bandwidth + Expiry"
        echo -e "12) Reset Bandwidth"
        echo -e "13) Speed Test (iperf3 server)"
        echo -e "14) Live Logs (tail)"
        echo -e "15) Backup All Data"
        echo -e "16) Restore Backup"
        echo -e "17) Change Port Range"
        echo -e "18) Auto-Update OPUDP"
        echo -e "19) Set Connection Limit (per user)"
        echo -e "20) Trial / Test User (1-60 min)"
        echo -e "21) Bind Device ID to User (anti‑sharing)"
        echo -e ""
        echo -e "99) UNINSTALL (DANGER)"
        echo -e " 0) Exit"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "Choose [0–21]: " choice

        case $choice in
            1) systemctl start 'zivpn-user-*' 2>/dev/null; echo "Started."; sleep 1 ;;
            2) systemctl stop 'zivpn-user-*' 2>/dev/null; echo "Stopped."; sleep 1 ;;
            3) systemctl restart 'zivpn-user-*' 2>/dev/null; echo "Restarted."; sleep 1 ;;
            4) systemctl status 'zivpn-user-*' --no-pager ;;
            5) list_users; read -p "Press Enter..." ;;
            6)
                read -p "Username: " u
                read -p "Password (enter for random): " p
                [[ -z "$p" ]] && p=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
                read -p "Validity (days): " d
                read -p "Data quota (MB, e.g. 1024): " q
                read -p "Device ID to bind (optional, press Enter to skip): " dev
                add_user "$u" "$p" "$d" "$q" "$dev"
                read -p "Press Enter..."
                ;;
            7)
                read -p "Username to remove: " u
                delete_user "$u"
                read -p "Press Enter..."
                ;;
            8)
                read -p "Username to extend: " u
                read -p "Additional days: " ad
                old_line=$(grep "^$u|" "$DB_FILE")
                if [[ -z "$old_line" ]]; then
                    echo "User not found."
                else
                    old_exp=$(echo "$old_line" | cut -d'|' -f3)
                    new_exp=$((old_exp + ad*86400))
                    sed -i "s/^$u|[^|]*|$old_exp|/$u|$(echo "$old_line" | cut -d'|' -f2)|$new_exp|/" "$DB_FILE"
                    echo "Extended."
                fi
                read -p "Press Enter..."
                ;;
            9) cleanup_expired; read -p "Done. Press Enter..." ;;
            10) ss -lunp | grep udp; read -p "Press Enter..." ;;
            11) show_bandwidth; read -p "Press Enter..." ;;
            12) reset_bandwidth; read -p "Press Enter..." ;;
            13) 
                read -p "Install iperf3? (y/n): " ins
                [[ "$ins" == "y" ]] && apt install iperf3 -y
                iperf3 -s &
                echo "iperf3 server running in background. Press Ctrl+C to stop."
                sleep 3
                ;;
            14) tail -f "$LOG_DIR"/*.log ;;
            15) 
                tar -czf "$BACKUP_DIR/backup_$(date +%F).tar.gz" "$DB_FILE" "$CONF_DIR" "$SERVICE_DIR/zivpn-user-*"
                echo "Backup saved to $BACKUP_DIR"
                read -p "Press Enter..."
                ;;
            16)
                read -p "Backup file path: " bf
                tar -xzf "$bf" -C /
                systemctl daemon-reload
                echo "Restored."
                read -p "Press Enter..."
                ;;
            17)
                read -p "New base port (current: $BASE_PORT): " newport
                sed -i "s/^BASE_PORT=.*/BASE_PORT=$newport/" "$0"
                echo "Port changed to $newport. Please restart the script."
                read -p "Press Enter..."
                ;;
            18)
                wget -O "$0" https://raw.githubusercontent.com/OfficialOnePesewa/opudp/main/opudp.sh && chmod +x "$0"
                echo "Updated. Restarting..."
                exec "$0"
                ;;
            19)
                read -p "Connection limit per user (e.g., 2): " lim
                echo "Not fully auto-implemented. Use iptables connlimit manually."
                read -p "Press Enter..."
                ;;
            20)
                read -p "Test minutes (1-60): " min
                if [[ $min -ge 1 && $min -le 60 ]]; then
                    test_user "$min"
                else
                    echo "Invalid minutes."
                fi
                read -p "Press Enter..."
                ;;
            21)
                bind_device_to_user
                read -p "Press Enter..."
                ;;
            99)
                read -p "Remove OPUDP completely? (yes/no): " sure
                if [[ "$sure" == "yes" ]]; then
                    systemctl stop 'zivpn-user-*'
                    systemctl disable 'zivpn-user-*'
                    rm -rf /etc/zivpn "$BIN_PATH" "$SERVICE_DIR/zivpn-user-*"
                    iptables -F
                    echo "Uninstalled."
                    exit 0
                fi
                ;;
            0) exit 0 ;;
            *) echo "Invalid option."; sleep 1 ;;
        esac
    done
}

# ------------------- INIT -------------------
install_deps
fetch_binary
init_db

# cron for auto cleanup
(crontab -l 2>/dev/null | grep -v "$0 cleanup_expired"; echo "0 * * * * $0 cleanup_expired") | crontab -

if [[ ! -s "$DB_FILE" ]]; then
    echo -e "${GREEN}Welcome to OPUDP Panel! Default port: $BASE_PORT${NC}"
    echo -e "${YELLOW}Use option 6 to add your first user.${NC}"
    sleep 2
fi

main_menu
