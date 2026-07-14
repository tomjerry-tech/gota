# Wolf Assets

`wolf_den.png` is the normalized map-ready wolf den asset on a transparent 192x192 canvas with a bottom-center placement anchor.

`wolf_den_alpha.png` is the high-resolution transparent source retained for future variants, UI icons, damage states, and alternate lighting.

`wolf_idle.png` and `wolf_run_side.png` are normalized 128x128-frame strips used by the visible night wolves. `wolf_master.png` keeps the matching single-frame reference.

The GPT Image 2 prompts, chroma-key sources, alpha intermediates, and normalization script are stored in `work/imagegen/`. The visible wolf strips reuse the existing generated drafts; no new model generation was needed for the night-chase implementation.
