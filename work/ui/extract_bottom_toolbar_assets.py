from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parents[2]
PACK = ROOT / "Tiny Swords (Free Pack)" / "Tiny Swords (Free Pack)"
OUT = ROOT / "assets" / "tiny_swords" / "ui" / "bottom_toolbar"
OUT.mkdir(parents=True, exist_ok=True)


def fit_icon(source: Image.Image, size: tuple[int, int] = (54, 54)) -> Image.Image:
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Icon has no visible pixels")
    icon = source.crop(bbox)
    icon.thumbnail((48, 48), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(icon, ((size[0] - icon.width) // 2, (size[1] - icon.height) // 2))
    return canvas


paper_sheet = Image.open(
    PACK / "UI Elements" / "UI Elements" / "Papers" / "RegularPaper.png"
).convert("RGBA")

# RegularPaper is a nine-slice construction sheet.
pieces = [
    [paper_sheet.crop((12, 20, 64, 64)), paper_sheet.crop((128, 20, 192, 64)), paper_sheet.crop((256, 20, 308, 64))],
    [paper_sheet.crop((12, 128, 64, 192)), paper_sheet.crop((128, 128, 192, 192)), paper_sheet.crop((256, 128, 308, 192))],
    [paper_sheet.crop((12, 256, 64, 301)), paper_sheet.crop((128, 256, 192, 301)), paper_sheet.crop((256, 256, 308, 301))],
]
toolbar = Image.new("RGBA", (440, 100), (0, 0, 0, 0))
column_widths = [52, 336, 52]
row_heights = [28, 44, 28]
y = 0
for row, height in enumerate(row_heights):
    x = 0
    for column, width in enumerate(column_widths):
        piece = pieces[row][column].resize((width, height), Image.Resampling.NEAREST)
        toolbar.alpha_composite(piece, (x, y))
        x += width
    y += height
toolbar.save(OUT / "toolbar_paper.png")

build = Image.open(
    PACK / "UI Elements" / "UI Elements" / "Icons" / "Icon_01.png"
).convert("RGBA")
fit_icon(build).save(OUT / "build.png")

sheep_sheet = Image.open(ROOT / "assets" / "tiny_swords" / "sheep" / "sheep_idle.png").convert("RGBA")
fit_icon(sheep_sheet.crop((0, 0, 128, 128))).save(OUT / "sheep.png")

medical = Image.open(ROOT / "work" / "imagegen" / "medical_icon_alpha.png").convert("RGBA")
fit_icon(medical).save(OUT / "medical.png")

print("Wrote bottom toolbar assets")
