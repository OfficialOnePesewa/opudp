cat > /usr/local/bin/opudp_hwid_enforcer.sh <<'EOF'
#!/bin/bash
# HWID Lock Enforcer – only the first registered device can connect
HWID_DB="/etc/zivpn/hwid_allowed.db"        # password|allowed_hwid
USER_DB="/etc/zivpn/users.db"               # password|expiry|quota|port|hwid|used
LOG_FILE="/var/log/opudp_hwid_enforcer.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

# Ensure required files exist
touch "$HWID_DB" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null

# Main loop – tails ZIVPN logs and blocks mismatched HWIDs
journalctl -u zivpn -n0 -f --no-pager 2>/dev/null | while IFS= read -r line; do
    # Expect log format like: "... client connected {pass} from {ip} hwid={hwid}"
    # Adjust pattern if needed – it looks for "hwid=" and a password-like string
    if echo "$line" | grep -qiE 'client connected|user connected|accepted'; then
        # Extract password (first field after 'connected' or 'user') – robust extraction
        pass=$(echo "$line" | sed -n 's/.*\(connected\|user\) \([^ ]*\).*/\2/p' | tr -d '[:space:]')
        # Extract HWID
        hwid=$(echo "$line" | sed -n 's/.*hwid[=:]\? \([^\s]*\).*/\1/p' | tr -d '[:space:]')
        # Extract source IP
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]\+\).*/\1/p' | tr -d '[:space:]')

        if [ -n "$pass" ] && [ -n "$hwid" ] && [ -n "$ip" ]; then
            allowed_hwid=$(grep "^${pass}|" "$HWID_DB" 2>/dev/null | cut -d'|' -f2)
            if [ -n "$allowed_hwid" ]; then
                if [ "$hwid" != "$allowed_hwid" ]; then
                    port=$(grep "^${pass}|" "$USER_DB" 2>/dev/null | cut -d'|' -f4)
                    if [ -n "$port" ]; then
                        log "BLOCKED – user $pass, wrong HWID $hwid (allowed $allowed_hwid) from $ip on port $port"
                        # Drop only that IP on that port
                        iptables -I INPUT -p udp --dport "$port" -s "$ip" -j DROP 2>/dev/null
                        # Kill existing connections from that IP
                        conntrack -D -p udp --dport "$port" -s "$ip" 2>/dev/null
                        echo "$(date) - KICKED $ip (wrong HWID) for user $pass" >> /var/log/opudp_hwid_kick.log
                    fi
                fi
            fi
        fi
    fi
done
EOF

chmod +x /usr/local/bin/opudp_hwid_enforcer.sh
