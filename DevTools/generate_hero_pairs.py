#!/usr/bin/env python3
"""
Generate matching portrait/full-body pairs for hero sprites.
Uses the same seed and character description but modifies the prompt
to specify framing (full body vs portrait bust).

Saves:
  - Full body:  Assets/Sprites/Heroes/{char_id}/{char_id}.png  (64x64, for combat)
  - Portrait:   Assets/Sprites/Heroes/{char_id}/portrait.png    (64x64, for cards/UI)

Usage:
  python DevTools/generate_hero_pairs.py --all
  python DevTools/generate_hero_pairs.py --all --dry-run
  python DevTools/generate_hero_pairs.py --char elf_f
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
SOURCES_DIR = OUTPUT_DIR / "_sources"

RATE_LIMIT_SECONDS = 1.0
SEED = 42

# Characters that came out as full-body (need portrait generated)
FULL_BODY_CHARS = [
    "human_m", "human_f", "elf_m", "dwarf_m", "dwarf_f",
    "mossfolk_m", "tidelings_m", "dragonkin_m", "dragonkin_f", "undead_m"
]

# Characters that came out as portrait/bust (need full-body generated)
PORTRAIT_CHARS = [
    "elf_f", "mossfolk_f", "tidelings_f",
    "crystalborn_m", "crystalborn_f", "undead_f",
    "voidwalkers_m", "voidwalkers_f"
]

FULL_BODY_SUFFIX = " Full body visible from head to feet, complete character standing on ground, neutral standing pose."
PORTRAIT_SUFFIX = " Close-up portrait showing head and upper chest only, face clearly visible, detailed facial features."


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


def generate_variant(client: Client, char: dict, settings: dict,
                     style_prefix: str, variant: str,
                     seed: int = SEED, dry_run: bool = False) -> bool:
    """Generate a full-body or portrait variant for a character.

    variant: "full_body" or "portrait"
    """
    char_id = char["char_id"]
    width = settings.get("width", 32)
    height = settings.get("height", 32)
    upscale = settings.get("upscale_factor", 2)
    final_w = width * upscale
    final_h = height * upscale

    base_prompt = f"{style_prefix} {char['description']}"
    if variant == "full_body":
        full_prompt = base_prompt + FULL_BODY_SUFFIX
        out_filename = f"{char_id}.png"
        source_filename = f"{char_id}.png"
    else:
        full_prompt = base_prompt + PORTRAIT_SUFFIX
        out_filename = "portrait.png"
        source_filename = f"{char_id}_portrait.png"

    char_dir = OUTPUT_DIR / char_id
    final_path = char_dir / out_filename
    source_path = SOURCES_DIR / source_filename

    print(f"\n  {variant.upper()}: {char_id}")
    print(f"    Output: {final_path.relative_to(PROJECT_ROOT)}")

    if final_path.exists():
        print(f"    SKIP: already exists")
        return True

    if dry_run:
        print(f"    [DRY RUN] Would generate {out_filename}")
        return True

    try:
        params = {
            "description": full_prompt,
            "image_size": {"width": width, "height": height},
            "text_guidance_scale": settings.get("text_guidance_scale", 5.0),
            "outline": settings.get("outline", "selective outline"),
            "shading": settings.get("shading", "medium shading"),
            "detail": settings.get("detail", "highly detailed"),
            "view": settings.get("view", "side"),
            "no_background": settings.get("no_background", True),
            "seed": seed,
        }
        negative = settings.get("negative_description", "")
        if negative:
            params["negative_description"] = negative

        print(f"    Generating via Pixflux...")
        response = client.generate_image_pixflux(**params)
        pil_img = response.image.pil_image()

        SOURCES_DIR.mkdir(parents=True, exist_ok=True)
        char_dir.mkdir(parents=True, exist_ok=True)

        # Save raw source
        pil_img.save(str(source_path), "PNG")

        # Upscale and save final
        upscaled = pil_img.resize((final_w, final_h), Image.NEAREST)
        upscaled.save(str(final_path), "PNG")
        print(f"    OK")
        return True

    except Exception as e:
        print(f"    ERROR: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate portrait/full-body pairs for hero sprites")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--all", action="store_true",
                       help="Generate missing variants for all characters")
    group.add_argument("--char", dest="char_id", type=str,
                       help="Generate missing variant for a single character")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without calling API")
    parser.add_argument("--force", action="store_true",
                        help="Regenerate even if files exist")
    parser.add_argument("--seed", type=int, default=SEED,
                        help="Seed for generation")

    args = parser.parse_args()
    prompts = load_prompts()
    settings = prompts.get("settings", {})
    style_prefix = prompts["styles"]["snes"]["prefix"]
    characters = {c["char_id"]: c for c in prompts["characters"]}

    if args.char_id:
        if args.char_id not in characters:
            print(f"ERROR: Character '{args.char_id}' not found.")
            sys.exit(1)
        chars_to_process = [args.char_id]
    else:
        chars_to_process = list(characters.keys())

    client = None
    if not args.dry_run:
        client = get_client()
        balance = client.get_balance()
        print(f"PixelLab balance: {balance}")

    success = 0
    failed = 0
    skipped = 0

    for char_id in chars_to_process:
        char = characters[char_id]
        char_dir = OUTPUT_DIR / char_id

        # Determine what we need to generate
        has_full_body = (char_dir / f"{char_id}.png").exists()
        has_portrait = (char_dir / "portrait.png").exists()

        if args.force:
            # Force both
            needs_full = True
            needs_portrait = True
        else:
            needs_full = not has_full_body
            needs_portrait = not has_portrait

        if char_id in FULL_BODY_CHARS:
            # We have good full body, might need portrait
            if has_full_body and not has_portrait:
                print(f"\n{'='*50}")
                print(f"{char_id}: Has full body, generating PORTRAIT")
                if generate_variant(client, char, settings, style_prefix,
                                    "portrait", seed=args.seed, dry_run=args.dry_run):
                    success += 1
                else:
                    failed += 1
                if not args.dry_run:
                    time.sleep(RATE_LIMIT_SECONDS)
            elif not has_portrait:
                # No full body file either — generate portrait
                print(f"\n{'='*50}")
                print(f"{char_id}: Generating PORTRAIT")
                if generate_variant(client, char, settings, style_prefix,
                                    "portrait", seed=args.seed, dry_run=args.dry_run):
                    success += 1
                else:
                    failed += 1
                if not args.dry_run:
                    time.sleep(RATE_LIMIT_SECONDS)
            else:
                skipped += 1

        elif char_id in PORTRAIT_CHARS:
            # We have good portrait (as main sprite), need full body
            # First: rename existing sprite to portrait if portrait doesn't exist
            existing_sprite = char_dir / f"{char_id}.png"
            portrait_path = char_dir / "portrait.png"

            if existing_sprite.exists() and not portrait_path.exists():
                # The existing sprite IS the portrait — copy it
                print(f"\n{'='*50}")
                print(f"{char_id}: Copying existing bust as portrait")
                from shutil import copy2
                portrait_path.parent.mkdir(parents=True, exist_ok=True)
                copy2(str(existing_sprite), str(portrait_path))
                print(f"  Copied {char_id}.png -> portrait.png")

            # Now generate full body to replace the main sprite
            if args.force or not existing_sprite.exists() or char_id in PORTRAIT_CHARS:
                # Delete existing main sprite so it regenerates as full body
                if existing_sprite.exists() and (args.force or char_id in PORTRAIT_CHARS):
                    existing_sprite.unlink()
                    # Also delete source
                    source = SOURCES_DIR / f"{char_id}.png"
                    if source.exists():
                        source.unlink()

                print(f"{char_id}: Generating FULL BODY")
                if generate_variant(client, char, settings, style_prefix,
                                    "full_body", seed=args.seed, dry_run=args.dry_run):
                    success += 1
                else:
                    failed += 1
                if not args.dry_run:
                    time.sleep(RATE_LIMIT_SECONDS)
        else:
            # Not categorized — generate both if missing
            if needs_portrait:
                if generate_variant(client, char, settings, style_prefix,
                                    "portrait", seed=args.seed, dry_run=args.dry_run):
                    success += 1
                else:
                    failed += 1
                if not args.dry_run:
                    time.sleep(RATE_LIMIT_SECONDS)
            if needs_full:
                if generate_variant(client, char, settings, style_prefix,
                                    "full_body", seed=args.seed, dry_run=args.dry_run):
                    success += 1
                else:
                    failed += 1
                if not args.dry_run:
                    time.sleep(RATE_LIMIT_SECONDS)

    print(f"\n{'='*50}")
    print(f"Done! Generated: {success}, Failed: {failed}, Skipped: {skipped}")
    if client:
        balance = client.get_balance()
        print(f"PixelLab balance: {balance}")


if __name__ == "__main__":
    main()
