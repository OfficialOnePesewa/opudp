```markdown
# OP UDP PANEL – by @OfficialOnePesewa

![Version](https://img.shields.io/badge/version-2.0-green)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-orange)
![ZIVPN](https://img.shields.io/badge/ZIVPN-v1.4.9-blue)

Professional UDP tunnel management panel powered by **ZIVPN v1.4.9**, featuring **HWID device binding**, **Telegram bot integration**, **real-time bandwidth monitoring**, **quota enforcement**, and full **VoIP support** — built for Debian/Ubuntu VPS environments.

---

## 🚀 Features

- 🔐 **HWID Device Binding** — Each user password is locked to a specific device (`userpass_HWID`)
- 👥 **User Management** — Add, remove, renew users with expiry dates and data quotas
- 📊 **Bandwidth Tracking** — Per-user traffic accounting via iptables chains
- 📡 **Telegram Bot** — Full admin control + sub-admin support + user self-service (`/mystatus`)
- ⏳ **User Status** — Expiry, used/remaining bandwidth, active sessions (panel & bot)
- 🔌 **VoIP Ready** — SIP (5060) and RTP (6000–19999) ports open by default
- 🚀 **BBR Optimizer** — One-click TCP/UDP acceleration
- 📡 **BadVPN UDPGW** — UDP gateway for WS/TLS tunnels
- 🧹 **Auto Cleanup** — Removes expired users automatically
- 💾 **Backup & Restore** — Full config and user database backup
- 🌐 **Geo Detection** — Dual-API fallback (ipapi.co → ip-api.com)
- 🎨 **Fire Gradient UI** — Pixel art OPUDP logo with ANSI 256-color dashboard

---

## 📦 Installation

### One-line installer (recommended)

```bash
wget -qO /tmp/install.sh https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/install.sh && bash /tmp/install.sh
```

### Or with curl

```bash
bash <(curl -s https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/install.sh)
```

---

## 🖥️ Panel Command

After installation, open the management panel with:

```bash
opudp
```

> Legacy alias also works: `onepesewa`

---

## 📋 Menu Options

| # | Option | Description |
|---|--------|-------------|
| 1 | ▶ Start | Start ZIVPN service |
| 2 | ■ Stop | Stop ZIVPN service |
| 3 | ↺ Restart | Restart ZIVPN service |
| 4 | ◉ Status | View service status |
| 5 | List Users | Show all registered users |
| 6 | Add User | Create user with HWID binding |
| 7 | Remove User | Delete user and clean iptables |
| 8 | Renew User | Extend user expiry |
| 9 | Cleanup | Remove all expired users |
| 10 | Conn Stats | Live connection statistics |
| 11 | BW + Expiry | Bandwidth and expiry report |
| 12 | Reset BW | Reset user bandwidth counters |
| 13 | Speed Test | Server speed test |
| 14 | Live Logs | Stream ZIVPN journal logs |
| 15 | Backup | Backup all config and user data |
| 16 | Restore | Restore from backup |
| 17 | Port Range | Configure user port allocation range |
| 18 | ⬆ Update | Self-update panel from GitHub |
| 19 | Conn Limit | Set per-user connection limit |
| 20 | Trial User | Create auto-expiring trial account |
| 21 | 🚀 BBR Opt | Install BBR + TCP optimizer |
| 22 | 📡 BadVPN | Install BadVPN UDPGW |
| 23 | 🤖 Bot Config | Configure Telegram bot |
| 99 | 🗑 Uninstall | Fully remove panel and ZIVPN |

---

## 🔧 How HWID Binding Works

ZIVPN v1.4.9 encodes credentials as `password|HWID` natively. The panel stores users as:

```
userpass_HWID | expiry | quota | port | hwid | used_bytes
```

The HWID is sent automatically by the ZIVPN client app — no manual input needed from the user.

---

## 🤖 Telegram Bot Setup

1. Open panel → `[23] Bot Config`
2. Set your bot token from `@BotFather`
3. Start the bot service
4. Add yourself as admin using your Telegram Chat ID
5. Add sub-admins as needed

The bot supports full user management, server status, bandwidth reports, trial creation, and cleanup — all from Telegram.

---

## 🗂️ File Structure

```
/etc/zivpn/
├── config.json        # ZIVPN server config
├── users.db           # User database (pipe-delimited)
├── usage.db           # Per-user bandwidth counters
├── zivpn.crt          # SSL certificate (RSA 4096)
├── zivpn.key          # SSL private key
├── telegram_token     # Bot token
├── bot_admins.db      # Sub-admin Chat IDs
├── conn_limits.db     # Per-user connection limits
└── backups/           # Timestamped backup archives

/usr/local/bin/
├── opudp              # Main panel command
├── onepesewa          # Legacy alias → opudp
├── zivpn              # ZIVPN binary
└── opudp_bot.py       # Telegram bot script
```

---

## 🌐 Ports Used

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH access |
| 5667 | UDP | ZIVPN main listener |
| 5060 | UDP | VoIP SIP |
| 7300 | UDP | NAT → 5667 |
| 6000–19999 | UDP | NAT range + VoIP RTP → 5667 |

---

## ⚙️ Requirements

- Debian 10+ or Ubuntu 20.04+
- Root access
- 512MB RAM minimum
- Open UDP ports on your VPS firewall

---

## 📞 Support

- **Telegram Admin:** [@OfficialOnePesewa](https://t.me/OfficialOnePesewa)
- **Channel:** [t.me/officialonepesewatech](https://t.me/officialonepesewatech)

---

## 📄 License

MIT License — free to use, modify, and distribute.

---

> Built with ❤️ by [@OfficialOnePesewa](https://t.me/OfficialOnePesewa) — OP Data Solutions, Ghana 🇬🇭
```
