from pathlib import Path
from PIL import Image

source = Image.open(Path(__file__).with_name("sheep-run-alpha.png")).convert("RGBA")
frames = []
for row in range(2):
    for column in range(4):
        frame = source.crop((column * 256, row * 256, (column + 1) * 256, (row + 1) * 256))
        frames.append(frame.resize((128, 128), Image.Resampling.LANCZOS))

output = Image.new("RGBA", (128 * len(frames), 128), (0, 0, 0, 0))
for index, frame in enumerate(frames):
    output.alpha_composite(frame, (index * 128, 0))
output.save(Path(__file__).with_name("sheep_run_8x128.png"))
print("Wrote sheep_run_8x128.png")
