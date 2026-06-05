"""Generate Taúl app icon (.ico and .png)."""

from PIL import Image, ImageDraw, ImageFont
import os

# ── Colors ──
BG_DARK = (23, 88, 75)       # teal oscuro
BG_LIGHT = (30, 120, 100)    # teal claro (gradient stop)
GOLD = (245, 166, 35)        # dorado para la T
WHITE = (245, 245, 245)

# ── Canvas ──
SIZE = 512
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# ── Rounded square background ──
margin = 16
r = 80  # corner radius
draw.rounded_rectangle(
    [margin, margin, SIZE - margin, SIZE - margin],
    radius=r,
    fill=BG_DARK,
)

# ── Gradient overlay (top-left lighter) ──
for y in range(margin, SIZE - margin):
    ratio = (y - margin) / (SIZE - 2 * margin)
    r = int(BG_DARK[0] + (BG_LIGHT[0] - BG_DARK[0]) * (1 - ratio))
    g = int(BG_DARK[1] + (BG_LIGHT[1] - BG_DARK[1]) * (1 - ratio))
    b = int(BG_DARK[2] + (BG_LIGHT[2] - BG_DARK[2]) * (1 - ratio))
    draw.line([(margin, y), (SIZE - margin, y)], fill=(r, g, b, 180))

# ── Letter "T" ──
# Use a bold sans-serif font
try:
    font = ImageFont.truetype("arial.ttf", 280)
except OSError:
    font = ImageFont.load_default()

# Center the T
text = "T"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
tx = (SIZE - tw) // 2 - bbox[0]
ty = (SIZE - th) // 2 - bbox[1] - 10  # nudge up slightly

draw.text((tx, ty), text, fill=GOLD, font=font)

# ── Subtle lock dot (small keyhole accent) ──
# Small circle at bottom-right of T
lock_x = SIZE // 2 + 60
lock_y = SIZE // 2 + 50
draw.ellipse(
    [lock_x - 12, lock_y - 12, lock_x + 12, lock_y + 12],
    fill=GOLD,
)

# ── Save multi-res ICO ──
ico_sizes = [16, 32, 48, 64, 96, 128, 256]

ico_dir = os.path.join(os.path.dirname(__file__), "..", "windows", "runner", "resources")
ico_path = os.path.join(ico_dir, "app_icon.ico")

# Create .ico with multiple resolutions
img_resized = [img.resize((s, s), Image.LANCZOS) for s in ico_sizes]
img_resized[0].save(
    ico_path,
    format="ICO",
    sizes=[(s, s) for s in ico_sizes],
    append_images=img_resized[1:],
)
print(f"ICO saved: {ico_path}")

# ── Also save high-res PNG for other uses ──
png_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "images")
os.makedirs(png_dir, exist_ok=True)
png_path = os.path.join(png_dir, "icon.png")
img.save(png_path, format="PNG")
print(f"PNG saved: {png_path}")

# ── Resize for Flutter's asset icon ──
img_48 = img.resize((48, 48), Image.LANCZOS)
icon_48_path = os.path.join(png_dir, "app_icon.png")
img_48.save(icon_48_path, format="PNG")
print(f"48x48 PNG saved: {icon_48_path}")
