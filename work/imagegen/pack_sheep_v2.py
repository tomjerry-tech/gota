from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
ADULT = ROOT / "sheep_v2_adult"
LAMB = ROOT / "sheep_v2_lamb"
FRAME_SIZE = 128
ADULT_MAX_WIDTH = 52
ADULT_MAX_HEIGHT = 47
ADULT_CENTER_Y = 62


def visible_runs(image: Image.Image, expected: int) -> list[tuple[int, int]]:
    alpha = image.getchannel("A")
    occupied = []
    for x in range(image.width):
        column = alpha.crop((x, 0, x + 1, image.height))
        occupied.append(sum(1 for value in column.getdata() if value > 32) >= 3)

    runs: list[tuple[int, int]] = []
    start = None
    for x, is_occupied in enumerate(occupied + [False]):
        if is_occupied and start is None:
            start = x
        elif not is_occupied and start is not None:
            if x - start > 4:
                runs.append((start, x))
            start = None
    if len(runs) != expected:
        raise RuntimeError(f"Expected {expected} objects, found {len(runs)}: {runs}")
    return runs


def extract_row(image: Image.Image, expected: int) -> list[Image.Image]:
    frames = []
    for left, right in visible_runs(image, expected):
        strip = image.crop((left, 0, right, image.height))
        bbox = strip.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"Empty object at x={left}")
        frames.append(strip.crop(bbox))
    return frames


def rows(source_name: str, counts: list[int]) -> list[list[Image.Image]]:
    image = Image.open(ROOT / source_name).convert("RGBA")
    row_height = image.height // len(counts)
    result = []
    for row, count in enumerate(counts):
        row_image = image.crop((0, row * row_height, image.width, (row + 1) * row_height))
        result.append(extract_row(row_image, count))
    return result


def normalize_frames(frames: list[Image.Image], scale_factor: float = 1.0) -> list[Image.Image]:
    widest = max(frame.width for frame in frames)
    tallest = max(frame.height for frame in frames)
    scale = min(ADULT_MAX_WIDTH / widest, ADULT_MAX_HEIGHT / tallest) * scale_factor
    output = []
    for frame in frames:
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        resized = frame.resize(size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        x = (FRAME_SIZE - resized.width) // 2
        y = ADULT_CENTER_Y - resized.height // 2
        canvas.alpha_composite(resized, (x, y))
        output.append(canvas)
    return output


def write_strip(frames: list[Image.Image], directory: Path, name: str, scale_factor: float) -> None:
    normalized = normalize_frames(frames, scale_factor)
    strip = Image.new("RGBA", (FRAME_SIZE * len(normalized), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
    directory.mkdir(parents=True, exist_ok=True)
    strip.save(directory / name)
    print(f"Wrote {directory.name}/{name}")


idle = rows("sheep_idle_v2_alpha.png", [6])[0]
eat_rows = rows("sheep_eat_v2_alpha.png", [6, 6])
eat = eat_rows[0] + eat_rows[1]
rest_rows = rows("sheep_rest_v2_alpha.png", [6, 6])
side = rows("sheep_walk_side_v2_alpha.png", [4])[0]
vertical = rows("sheep_walk_vertical_v2_alpha.png", [4, 4])
diagonal = rows("sheep_walk_diagonal_v2_alpha.png", [4, 4])

assets = {
    "sheep_idle.png": idle,
    "sheep_eat.png": eat,
    "sheep_lie_down.png": rest_rows[0],
    "sheep_rest.png": rest_rows[1],
    "sheep_move.png": side,
    "sheep_walk_up.png": vertical[0],
    "sheep_walk_down.png": vertical[1],
    "sheep_walk_diag_up.png": diagonal[0],
    "sheep_walk_diag_down.png": diagonal[1],
}

for filename, frames in assets.items():
    write_strip(frames, ADULT, filename, 1.0)
    write_strip(frames, LAMB, filename, 0.5)

# Movement already brings the sheep to the grass. Start eating from the final
# standing frame, lower the head once, then loop only the low chewing poses.
write_strip(eat[1:6], ADULT, "sheep_eat_enter.png", 1.0)
write_strip(eat[5:12], ADULT, "sheep_eat_loop.png", 1.0)
write_strip(eat[1:6], LAMB, "sheep_eat_enter.png", 0.5)
write_strip(eat[5:12], LAMB, "sheep_eat_loop.png", 0.5)

# Keep the existing scare state compatible while preserving the new character.
run_frames = side + side
write_strip(run_frames, ADULT, "sheep_run.png", 1.0)
write_strip(run_frames, LAMB, "sheep_run.png", 0.5)
