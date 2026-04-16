#!/usr/bin/env python3
"""
OP UDP PANEL Telegram Bot
Manages VPN users via Telegram commands.
"""

import os
import subprocess
import logging
from datetime import datetime, timedelta
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes

# Configuration paths
CONFIG_DIR = "/etc/zivpn"
TOKEN_FILE = f"{CONFIG_DIR}/telegram_token"
ADMINS_DB = f"{CONFIG_DIR}/admins.db"
USERS_DB = f"{CONFIG_DIR}/users.db"
USAGE_DB = f"{CONFIG_DIR}/usage.db"
TELEGRAM_DB = f"{CONFIG_DIR}/telegram.db"
CONFIG_JSON = f"{CONFIG_DIR}/config.json"

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# ------------------ Helper Functions ------------------
def load_token():
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            return f.read().strip()
    return None

def is_admin(user_id: int) -> bool:
    if not os.path.exists(ADMINS_DB):
        return False
    with open(ADMINS_DB) as f:
        for line in f:
            if line.startswith(f"{user_id}|"):
                return True
    return False

def is_owner(user_id: int) -> bool:
    if not os.path.exists(ADMINS_DB):
        return False
    with open(ADMINS_DB) as f:
        for line in f:
            if line.startswith(f"{user_id}|owner|"):
                return True
    return False

def run_panel_command(cmd: str) -> str:
    """Execute onepesewa internal command and return output."""
    try:
        result = subprocess.run(
            ["/usr/local/bin/onepesewa", f"--bot-{cmd}"],
            capture_output=True, text=True, timeout=30
        )
        return result.stdout.strip()
    except Exception as e:
        logger.error(f"Command failed: {e}")
        return "ERROR"

def format_bytes(b: int) -> str:
    if b >= 1073741824:
        return f"{b/1073741824:.2f} GB"
    elif b >= 1048576:
        return f"{b/1048576:.2f} MB"
    elif b >= 1024:
        return f"{b/1024:.2f} KB"
    return f"{b} B"

def quota_to_bytes(q: str) -> int:
    q = q.lower()
    if q.endswith("gb"):
        return int(float(q[:-2]) * 1073741824)
    elif q.endswith("mb"):
        return int(float(q[:-2]) * 1048576)
    return 0

