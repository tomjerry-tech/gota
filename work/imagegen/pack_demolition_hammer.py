from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
SOURCE = ROOT / "demolition_hammer_alpha.png"
OUTPUT = ROOT.parent.parent / "assets" / "tiny_swords" / "ui" / "build_menu" / "demolition_hammer.png"
FRAME_SIZE = 128


source = Image.open(SOURCE).convert("RGBA")
cell_width = source.width // 3
cell_height = source.height // 2
frames: list[Image.Image] = []
for row in range(2):
    for column in range(3):
        cell = source.crop(
            (
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            )
        )
        bbox = cell.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"Empty hammer frame at row {row}, column {column}")
        frames.append(cell.crop(bbox))

widest = max(frame.width for frame in frames)
tallest = max(frame.height for frame in frames)
scale = min(88 / widest, 96 / tallest)
strip = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
for index, frame in enumerate(frames):
    size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
    resized = frame.resize(size, Image.Resampling.LANCZOS)
    x = index * FRAME_SIZE + (FRAME_SIZE - resized.width) // 2
    y = (FRAME_SIZE - resized.height) // 2
    strip.alpha_composite(resized, (x, y))

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
strip.save(OUTPUT)
print(f"Wrote {OUTPUT}")
