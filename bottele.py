import warnings
warnings.filterwarnings("ignore", category=UserWarning, module="apscheduler")

import asyncio
import json
import re
import aiohttp
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, BotCommand
from telegram.ext import Application, CommandHandler, ContextTypes, CallbackQueryHandler
import logging

# ==================== CẤU HÌNH ====================
BOT_TOKEN = "Token bot"  # Thay token bot
ADMIN_IDS = [8250683783]  # ID admin
GROUP_ID = -1003302412963  # ID nhóm chat

TIMEOUT = 15
WAIT_TIME = 15 * 60  # 15 phút
MAX_RETRIES = 3

# L"""ưu trữ VIP users và sessions
vip_users = set()
active_sessions = {}

# Logging - TẮT HẾT LOG
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.CRITICAL  # Chỉ hiện lỗi nghiêm trọng
)
logger = logging.getLogger(__name__)
logger.setLevel(logging.CRITICAL)

# Tắt log của thư viện khác
logging.getLogger('telegram').setLevel(logging.CRITICAL)
logging.getLogger('httpx').setLevel(logging.CRITICAL)
logging.getLogger('httpcore').setLevel(logging.CRITICAL)
logging.getLogger('aiohttp').setLevel(logging.CRITICAL)

# ==================== LOAD/SAVE VIP ====================
def load_vip_users():
    """Load danh sách VIP từ file"""
    try:
        with open('vip_users.json', 'r') as f:
            data = json.load(f)
            return set(data.get('users', []))
    except FileNotFoundError:
        return set()
    except json.JSONDecodeError:
        return set()

def save_vip_users():
    """Lưu danh sách VIP vào file"""
    try:
        with open('vip_users.json', 'w') as f:
            json.dump({'users': list(vip_users)}, f)
    except Exception:
        pass

vip_users = load_vip_users()

# ==================== SESSION STATS ====================
class SessionStats:
    def __init__(self, user_id, aweme_id, mode):
        self.user_id = user_id
        self.aweme_id = aweme_id
        self.mode = mode
        self.total_likes = 0
        self.total_views = 0
        self.cycles = 0
        self.start_time = datetime.now()
        self.last_stats = {}
        self.is_running = False
        self.task = None

    def add_likes(self, amount):
        self.total_likes += amount

    def add_views(self, amount):
        self.total_views += amount

    def increment_cycle(self):
        self.cycles += 1

    def get_runtime(self):
        delta = datetime.now() - self.start_time
        hours = delta.seconds // 3600
        minutes = (delta.seconds % 3600) // 60
        return f"{hours}h {minutes}m"

    def update_last_stats(self, stats_data):
        if stats_data:
            self.last_stats = stats_data

# ==================== HELPER FUNCTIONS ====================
def is_admin(user_id):
    return user_id in ADMIN_IDS

def is_vip(user_id):
    return user_id in vip_users or is_admin(user_id)

