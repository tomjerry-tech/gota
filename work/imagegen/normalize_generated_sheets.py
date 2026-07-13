from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
FRAME_SIZE = 128


def extract_frames(source_name: str, columns: int, rows: int) -> list[list[Image.Image]]:
    source = Image.open(ROOT / source_name).convert("RGBA")
    tile_width = source.width // columns
    tile_height = source.height // rows
    result: list[list[Image.Image]] = []
    for row in range(rows):
        row_frames: list[Image.Image] = []
        for column in range(columns):
            tile = source.crop(
                (
                    column * tile_width,
                    row * tile_height,
                    (column + 1) * tile_width,
                    (row + 1) * tile_height,
                )
            )
            bbox = tile.getchannel("A").getbbox()
            if bbox is None:
                raise RuntimeError(f"Empty frame at row {row}, column {column}")
            row_frames.append(tile.crop(bbox))
        result.append(row_frames)
    return result


def extract_horizontal_objects(source_name: str, expected_count: int) -> list[Image.Image]:
    source = Image.open(ROOT / source_name).convert("RGBA")
    alpha = source.getchannel("A")
    occupied = []
    for x in range(source.width):
        visible_pixels = sum(1 for value in alpha.crop((x, 0, x + 1, source.height)).getdata() if value > 32)
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
        raise RuntimeError(
            f"Expected {expected_count} objects in {source_name}, found {len(runs)}: {runs}"
        )

    frames = []
    for left, right in runs:
        strip = source.crop((left, 0, right, source.height))
        bbox = strip.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"Empty object in {source_name} at x={left}")
        frames.append(strip.crop(bbox))
    return frames


def write_strip(
    frames: list[Image.Image],
    output_name: str,
    max_width: int,
    max_height: int,
    center_y: int | None = None,
) -> None:
    widest = max(frame.width for frame in frames)
    tallest = max(frame.height for frame in frames)
    scale = min(max_width / widest, max_height / tallest)
    output = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        resized = frame.resize(size, Image.Resampling.LANCZOS)
        x = index * FRAME_SIZE + (FRAME_SIZE - resized.width) // 2
        y = (
            FRAME_SIZE - 5 - resized.height
            if center_y is None
            else center_y - resized.height // 2
        )
        output.alpha_composite(resized, (x, y))
    output.save(ROOT / output_name)
    print(f"Wrote {output_name}")


rest_rows = extract_frames("sheep_rest_alpha.png", columns=6, rows=2)
write_strip(rest_rows[0], "sheep_lie_down.png", max_width=52, max_height=47, center_y=62)
write_strip(rest_rows[1], "sheep_rest.png", max_width=52, max_height=47, center_y=62)

vertical_rows = extract_frames("sheep_vertical_alpha.png", columns=4, rows=2)
write_strip(vertical_rows[0], "sheep_walk_up.png", max_width=52, max_height=47, center_y=62)
write_strip(vertical_rows[1], "sheep_walk_down.png", max_width=52, max_height=47, center_y=62)

growth_frames = extract_horizontal_objects("grass_growth_alpha.png", expected_count=4)
write_strip(growth_frames, "grass_growth.png", max_width=82, max_height=86)

eaten_frames = extract_horizontal_objects("grass_eaten_alpha.png", expected_count=6)
write_strip(eaten_frames, "grass_eaten.png", max_width=82, max_height=86)
