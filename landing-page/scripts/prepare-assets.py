"""Rebuild local web assets from documented, fictional app screenshots.

Optional maintenance tool: Python + Pillow. The site itself only needs Node.
No personal files, credentials, runtime configuration, or backend calls.
"""
from pathlib import Path
import shutil
from PIL import Image

SITE = Path(__file__).resolve().parents[1]
APP = SITE.parent
OUTPUT = SITE / "public" / "assets"
SCREENS = {
    "home": "12-home.png",
    "timeline": "15-timeline.png",
    "chat": "14-chat.png",
    "bucket-list": "19-bucket-list.png",
    "love-notes": "16-love-notes.png",
    "time-capsules": "17-time-capsules.png",
    "capsule-sealed": "25-capsule-sealed.png",
}
ICONS = [
    "heart", "timeline", "mood", "love-notes", "time-capsule", "chat",
    "calendar", "plan-date", "question", "home", "link", "lock", "listen",
]

for directory in ("screens", "moods", "icons"):
    (OUTPUT / directory).mkdir(parents=True, exist_ok=True)

original_total = 0
for name, original in SCREENS.items():
    source = APP / "docs" / "screenshots" / original
    original_total += source.stat().st_size
    with Image.open(source) as image:
        image = image.convert("RGB")
        height = round(image.height * 620 / image.width)
        image = image.resize((620, height), Image.Resampling.LANCZOS)
        image.save(OUTPUT / "screens" / f"{name}.webp", quality=88, method=6)

for name in ("loved", "calm", "need_a_hug"):
    with Image.open(APP / "assets" / "moods" / f"{name}.png") as image:
        image = image.convert("RGBA")
        image.thumbnail((400, 400), Image.Resampling.LANCZOS)
        image.save(OUTPUT / "moods" / f"{name}.webp", quality=87, method=6)

for name in ICONS:
    shutil.copyfile(APP / "assets" / "icons" / f"{name}.svg", OUTPUT / "icons" / f"{name}.svg")

size = sum(file.stat().st_size for file in (OUTPUT / "screens").glob("*.webp"))
print(f"Screenshots: {original_total:,} -> {size:,} bytes ({100 * (1 - size/original_total):.0f}% smaller).")
