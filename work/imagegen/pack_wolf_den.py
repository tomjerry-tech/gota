from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
SOURCE = ROOT / "wolf_den_alpha.png"
ASSET_DIR = ROOT.parents[1] / "assets" / "tiny_swords" / "wolf"
CANVAS_SIZE = 192
MAX_WIDTH = 184
MAX_HEIGHT = 176
BOTTOM_MARGIN = 6


image = Image.open(SOURCE).convert("RGBA")
bbox = image.getchannel("A").getbbox()
if bbox is None:
    raise RuntimeError("wolf_den_alpha.png contains no visible pixels")

cropped = image.crop(bbox)
scale = min(MAX_WIDTH / cropped.width, MAX_HEIGHT / cropped.height)
size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
resized = cropped.resize(size, Image.Resampling.NEAREST)

canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
x = (CANVAS_SIZE - resized.width) // 2
y = CANVAS_SIZE - BOTTOM_MARGIN - resized.height
canvas.alpha_composite(resized, (x, y))

ASSET_DIR.mkdir(parents=True, exist_ok=True)
image.save(ASSET_DIR / "wolf_den_alpha.png")
canvas.save(ASSET_DIR / "wolf_den.png")
print(f"Wrote {ASSET_DIR / 'wolf_den_alpha.png'}")
print(f"Wrote {ASSET_DIR / 'wolf_den.png'}")
