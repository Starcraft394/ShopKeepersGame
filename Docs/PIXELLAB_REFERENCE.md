# PixelLab Integration Reference

## Overview

We use the [PixelLab API](https://api.pixellab.ai) to generate pixel art backgrounds and building sprites for the game. All generation is automated via `DevTools/generate_backgrounds.py`.

## API Endpoint

**`create-image-pixflux`** — Text-to-image pixel art generation.

- Dimensions: 16-400px per axis
- We generate at **320x180** (16:9, SNES-scale) and upscale **3x nearest-neighbor** to 960x540
- Building sprites: **128x128** with `no_background=True` for transparency

## Authentication

Bearer token via `PIXELLAB_API_KEY` environment variable.

```bash
# Windows
set PIXELLAB_API_KEY=your_key_here

# Bash
export PIXELLAB_API_KEY=your_key_here
```

## Python Client

```python
from pixellab import Client
client = Client(secret="YOUR_API_KEY")

# Generate
response = client.generate_image_pixflux(
    description="Pixel art, SNES style, ...",
    image_size={"width": 320, "height": 180},
    text_guidance_scale=8.0,
    outline="selective outline",
    shading="medium shading",
    detail="medium detail",
    view="side",
    no_background=False,
    negative_description="No characters, no text, ...",
    seed=42  # optional, 0=random
)

# Get PIL Image
pil_img = response.image.pil_image()

# Check credits
balance = client.get_balance()
```

## Style Parameters

| Parameter | Values | Our Default |
|-----------|--------|-------------|
| outline | `selective outline`, `single color outline`, `single color black outline`, `lineless` | `selective outline` |
| shading | `flat shading`, `basic shading`, `medium shading`, `detailed shading`, `highly detailed shading` | `medium shading` |
| detail | `low detail`, `medium detail`, `highly detailed` | `medium detail` (scenes), `highly detailed` (buildings) |
| view | `side`, `low top-down`, `high top-down` | `side` |

## Script Usage

```bash
# List all available scenes
python DevTools/generate_backgrounds.py --list

# Generate a single scene
python DevTools/generate_backgrounds.py --scene town_thornhaven_T1

# Generate all scenes in a category
python DevTools/generate_backgrounds.py --category town

# Generate everything
python DevTools/generate_backgrounds.py --all

# Preview without calling API
python DevTools/generate_backgrounds.py --all --dry-run

# Reproducible generation with seed
python DevTools/generate_backgrounds.py --scene dungeon_R1 --seed 42

# Force regeneration (delete existing first)
python DevTools/generate_backgrounds.py --scene dungeon_R1 --force

# Check credit balance
python DevTools/generate_backgrounds.py --balance
```

## File Structure

```
Assets/Backgrounds/
  _staging/                              <- Review here before importing
    sources/                             <- 320x180 raw PixelLab output
      town_thornhaven_T1.png
      ...
    town_thornhaven_T1.png               <- 960x540 upscaled (final)
    ...
  _archive_v1_with_buildings/            <- v1 town BGs (had buildings baked in)
    town_thornhaven_T1.png               <- Could reuse as loading screens or menus
    ...
  town_thornhaven_T1.png                 <- Approved files go here (Godot looks here)
  dungeon_R1.png
  ...
```

**Workflow:** Generate to `_staging/` -> Review -> Move approved files up to `Assets/Backgrounds/`.

## Asset Manifest (32 images)

| Category | Count | IDs |
|----------|-------|-----|
| Town | 7 | town_thornhaven_T1, town_sproutrest_T1, town_shelldrift_T1, town_embercradle_T1, town_crystalhearth_T1, town_duskhollow_T1, town_void_threshold_T1 |
| Dungeon | 7 | dungeon_R1 through dungeon_R7 (shared across all floors, combat, camp) |
| Event | 7 | event_R1 through event_R7 |
| Shop | 1 | shop_interior |
| Building | 10 | building_dungeon, building_inn, building_shop, building_storage, building_blacksmith, building_huntsman, building_enchanter, building_chef, building_alchemist, building_training |

## Godot Integration

**BackgroundManager** autoload (`Game/Core/BackgroundManager.gd`) handles swapping ColorRect backgrounds for TextureRect when a matching PNG exists.

```gdscript
# In any scene's _ready():
BackgroundManager.apply_background(self, "town", "town_thornhaven_T1")
BackgroundManager.apply_background(self, "dungeon", "R1")
BackgroundManager.apply_background(self, "shop", "interior")
BackgroundManager.apply_background(self, "event", "R1")
```

**Graceful fallback:** If the PNG doesn't exist in `Assets/Backgrounds/`, the original ColorRect stays visible. No crash, no error.

**Resolution:** Images are 960x540 (3x upscaled from 320x180). TextureRect uses `EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_COVERED` to fill the viewport.

## Prompt Patterns

### Town backgrounds (v2 — environment-only)
- **No buildings in town backgrounds.** Building sprites (128x128 PNGs) are placed as interactive buttons on top.
- Town prompts describe pure landscape/environment: forest clearing, mushroom cavern, coastal ruins, volcanic rock, crystal grove, necropolis ground, void fragment.
- Emphasize "wide open" center area for building sprite placement.
- End prompts with "No buildings." as reinforcement.
- Negative description includes: `"No buildings, no structures, no houses, no roofs, no walls, no doors, no architecture"`
- v1 backgrounds (with buildings baked in) are archived in `_archive_v1_with_buildings/` for potential reuse as loading screens or menu art.

### What works well
- Start with "Pixel art, SNES style" for consistent aesthetic
- Specify palette explicitly ("warm amber and forest green palette")
- Describe low-contrast center areas for UI readability ("Center area is wide open low-contrast dirt clearing")
- Negative prompt excluding characters, text, UI, modern objects, architecture

### What to avoid
- Don't include character/creature descriptions (negative prompt handles this)
- Don't include buildings in town backgrounds (building sprites handle this)
- Avoid requesting specific text or labels in the scene
- Don't mix photorealistic terms with pixel art style

## Credit Usage

Each `create-image-pixflux` call costs credits. Check balance with `--balance` flag.

- 32 total images = ~32 API calls for a full set
- Building sprites are smaller (128x128) but cost the same per call
- Use `--seed` for reproducibility; only regenerate what you need with `--scene`

## Prompt Library

All prompts are in `DevTools/pixellab_prompts.json`. Edit that file to tweak descriptions, then regenerate with `--force`.

See `Docs/BACKGROUNDS_MASTER.md` for the full art direction guide, region palettes, and layered composition specs (future upgrade).
