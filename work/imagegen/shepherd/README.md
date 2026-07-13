# Shepherd Backup Sprite Pack

This folder keeps source generations, prompts, and normalized 128x128 sprite strips for the backup shepherd character.

Character lock:

- Long black hair with center-parted fringe
- Large round black glasses
- Cream-white quilted puffer jacket
- Pale trousers and light shoes with subtle pale aqua accents
- Tiny Swords-compatible top-down three-quarter pixel art

Delivered actions:

- `idle`: four one-frame directional standing poses from the generated master
- `walk`: four directions, 6 frames per direction
- `run`: four directions, 7 frames per direction (the model returned 7 clean poses)
- `lie_down`: 6-frame standing-to-lying transition
- `rest`: 6-frame lying/sleeping loop derived from the final generated lie-down poses
- `whistle`: 6-frame sheep-calling interaction
- `tend`: 6-frame crouching/checking interaction derived from the opening generated lie-down poses
- `tend_lamb`: the same generated 6-frame shepherd interaction composited with the game's existing lamb sprite
- `carry_lamb`: 4-frame stand, crouch, lift, and hold keyframe sequence

Generation note:

- The configured provider timed out on medium-quality carry-lamb requests. The final four-keyframe sheet succeeded with GPT Image 2 at low source quality and was then normalized to 128x128 game frames.

All production strips use 128x128 cells on transparent backgrounds. Source sheets use a flat `#ff00ff` chroma-key background for local alpha extraction.

Generation model: `gpt-image-2`

Provider used for this batch: `https://apinebula.com/v1`
