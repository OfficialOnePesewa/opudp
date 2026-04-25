# OP UDP PANEL – Professional UDP Tunnel Manager

![Version](https://img.shields.io/badge/version-2.0-green)
![License](https://img.shields.io/badge/license-MIT-blue)

Professional UDP tunnel management panel with **HWID device binding**, **Telegram bot integration**, **real‑time user status**, and full **VoIP support**.

## 🚀 Features

- **UDP Tunnel Server** – Powered by ZIVPN (udp‑zivpn)
- **User Management** – Add/remove/renew users with expiry and quota
- **HWID Binding** – Each password is tied to a specific device (`password = userpass_HWID`)
- **Bandwidth Tracking** – Per‑user traffic accounting via iptables
- **Telegram Bot** – Full admin control + user self‑service (`/mystatus`)
- **User Status** – Check expiry, used/total bandwidth, remaining days, active sessions (panel & bot)
- **VoIP Ready** – SIP (5060) and RTP (6000‑19999) ports open
- **BBR Optimizer** – One‑click TCP acceleration
- **BadVPN** – UDP gateway for WS/TLS tunnels
- **Auto‑cleanup** – Removes expired users automatically

## 📦 Installation

### One‑line installer (recommended)

```bash
wget -qO /tmp/install.sh https://raw.githubusercontent.com/OfficialOnePesewa/OFFICIAL-ONEPESEWA-UDP/main/install.sh && bash /tmp/install.sh
