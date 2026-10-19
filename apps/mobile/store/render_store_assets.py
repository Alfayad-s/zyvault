"""Play Store graphics for zyvault. Run: python3 render_store_assets.py"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
FONTS = ROOT / "fonts"
OUT = ROOT

INK = (22, 24, 29)
MUTED = (109, 114, 128)
LIME = (200, 245, 122)
GREEN = (61, 220, 132)
WHITE = (255, 255, 255)
PAPER = (246, 247, 244)
PHONE = (17, 17, 17)
CARD = (44, 44, 46)
LINE = (58, 58, 60)
SOFT = (142, 142, 147)
DARK = (22, 22, 22)

S = 2


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size * S)


EB = "PlusJakartaSans-ExtraBold.ttf"
BD = "PlusJakartaSans-Bold.ttf"
MD = "PlusJakartaSans-Medium.ttf"
RG = "PlusJakartaSans-Regular.ttf"


def new(w: int, h: int, color) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (w * S, h * S), color)
    return image, ImageDraw.Draw(image)


def save(image: Image.Image, name: str, w: int, h: int) -> None:
    image.resize((w, h), Image.Resampling.LANCZOS).save(OUT / name, "PNG", optimize=True)


def text_width(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont) -> int:
    return int(draw.textlength(text, font=face))


def wordmark(draw: ImageDraw.ImageDraw, x: int, y: int, size: int, ink=INK) -> int:
    face = font(EB, size)
    label = "zyvault"
    draw.text((x * S, y * S), label, font=face, fill=ink)
    width = text_width(draw, label, face) / S
    ascent, _ = face.getmetrics()
    dot = max(8, int(size * 0.22))
    gap = max(3, int(size * 0.06))
    left = x + width + gap
    top = y + (ascent / S) - dot - size * 0.04
    draw.ellipse(
        (left * S, top * S, (left + dot) * S, (top + dot) * S),
        fill=LIME,
    )
    return int(width + gap + dot)


def round_rect(draw, box, radius, fill):
    x0, y0, x1, y1 = [v * S for v in box]
    draw.rounded_rectangle((x0, y0, x1, y1), radius=radius * S, fill=fill)


def label(draw, xy, text, face, fill):
    draw.text((xy[0] * S, xy[1] * S), text, font=face, fill=fill)


def shadow_phone(base: Image.Image, box, radius: int) -> None:
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    paint = ImageDraw.Draw(layer)
    paint.rounded_rectangle(
        ((x0 + 8) * S, (y0 + 28) * S, (x1 - 8) * S, (y1 + 18) * S),
        radius=radius * S,
        fill=(22, 24, 29, 48),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(18 * S))
    base.paste(Image.alpha_composite(base.convert("RGBA"), layer).convert("RGB"))


def status_bar(draw, x, y, w):
    face = font(MD, 13)
    label(draw, (x + 22, y + 16), "9:41", face, WHITE)
    label(draw, (x + w - 78, y + 16), "5G", face, WHITE)


def app_bar(draw, x, y, w, title: str):
    face = font(BD, 17)
    tw = text_width(draw, title, face) / S
    label(draw, (x + (w - tw) / 2, y + 8), title, face, WHITE)
    round_rect(draw, (x + w - 46, y + 4, x + w - 16, y + 34), 15, LINE)
    label(draw, (x + w - 37, y + 8), "F", font(BD, 13), WHITE)


def bottom_nav(draw, x, y, w, selected: int):
    names = ["Home", "Activity", "Money", "Scheduled"]
    pill_w = 318
    pill_h = 52
    left = x + (w - pill_w - 64) / 2
    top = y
    round_rect(draw, (left, top, left + pill_w, top + pill_h), 26, DARK)
    slot = pill_w / 4
    for index, name in enumerate(names):
        color = WHITE if index == selected else SOFT
        face = font(BD, 10)
        tw = text_width(draw, name, face) / S
        label(draw, (left + slot * index + (slot - tw) / 2, top + 18), name, face, color)
    add = left + pill_w + 12
    round_rect(draw, (add, top, add + 52, top + 52), 26, DARK)
    face = font(EB, 22)
    label(draw, (add + 16, top + 10), "+", face, WHITE)


def row(draw, x, y, w, title, meta, amount, positive=False):
    round_rect(draw, (x, y, x + w, y + 64), 16, CARD)
    label(draw, (x + 16, y + 12), title, font(BD, 15), WHITE)
    label(draw, (x + 16, y + 34), meta, font(RG, 12), SOFT)
    face = font(EB, 15)
    color = GREEN if positive else WHITE
    tw = text_width(draw, amount, face) / S
    label(draw, (x + w - 16 - tw, y + 22), amount, face, color)


def screenshot(filename, headline, sub, selected, body):
    image, draw = new(1080, 1920, PAPER)
    label(draw, (72, 72), headline, font(EB, 48), INK)
    label(draw, (72, 142), sub, font(MD, 22), MUTED)
    probe = ImageDraw.Draw(Image.new("RGB", (1080 * S, 4000 * S), PHONE))
    content_end = body(probe, 138, 360, 804)
    content_h = content_end - 360
    chrome = 118 if selected is not None else 72
    phone_h = 62 + content_h + chrome
    top = 220 + max(0, (1620 - phone_h) / 2)
    box = (110, top, 970, top + phone_h)
    shadow_phone(image, box, 48)
    draw = ImageDraw.Draw(image)
    round_rect(draw, box, 48, PHONE)
    status_bar(draw, box[0], box[1] + 8, box[2] - box[0])
    body(draw, box[0] + 28, box[1] + 62, 804)
    if selected is not None:
        bottom_nav(draw, box[0], box[3] - 78, box[2] - box[0], selected)
    save(image, filename, 1080, 1920)


def icon():
    image, draw = new(512, 512, WHITE)
    size = 72
    face = font(EB, size)
    width = text_width(draw, "zyvault", face) / S
    dot = max(8, int(size * 0.22))
    gap = max(3, int(size * 0.06))
    total = width + gap + dot
    x = (512 - total) / 2
    y = (512 - size) / 2 - 6
    wordmark(draw, x, y, size)
    save(image, "icon-512.png", 512, 512)


def feature():
    image, draw = new(1024, 500, WHITE)
    wordmark(draw, 64, 118, 86)
    label(draw, (64, 250), "An Android money tracker you talk to", font(MD, 26), INK)
    facts = ["English, Malayalam, Hinglish", "Budgets, goals, who owes whom", "Alerts stay on the phone"]
    x = 64
    for fact in facts:
        face = font(BD, 16)
        tw = text_width(draw, fact, face) / S
        round_rect(draw, (x, 330, x + tw + 36, 372), 21, (244, 247, 232))
        draw.ellipse(((x + 14) * S, 346 * S, (x + 26) * S, 358 * S), fill=LIME)
        label(draw, (x + 32, 340), fact, face, INK)
        x += tw + 48
    save(image, "feature-graphic-1024x500.png", 1024, 500)


def screen_home(draw, x, y, w):
    app_bar(draw, x, y, w, "Home")
    y += 52
    round_rect(draw, (x, y, x + w, y + 168), 22, CARD)
    label(draw, (x + 18, y + 16), "Balance", font(MD, 13), SOFT)
    label(draw, (x + 18, y + 40), "₹48,260", font(EB, 36), WHITE)
    label(draw, (x + 18, y + 96), "+₹22,160 this month", font(BD, 14), GREEN)
    round_rect(draw, (x + w - 196, y + 112, x + w - 108, y + 148), 16, LINE)
    label(draw, (x + w - 178, y + 120), "Receive", font(BD, 13), WHITE)
    round_rect(draw, (x + w - 96, y + 112, x + w - 16, y + 148), 16, LIME)
    label(draw, (x + w - 74, y + 120), "Send", font(BD, 13), (23, 49, 12))
    y += 184
    gap = 12
    half = (w - gap) / 2
    round_rect(draw, (x, y, x + half, y + 118), 18, CARD)
    label(draw, (x + 14, y + 12), "Spending", font(BD, 15), WHITE)
    label(draw, (x + 14, y + 34), "Spent in October", font(RG, 12), SOFT)
    label(draw, (x + 14, y + 68), "₹12,840", font(EB, 20), WHITE)
    right = x + half + gap
    round_rect(draw, (right, y, right + half, y + 118), 18, CARD)
    label(draw, (right + 14, y + 12), "Next payment", font(BD, 15), WHITE)
    label(draw, (right + 14, y + 34), "5 Nov", font(RG, 12), SOFT)
    label(draw, (right + 14, y + 64), "₹12,000", font(EB, 18), WHITE)
    label(draw, (right + 14, y + 90), "Rent", font(RG, 12), SOFT)
    y += 136
    label(draw, (x, y), "Today", font(BD, 13), SOFT)
    y += 24
    row(draw, x, y, w, "Pizza", "Food · yesterday", "₹450")
    y += 74
    row(draw, x, y, w, "Groceries", "Groceries · 18 Oct", "₹1,240")
    y += 74
    row(draw, x, y, w, "Salary", "Income · 6 Oct", "+₹35,000", positive=True)
    return y + 64


def screen_say(draw, x, y, w):
    app_bar(draw, x, y, w, "Add")
    y += 64
    label(draw, (x, y), "Say it the way you would", font(BD, 16), WHITE)
    y += 36
    round_rect(draw, (x, y, x + w, y + 92), 18, CARD)
    label(draw, (x + 16, y + 18), "450 pizza last night", font(MD, 18), WHITE)
    label(draw, (x + 16, y + 52), "English, Malayalam or Hinglish", font(RG, 12), SOFT)
    y += 116
    round_rect(draw, (x, y, x + w, y + 176), 18, CARD)
    label(draw, (x + 16, y + 16), "Ready to save", font(MD, 13), LIME)
    label(draw, (x + 16, y + 42), "₹450", font(EB, 32), WHITE)
    label(draw, (x + 16, y + 92), "Pizza", font(BD, 16), WHITE)
    label(draw, (x + 16, y + 116), "Food  ·  Yesterday  ·  Cash", font(RG, 13), SOFT)
    y += 196
    round_rect(draw, (x, y, x + w, y + 52), 16, LIME)
    face = font(EB, 16)
    tw = text_width(draw, "Save", face) / S
    label(draw, (x + (w - tw) / 2, y + 14), "Save", face, (23, 49, 12))
    y += 76
    label(draw, (x, y), "You check the line before it is saved.", font(RG, 13), SOFT)
    return y + 28


def screen_activity(draw, x, y, w):
    app_bar(draw, x, y, w, "Activity")
    y += 52
    for index, name in enumerate(["Week", "Month", "Quarter"]):
        fill = LIME if index == 1 else CARD
        ink = (23, 49, 12) if index == 1 else WHITE
        left = x + index * 108
        round_rect(draw, (left, y, left + 98, y + 34), 17, fill)
        face = font(BD, 13)
        tw = text_width(draw, name, face) / S
        label(draw, (left + (98 - tw) / 2, y + 8), name, face, ink)
    y += 52
    label(draw, (x, y), "October", font(MD, 13), SOFT)
    label(draw, (x, y + 22), "₹12,840 spent", font(EB, 26), WHITE)
    y += 72
    label(draw, (x, y), "Today", font(BD, 13), SOFT)
    y += 24
    row(draw, x, y, w, "Coffee", "Food · 9:10 am", "₹180")
    y += 74
    label(draw, (x, y), "Yesterday", font(BD, 13), SOFT)
    y += 24
    row(draw, x, y, w, "Pizza", "Food", "₹450")
    y += 74
    row(draw, x, y, w, "Groceries", "Groceries", "₹1,240")
    y += 74
    label(draw, (x, y), "6 Oct", font(BD, 13), SOFT)
    y += 24
    row(draw, x, y, w, "Salary", "Income", "+₹35,000", positive=True)
    return y + 64


def screen_budgets(draw, x, y, w):
    app_bar(draw, x, y, w, "Home")
    y += 52
    label(draw, (x, y), "Budgets", font(EB, 20), WHITE)
    y += 36

    def budget(title, spent, limit_text, ratio, warn):
        nonlocal y
        round_rect(draw, (x, y, x + w, y + 86), 16, CARD)
        label(draw, (x + 16, y + 12), title, font(BD, 15), WHITE)
        face = font(BD, 13)
        tw = text_width(draw, spent, face) / S
        label(draw, (x + w - 16 - tw, y + 14), spent, face, WHITE if not warn else (255, 179, 92))
        label(draw, (x + 16, y + 36), limit_text, font(RG, 12), SOFT)
        bar_y = y + 58
        round_rect(draw, (x + 16, bar_y, x + w - 16, bar_y + 10), 5, LINE)
        round_rect(draw, (x + 16, bar_y, x + 16 + (w - 32) * ratio, bar_y + 10), 5, LIME if not warn else (255, 179, 92))
        y += 98

    budget("Food", "₹4,800", "₹6,000 · 80%", 0.80, True)
    budget("Groceries", "₹3,100", "₹5,000 · 62%", 0.62, False)
    budget("Travel", "₹800", "₹2,000 · 40%", 0.40, False)
    y += 8
    label(draw, (x, y), "Goals", font(EB, 20), WHITE)
    y += 36
    round_rect(draw, (x, y, x + w, y + 92), 16, CARD)
    label(draw, (x + 16, y + 14), "Goa trip", font(BD, 15), WHITE)
    label(draw, (x + 16, y + 38), "₹8,500 of ₹20,000", font(RG, 13), SOFT)
    round_rect(draw, (x + 16, y + 66, x + w - 16, y + 76), 5, LINE)
    round_rect(draw, (x + 16, y + 66, x + 16 + (w - 32) * 0.42, y + 76), 5, LIME)
    return y + 92


def screen_people(draw, x, y, w):
    app_bar(draw, x, y, w, "Money")
    y += 52
    label(draw, (x, y), "Accounts", font(EB, 20), WHITE)
    y += 36
    row(draw, x, y, w, "Cash", "Wallet", "₹3,200")
    y += 74
    row(draw, x, y, w, "SBI", "Savings", "₹45,060")
    y += 96
    label(draw, (x, y), "Who owes whom", font(EB, 20), WHITE)
    y += 36
    round_rect(draw, (x, y, x + w, y + 72), 16, CARD)
    label(draw, (x + 16, y + 14), "Anoop owes you", font(BD, 15), WHITE)
    label(draw, (x + 16, y + 38), "Lent · 12 Oct", font(RG, 12), SOFT)
    face = font(EB, 16)
    amount = "₹2,000"
    tw = text_width(draw, amount, face) / S
    label(draw, (x + w - 16 - tw, y + 24), amount, face, GREEN)
    y += 84
    round_rect(draw, (x, y, x + w, y + 72), 16, CARD)
    label(draw, (x + 16, y + 14), "You owe Priya", font(BD, 15), WHITE)
    label(draw, (x + 16, y + 38), "Borrowed · 2 Oct", font(RG, 12), SOFT)
    amount = "₹500"
    tw = text_width(draw, amount, face) / S
    label(draw, (x + w - 16 - tw, y + 24), amount, face, WHITE)
    return y + 72


def screen_profile(draw, x, y, w):
    label(draw, (x, y + 6), "Profile", font(EB, 22), WHITE)
    y += 56

    def toggle(title, body, on=True):
        nonlocal y
        round_rect(draw, (x, y, x + w, y + 78), 16, CARD)
        label(draw, (x + 16, y + 14), title, font(BD, 15), WHITE)
        label(draw, (x + 16, y + 40), body, font(RG, 12), SOFT)
        knob_x = x + w - 58
        round_rect(draw, (knob_x, y + 26, knob_x + 42, y + 48), 11, LIME if on else LINE)
        dot = knob_x + (22 if on else 2)
        draw.ellipse(
            (dot * S, (y + 28) * S, (dot + 16) * S, (y + 44) * S),
            fill=(23, 49, 12) if on else SOFT,
        )
        y += 90

    toggle("Unlock with fingerprint", "Ask when the app opens")
    toggle("Read bank SMS", "From the message notification")
    toggle("Read UPI app alerts", "GPay, PhonePe, Paytm, BHIM, CRED")
    round_rect(draw, (x, y, x + w, y + 72), 16, CARD)
    label(draw, (x + 16, y + 14), "Server push", font(BD, 15), WHITE)
    label(draw, (x + 16, y + 40), "Reminders also stay on this phone", font(RG, 12), SOFT)
    return y + 72


def main():
    icon()
    feature()
    screenshot(
        "screenshot-1-home.png",
        "See the month",
        "Balance, spending and the next payment.",
        0,
        screen_home,
    )
    screenshot(
        "screenshot-2-say.png",
        "Just say it",
        "Speak or type. You confirm the line, then save.",
        None,
        screen_say,
    )
    screenshot(
        "screenshot-3-activity.png",
        "Every line, in one place",
        "Week, month or quarter. Income stays green.",
        1,
        screen_activity,
    )
    screenshot(
        "screenshot-4-budgets.png",
        "Budgets that warn you",
        "A nudge at 80%, and a goal you can add to.",
        0,
        screen_budgets,
    )
    screenshot(
        "screenshot-5-people.png",
        "Who owes whom",
        "Accounts, money you lent, and money you borrowed.",
        2,
        screen_people,
    )
    screenshot(
        "screenshot-6-profile.png",
        "Yours, on this phone",
        "A lock, and payment alerts that stay on the phone.",
        None,
        screen_profile,
    )
    print("wrote", OUT)


if __name__ == "__main__":
    main()
