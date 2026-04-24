#!/usr/bin/env python3
import os
import subprocess
import sys
import re
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes, MessageHandler, filters

BOT_TOKEN_FILE = "/etc/zivpn/telegram_token"
ADMINS_FILE    = "/etc/zivpn/bot_admins.db"
PANEL_CMD      = "/usr/local/bin/onepesewa"

# ─────────────────────────────────────────────
#  ASCII HEADER
# ─────────────────────────────────────────────
HEADER = """
╔══════════════════════════════════════╗
║   ░▀▀█░▀█▀░█░█░█░█▀█░█▀█            ║
║   ░▄▀░░░█░░▀▄▀░█░█▀▀░█░█            ║
║   ░▀▀▀░▀▀▀░░▀░░▀░▀░░░▀░▀            ║
║         OP UDP PANEL BOT             ║
║   ─────────────────────────────────  ║
║   🛡  Secure  │  ⚡ Fast  │  🔧 Smart ║
╚══════════════════════════════════════╝
"""

# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────
def is_admin(chat_id: int) -> bool:
    if not os.path.exists(ADMINS_FILE):
        return False
    with open(ADMINS_FILE) as f:
        admins = [line.strip() for line in f if line.strip()]
    return str(chat_id) in admins


def clean_output(raw: str) -> str:
    """Convert panel output to clean, readable text."""
    raw = raw.replace('%0A', '\n').replace('\\n', '\n')
    lines = raw.split('\n')
    cleaned = [line.strip() for line in lines if line.strip()]
    return '\n'.join(cleaned)


def run(cmd_args: list) -> str:
    """Run a panel command and return cleaned stdout."""
    result = subprocess.run(cmd_args, capture_output=True, text=True, timeout=60)
    out = (result.stdout or '').strip()
    err = (result.stderr or '').strip()
    return clean_output(out) if out else (clean_output(err) if err else '⚠️ No output returned.')


