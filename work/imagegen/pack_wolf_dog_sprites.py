from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).parent
ASSETS = ROOT.parent.parent / "assets" / "tiny_swords"
FRAME_SIZE = 128
FOOT_Y = 88

CHARACTERS = {
    "wolf": {"max_size": (64, 48)},
    "shepherd_dog": {"max_size": (58, 46)},
}

ACTIONS = {
    "idle": {"grid": (3, 2), "outputs": [("idle", 0, 6)]},
    "run_side": {"grid": (3, 2), "outputs": [("run_side", 0, 6)]},
    "run_vertical": {
        "grid": (4, 2),
        "outputs": [("run_up", 0, 4), ("run_down", 4, 8)],
    },
    "run_diagonal": {
        "grid": (4, 2),
        "outputs": [("run_diag_up", 0, 4), ("run_diag_down", 4, 8)],
    },
    "howl": {"grid": (3, 2), "outputs": [("howl", 0, 6)]},
    "bite": {"grid": (3, 2), "outputs": [("bite", 0, 6)]},
    "recoil": {"grid": (2, 2), "outputs": [("recoil", 0, 4)]},
    "bark": {"grid": (3, 2), "outputs": [("bark", 0, 6)]},
    "attack": {"grid": (3, 2), "outputs": [("attack", 0, 6)]},
    "guard": {"grid": (2, 2), "outputs": [("guard", 0, 4)]},
}

CHARACTER_ACTIONS = {
    "wolf": ["idle", "run_side", "run_vertical", "run_diagonal", "howl", "bite", "recoil"],
    "shepherd_dog": ["idle", "run_side", "run_vertical", "run_diagonal", "bark", "attack", "guard"],
}


def crop_grid(source: Path, columns: int, rows: int) -> list[Image.Image]:
    image = Image.open(source).convert("RGBA")
    frames: list[Image.Image] = []
    for row in range(rows):
        top = round(row * image.height / rows)
        bottom = round((row + 1) * image.height / rows)
        for column in range(columns):
            left = round(column * image.width / columns)
            right = round((column + 1) * image.width / columns)
            tile = image.crop((left, top, right, bottom))
            bounds = tile.getchannel("A").getbbox()
            if bounds is None:
                raise RuntimeError(f"Empty frame at row {row}, column {column}: {source.name}")
            frames.append(tile.crop(bounds))
    return frames


def normalize(frames: list[Image.Image], max_size: tuple[int, int]) -> list[Image.Image]:
    widest = max(frame.width for frame in frames)
    tallest = max(frame.height for frame in frames)
    scale = min(max_size[0] / widest, max_size[1] / tallest)
    output: list[Image.Image] = []
    for frame in frames:
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        resized = frame.resize(size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        x = (FRAME_SIZE - resized.width) // 2
        y = FOOT_Y - resized.height
        canvas.alpha_composite(resized, (x, y))
        output.append(canvas)
    return output


def write_strip(frames: list[Image.Image], output: Path) -> None:
    strip = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output)
    print(f"Wrote {output.relative_to(ROOT.parent.parent)}")


def pack_master(character: str) -> None:
    source = ROOT / f"{character}_master_alpha.png"
    if not source.exists():
        raise FileNotFoundError(source)
    image = Image.open(source).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"Empty master: {source.name}")
    frame = normalize([image.crop(bounds)], CHARACTERS[character]["max_size"])[0]
    output_name = "dog_master.png" if character == "shepherd_dog" else "wolf_master.png"
    output_dir = ASSETS / ("dog" if character == "shepherd_dog" else "wolf")
    write_strip([frame], output_dir / output_name)


def pack_action(character: str, action: str) -> list[Path]:
    config = ACTIONS[action]
    source = ROOT / f"{character}_{action}_alpha.png"
    if not source.exists():
        raise FileNotFoundError(source)
    frames = crop_grid(source, *config["grid"])
    frames = normalize(frames, CHARACTERS[character]["max_size"])
    prefix = "dog" if character == "shepherd_dog" else "wolf"
    output_dir = ASSETS / ("dog" if character == "shepherd_dog" else "wolf")
    outputs: list[Path] = []
    for output_action, start, end in config["outputs"]:
        path = output_dir / f"{prefix}_{output_action}.png"
        write_strip(frames[start:end], path)
        outputs.append(path)
    return outputs


def checkerboard(width: int, height: int, cell: int = 8) -> Image.Image:
    image = Image.new("RGBA", (width, height), (230, 226, 214, 255))
    draw = ImageDraw.Draw(image)
    alternate = (202, 211, 206, 255)
    for y in range(0, height, cell):
        for x in range(0, width, cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=alternate)
    return image


def make_preview(paths: list[Path]) -> None:
    preview_scale = 1
    label_width = 180
    row_height = FRAME_SIZE + 24
    content_width = max(Image.open(path).width for path in paths) * preview_scale
    preview = Image.new("RGBA", (label_width + content_width + 24, row_height * len(paths) + 16), (35, 42, 48, 255))
    draw = ImageDraw.Draw(preview)
    for row, path in enumerate(paths):
        strip = Image.open(path).convert("RGBA")
        y = row * row_height + 12
        background = checkerboard(content_width, FRAME_SIZE)
        preview.alpha_composite(background, (label_width + 12, y))
        preview.alpha_composite(strip, (label_width + 12, y))
        draw.text((12, y + 52), f"{path.parent.name}/{path.stem}", fill=(245, 238, 213, 255))
    preview.save(ROOT / "wolf_dog_animation_preview.png")
    print("Wrote work/imagegen/wolf_dog_animation_preview.png")


def validate(paths: list[Path]) -> None:
    for path in paths:
        image = Image.open(path).convert("RGBA")
        if image.height != FRAME_SIZE or image.width % FRAME_SIZE != 0:
            raise RuntimeError(f"Invalid strip dimensions: {path} -> {image.size}")
        for index in range(image.width // FRAME_SIZE):
            frame = image.crop((index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE))
            alpha = frame.getchannel("A")
            if alpha.getbbox() is None:
                raise RuntimeError(f"Empty final frame {index}: {path}")
            if frame.getpixel((0, 0))[3] != 0:
                raise RuntimeError(f"Opaque corner in final frame {index}: {path}")


def main() -> None:
    outputs: list[Path] = []
    for character, actions in CHARACTER_ACTIONS.items():
        pack_master(character)
        for action in actions:
            outputs.extend(pack_action(character, action))
    validate(outputs)
    make_preview(outputs)


if __name__ == "__main__":
    main()
