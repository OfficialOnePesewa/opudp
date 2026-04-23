#!/usr/bin/env python3
"""
OP UDP Panel Telegram Bot – Full admin control & user self-service.
Requires: python-telegram-bot, panel script at /usr/local/bin/onepesewa.
"""

import os
import subprocess
import sys
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes, MessageHandler, filters

# ── Paths ─────────────────────────────────────────────────────────────────────
BOT_TOKEN_FILE = "/etc/zivpn/telegram_token"
ADMINS_FILE = "/etc/zivpn/bot_admins.db"
PANEL_CMD = "/usr/local/bin/onepesewa"

# ── Helper: admin check ───────────────────────────────────────────────────────
def is_admin(chat_id):
    if not os.path.exists(ADMINS_FILE):
        return False
    with open(ADMINS_FILE) as f:
        admins = [line.strip() for line in f if line.strip()]
    return str(chat_id) in admins

# ── Keyboard generator ────────────────────────────────────────────────────────
def get_main_keyboard():
    """Returns the main inline keyboard used in /menu and callbacks."""
    return [
        [InlineKeyboardButton("📊 Status", callback_data="status")],
        [InlineKeyboardButton("➕ Add User", callback_data="adduser")],
        [InlineKeyboardButton("➖ Remove User", callback_data="removeuser")],
        [InlineKeyboardButton("🔁 Renew User", callback_data="renew")],
        [InlineKeyboardButton("🔃 Reset Bandwidth", callback_data="resetbw")],
        [InlineKeyboardButton("👤 User Info", callback_data="userinfo")],
        [InlineKeyboardButton("📋 List Users", callback_data="list")],
        [InlineKeyboardButton("🧹 Cleanup Expired", callback_data="cleanup")],
        [InlineKeyboardButton("🧪 Trial User", callback_data="trial")],
        [InlineKeyboardButton("🚀 Install BBR", callback_data="bbr")],
        [InlineKeyboardButton("📡 Install BadVPN", callback_data="badvpn")],
        [InlineKeyboardButton("👑 Admin Management", callback_data="adminmenu")],
    ]

# ── Commands ──────────────────────────────────────────────────────────────────
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    if is_admin(chat_id):
        await update.message.reply_text(
            "🤖 *Welcome, admin!*\nUse /menu to manage the server.\n"
            "Users can check their account with /mystatus.",
            parse_mode="Markdown"
        )
    else:
        await update.message.reply_text(
            f"❌ You are not authorized as admin.\n"
            f"Your Chat ID is `{chat_id}` – ask the main admin to add it.\n\n"
            f"👉 As a user you can check your own status:\n`/mystatus <your_full_password>`",
            parse_mode="Markdown"
        )

async def get_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    await update.message.reply_text(f"📱 Your Chat ID: `{chat_id}`", parse_mode="Markdown")

async def my_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not context.args:
        await update.message.reply_text("Usage: `/mystatus <your_full_password>`", parse_mode="Markdown")
        return
    password = " ".join(context.args)
    result = subprocess.run(
        [PANEL_CMD, "--bot-userstatus", password],
        capture_output=True, text=True, timeout=15
    )
    if result.returncode != 0 or "not found" in result.stdout.lower():
        await update.message.reply_text("❌ Password not found or invalid.")
    else:
        await update.message.reply_text(f"📊 *Your Account Status*\n{result.stdout}", parse_mode="Markdown")

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "ℹ️ *Available commands:*\n"
        "/start – Welcome message\n"
        "/id – Show your Telegram Chat ID\n"
        "/mystatus <password> – Check your account (for any user)\n"
        "/menu – Admin control panel",
        parse_mode="Markdown"
    )

# ── Admin menu (sent as new message when using /menu) ─────────────────────────
async def menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    if not is_admin(chat_id):
        await update.message.reply_text("❌ Unauthorized.")
        return
    await update.message.reply_text(
        "Choose an action:",
        reply_markup=InlineKeyboardMarkup(get_main_keyboard())
    )