def main_keyboard() -> InlineKeyboardMarkup:
    keyboard = [
        [
            InlineKeyboardButton("📊 Status",       callback_data="status"),
            InlineKeyboardButton("📋 List Users",   callback_data="list"),
        ],
        [
            InlineKeyboardButton("➕ Add User",      callback_data="adduser"),
            InlineKeyboardButton("➖ Remove User",   callback_data="removeuser"),
        ],
        [
            InlineKeyboardButton("🔁 Renew User",   callback_data="renew"),
            InlineKeyboardButton("🔃 Reset BW",     callback_data="resetbw"),
        ],
        [
            InlineKeyboardButton("👤 User Info",    callback_data="userinfo"),
            InlineKeyboardButton("🧹 Cleanup",      callback_data="cleanup"),
        ],
        [
            InlineKeyboardButton("🧪 Trial User",   callback_data="trial"),
            InlineKeyboardButton("👑 Admin Mgmt",   callback_data="adminmenu"),
        ],
        [
            InlineKeyboardButton("🚀 Install BBR",  callback_data="bbr"),
            InlineKeyboardButton("📡 BadVPN",       callback_data="badvpn"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard)


def admin_keyboard() -> InlineKeyboardMarkup:
    keyboard = [
        [InlineKeyboardButton("➕ Add Admin",    callback_data="addadmin")],
        [InlineKeyboardButton("➖ Remove Admin", callback_data="removeadmin")],
        [InlineKeyboardButton("📄 List Admins", callback_data="listadmins")],
        [InlineKeyboardButton("◀️ Back to Menu", callback_data="backmenu")],
    ]
    return InlineKeyboardMarkup(keyboard)


async def send_menu(target, context, edit=False):
    """Send or edit the main menu message."""
    text = (
        f"```{HEADER}```\n"
        "📌 *ZIVPN Control Panel*\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "Select an option below:"
    )
    if edit:
        await target.edit_message_text(text, reply_markup=main_keyboard(), parse_mode="Markdown")
    else:
        await target.reply_text(text, reply_markup=main_keyboard(), parse_mode="Markdown")


# ─────────────────────────────────────────────
#  COMMAND HANDLERS
# ─────────────────────────────────────────────
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    if not is_admin(chat_id):
        await update.message.reply_text(
            f"❌ *Unauthorized Access*\n\n"
            f"Your Chat ID: `{chat_id}`\n"
            f"Ask the main admin to add this ID via the panel (option 5).",
            parse_mode="Markdown"
        )
        return
    await update.message.reply_text(
        f"```{HEADER}```\n"
        "👋 *Welcome to OP UDP Panel Bot!*\n\n"
        "Use /menu to open the control panel.\n"
        "Use /id to get your Telegram Chat ID.",
        parse_mode="Markdown"
    )


async def get_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    await update.message.reply_text(
        f"📱 *Your Chat ID*\n\n`{chat_id}`\n\n"
        "_Share this with the main admin to get access._",
        parse_mode="Markdown"
    )


async def menu_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    if not is_admin(chat_id):
        await update.message.reply_text("❌ Unauthorized. Use /id to get your Chat ID.")
        return
    context.user_data.clear()
    await send_menu(update.message, context, edit=False)


# ─────────────────────────────────────────────
#  BUTTON CALLBACK HANDLER
# ─────────────────────────────────────────────
async def button_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    chat_id = update.effective_chat.id
    if not is_admin(chat_id):
        await query.edit_message_text("❌ Unauthorized.")
        return

    data = query.data

    # ── Navigation ──────────────────────────────
    if data == "backmenu":
        context.user_data.clear()
        await send_menu(query, context, edit=True)
        return

    if data == "adminmenu":
        await query.edit_message_text(
            f"```{HEADER}```\n"
            "👑 *Admin Management*\n"
            "━━━━━━━━━━━━━━━━━━━━\n"
            "Manage bot administrators:",
            reply_markup=admin_keyboard(),
            parse_mode="Markdown"
        )
        return

    # ── Status ──────────────────────────────────
    if data == "status":
        await query.edit_message_text("⏳ Fetching server status...")
        output = run([PANEL_CMD, "--bot-status"])
        await query.edit_message_text(
            f"```{HEADER}```\n"
            f"📡 *Server Status*\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"```\n{output}\n```",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("◀️ Back", callback_data="backmenu")]]),
            parse_mode="Markdown"
        )
        return

    # ── List Users ──────────────────────────────
    if data == "list":
        await query.edit_message_text("⏳ Fetching user list...")
        output = run([PANEL_CMD, "--bot-list"])
        # Telegram has a 4096 char limit; truncate if needed
        if len(output) > 3500:
            output = output[:3500] + "\n... (truncated)"
        await query.edit_message_text(
            f"```{HEADER}```\n"
            f"📋 *User List*\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"```\n{output}\n```",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("◀️ Back", callback_data="backmenu")]]),
            parse_mode="Markdown"
        )
        return

    # ── Cleanup ──────────────────────────────────
    if data == "cleanup":
        await query.edit_message_text("⏳ Running cleanup...")
        output = run([PANEL_CMD, "--bot-cleanup"])
        await query.edit_message_text(
            f"🧹 *Cleanup Complete*\n\n```\n{output}\n```",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("◀️ Back", callback_data="backmenu")]]),
            parse_mode="Markdown"
        )
        return

    # ── BBR ──────────────────────────────────────
    if data == "bbr":
        await query.edit_message_text("🚀 Installing BBR... This may take a few minutes.\n⏳ Please wait.")
        output = run([PANEL_CMD, "--bot-bbr"])
        await query.edit_message_text(
            f"🚀 *BBR Installation*\n\n```\n{output}\n```",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("◀️ Back", callback_data="backmenu")]]),
            parse_mode="Markdown"
        )
        return

    # ── BadVPN ───────────────────────────────────
    if data == "badvpn":
        await query.edit_message_text("📡 Installing BadVPN... Please wait.\n⏳")
        output = run([PANEL_CMD, "--bot-badvpn"])
        await query.edit_message_text(
            f"📡 *BadVPN Installation*\n\n```\n{output}\n```",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("◀️ Back", callback_data="backmenu")]]),
            parse_mode="Markdown"
        )
        return

    # ── List Admins ──────────────────────────────
    if data == "listadmins":
        if not os.path.exists(ADMINS_FILE):
            admins_text = "No admins configured yet."
        else:
            with open(ADMINS_FILE) as f:
                admins_text = f.read().strip() or "No admins configured yet."
        await query.edit_message_text(
            f"👥 *Admin List*\n\n```\n{admins_text}\n```",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("◀️ Back", callback_data="adminmenu")]]),
            parse_mode="Markdown"
        )
        return

    # ── Multi-step flows: set state & prompt ─────
    prompts = {
        "adduser":     ("adduser_password",    "🔑 *Add User — Step 1/4*\n\nEnter the base password:"),
        "removeuser":  ("removeuser_password", "🗑️ *Remove User*\n\nEnter the full password to remove:"),
        "renew":       ("renew_password",      "🔁 *Renew User — Step 1/2*\n\nEnter the password to renew:"),
        "resetbw":     ("resetbw_password",    "🔃 *Reset Bandwidth*\n\nEnter the password to reset:"),
        "userinfo":    ("userinfo_password",   "🔍 *User Info*\n\nEnter the password to look up:"),
        "trial":       ("trial_minutes",       "🧪 *Trial User*\n\nEnter trial duration in minutes (1–60):"),
        "addadmin":    ("addadmin_chatid",     "➕ *Add Admin*\n\nSend the Telegram Chat ID of the new admin:"),
        "removeadmin": ("removeadmin_chatid",  "➖ *Remove Admin*\n\nSend the Chat ID to remove:"),
    }
    if data in prompts:
        state, prompt = prompts[data]
        context.user_data.clear()
        context.user_data['awaiting'] = state
        context.user_data['origin_chat'] = chat_id
        cancel_btn = InlineKeyboardMarkup([[InlineKeyboardButton("❌ Cancel", callback_data="backmenu")]])
        await query.edit_message_text(prompt, reply_markup=cancel_btn, parse_mode="Markdown")
        return

    # Fallback
    await query.edit_message_text("⚠️ Unknown action. Use /menu to restart.")


