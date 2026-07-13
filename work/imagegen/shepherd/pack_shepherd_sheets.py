from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).parent
OUTPUT = ROOT / "packed"
FRAME_SIZE = 128
ALPHA_THRESHOLD = 24


@dataclass(frozen=True)
class Sheet:
    name: str
    columns: int
    rows: tuple[str, ...]
    max_width: int
    max_height: int
    ground_y: int


SHEETS = (
    Sheet("master", 2, ("down_up", "left_right"), 82, 104, 112),
    Sheet("idle", 6, ("down",), 82, 104, 112),
    Sheet("walk", 6, ("down", "up", "left", "right"), 88, 104, 112),
    Sheet("run", 7, ("down", "up", "left", "right"), 94, 104, 112),
    Sheet("lie_down", 6, ("side",), 108, 82, 108),
    Sheet("rest", 6, ("side",), 108, 82, 108),
    Sheet("whistle", 6, ("down_right",), 88, 104, 112),
    Sheet("tend", 6, ("right",), 100, 104, 112),
    Sheet("carry_lamb", 4, ("down_right",), 108, 104, 112),
)


def crop_visible(cell: Image.Image, label: str) -> Image.Image:
    alpha = cell.getchannel("A").point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"Empty generated frame: {label}")
    return cell.crop(bbox)


def visible_runs(row: Image.Image) -> list[tuple[int, int]]:
    alpha = row.getchannel("A")
    occupied = []
    for x in range(row.width):
        visible = sum(
            1 for value in alpha.crop((x, 0, x + 1, row.height)).getdata() if value > ALPHA_THRESHOLD
        )
        occupied.append(visible >= 3)

    runs: list[tuple[int, int]] = []
    start = None
    for x, is_occupied in enumerate(occupied + [False]):
        if is_occupied and start is None:
            start = x
        elif not is_occupied and start is not None:
            if x - start > 4:
                runs.append((start, x))
            start = None
    return runs


def extract_grid(source: Image.Image, sheet: Sheet) -> list[list[Image.Image]]:
    result: list[list[Image.Image]] = []
    for row_index, row_name in enumerate(sheet.rows):
        top = round(row_index * source.height / len(sheet.rows))
        bottom = round((row_index + 1) * source.height / len(sheet.rows))
        row = source.crop((0, top, source.width, bottom))
        runs = visible_runs(row)
        if len(runs) != sheet.columns:
            raise RuntimeError(
                f"Expected {sheet.columns} frames in {sheet.name}/{row_name}, "
                f"found {len(runs)}: {runs}"
            )
        frames = [
            crop_visible(row.crop((left, 0, right, row.height)), f"{sheet.name}/{row_name}/{column}")
            for column, (left, right) in enumerate(runs)
        ]
        result.append(frames)
    return result


def normalize_row(frames: list[Image.Image], sheet: Sheet) -> Image.Image:
    widest = max(frame.width for frame in frames)
    tallest = max(frame.height for frame in frames)
    scale = min(sheet.max_width / widest, sheet.max_height / tallest)
    strip = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))

    for index, frame in enumerate(frames):
        width = max(1, round(frame.width * scale))
        height = max(1, round(frame.height * scale))
        resized = frame.resize((width, height), Image.Resampling.NEAREST)
        x = index * FRAME_SIZE + (FRAME_SIZE - width) // 2
        y = sheet.ground_y - height
        strip.alpha_composite(resized, (x, y))
    return strip


def write_row(frames: list[Image.Image], sheet: Sheet, output_name: str) -> None:
    output = OUTPUT / output_name
    normalize_row(frames, sheet).save(output)
    print(f"Wrote {output.relative_to(ROOT)}")


def write_tend_lamb(frames: list[Image.Image], sheet: Sheet) -> None:
    lamb_path = ROOT.parents[2] / "assets" / "tiny_swords" / "sheep" / "lamb" / "sheep_idle.png"
    if not lamb_path.exists():
        print(f"Skipping missing {lamb_path}")
        return

    strip = normalize_row(frames, sheet)
    lamb_strip = Image.open(lamb_path).convert("RGBA")
    lamb_frame_count = lamb_strip.width // FRAME_SIZE
    for index in range(len(frames)):
        source_index = index % lamb_frame_count
        lamb_cell = lamb_strip.crop(
            (source_index * FRAME_SIZE, 0, (source_index + 1) * FRAME_SIZE, FRAME_SIZE)
        )
        lamb = crop_visible(lamb_cell, f"lamb/{source_index}")
        x = index * FRAME_SIZE + 88
        y = sheet.ground_y - lamb.height
        strip.alpha_composite(lamb, (x, y))

    output = OUTPUT / "shepherd_tend_lamb_right.png"
    strip.save(output)
    print(f"Wrote {output.relative_to(ROOT)}")


def pack_sheet(sheet: Sheet) -> list[list[Image.Image]] | None:
    path = ROOT / f"shepherd_{sheet.name}_alpha.png"
    if not path.exists():
        print(f"Skipping missing {path.name}")
        return None

    source = Image.open(path).convert("RGBA")
    rows = extract_grid(source, sheet)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for row_name, frames in zip(sheet.rows, rows, strict=True):
        write_row(frames, sheet, f"shepherd_{sheet.name}_{row_name}.png")
    return rows


packed = {definition.name: pack_sheet(definition) for definition in SHEETS}

master_rows = packed["master"]
if master_rows:
    master_sheet = SHEETS[0]
    master_directions = {
        "down": master_rows[0][0],
        "up": master_rows[0][1],
        "left": master_rows[1][0],
        "right": master_rows[1][1],
    }
    for direction, frame in master_directions.items():
        write_row([frame], master_sheet, f"shepherd_master_{direction}.png")
        if packed["idle"] is None:
            write_row([frame], master_sheet, f"shepherd_idle_{direction}.png")

lie_down_rows = packed["lie_down"]
if lie_down_rows:
    lie_down_frames = lie_down_rows[0]
    if packed["rest"] is None:
        rest_sheet = next(sheet for sheet in SHEETS if sheet.name == "rest")
        rest_frames = [lie_down_frames[index] for index in (4, 5, 5, 4, 4, 5)]
        write_row(rest_frames, rest_sheet, "shepherd_rest_side.png")
    if packed["tend"] is None:
        tend_sheet = next(sheet for sheet in SHEETS if sheet.name == "tend")
        tend_frames = [lie_down_frames[index] for index in (0, 1, 2, 2, 1, 0)]
        write_row(tend_frames, tend_sheet, "shepherd_tend_right.png")
        write_tend_lamb(tend_frames, tend_sheet)