# ── Callback handler (button presses) ────────────────────────────────────────
async def button_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    chat_id = update.effective_chat.id
    if not is_admin(chat_id):
        await query.edit_message_text("❌ Unauthorized.")
        return

    data = query.data

    # --- Direct actions (non‑state) ---
    if data == "status":
        result = subprocess.run([PANEL_CMD, "--bot-status"], capture_output=True, text=True, timeout=10)
        await query.edit_message_text(f"📡 *Server Status*\n{result.stdout}", parse_mode="Markdown")

    elif data == "list":
        result = subprocess.run([PANEL_CMD, "--bot-list"], capture_output=True, text=True, timeout=10)
        await query.edit_message_text(f"📋 *User List*\n{result.stdout}", parse_mode="Markdown")

    elif data == "cleanup":
        result = subprocess.run([PANEL_CMD, "--bot-cleanup"], capture_output=True, text=True, timeout=30)
        await query.edit_message_text(f"🧹 {result.stdout}")

    elif data == "trial":
        context.user_data['awaiting'] = 'trial_minutes'
        await query.edit_message_text("⏱ Enter trial minutes (1–60):")

    elif data == "bbr":
        await query.edit_message_text("🚀 Installing BBR optimizer (this may take a while)...")
        result = subprocess.run([PANEL_CMD, "--bot-bbr"], capture_output=True, text=True, timeout=120)
        await query.edit_message_text(f"🚀 {result.stdout}")

    elif data == "badvpn":
        await query.edit_message_text("📡 Installing BadVPN...")
        result = subprocess.run([PANEL_CMD, "--bot-badvpn"], capture_output=True, text=True, timeout=120)
        await query.edit_message_text(f"📡 {result.stdout}")

    # --- Actions that require further text input ---
    elif data == "adduser":
        context.user_data['awaiting'] = 'adduser_password'
        await query.edit_message_text("➕ Step 1/4: Send the *base password*.")

    elif data == "removeuser":
        context.user_data['awaiting'] = 'removeuser_password'
        await query.edit_message_text("➖ Send the *full password* of the user to remove.")

    elif data == "renew":
        context.user_data['awaiting'] = 'renew_password'
        await query.edit_message_text("🔁 Send the *full password* of the user to renew.")

    elif data == "resetbw":
        context.user_data['awaiting'] = 'resetbw_password'
        await query.edit_message_text("🔃 Send the *full password* to reset bandwidth.")

    elif data == "userinfo":
        context.user_data['awaiting'] = 'userinfo_password'
        await query.edit_message_text("👤 Send the *full password* to view account info.")

    # --- Admin management sub‑menu ---
    elif data == "adminmenu":
        keyboard = [
            [InlineKeyboardButton("➕ Add Admin", callback_data="addadmin")],
            [InlineKeyboardButton("➖ Remove Admin", callback_data="removeadmin")],
            [InlineKeyboardButton("📄 List Admins", callback_data="listadmins")],
            [InlineKeyboardButton("◀️ Back to Menu", callback_data="menu")],
        ]
        await query.edit_message_text("👑 Admin Management:", reply_markup=InlineKeyboardMarkup(keyboard))

    elif data == "addadmin":
        context.user_data['awaiting'] = 'addadmin_chatid'
        await query.edit_message_text("➕ Send the *Telegram Chat ID* of the new admin.")

    elif data == "removeadmin":
        context.user_data['awaiting'] = 'removeadmin_chatid'
        await query.edit_message_text("➖ Send the *Chat ID* of the admin to remove.")

    elif data == "listadmins":
        if not os.path.exists(ADMINS_FILE):
            await query.edit_message_text("No admins configured.")
            return
        with open(ADMINS_FILE) as f:
            admins = f.read().strip()
        await query.edit_message_text(f"👥 *Admins*\n`{admins}`", parse_mode="Markdown")

    elif data == "menu":
        # Go back to main menu – edit current message
        await query.edit_message_text(
            "Choose an action:",
            reply_markup=InlineKeyboardMarkup(get_main_keyboard())
        )
        # Clear any pending state
        context.user_data.pop('awaiting', None)

    else:
        await query.edit_message_text("❓ Unknown option.")