# ─────────────────────────────────────────────
#  MESSAGE (STATE MACHINE) HANDLER
# ─────────────────────────────────────────────
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    if not is_admin(chat_id):
        await update.message.reply_text("❌ Unauthorized. Use /id to get your Chat ID.")
        return

    text  = update.message.text.strip()
    state = context.user_data.get('awaiting')

    if not state:
        await update.message.reply_text("ℹ️ Use /menu to open the control panel.")
        return

    cancel_hint = "\n\n_Use /menu to cancel and start over._"

    # ── Add User flow ────────────────────────────
    if state == 'adduser_password':
        context.user_data['adduser_password'] = text
        context.user_data['awaiting'] = 'adduser_days'
        await update.message.reply_text(
            "📅 *Add User — Step 2/4*\n\nEnter validity in days (e.g. `30`):" + cancel_hint,
            parse_mode="Markdown"
        )

    elif state == 'adduser_days':
        if not text.isdigit():
            await update.message.reply_text("❌ Please enter a valid number of days (digits only).")
            return
        context.user_data['adduser_days'] = text
        context.user_data['awaiting'] = 'adduser_quota'
        await update.message.reply_text(
            "📊 *Add User — Step 3/4*\n\nEnter quota (e.g. `10GB` or `500MB`):" + cancel_hint,
            parse_mode="Markdown"
        )

    elif state == 'adduser_quota':
        context.user_data['adduser_quota'] = text
        context.user_data['awaiting'] = 'adduser_hwid'
        await update.message.reply_text(
            "🔒 *Add User — Step 4/4*\n\nEnter client HWID (from ZIVPN app):" + cancel_hint,
            parse_mode="Markdown"
        )

    elif state == 'adduser_hwid':
        password = context.user_data.get('adduser_password', '')
        days     = context.user_data.get('adduser_days', '')
        quota    = context.user_data.get('adduser_quota', '')
        hwid     = text
        await update.message.reply_text("⏳ Creating user...")
        output = run([PANEL_CMD, "--bot-adduser", password, days, quota, hwid])
        await update.message.reply_text(
            f"✅ *User Created Successfully*\n\n```\n{output}\n```",
            parse_mode="Markdown"
        )
        context.user_data.clear()

    # ── Remove User ──────────────────────────────
    elif state == 'removeuser_password':
        await update.message.reply_text("⏳ Removing user...")
        output = run([PANEL_CMD, "--bot-removeuser", text])
        await update.message.reply_text(
            f"🗑️ *Remove User Result*\n\n```\n{output}\n```",
            parse_mode="Markdown"
        )
        context.user_data.clear()

    # ── Renew flow ───────────────────────────────
    elif state == 'renew_password':
        context.user_data['renew_password'] = text
        context.user_data['awaiting'] = 'renew_days'
        await update.message.reply_text(
            "📅 *Renew User — Step 2/2*\n\nEnter additional days to add:" + cancel_hint,
            parse_mode="Markdown"
        )

    elif state == 'renew_days':
        if not text.isdigit():
            await update.message.reply_text("❌ Please enter a valid number of days (digits only).")
            return
        password = context.user_data.get('renew_password', '')
        await update.message.reply_text("⏳ Renewing user...")
        output = run([PANEL_CMD, "--bot-renew", password, text])
        await update.message.reply_text(
            f"🔁 *Renew Result*\n\n```\n{output}\n```",
            parse_mode="Markdown"
        )
        context.user_data.clear()

    # ── Reset Bandwidth ──────────────────────────
    elif state == 'resetbw_password':
        await update.message.reply_text("⏳ Resetting bandwidth...")
        output = run([PANEL_CMD, "--bot-resetbw", text])
        await update.message.reply_text(
            f"🔃 *Bandwidth Reset*\n\n```\n{output}\n```",
            parse_mode="Markdown"
        )
        context.user_data.clear()

    # ── User Info ────────────────────────────────
    elif state == 'userinfo_password':
        await update.message.reply_text("⏳ Fetching user info...")
        output = run([PANEL_CMD, "--bot-userinfo", text])
        await update.message.reply_text(
            f"🔍 *User Info*\n\n```\n{output}\n```",
            parse_mode="Markdown"
        )
        context.user_data.clear()

    # ── Trial ────────────────────────────────────
    elif state == 'trial_minutes':
        if not text.isdigit() or not (1 <= int(text) <= 60):
            await update.message.reply_text("❌ Enter a number between 1 and 60.")
            return
        await update.message.reply_text("⏳ Creating trial user...")
        output = run([PANEL_CMD, "--bot-trial", text])
        await update.message.reply_text(
            f"🧪 *Trial User Created*\n\n```\n{output}\n```",
            parse_mode="Markdown"
        )
        context.user_data.clear()

    # ── Add Admin ────────────────────────────────
    elif state == 'addadmin_chatid':
        new_id = text.strip()
        if not new_id.lstrip('-').isdigit():
            await update.message.reply_text("❌ Invalid Chat ID — must be numeric.")
            return
        with open(ADMINS_FILE, 'a') as f:
            f.write(f"{new_id}\n")
        await update.message.reply_text(
            f"✅ Admin `{new_id}` added successfully.",
            parse_mode="Markdown"
        )
        context.user_data.clear()

    # ── Remove Admin ─────────────────────────────
    elif state == 'removeadmin_chatid':
        rem_id = text.strip()
        if not os.path.exists(ADMINS_FILE):
            await update.message.reply_text("⚠️ No admins file found.")
            return
        with open(ADMINS_FILE, 'r') as f:
            lines = f.readlines()
        new_lines = [l for l in lines if l.strip() != rem_id]
        removed   = len(lines) != len(new_lines)
        with open(ADMINS_FILE, 'w') as f:
            f.writelines(new_lines)
        if removed:
            await update.message.reply_text(
                f"✅ Admin `{rem_id}` removed successfully.",
                parse_mode="Markdown"
            )
        else:
            await update.message.reply_text(
                f"⚠️ Chat ID `{rem_id}` was not found in the admin list.",
                parse_mode="Markdown"
            )
        context.user_data.clear()

    else:
        await update.message.reply_text("⚠️ Unknown state. Use /menu to restart.")
        context.user_data.clear()


# ─────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────
def main():
    if not os.path.exists(BOT_TOKEN_FILE):
        print("❌  Bot token not found. Configure it via the panel first.")
        sys.exit(1)

    with open(BOT_TOKEN_FILE) as f:
        token = f.read().strip()

    if not token:
        print("❌  Bot token file is empty.")
        sys.exit(1)

    print(HEADER)
    print("✅  Bot starting...")

    app = Application.builder().token(token).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("id",    get_id))
    app.add_handler(CommandHandler("menu",  menu_cmd))
    app.add_handler(CallbackQueryHandler(button_callback))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    print("🤖  Bot is running. Press Ctrl+C to stop.\n")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
