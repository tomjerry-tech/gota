from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
OUTPUT = ROOT.parents[2] / "assets" / "tiny_swords" / "cat_backup"
FRAME_SIZE = 128
GROUND_Y = 82


def split_rows(source_name: str, counts: list[int]) -> list[list[Image.Image]]:
    source = Image.open(ROOT / source_name).convert("RGBA")
    result: list[list[Image.Image]] = []
    for row, expected_count in enumerate(counts):
        top = round(row * source.height / len(counts))
        bottom = round((row + 1) * source.height / len(counts))
        row_image = source.crop((0, top, source.width, bottom))
        alpha = row_image.getchannel("A")
        occupied: list[bool] = []
        for x in range(row_image.width):
            column = alpha.crop((x, 0, x + 1, row_image.height))
            occupied.append(sum(column.histogram()[33:]) >= 3)

        runs: list[tuple[int, int]] = []
        start: int | None = None
        for x, is_occupied in enumerate(occupied + [False]):
            if is_occupied and start is None:
                start = x
            elif not is_occupied and start is not None:
                if x - start > 4:
                    runs.append((start, x))
                start = None
        if len(runs) != expected_count:
            raise RuntimeError(
                f"Expected {expected_count} frames in row {row}, found {len(runs)}: {runs}"
            )

        row_frames: list[Image.Image] = []
        for left, right in runs:
            frame = row_image.crop((left, 0, right, row_image.height))
            bbox = frame.getchannel("A").getbbox()
            if bbox is None:
                raise RuntimeError(f"Empty frame at row {row}, x={left}")
            row_frames.append(frame.crop(bbox))
        result.append(row_frames)
    return result


def remove_small_components(frame: Image.Image, minimum_ratio: float = 0.005) -> Image.Image:
    alpha = frame.getchannel("A")
    width, height = frame.size
    visible = alpha.load()
    visited: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []

    for y in range(height):
        for x in range(width):
            if visible[x, y] <= 32 or (x, y) in visited:
                continue
            component: list[tuple[int, int]] = []
            queue = deque([(x, y)])
            visited.add((x, y))
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for offset_y in (-1, 0, 1):
                    for offset_x in (-1, 0, 1):
                        if offset_x == 0 and offset_y == 0:
                            continue
                        next_x = current_x + offset_x
                        next_y = current_y + offset_y
                        point = (next_x, next_y)
                        if (
                            0 <= next_x < width
                            and 0 <= next_y < height
                            and point not in visited
                            and visible[next_x, next_y] > 32
                        ):
                            visited.add(point)
                            queue.append(point)
            components.append(component)

    if not components:
        raise RuntimeError("Frame contains no visible component")

    largest = max(len(component) for component in components)
    minimum_area = max(8, round(largest * minimum_ratio))
    cleaned = frame.copy()
    cleaned_pixels = cleaned.load()
    for component in components:
        if len(component) >= minimum_area:
            continue
        for x, y in component:
            cleaned_pixels[x, y] = (0, 0, 0, 0)

    bbox = cleaned.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Component cleanup removed the whole frame")
    return cleaned.crop(bbox)


def normalize(frames: list[Image.Image], target_height: int, ground_y: int) -> list[Image.Image]:
    cleaned = [remove_small_components(frame) for frame in frames]
    tallest = max(frame.height for frame in cleaned)
    scale = target_height / tallest
    normalized: list[Image.Image] = []
    for frame in cleaned:
        size = (
            max(1, round(frame.width * scale)),
            max(1, round(frame.height * scale)),
        )
        resized = frame.resize(size, Image.Resampling.NEAREST)
        if resized.width > FRAME_SIZE - 8:
            width_scale = (FRAME_SIZE - 8) / resized.width
            resized = resized.resize(
                (
                    FRAME_SIZE - 8,
                    max(1, round(resized.height * width_scale)),
                ),
                Image.Resampling.NEAREST,
            )
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        x = (FRAME_SIZE - resized.width) // 2
        y = ground_y - resized.height
        canvas.alpha_composite(resized, (x, y))
        normalized.append(canvas)
    return normalized


def write_strip(frames: list[Image.Image], output_name: str) -> None:
    strip = Image.new(
        "RGBA",
        (FRAME_SIZE * len(frames), FRAME_SIZE),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    strip.save(OUTPUT / output_name)
    print(f"Wrote {OUTPUT / output_name}")


def validate_strip(output_name: str, frame_count: int) -> None:
    image = Image.open(OUTPUT / output_name).convert("RGBA")
    expected_size = (FRAME_SIZE * frame_count, FRAME_SIZE)
    if image.size != expected_size:
        raise RuntimeError(f"{output_name} has size {image.size}, expected {expected_size}")
    for corner in ((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)):
        if image.getpixel(corner)[3] != 0:
            raise RuntimeError(f"{output_name} has a non-transparent corner at {corner}")
    for index in range(frame_count):
        frame = image.crop((index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE))
        if frame.getchannel("A").getbbox() is None:
            raise RuntimeError(f"{output_name} frame {index} is empty")
    print(f"Validated {output_name}: {frame_count} frames, transparent corners")


idle = split_rows("cat_idle_alpha.png", counts=[6])[0]
run = split_rows("cat_run_alpha.png", counts=[8])[0]
rest_rows = split_rows("cat_rest_alpha.png", counts=[6, 6])

write_strip(normalize(idle, target_height=54, ground_y=GROUND_Y), "cat_idle.png")
write_strip(normalize(run, target_height=48, ground_y=GROUND_Y), "cat_run.png")
write_strip(normalize(rest_rows[0], target_height=54, ground_y=GROUND_Y), "cat_lie_down.png")
write_strip(normalize(rest_rows[1], target_height=38, ground_y=GROUND_Y), "cat_rest.png")

validate_strip("cat_idle.png", frame_count=6)
validate_strip("cat_run.png", frame_count=8)
validate_strip("cat_lie_down.png", frame_count=6)
validate_strip("cat_rest.png", frame_count=6)