# ── Text message handler (for step‑by‑step operations) ───────────────────────
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    if not is_admin(chat_id):
        await update.message.reply_text("❌ Unauthorized. Use /mystatus to check your account.")
        return

    text = update.message.text.strip()
    state = context.user_data.get('awaiting')

    if not state:
        await update.message.reply_text("Use /menu to start an action.")
        return

    # ── Add user flow ──
    if state == 'adduser_password':
        context.user_data['adduser_password'] = text
        context.user_data['awaiting'] = 'adduser_days'
        await update.message.reply_text("⏳ Step 2/4: Enter validity in *days*.")

    elif state == 'adduser_days':
        if not text.isdigit():
            await update.message.reply_text("❌ Please send a number (days).")
            return
        context.user_data['adduser_days'] = text
        context.user_data['awaiting'] = 'adduser_quota'
        await update.message.reply_text("📊 Step 3/4: Enter *quota* (e.g. 10GB or 500MB).")

    elif state == 'adduser_quota':
        context.user_data['adduser_quota'] = text
        context.user_data['awaiting'] = 'adduser_hwid'
        await update.message.reply_text("🔐 Step 4/4: Enter *client HWID* (from ZIVPN app).")

    elif state == 'adduser_hwid':
        hwid = text
        password = context.user_data['adduser_password']
        days = context.user_data['adduser_days']
        quota = context.user_data['adduser_quota']
        result = subprocess.run(
            [PANEL_CMD, "--bot-adduser", password, days, quota, hwid],
            capture_output=True, text=True, timeout=15
        )
        await update.message.reply_text(f"✅ User created:\n{result.stdout}")
        context.user_data['awaiting'] = None
        # Show menu again
        await update.message.reply_text(
            "What would you like to do next?",
            reply_markup=InlineKeyboardMarkup(get_main_keyboard())
        )

    # ── Renew flow ──
    elif state == 'renew_password':
        context.user_data['renew_password'] = text
        context.user_data['awaiting'] = 'renew_days'
        await update.message.reply_text("⏳ Send the number of *days to add*.")

    elif state == 'renew_days':
        if not text.isdigit():
            await update.message.reply_text("❌ Please send a number.")
            return
        result = subprocess.run(
            [PANEL_CMD, "--bot-renew", context.user_data['renew_password'], text],
            capture_output=True, text=True, timeout=10
        )
        await update.message.reply_text(result.stdout)
        context.user_data['awaiting'] = None
        await update.message.reply_text(
            "What would you like to do next?",
            reply_markup=InlineKeyboardMarkup(get_main_keyboard())
        )

    # ── Single‑step commands ──
    elif state == 'removeuser_password':
        result = subprocess.run(
            [PANEL_CMD, "--bot-removeuser", text],
            capture_output=True, text=True, timeout=10
        )
        await update.message.reply_text(result.stdout)
        context.user_data['awaiting'] = None

    elif state == 'resetbw_password':
        result = subprocess.run(
            [PANEL_CMD, "--bot-resetbw", text],
            capture_output=True, text=True, timeout=10
        )
        await update.message.reply_text(result.stdout)
        context.user_data['awaiting'] = None

    elif state == 'userinfo_password':
        result = subprocess.run(
            [PANEL_CMD, "--bot-userinfo", text],
            capture_output=True, text=True, timeout=10
        )
        await update.message.reply_text(result.stdout)
        context.user_data['awaiting'] = None

    elif state == 'trial_minutes':
        result = subprocess.run(
            [PANEL_CMD, "--bot-trial", text],
            capture_output=True, text=True, timeout=15
        )
        await update.message.reply_text(result.stdout)
        context.user_data['awaiting'] = None

    # ── Admin list modifications ──
    elif state == 'addadmin_chatid':
        chat_id_new = text.strip()
        if not chat_id_new.isdigit():
            await update.message.reply_text("❌ Invalid Chat ID, must be a number.")
            return
        os.makedirs(os.path.dirname(ADMINS_FILE), exist_ok=True)
        with open(ADMINS_FILE, 'a') as f:
            f.write(f"{chat_id_new}\n")
        await update.message.reply_text(f"✅ Admin {chat_id_new} added.")
        context.user_data['awaiting'] = None

    elif state == 'removeadmin_chatid':
        chat_id_rem = text.strip()
        if not os.path.exists(ADMINS_FILE):
            await update.message.reply_text("No admins file.")
            return
        with open(ADMINS_FILE, 'r') as f:
            lines = f.readlines()
        with open(ADMINS_FILE, 'w') as f:
            for line in lines:
                if line.strip() != chat_id_rem:
                    f.write(line)
        await update.message.reply_text(f"✅ Admin {chat_id_rem} removed.")
        context.user_data['awaiting'] = None

    else:
        await update.message.reply_text("❓ Unknown state. Use /menu.")

# ── Main entry point ──────────────────────────────────────────────────────────
def main():
    if not os.path.exists(BOT_TOKEN_FILE):
        print("❌ Bot token not found. Please configure via panel first.")
        sys.exit(1)

    with open(BOT_TOKEN_FILE) as f:
        token = f.read().strip()

    app = Application.builder().token(token).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("id", get_id))
    app.add_handler(CommandHandler("mystatus", my_status))
    app.add_handler(CommandHandler("menu", menu))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CallbackQueryHandler(button_callback))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    print("✅ Bot started – polling...")
    app.run_polling()

if __name__ == "__main__":
    main()