# ==================== API FUNCTIONS ====================
async def resolve_short_url(short_url):
    """Giải quyết link rút gọn TikTok (vt.tiktok.com, vm.tiktok.com)"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                short_url, 
                allow_redirects=True,
                timeout=aiohttp.ClientTimeout(total=10)
            ) as response:
                return str(response.url)
    except Exception:
        return short_url

async def extract_aweme_id(url):
    """Tách aweme_id từ URL TikTok"""
    # Nếu là link rút gọn, giải quyết trước
    if 'vt.tiktok.com' in url or 'vm.tiktok.com' in url:
        url = await resolve_short_url(url)

    patterns = [
        r'/video/(\d+)',
        r'@[\w\.]+/video/(\d+)',
        r'v/(\d+)',
        r'/(\d{19})',
    ]

    for pattern in patterns:
        m = re.search(pattern, url)
        if m:
            return m.group(1)
    return None

async def get_aweme_id_from_api(link):
    """Lấy aweme_id từ API Like3s"""
    # Giải quyết link rút gọn trước
    if 'vt.tiktok.com' in link or 'vm.tiktok.com' in link:
        link = await resolve_short_url(link)

    api_url = f"https://api.like3s.vn/api/extension/find-uid?link={link}"

    for attempt in range(MAX_RETRIES):
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(api_url, timeout=aiohttp.ClientTimeout(total=TIMEOUT)) as response:
                    data = await response.json()

                    if data.get("code") == 200 and data.get("data"):
                        uid = data["data"].get("uid")
                        if uid:
                            return str(uid)
        except Exception:
            if attempt < MAX_RETRIES - 1:
                await asyncio.sleep(2)

    return None

async def get_token(aweme_id):
    """Lấy token từ tikfollowers API - thử liên tục"""
    url = "https://tikfollowers.com/api/search"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Content-Type": "application/json"
    }
    payload = {"input": aweme_id, "type": "videoDetails"}

    while True:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=payload, headers=headers, timeout=aiohttp.ClientTimeout(total=TIMEOUT)) as response:
                    data = await response.json()

                    if data.get("success"):
                        return data.get("token")
        except Exception:
            pass

        # Đợi 30s rồi thử lại
        await asyncio.sleep(30)

async def send_process(aweme_id, token, type_action):
    """Gửi yêu cầu like/view"""
    url = "https://tikfollowers.com/api/process"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Content-Type": "application/json"
    }
    payload = {
        "type": type_action,
        "token": token,
        "aweme_id": aweme_id,
        "amount": 20,
        "target_identifier": {"aweme_id": aweme_id}
    }

    for attempt in range(MAX_RETRIES):
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=payload, headers=headers, timeout=aiohttp.ClientTimeout(total=TIMEOUT)) as response:
                    return await response.json()
        except Exception:
            if attempt < MAX_RETRIES - 1:
                await asyncio.sleep(2)

    return {"success": False}

# ==================== MESSAGE BUILDERS ====================
def build_stats_message(session):
    """Tạo message thống kê"""
    message = f"""
📊 <b>THỐNG KÊ PHIÊN CHẠY</b>

⏱️ <b>Thời gian:</b> {session.get_runtime()}
🔄 <b>Chu kỳ:</b> {session.cycles}
🎯 <b>Chế độ:</b> {session.mode}

📈 <b>Đã gửi:</b>
"""

    if session.mode in ["Like", "Both"]:
        message += f"❤️ Like: <code>{session.total_likes:,}</code>\n"
    if session.mode in ["View", "Both"]:
        message += f"👁️ View: <code>{session.total_views:,}</code>\n"

    if session.last_stats:
        message += f"""
📹 <b>Thống kê video:</b>
❤️ Like: <code>{session.last_stats.get('digg_count', 0):,}</code>
👁️ View: <code>{session.last_stats.get('play_count', 0):,}</code>
💬 Comment: <code>{session.last_stats.get('comment_count', 0):,}</code>
🔄 Share: <code>{session.last_stats.get('share_count', 0):,}</code>
⭐ Favorite: <code>{session.last_stats.get('collect_count', 0):,}</code>
"""

    message += f"\n📌 <b>Video ID:</b> <code>{session.aweme_id}</code>"
    return message

# ==================== AUTO SESSION ====================
async def run_auto_session(context, session):
    """Chạy session tự động"""
    user_id = session.user_id

    while session.is_running:
        try:
            # Lấy token (thử liên tục)
            token = await get_token(session.aweme_id)

            success = False

            # LIKE
            if session.mode in ["Like", "Both"]:
                result = await send_process(session.aweme_id, token, "like")

                if result.get("success"):
                    amount = result.get("data", {}).get("amount_processed", 0)
                    session.add_likes(amount)

                    video_stats = result.get("data", {}).get("stats", {})
                    if video_stats:
                        session.update_last_stats(video_stats)

                    success = True

            # VIEW
            if session.mode in ["View", "Both"]:
                result = await send_process(session.aweme_id, token, "video_views")

                if result.get("success"):
                    amount = result.get("data", {}).get("amount_processed", 0)
                    session.add_views(amount)

                    video_stats = result.get("data", {}).get("stats", {})
                    if video_stats:
                        session.update_last_stats(video_stats)

                    success = True

            if success:
                session.increment_cycle()

                # Gửi thông báo
                message = f"""
