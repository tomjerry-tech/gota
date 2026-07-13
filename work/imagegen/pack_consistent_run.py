from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent.parent.parent
source = Image.open(Path(__file__).with_name("sheep_move_unified.png")).convert("RGBA")
frames = []
for index in range(8):
    source_index = index % 4
    frame = source.crop((source_index * 128, 0, (source_index + 1) * 128, 128))
    frames.append(frame)

output = Image.new("RGBA", (128 * len(frames), 128), (0, 0, 0, 0))
for index, frame in enumerate(frames):
    output.alpha_composite(frame, (index * 128, 0))
output.save(ROOT / "assets/tiny_swords/sheep/sheep_run.png")
print("Wrote consistent 8-frame run strip")
