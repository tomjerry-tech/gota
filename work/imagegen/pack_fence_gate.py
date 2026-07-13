from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
SOURCE = ROOT / "fence_gate_alpha.png"
OUTPUT = ROOT.parents[1] / "assets" / "tiny_swords" / "buildings" / "fence_gate.png"

image = Image.open(SOURCE).convert("RGBA")
bounds = image.getchannel("A").getbbox()
if bounds is None:
    raise RuntimeError("fence_gate_alpha.png contains no visible pixels")

cropped = image.crop(bounds)
scale = min(84 / cropped.width, 50 / cropped.height)
size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
resized = cropped.resize(size, Image.Resampling.NEAREST)
canvas = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
canvas.alpha_composite(resized, ((96 - size[0]) // 2, (64 - size[1]) // 2))

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
canvas.save(OUTPUT)
print(f"Wrote {OUTPUT}")
