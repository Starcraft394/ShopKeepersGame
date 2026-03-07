#!/usr/bin/env python3
"""
Generate animation frames for hero sprites via PixelLab Pixflux.
Each frame is generated individually to preserve SNES pixel art style.

Usage:
  python DevTools/generate_hero_animations.py --char human_m
  python DevTools/generate_hero_animations.py --race human
  python DevTools/generate_hero_animations.py --char human_m --anim attack
  python DevTools/generate_hero_animations.py --char human_m --preview
  python DevTools/generate_hero_animations.py --list
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

try:
    from pixellab import Client
except ImportError:
    print("ERROR: pixellab package not installed. Run: pip install pixellab")
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow package not installed. Run: pip install Pillow")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
PROMPTS_FILE = SCRIPT_DIR / "pixellab_hero_prompts.json"
OUTPUT_DIR = PROJECT_ROOT / "Assets" / "Sprites" / "Heroes"

RATE_LIMIT_SECONDS = 1.5  # Slightly longer to be gentle on API
SEED = 42

# Animation frame definitions: pose descriptions for each frame
# These are appended to the character's base description
ANIMATION_FRAMES = {
    "idle": {
        "prefix": "Idle",
        "fps": 6,
        "loop": True,
        "frames": [
            "Standing neutral pose, arms relaxed at sides, facing forward.",
            "Standing pose, very slight lean forward, arms relaxed, facing forward.",
            "Standing neutral pose, arms relaxed at sides, facing forward.",
            "Standing pose, very slight lean back, arms relaxed, facing forward.",
        ],
    },
    "attack": {
        "prefix": "Attack",
        "fps": 10,
        "loop": False,
        "frames": [
            "Winding up to attack, pulling right arm back, body turning right.",
            "Mid-swing, right arm extended forward in melee strike, lunging forward.",
            "Full extension, right arm stretched out hitting target, body leaned forward.",
            "Follow through after attack, arm still extended, slight recoil backward.",
            "Returning to neutral stance after attack, arms lowering to sides.",
        ],
    },
    "cast": {
        "prefix": "Cast",
        "fps": 10,
        "loop": False,
        "frames": [
            "Beginning to cast a spell, raising both hands upward, magical energy gathering.",
            "Hands raised above head, glowing magical energy between palms, casting pose.",
            "Releasing spell forward, arms thrust forward, magical energy shooting out.",
            "Spell cast complete, magical energy fading, arms extended forward.",
            "Lowering arms back to sides, returning to neutral stance after casting.",
        ],
    },
    "hit": {
        "prefix": "Hit",
        "fps": 10,
        "loop": False,
        "frames": [
            "Flinching backward from being struck, arms up defensively, pain expression.",
            "Staggering back, leaning away from impact, one arm across body.",
            "Recovering from hit, straightening up, returning toward neutral stance.",
        ],
    },
    "death": {
        "prefix": "Death",
        "fps": 8,
        "loop": False,
        "frames": [
            "Stumbling, losing balance, knees buckling, arms flailing.",
            "Falling sideways, body tilting, one knee on ground.",
            "Collapsing further, body almost horizontal, arms limp.",
            "Lying on ground defeated, body flat, eyes closed.",
            "Lying motionless on ground, completely defeated, still pose.",
        ],
    },
    "walk": {
        "prefix": "Walk",
        "fps": 8,
        "loop": True,
        "frames": [
            "Walking forward, left foot stepping forward, right arm forward.",
            "Walking, left foot planted, right foot lifting, mid-stride.",
            "Walking, right foot stepping forward, left arm forward.",
            "Walking, right foot planted, left foot lifting, mid-stride.",
            "Walking forward, left foot stepping forward, right arm forward.",
            "Walking, weight shifting, both feet near ground, transitioning step.",
        ],
    },
}


def _load_env_file() -> None:
    env_path = PROJECT_ROOT / ".env"
    if not env_path.exists():
        return
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key and value:
                    os.environ.setdefault(key, value)


def get_client() -> Client:
    _load_env_file()
    api_key = os.environ.get("PIXELLAB_API_KEY")
    if not api_key:
        print("ERROR: PIXELLAB_API_KEY not found.")
        sys.exit(1)
    return Client(secret=api_key)


def load_prompts() -> dict:
    with open(PROMPTS_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def generate_animation_frames(client: Client, char: dict, anim_name: str,
                               style_prefix: str, settings: dict,
                               seed: int = SEED, dry_run: bool = False) -> int:
    """Generate all frames for one animation of one character. Returns success count."""
    char_id = char["char_id"]
    anim_def = ANIMATION_FRAMES[anim_name]
    prefix = anim_def["prefix"]
    frames = anim_def["frames"]
    char_dir = OUTPUT_DIR / char_id
    char_dir.mkdir(parents=True, exist_ok=True)

    neg = settings.get("negative_description", "")
    base_prompt = f"{style_prefix} {char['description']}"

    success = 0
    for i, pose in enumerate(frames, 1):
        frame_path = char_dir / f"{prefix}{i}.png"
        if frame_path.exists():
            print(f"    {prefix}{i}.png — SKIP (exists)")
            success += 1
            continue

        if dry_run:
            print(f"    {prefix}{i}.png — [DRY RUN]")
            success += 1
            continue

        full_prompt = f"{base_prompt} {pose}"
        print(f"    {prefix}{i}.png — generating...")

        try:
            response = client.generate_image_pixflux(
                description=full_prompt,
                image_size={"width": 32, "height": 32},
                text_guidance_scale=settings.get("text_guidance_scale", 5.0),
                outline=settings.get("outline", "selective outline"),
                shading=settings.get("shading", "medium shading"),
                detail=settings.get("detail", "highly detailed"),
                view=settings.get("view", "side"),
                no_background=settings.get("no_background", True),
                negative_description=neg,
                seed=seed,
            )
            img = response.image.pil_image()
            upscaled = img.resize((64, 64), Image.NEAREST)
            upscaled.save(str(frame_path), "PNG")
            success += 1
            time.sleep(RATE_LIMIT_SECONDS)
        except Exception as e:
            print(f"    ERROR: {e}")
            time.sleep(RATE_LIMIT_SECONDS)

    return success


def make_preview_gif(char_id: str, anim_name: str) -> None:
    """Create an animated GIF preview for a character's animation."""
    anim_def = ANIMATION_FRAMES[anim_name]
    prefix = anim_def["prefix"]
    fps = anim_def["fps"]
    char_dir = OUTPUT_DIR / char_id

    frames = []
    i = 1
    while True:
        path = char_dir / f"{prefix}{i}.png"
        if not path.exists():
            break
        img = Image.open(str(path)).convert("RGBA")
        bg = Image.new("RGBA", img.size, (30, 30, 40, 255))
        bg.paste(img, (0, 0), img)
        frames.append(bg.convert("RGB"))
        i += 1

    if len(frames) < 2:
        return

    gif_path = char_dir / f"{anim_name}_preview.gif"
    duration = int(1000 / fps)
    frames[0].save(
        str(gif_path), save_all=True, append_images=frames[1:],
        duration=duration, loop=0,
    )
    print(f"    Preview: {gif_path.name}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate hero animation frames via PixelLab Pixflux")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--char", type=str, help="Generate for a single character")
    group.add_argument("--race", type=str, help="Generate for both genders of a race")
    group.add_argument("--list", action="store_true", help="List animations")

    parser.add_argument("--anim", type=str, default="all",
                        help="Animation name or 'all' (default: all)")
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true",
                        help="Delete existing frames before generating")
    parser.add_argument("--preview", action="store_true",
                        help="Generate preview GIFs after frames")

    args = parser.parse_args()

    if args.list:
        print("\nAnimation definitions:")
        for name, adef in ANIMATION_FRAMES.items():
            print(f"  {name}: {len(adef['frames'])} frames, "
                  f"{adef['fps']}fps, {'loop' if adef['loop'] else 'one-shot'}")
        print(f"\nTotal frames per character: "
              f"{sum(len(a['frames']) for a in ANIMATION_FRAMES.values())}")
        return

    prompts = load_prompts()
    settings = prompts.get("settings", {})
    style_prefix = prompts["styles"]["snes"]["prefix"]
    characters = {c["char_id"]: c for c in prompts["characters"]}

    # Filter characters
    if args.char:
        if args.char not in characters:
            print(f"ERROR: '{args.char}' not found. Available: {', '.join(characters)}")
            sys.exit(1)
        chars = [characters[args.char]]
    else:
        chars = [c for c in prompts["characters"] if c["race_id"] == args.race]
        if not chars:
            print(f"ERROR: Race '{args.race}' not found.")
            sys.exit(1)

    # Filter animations
    if args.anim == "all":
        anims = list(ANIMATION_FRAMES.keys())
    elif args.anim in ANIMATION_FRAMES:
        anims = [args.anim]
    else:
        print(f"ERROR: Unknown animation '{args.anim}'")
        sys.exit(1)

    total_frames = sum(len(ANIMATION_FRAMES[a]["frames"]) for a in anims)
    print(f"\nHero Animation Generator (Pixflux frame-by-frame)")
    print(f"Characters: {len(chars)}, Animations: {len(anims)}, "
          f"Frames per char: {total_frames}")
    print(f"Total API calls: {len(chars) * total_frames}")

    client = None
    if not args.dry_run:
        client = get_client()
        balance = client.get_balance()
        print(f"Balance: {balance}")

    total_success = 0
    total_failed = 0

    for char in chars:
        char_id = char["char_id"]
        print(f"\n{'='*50}")
        print(f"Character: {char_id} ({char['race_id']} {char['gender']})")

        # Force: delete existing frames
        if args.force and not args.dry_run:
            char_dir = OUTPUT_DIR / char_id
            for anim_name in anims:
                prefix = ANIMATION_FRAMES[anim_name]["prefix"]
                for f in char_dir.glob(f"{prefix}*.png"):
                    f.unlink()
                # Also remove preview gif
                gif = char_dir / f"{anim_name}_preview.gif"
                if gif.exists():
                    gif.unlink()

        for anim_name in anims:
            n_frames = len(ANIMATION_FRAMES[anim_name]["frames"])
            print(f"  {anim_name} ({n_frames} frames):")
            ok = generate_animation_frames(
                client, char, anim_name, style_prefix, settings,
                seed=args.seed, dry_run=args.dry_run
            )
            total_success += ok
            total_failed += n_frames - ok

            if args.preview and not args.dry_run:
                make_preview_gif(char_id, anim_name)

    print(f"\n{'='*50}")
    print(f"Done! Frames: {total_success} OK, {total_failed} failed")
    if client:
        print(f"Balance: {client.get_balance()}")


if __name__ == "__main__":
    main()
