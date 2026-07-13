from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parents[2]
PACK = ROOT / "Tiny Swords (Free Pack)" / "Tiny Swords (Free Pack)"
OUT = ROOT / "assets" / "tiny_swords" / "ui"
OUT.mkdir(parents=True, exist_ok=True)

# The first ribbon is stored as left, center, and right construction pieces.
ribbon_sheet = Image.open(
    PACK / "UI Elements" / "UI Elements" / "Ribbons" / "BigRibbons.png"
).convert("RGBA")
left = ribbon_sheet.crop((30, 20, 128, 123))
center = ribbon_sheet.crop((192, 20, 256, 123))
right = ribbon_sheet.crop((320, 20, 417, 123))
ribbon = Image.new("RGBA", (560, 103), (0, 0, 0, 0))
ribbon.alpha_composite(left, (0, 0))
for x in range(left.width, ribbon.width - right.width, center.width):
    ribbon.alpha_composite(center, (x, 0))
ribbon.alpha_composite(right, (ribbon.width - right.width, 0))
ribbon.save(OUT / "hud_ribbon_blue.png")

coin_sheet = Image.open(
    PACK / "UI Elements" / "UI Elements" / "Icons" / "Icon_03.png"
).convert("RGBA")
coin_bbox = coin_sheet.getchannel("A").getbbox()
if coin_bbox is None:
    raise RuntimeError("Gold resource sheet has no visible pixels")
coin = coin_sheet.crop(coin_bbox)
coin_canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
coin.thumbnail((30, 30), Image.Resampling.NEAREST)
coin_canvas.alpha_composite(coin, ((32 - coin.width) // 2, (32 - coin.height) // 2))
coin_canvas.save(OUT / "coin.png")

sheep_sheet = Image.open(
    ROOT / "assets" / "tiny_swords" / "sheep" / "sheep_idle.png"
).convert("RGBA")
sheep_frame = sheep_sheet.crop((0, 0, 128, 128))
sheep_bbox = sheep_frame.getchannel("A").getbbox()
if sheep_bbox is None:
    raise RuntimeError("Sheep idle frame has no visible pixels")
sheep = sheep_frame.crop(sheep_bbox).resize((31, 28), Image.Resampling.NEAREST)
sheep_canvas = Image.new("RGBA", (36, 32), (0, 0, 0, 0))
sheep_canvas.alpha_composite(sheep, ((36 - sheep.width) // 2, (32 - sheep.height) // 2))
sheep_canvas.save(OUT / "sheep_count.png")

print("Wrote HUD ribbon, coin, and sheep icons")
