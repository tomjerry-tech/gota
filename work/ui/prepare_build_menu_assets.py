from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parents[2]
PACK = ROOT / "Tiny Swords (Free Pack)" / "Tiny Swords (Free Pack)"
OUT = ROOT / "assets" / "tiny_swords" / "ui" / "build_menu"
OUT.mkdir(parents=True, exist_ok=True)


def fit_icon(source: Image.Image, name: str) -> None:
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"{name} has no visible pixels")
    icon = source.crop(bbox)
    icon.thumbnail((52, 52), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (58, 58), (0, 0, 0, 0))
    canvas.alpha_composite(icon, ((58 - icon.width) // 2, (58 - icon.height) // 2))
    canvas.save(OUT / name)


fit_icon(Image.open(ROOT / "work/imagegen/build_dog_house_alpha.png").convert("RGBA"), "dog_house.png")
fit_icon(Image.open(ROOT / "work/imagegen/build_lamb_shelter_alpha.png").convert("RGBA"), "lamb_shelter.png")
fit_icon(Image.open(ROOT / "work/imagegen/build_land_expand_alpha.png").convert("RGBA"), "land_expand.png")
fit_icon(Image.open(ROOT / "work/imagegen/build_fence_alpha.png").convert("RGBA"), "fence.png")

house_sheet = Image.open(PACK / "Buildings/Blue Buildings/House1.png").convert("RGBA")
house_frame = house_sheet.crop((0, 0, 128, 192))
fit_icon(house_frame, "shepherd_house.png")

coin = Image.open(ROOT / "assets/tiny_swords/ui/coin.png").convert("RGBA")
coin.thumbnail((22, 22), Image.Resampling.NEAREST)
coin.save(OUT / "coin_small.png")

# Reuse the continuous paper texture as a scalable panel background.
paper = Image.open(ROOT / "assets/tiny_swords/ui/bottom_toolbar/toolbar_paper.png").convert("RGBA")
panel = paper.resize((600, 400), Image.Resampling.NEAREST)
panel.save(OUT / "panel_paper.png")

ribbon = Image.open(ROOT / "assets/tiny_swords/ui/hud_ribbon_blue.png").convert("RGBA")
ribbon = ribbon.resize((190, 64), Image.Resampling.NEAREST)
ribbon.save(OUT / "title_ribbon.png")

print("Prepared build menu assets")
