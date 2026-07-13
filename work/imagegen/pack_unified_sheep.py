from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
FRAME_SIZE = 128
TARGET_CENTER_Y = 62
MAX_WIDTH = 52
MAX_HEIGHT = 47


def extract_horizontal_objects(image: Image.Image, expected_count: int) -> list[Image.Image]:
    alpha = image.getchannel("A")
    occupied = []
    for x in range(image.width):
        column = alpha.crop((x, 0, x + 1, image.height))
        visible_pixels = sum(1 for value in column.getdata() if value > 32)
        occupied.append(visible_pixels >= 3)

    runs: list[tuple[int, int]] = []
    start = None
    for x, is_occupied in enumerate(occupied + [False]):
        if is_occupied and start is None:
            start = x
        elif not is_occupied and start is not None:
            if x - start > 4:
                runs.append((start, x))
            start = None

    if len(runs) != expected_count:
        raise RuntimeError(f"Expected {expected_count} objects, found {len(runs)}: {runs}")

    frames = []
    for left, right in runs:
        strip = image.crop((left, 0, right, image.height))
        bbox = strip.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"Empty object at x={left}")
        frames.append(strip.crop(bbox))
    return frames


def write_strip(frames: list[Image.Image], output_name: str) -> None:
    widest = max(frame.width for frame in frames)
    tallest = max(frame.height for frame in frames)
    scale = min(MAX_WIDTH / widest, MAX_HEIGHT / tallest)
    output = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        resized = frame.resize(size, Image.Resampling.LANCZOS)
        x = index * FRAME_SIZE + (FRAME_SIZE - resized.width) // 2
        y = TARGET_CENTER_Y - resized.height // 2
        output.alpha_composite(resized, (x, y))
    output.save(ROOT / output_name)
    print(f"Wrote {output_name}")


idle = Image.open(ROOT / "sheep_idle_unified_alpha.png").convert("RGBA")
write_strip(extract_horizontal_objects(idle, 6), "sheep_idle_unified.png")

walk = Image.open(ROOT / "sheep_walk_unified_alpha.png").convert("RGBA")
write_strip(extract_horizontal_objects(walk, 4), "sheep_move_unified.png")

eat = Image.open(ROOT / "sheep_eat_unified_alpha.png").convert("RGBA")
row_height = eat.height // 2
eat_frames = []
for row in range(2):
    row_image = eat.crop((0, row * row_height, eat.width, (row + 1) * row_height))
    eat_frames.extend(extract_horizontal_objects(row_image, 6))
write_strip(eat_frames, "sheep_eat_unified.png")

rest = Image.open(ROOT / "sheep_rest_unified_alpha.png").convert("RGBA")
row_height = rest.height // 2
lie_down_row = rest.crop((0, 0, rest.width, row_height))
resting_row = rest.crop((0, row_height, rest.width, rest.height))
write_strip(extract_horizontal_objects(lie_down_row, 6), "sheep_lie_down_unified.png")
write_strip(extract_horizontal_objects(resting_row, 6), "sheep_rest_unified.png")

vertical = Image.open(ROOT / "sheep_vertical_unified_alpha.png").convert("RGBA")
row_height = vertical.height // 2
walk_up_row = vertical.crop((0, 0, vertical.width, row_height))
walk_down_row = vertical.crop((0, row_height, vertical.width, vertical.height))
write_strip(extract_horizontal_objects(walk_up_row, 4), "sheep_walk_up_unified.png")
write_strip(extract_horizontal_objects(walk_down_row, 4), "sheep_walk_down_unified.png")