✅ <b>Chu kỳ #{session.cycles} hoàn thành!</b>

❤️ Tổng Like: <code>{session.total_likes:,}</code>
👁️ Tổng View: <code>{session.total_views:,}</code>

⏰ Chờ 15 phút cho chu kỳ tiếp theo...
"""
                await context.bot.send_message(
                    chat_id=user_id,
                    text=message,
                    parse_mode='HTML'
                )

            # Đợi 15 phút
            if session.is_running:
                await asyncio.sleep(WAIT_TIME)

        except Exception:
            await asyncio.sleep(30)

# ==================== COMMANDS ====================
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /start"""
    keyboard = [
        [InlineKeyboardButton("📖 Hướng dẫn", callback_data="help")],
        [InlineKeyboardButton("📊 Thống kê", callback_data="stats")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)

    message = """
🚀 <b>TIKTOK AUTO TOOL</b>

Chào mừng bạn đến với bot tăng Like/View TikTok!

<b>Lệnh cơ bản:</b>
/like [link] - Tăng Like 1 lần
/view [link] - Tăng View 1 lần

<b>Lệnh VIP:</b>
/auto [link] - Tự động Like + View
/autolike [link] - Tự động Like
/autoview [link] - Tự động View
/stop - Dừng auto

<b>Admin:</b>
/addvip [user_id] - Cấp VIP
/removevip [user_id] - Xóa VIP
/listvip - Xem danh sách VIP

💡 Link hỗ trợ: vt.tiktok.com, vm.tiktok.com, link đầy đủ
"""

    await update.message.reply_text(
        message,
        parse_mode='HTML',
        reply_markup=reply_markup
    )

async def like_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /like [link]"""
    if not context.args:
        await update.message.reply_text("❌ Vui lòng nhập link!\nVí dụ: /like https://vt.tiktok.com/...")
        return

    link = context.args[0]
    msg = await update.message.reply_text("🔍 Đang xử lý...")

    # Lấy ID
    aweme_id = await extract_aweme_id(link)

    if not aweme_id:
        await msg.edit_text("🔄 Thử API phụ...")
        aweme_id = await get_aweme_id_from_api(link)

    if not aweme_id:
        await msg.edit_text("❌ Không thể lấy ID video. Vui lòng kiểm tra link!")
        return

    # Lấy token
    await msg.edit_text("🔑 Đang lấy token...")
    token = await get_token(aweme_id)

    # Gửi like
    await msg.edit_text("❤️ Đang gửi Like...")
    result = await send_process(aweme_id, token, "like")

    if result.get("success"):
        amount = result.get("data", {}).get("amount_processed", 0)
        await msg.edit_text(
            f"✅ <b>Thành công!</b>\n\n"
            f"❤️ Đã tăng <code>{amount}</code> Like\n"
            f"📌 Video ID: <code>{aweme_id}</code>",
            parse_mode='HTML'
        )
    else:
        await msg.edit_text("❌ Gửi Like thất bại, đợi 15 phút buff tiếp hoặc thay link khác!")

async def view_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /view [link]"""
    if not context.args:
        await update.message.reply_text("❌ Vui lòng nhập link!\nVí dụ: /view https://vt.tiktok.com/...")
        return

    link = context.args[0]
    msg = await update.message.reply_text("🔍 Đang xử lý...")

    # Lấy ID
    aweme_id = await extract_aweme_id(link)

    if not aweme_id:
        await msg.edit_text("🔄 Thử API phụ...")
        aweme_id = await get_aweme_id_from_api(link)

    if not aweme_id:
        await msg.edit_text("❌ Không thể lấy ID video. Vui lòng kiểm tra link!")
        return

    # Lấy token
    await msg.edit_text("🔑 Đang lấy token...")
    token = await get_token(aweme_id)

    # Gửi view
    await msg.edit_text("👁️ Đang gửi View...")
    result = await send_process(aweme_id, token, "video_views")

    if result.get("success"):
        amount = result.get("data", {}).get("amount_processed", 0)
        await msg.edit_text(
            f"✅ <b>Thành công!</b>\n\n"
            f"👁️ Đã tăng <code>{amount}</code> View\n"
            f"📌 Video ID: <code>{aweme_id}</code>",
            parse_mode='HTML'
        )
    else:
        await msg.edit_text("❌ Gửi View thất bại, đợi 15 phút buff tiếp hoặc thay link khác!")

async def auto_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /auto [link] - VIP only"""
    user_id = update.effective_user.id

    if not is_vip(user_id):
        await update.message.reply_text("🚫 Bạn cần VIP để dùng lệnh này!\nLiên hệ admin.")
        return

    if user_id in active_sessions and active_sessions[user_id].is_running:
        await update.message.reply_text("⚠️ Bạn đang có phiên auto!\nDùng /stop để dừng.")
        return

    if not context.args:
        await update.message.reply_text("❌ Vui lòng nhập link!\nVí dụ: /auto https://vt.tiktok.com/...")
        return

    link = context.args[0]
    msg = await update.message.reply_text("🔍 Đang xử lý...")

    # Lấy ID
    aweme_id = await extract_aweme_id(link)

    if not aweme_id:
        await msg.edit_text("🔄 Thử API phụ...")
        aweme_id = await get_aweme_id_from_api(link)

    if not aweme_id:
        await msg.edit_text("❌ Không thể lấy ID video!")
        return

    # Tạo session
    session = SessionStats(user_id, aweme_id, "Both")
    active_sessions[user_id] = session
    session.is_running = True

    await msg.edit_text(
        f"✅ <b>Đã bắt đầu AUTO!</b>\n\n"
        f"🎯 Chế độ: Like + View\n"
        f"⏰ Chu kỳ: 15 phút/lần\n"
        f"📌 Video ID: <code>{aweme_id}</code>\n\n"
        f"Dùng /stop để dừng",
        parse_mode='HTML'
    )

    # Start task
    session.task = asyncio.create_task(run_auto_session(context, session))

async def autolike_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /autolike [link] - VIP only"""
    user_id = update.effective_user.id

    if not is_vip(user_id):
        await update.message.reply_text("🚫 Bạn cần VIP để dùng lệnh này!")
        return

    if user_id in active_sessions and active_sessions[user_id].is_running:
        await update.message.reply_text("⚠️ Bạn đang có phiên auto!\nDùng /stop để dừng.")
        return

    if not context.args:
        await update.message.reply_text("❌ Vui lòng nhập link!")
        return

    link = context.args[0]
    msg = await update.message.reply_text("🔍 Đang xử lý...")

    aweme_id = await extract_aweme_id(link)
    if not aweme_id:
        aweme_id = await get_aweme_id_from_api(link)

    if not aweme_id:
        await msg.edit_text("❌ Không thể lấy ID video!")
        return

    session = SessionStats(user_id, aweme_id, "Like")
    active_sessions[user_id] = session
    session.is_running = True

    await msg.edit_text(
        f"✅ <b>Đã bắt đầu AUTO LIKE!</b>\n\n"
        f"❤️ Chế độ: Like Only\n"
        f"⏰ Chu kỳ: 15 phút/lần\n"
        f"📌 Video ID: <code>{aweme_id}</code>",
        parse_mode='HTML'
    )

    session.task = asyncio.create_task(run_auto_session(context, session))

async def autoview_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /autoview [link] - VIP only"""
    user_id = update.effective_user.id

    if not is_vip(user_id):
        await update.message.reply_text("🚫 Bạn cần VIP để dùng lệnh này!")
        return

    if user_id in active_sessions and active_sessions[user_id].is_running:
        await update.message.reply_text("⚠️ Bạn đang có phiên auto!\nDùng /stop để dừng.")
        return

    if not context.args:
        await update.message.reply_text("❌ Vui lòng nhập link!")
        return

    link = context.args[0]
    msg = await update.message.reply_text("🔍 Đang xử lý...")

    aweme_id = await extract_aweme_id(link)
    if not aweme_id:
        aweme_id = await get_aweme_id_from_api(link)

    if not aweme_id:
        await msg.edit_text("❌ Không thể lấy ID video!")
        return

    session = SessionStats(user_id, aweme_id, "View")
    active_sessions[user_id] = session
    session.is_running = True

    await msg.edit_text(
        f"✅ <b>Đã bắt đầu AUTO VIEW!</b>\n\n"
        f"👁️ Chế độ: View Only\n"
        f"⏰ Chu kỳ: 15 phút/lần\n"
        f"📌 Video ID: <code>{aweme_id}</code>",
        parse_mode='HTML'
    )

    session.task = asyncio.create_task(run_auto_session(context, session))

async def stop_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /stop"""
    user_id = update.effective_user.id

    if user_id not in active_sessions or not active_sessions[user_id].is_running:
        await update.message.reply_text("⚠️ Bạn không có phiên auto nào!")
        return

    session = active_sessions[user_id]
    session.is_running = False

    if session.task:
        session.task.cancel()

    message = build_stats_message(session)
    message = "⏹️ <b>ĐÃ DỪNG PHIÊN</b>\n" + message

    await update.message.reply_text(message, parse_mode='HTML')
    del active_sessions[user_id]

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /stats"""
    user_id = update.effective_user.id

    if user_id not in active_sessions or not active_sessions[user_id].is_running:
        await update.message.reply_text("⚠️ Bạn không có phiên auto nào!")
        return

    session = active_sessions[user_id]
    message = build_stats_message(session)

    await update.message.reply_text(message, parse_mode='HTML')

# ==================== ADMIN COMMANDS ====================
async def addvip_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /addvip [user_id] - Admin only"""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("🚫 Chỉ admin mới dùng được!")
        return

    if not context.args:
        await update.message.reply_text("❌ Vui lòng nhập user ID!\nVí dụ: /addvip 123456789")
        return

    try:
        user_id = int(context.args[0])
        vip_users.add(user_id)
        save_vip_users()

        await update.message.reply_text(
            f"✅ Đã cấp VIP cho user <code>{user_id}</code>!",
            parse_mode='HTML'
        )
    except ValueError:
        await update.message.reply_text("❌ User ID không hợp lệ!")

async def removevip_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /removevip [user_id] - Admin only"""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("🚫 Chỉ admin mới dùng được!")
        return

    if not context.args:
        await update.message.reply_text("❌ Vui lòng nhập user ID!")
        return

    try:
        user_id = int(context.args[0])

        if user_id in vip_users:
            vip_users.discard(user_id)
            save_vip_users()

            # Dừng session nếu có
            if user_id in active_sessions:
                active_sessions[user_id].is_running = False
                if active_sessions[user_id].task:
                    active_sessions[user_id].task.cancel()
                del active_sessions[user_id]

            await update.message.reply_text(
                f"✅ Đã xóa VIP của user <code>{user_id}</code>!",
                parse_mode='HTML'
         )
        else:
            await update.message.reply_text("⚠️ User này không phải VIP!")
    except ValueError:
        await update.message.reply_text("❌ User ID không hợp lệ!")

async def listvip_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Command /listvip - Admin only"""
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("🚫 Chỉ admin mới dùng được!")
        return

    if not vip_users:
        await update.message.reply_text("📋 Chưa có VIP nào!")
        return

    message = "👥 <b>DANH SÁCH VIP</b>\n\n"
    for user_id in vip_users:
        status = "🟢 Đang auto" if user_id in active_sessions and active_sessions[user_id].is_running else "⚪ Offline"
        message += f"• <code>{user_id}</code> - {status}\n"

    message += f"\n📊 Tổng: <b>{len(vip_users)}</b> VIP"

    await update.message.reply_text(message, parse_mode='HTML')

# ==================== BUTTON HANDLERS ====================
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Xử lý callback buttons"""
    query = update.callback_query
    await query.answer()

    if query.data == "help":
        message = """
📖 <b>HƯỚNG DẪN SỬ DỤNG</b>

<b>🎯 Lệnh cơ bản (Tất cả):</b>
/like [link] - Tăng Like 1 lần
/view [link] - Tăng View 1 lần

<b>💎 Lệnh VIP:</b>
/auto [link] - Tự động Like + View
/autolike [link] - Tự động Like
/autoview [link] - Tự động View
/stop - Dừng phiên auto
/stats - Xem thống kê

<b>👑 Lệnh Admin:</b>
/addvip [user_id] - Cấp VIP
/removevip [user_id] - Xóa VIP
/listvip - Xem danh sách VIP

<b>💡 Lưu ý:</b>
• Link hỗ trợ: vt.tiktok.com, vm.tiktok.com
• Auto chạy mỗi 15 phút/lần
• Mỗi user chỉ 1 phiên auto
"""
        await query.edit_message_text(message, parse_mode='HTML')

    elif query.data == "stats":
        user_id = query.from_user.id
        if user_id in active_sessions and active_sessions[user_id].is_running:
            message = build_stats_message(active_sessions[user_id])
            await query.edit_message_text(message, parse_mode='HTML')
        else:
            await query.edit_message_text("⚠️ Bạn không có phiên auto nào!")

# ==================== SETUP BOT COMMANDS ====================
async def post_init(application: Application):
    """Thiết lập menu commands sau khi bot khởi động"""
    commands = [
        BotCommand("start", "Khởi động bot"),
        BotCommand("like", "Tăng Like 1 lần"),
        BotCommand("view", "Tăng View 1 lần"),
        BotCommand("auto", "Auto Like + View (VIP)"),
        BotCommand("autolike", "Auto Like (VIP)"),
        BotCommand("autoview", "Auto View (VIP)"),
        BotCommand("stop", "Dừng Auto"),
        BotCommand("stats", "Xem thống kê"),
        BotCommand("addvip", "Cấp VIP (Admin)"),
        BotCommand("removevip", "Xóa VIP (Admin)"),
        BotCommand("listvip", "Danh sách VIP (Admin)")
    ]
    
    try:
        await application.bot.set_my_commands(commands)
        print("✅ Menu commands đã được cập nhật")
    except Exception as e:
        print(f"❌ Lỗi khi cập nhật menu: {e}")


# ================== KHỞI ĐỘNG BOT ==================

if __name__ == "__main__":
    application = (
        Application.builder()
        .token(BOT_TOKEN)
        .post_init(post_init)
        .build()
    )

    # Command handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("like", like_command))
    application.add_handler(CommandHandler("view", view_command))
    application.add_handler(CommandHandler("auto", auto_command))
    application.add_handler(CommandHandler("autolike", autolike_command))
    application.add_handler(CommandHandler("autoview", autoview_command))
    application.add_handler(CommandHandler("stop", stop_command))
    application.add_handler(CommandHandler("stats", stats_command))
    application.add_handler(CommandHandler("addvip", addvip_command))
    application.add_handler(CommandHandler("removevip", removevip_command))
    application.add_handler(CommandHandler("listvip", listvip_command))

    # Button callbacks
    application.add_handler(CallbackQueryHandler(button_handler))

    print("🚀 Bot đang chạy trên Python 3.12 ...")
    application.run_polling()   # ⬅️ KHÔNG CẦN await, không dùng asyncio.run()