# ------------------ Command Handlers ------------------
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Link user account: /start <password>"""
    args = context.args
    if not args:
        await update.message.reply_text("Usage: /start <password>")
        return
    password = args[0]
    if not os.path.exists(USERS_DB):
        await update.message.reply_text("❌ No users database.")
        return
    found = False
    with open(USERS_DB) as f:
        for line in f:
            if line.startswith(f"{password}|"):
                found = True
                break
    if not found:
        await update.message.reply_text("❌ Invalid password.")
        return
    # Save telegram link
    chat_id = update.effective_user.id
    lines = []
    if os.path.exists(TELEGRAM_DB):
        with open(TELEGRAM_DB) as f:
            lines = [l for l in f if not l.startswith(f"{password}|")]
    lines.append(f"{password}|{chat_id}\n")
    with open(TELEGRAM_DB, "w") as f:
        f.writelines(lines)
    await update.message.reply_text("✅ Account linked! You'll receive usage updates.")

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    msg = "🔧 <b>User Commands</b>\n/start &lt;password&gt; - Link account\n\n"
    if is_admin(user_id):
        msg += "<b>Admin Commands</b>\n"
        msg += "/status - Server status\n"
        msg += "/listusers - All users\n"
        msg += "/userinfo &lt;pass&gt; - User details\n"
        msg += "/adduser &lt;pass&gt; &lt;days&gt; &lt;quota&gt; [devid]\n"
        msg += "/removeuser &lt;pass&gt;\n"
        msg += "/renew &lt;pass&gt; &lt;days&gt;\n"
        msg += "/resetbw &lt;pass&gt;\n"
        msg += "/cleanup - Remove expired\n"
    if is_owner(user_id):
        msg += "\n👑 <b>Owner Commands</b>\n"
        msg += "/addadmin &lt;tgid&gt; &lt;name&gt;\n"
        msg += "/removeadmin &lt;tgid&gt;\n"
        msg += "/listadmins\n"
    await update.message.reply_text(msg, parse_mode="HTML")

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    output = run_panel_command("status")
    await update.message.reply_text(output, parse_mode="HTML")

async def listusers(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    if not os.path.exists(USERS_DB):
        await update.message.reply_text("No users.")
        return
    lines = []
    with open(USERS_DB) as f:
        for line in f:
            parts = line.strip().split("|")
            if len(parts) >= 3:
                lines.append(f"{parts[0]} | {parts[1]} | {parts[2]}")
    msg = "👥 <b>Users:</b>\n" + "\n".join(lines[:30])
    if len(lines) > 30:
        msg += f"\n... and {len(lines)-30} more"
    await update.message.reply_text(msg, parse_mode="HTML")

async def userinfo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    args = context.args
    if not args:
        await update.message.reply_text("Usage: /userinfo <password>")
        return
    output = run_panel_command(f"userinfo {args[0]}")
    await update.message.reply_text(output, parse_mode="HTML")

async def adduser(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    args = context.args
    if len(args) < 3:
        await update.message.reply_text("Usage: /adduser <basepass> <days> <quota> [devid]")
        return
    basepass, days, quota = args[0], args[1], args[2]
    devid = args[3] if len(args) > 3 else ""
    output = run_panel_command(f"adduser {basepass} {days} {quota} {devid}")
    await update.message.reply_text(output, parse_mode="HTML")

async def removeuser(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    args = context.args
    if not args:
        await update.message.reply_text("Usage: /removeuser <password>")
        return
    output = run_panel_command(f"removeuser {args[0]}")
    await update.message.reply_text(output)

async def renew(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    args = context.args
    if len(args) < 2:
        await update.message.reply_text("Usage: /renew <password> <days>")
        return
    output = run_panel_command(f"renew {args[0]} {args[1]}")
    await update.message.reply_text(output)

async def resetbw(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    args = context.args
    if not args:
        await update.message.reply_text("Usage: /resetbw <password>")
        return
    output = run_panel_command(f"resetbw {args[0]}")
    await update.message.reply_text(output)

async def cleanup(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ Unauthorized.")
        return
    output = run_panel_command("cleanup")
    await update.message.reply_text(output)

async def addadmin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_owner(update.effective_user.id):
        await update.message.reply_text("⛔ Owner only.")
        return
    args = context.args
    if len(args) < 2:
        await update.message.reply_text("Usage: /addadmin <tgid> <name>")
        return
    tgid, name = args[0], " ".join(args[1:])
    lines = []
    if os.path.exists(ADMINS_DB):
        with open(ADMINS_DB) as f:
            lines = [l for l in f if not l.startswith(f"{tgid}|")]
    lines.append(f"{tgid}|admin|{name}\n")
    with open(ADMINS_DB, "w") as f:
        f.writelines(lines)
    await update.message.reply_text(f"✅ Admin {name} added.")

async def removeadmin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_owner(update.effective_user.id):
        await update.message.reply_text("⛔ Owner only.")
        return
    args = context.args
    if not args:
        await update.message.reply_text("Usage: /removeadmin <tgid>")
        return
    tgid = args[0]
    if os.path.exists(ADMINS_DB):
        with open(ADMINS_DB) as f:
            lines = [l for l in f if not l.startswith(f"{tgid}|")]
        with open(ADMINS_DB, "w") as f:
            f.writelines(lines)
    await update.message.reply_text("✅ Admin removed.")

async def listadmins(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_owner(update.effective_user.id):
        await update.message.reply_text("⛔ Owner only.")
        return
    if not os.path.exists(ADMINS_DB):
        await update.message.reply_text("No admins.")
        return
    lines = []
    with open(ADMINS_DB) as f:
        for line in f:
            parts = line.strip().split("|")
            if len(parts) >= 3:
                lines.append(f"{parts[0]} - {parts[1]} - {parts[2]}")
    await update.message.reply_text("👑 Admins:\n" + "\n".join(lines))

# ------------------ Main ------------------
def main():
    token = load_token()
    if not token:
        logger.error("Telegram token not set. Run 'onepesewa' option 22.")
        return

    app = Application.builder().token(token).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_cmd))
    app.add_handler(CommandHandler("status", status))
    app.add_handler(CommandHandler("listusers", listusers))
    app.add_handler(CommandHandler("userinfo", userinfo))
    app.add_handler(CommandHandler("adduser", adduser))
    app.add_handler(CommandHandler("removeuser", removeuser))
    app.add_handler(CommandHandler("renew", renew))
    app.add_handler(CommandHandler("resetbw", resetbw))
    app.add_handler(CommandHandler("cleanup", cleanup))
    app.add_handler(CommandHandler("addadmin", addadmin))
    app.add_handler(CommandHandler("removeadmin", removeadmin))
    app.add_handler(CommandHandler("listadmins", listadmins))

    logger.info("Bot started polling...")
    app.run_polling()

if __name__ == "__main__":
    main()
