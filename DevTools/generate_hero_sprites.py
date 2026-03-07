#!/usr/bin/env python3
"""
PixelLab Hero Sprite Generator for ShopKeepers Game
=====================================================
Generates pixel art character sprites for each hero race/gender combination.
Reads prompts from DevTools/pixellab_hero_prompts.json, generates at 32x32,
upscales 2x nearest-neighbor to 64x64, and saves to Assets/Sprites/Heroes/.

Phase 1: Static character sprites via Bitforge (style-referenced)
Phase 2: Animation frames via animate_with_text (--animate flag)

Usage:
  python DevTools/generate_hero_sprites.py --list
  python DevTools/generate_hero_sprites.py --char human_m
  python DevTools/generate_hero_sprites.py --race human
  python DevTools/generate_hero_sprites.py --all
  python DevTools/generate_hero_sprites.py --all --dry-run
  python DevTools/generate_hero_sprites.py --all --seed 42
  python DevTools/generate_hero_sprites.py --all --style snes
  python DevTools/generate_hero_sprites.py --animate human_m --anim idle
  python DevTools/generate_hero_sprites.py --animate human_m --anim all
  python DevTools/generate_hero_sprites.py --balance

Environment:
  PIXELLAB_API_KEY  -- Required. Your PixelLab API secret key.
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

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
PROMPTS_FILE = SCRIPT_DIR / "pixellab_hero_prompts.json"
OUTPUT_DIR = PROJECT_ROOT / "Assets" / "Sprites" / "Heroes"
SOURCES_DIR = OUTPUT_DIR / "_sources"

# Rate limit: seconds between API calls
RATE_LIMIT_SECONDS = 1.0


def load_prompts() -> dict:
    """Load the hero sprite prompt library."""
    if not PROMPTS_FILE.exists():
        print(f"ERROR: Prompt file not found: {PROMPTS_FILE}")
        sys.exit(1)
    with open(PROMPTS_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def _load_env_file() -> None:
    """Load key=value pairs from .env file in project root (if it exists)."""
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
    """Create a PixelLab API client from .env file or environment variable."""
    _load_env_file()
    api_key = os.environ.get("PIXELLAB_API_KEY")
    if not api_key:
        print("ERROR: PIXELLAB_API_KEY not found.")
        print("  Option 1: Create a .env file in the project root with:")
        print('    PIXELLAB_API_KEY=your_key_here')
        print("  Option 2: Set environment variable:")
        print("    set PIXELLAB_API_KEY=your_key_here  (Windows)")
        sys.exit(1)
    return Client(secret=api_key)


def check_balance(client: Client) -> None:
    """Print the current PixelLab credit balance."""
    try:
        balance = client.get_balance()
        print(f"PixelLab balance: {balance}")
    except Exception as e:
        print(f"WARNING: Could not check balance: {e}")


def build_prompt(char: dict, style_prefix: str) -> str:
    """Build the full prompt by combining style prefix with character description."""
    return f"{style_prefix} {char['description']}"


def list_characters(prompts: dict) -> None:
    """Print all available character variants."""
    characters = prompts.get("characters", [])
    print(f"\nPixelLab Hero Sprite Library -- {len(characters)} characters\n")
    by_race = {}
    for c in characters:
        by_race.setdefault(c["race_id"], []).append(c)

    for race_id in sorted(by_race.keys()):
        entries = by_race[race_id]
        print(f"  {race_id}:")
        for entry in entries:
            print(f"    - {entry['char_id']} ({entry['gender']})")

    print(f"\nAvailable styles:")
    for style_id, style_info in prompts.get("styles", {}).items():
        print(f"  - {style_id}: {style_info['label']}")

    print(f"\nAvailable animations:")
    for anim_id, anim_info in prompts.get("animations", {}).items():
        print(f"  - {anim_id}: {anim_info['action']} ({anim_info['n_frames']} frames)")
    print()


def filter_characters(prompts: dict, char_id: str = None, race_id: str = None) -> list:
    """Filter characters from the prompt library."""
    characters = prompts.get("characters", [])
    if char_id:
        matches = [c for c in characters if c["char_id"] == char_id]
        if not matches:
            print(f"ERROR: Character '{char_id}' not found.")
            print("Available characters:")
            for c in characters:
                print(f"  {c['char_id']}")
            sys.exit(1)
        return matches
    if race_id:
        matches = [c for c in characters if c["race_id"] == race_id]
        if not matches:
            print(f"ERROR: Race '{race_id}' not found.")
            sys.exit(1)
        return matches
    return characters


def generate_style_anchor(client: Client, prompts: dict, style_prefix: str,
                          seed: int = 0, dry_run: bool = False) -> Image.Image | None:
    """Generate or load the style anchor image."""
    anchor_path = SOURCES_DIR / "style_anchor.png"

    # Load existing anchor if available
    if anchor_path.exists():
        print(f"  Using existing style anchor: {anchor_path.relative_to(PROJECT_ROOT)}")
        return Image.open(str(anchor_path))

    if dry_run:
        print("  [DRY RUN] Would generate style_anchor.png")
        return None

    settings = prompts.get("settings", {})
    anchor_desc = prompts.get("style_anchor", {}).get("description", "")
    full_prompt = f"{style_prefix} {anchor_desc}"

    print(f"\nGenerating style anchor...")
    print(f"  Prompt: {full_prompt[:80]}...")

    try:
        params = {
            "description": full_prompt,
            "image_size": {"width": settings["width"], "height": settings["height"]},
            "text_guidance_scale": settings.get("text_guidance_scale", 5.0),
            "outline": settings.get("outline", "selective outline"),
            "shading": settings.get("shading", "medium shading"),
            "detail": settings.get("detail", "highly detailed"),
            "view": settings.get("view", "side"),
            "no_background": settings.get("no_background", True),
        }
        if seed:
            params["seed"] = seed

        response = client.generate_image_pixflux(**params)
        pil_img = response.image.pil_image()

        SOURCES_DIR.mkdir(parents=True, exist_ok=True)
        pil_img.save(str(anchor_path), "PNG")
        print(f"  Saved: {anchor_path.relative_to(PROJECT_ROOT)}")
        return pil_img

    except Exception as e:
        print(f"  ERROR generating style anchor: {e}")
        return None


def generate_character(client: Client, char: dict, settings: dict,
                       style_prefix: str, style_anchor_img: Image.Image | None = None,
                       seed: int = 0, dry_run: bool = False) -> bool:
    """Generate a single character sprite via PixelLab Bitforge API."""
    char_id = char["char_id"]
    width = settings.get("width", 32)
    height = settings.get("height", 32)
    upscale = settings.get("upscale_factor", 2)
    final_w = width * upscale
    final_h = height * upscale

    full_prompt = build_prompt(char, style_prefix)
    negative = settings.get("negative_description", "")

    print(f"\n{'='*60}")
    print(f"Character: {char_id} (race: {char['race_id']}, gender: {char['gender']})")
    print(f"  Size: {width}x{height} -> {final_w}x{final_h} ({upscale}x upscale)")
    print(f"  Prompt: {full_prompt[:80]}...")

    if dry_run:
        print(f"  [DRY RUN] Would generate {char_id}.png")
        return True

    source_path = SOURCES_DIR / f"{char_id}.png"
    final_dir = OUTPUT_DIR / char_id
    final_path = final_dir / f"{char_id}.png"

    # Skip if already exists
    if final_path.exists():
        print(f"  SKIP: {final_path.name} already exists. Use --force to regenerate.")
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
        }

        if negative:
            params["negative_description"] = negative
        if seed:
            params["seed"] = seed

        # Use Pixflux for all generation (Bitforge produces poor results at 32x32)
        print(f"  Generating via Pixflux...")
        response = client.generate_image_pixflux(**params)

        pil_img = response.image.pil_image()

        # Ensure directories
        SOURCES_DIR.mkdir(parents=True, exist_ok=True)
        final_dir.mkdir(parents=True, exist_ok=True)

        # Save raw source
        pil_img.save(str(source_path), "PNG")
        print(f"  Saved source: {source_path.relative_to(PROJECT_ROOT)}")

        # Upscale with nearest-neighbor and save to character folder
        upscaled = pil_img.resize((final_w, final_h), Image.NEAREST)
        upscaled.save(str(final_path), "PNG")
        print(f"  Saved final:  {final_path.relative_to(PROJECT_ROOT)}")
        print(f"  OK")
        return True

    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def generate_animation(client: Client, char: dict, anim_name: str,
                       anim_config: dict, settings: dict, style_prefix: str,
                       seed: int = 0, dry_run: bool = False) -> bool:
    """Generate animation frames for a character using animate_with_text."""
    char_id = char["char_id"]
    n_frames = anim_config["n_frames"]
    action = anim_config["action"]

    # Animation frame naming: Idle1.png, Idle2.png, etc.
    anim_prefix = anim_name.capitalize()
    char_dir = OUTPUT_DIR / char_id

    print(f"\n  Animation: {anim_name} ({n_frames} frames)")
    print(f"    Action: {action}")

    if dry_run:
        print(f"    [DRY RUN] Would generate {n_frames} frames")
        return True

    # Check if frames already exist
    first_frame = char_dir / f"{anim_prefix}1.png"
    if first_frame.exists():
        print(f"    SKIP: {anim_prefix} frames already exist. Use --force to regenerate.")
        return True

    # Load reference image (the static character sprite)
    ref_path = SOURCES_DIR / f"{char_id}.png"
    if not ref_path.exists():
        print(f"    ERROR: Reference image not found: {ref_path}")
        print(f"    Generate the static sprite first with --char {char_id}")
        return False

    ref_img = Image.open(str(ref_path))
    full_prompt = build_prompt(char, style_prefix)

    try:
        # animate_with_text works at 64x64 fixed
        response = client.animate_with_text(
            image_size={"width": 64, "height": 64},
            description=full_prompt,
            action=action,
            reference_image=ref_img,
            view=settings.get("view", "side"),
            direction="east",
            negative_description=settings.get("negative_description", ""),
            text_guidance_scale=7.5,
            image_guidance_scale=1.5,
            n_frames=n_frames,
            seed=seed if seed else 0,
        )

        # Save individual frames
        char_dir.mkdir(parents=True, exist_ok=True)
        frames = response.images  # List of PixelLabImage objects
        for i, frame in enumerate(frames, start=1):
            frame_path = char_dir / f"{anim_prefix}{i}.png"
            frame_img = frame.pil_image()
            frame_img.save(str(frame_path), "PNG")
            print(f"    Saved: {frame_path.name}")

        print(f"    OK ({len(frames)} frames)")
        return True

    except Exception as e:
        print(f"    ERROR: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate pixel art hero sprites via PixelLab API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--char", dest="char_id", type=str,
                       help="Generate a single character by char_id (e.g., human_m)")
    group.add_argument("--race", dest="race_id", type=str,
                       help="Generate all characters for a race (e.g., human)")
    group.add_argument("--all", action="store_true",
                       help="Generate all 18 character sprites")
    group.add_argument("--animate", dest="animate_char", type=str,
                       help="Generate animation frames for a character")
    group.add_argument("--list", action="store_true",
                       help="List all available characters and animations")
    group.add_argument("--balance", action="store_true",
                       help="Check API credit balance")

    parser.add_argument("--anim", type=str, default="all",
                        help="Animation to generate (idle, attack, cast, hit, death, walk, or 'all')")
    parser.add_argument("--style", type=str, default="snes",
                        help="Art style variant (snes, gba, modern, chibi)")
    parser.add_argument("--seed", type=int, default=0,
                        help="Seed for reproducible generation (0 = random)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview what would be generated without calling API")
    parser.add_argument("--force", action="store_true",
                        help="Regenerate even if files already exist")

    args = parser.parse_args()

    # Load prompts
    prompts = load_prompts()

    # List mode
    if args.list:
        list_characters(prompts)
        return

    # Balance check
    if args.balance:
        client = get_client()
        check_balance(client)
        return

    # Get style prefix
    styles = prompts.get("styles", {})
    if args.style not in styles:
        print(f"ERROR: Unknown style '{args.style}'. Available: {', '.join(styles.keys())}")
        sys.exit(1)
    style_prefix = styles[args.style]["prefix"]
    print(f"Style: {styles[args.style]['label']}")

    settings = prompts.get("settings", {})

    # Animation mode
    if args.animate_char:
        characters = filter_characters(prompts, char_id=args.animate_char)
        char = characters[0]
        animations = prompts.get("animations", {})

        if args.anim == "all":
            anim_list = list(animations.keys())
        elif args.anim in animations:
            anim_list = [args.anim]
        else:
            print(f"ERROR: Unknown animation '{args.anim}'. Available: {', '.join(animations.keys())}")
            sys.exit(1)

        print(f"\nGenerating animations for {char['char_id']}: {', '.join(anim_list)}")

        client = None
        if not args.dry_run:
            client = get_client()
            check_balance(client)

        success = 0
        failed = 0
        for anim_name in anim_list:
            anim_config = animations[anim_name]
            # Force-remove existing frames if --force
            if args.force and not args.dry_run:
                char_dir = OUTPUT_DIR / char["char_id"]
                prefix = anim_name.capitalize()
                for f in char_dir.glob(f"{prefix}*.png"):
                    f.unlink()

            result = generate_animation(
                client=client, char=char, anim_name=anim_name,
                anim_config=anim_config, settings=settings,
                style_prefix=style_prefix, seed=args.seed, dry_run=args.dry_run
            )
            if result:
                success += 1
            else:
                failed += 1

            if not args.dry_run and anim_name != anim_list[-1]:
                time.sleep(RATE_LIMIT_SECONDS)

        print(f"\n{'='*60}")
        print(f"Done! Generated: {success}, Failed: {failed}")
        return

    # Static sprite generation mode
    if args.all:
        characters = filter_characters(prompts)
    elif args.char_id:
        characters = filter_characters(prompts, char_id=args.char_id)
    elif args.race_id:
        characters = filter_characters(prompts, race_id=args.race_id)
    else:
        characters = filter_characters(prompts)

    print(f"\nPixelLab Hero Sprite Generator")
    print(f"Characters to generate: {len(characters)}")

    # Force: clean existing files
    if args.force and not args.dry_run:
        for char in characters:
            source_path = SOURCES_DIR / f"{char['char_id']}.png"
            final_dir = OUTPUT_DIR / char["char_id"]
            final_path = final_dir / f"{char['char_id']}.png"
            if final_path.exists():
                final_path.unlink()
                print(f"  Removed: {final_path.name}")
            if source_path.exists():
                source_path.unlink()

    # Get client
    client = None
    if not args.dry_run:
        client = get_client()
        check_balance(client)

    # Ensure output directories
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SOURCES_DIR.mkdir(parents=True, exist_ok=True)

    # Generate style anchor first
    style_anchor_img = generate_style_anchor(
        client, prompts, style_prefix, seed=args.seed, dry_run=args.dry_run
    )

    if not args.dry_run:
        time.sleep(RATE_LIMIT_SECONDS)

    # Generate characters
    success = 0
    failed = 0

    for i, char in enumerate(characters):
        result = generate_character(
            client=client, char=char, settings=settings,
            style_prefix=style_prefix, style_anchor_img=style_anchor_img,
            seed=args.seed, dry_run=args.dry_run
        )
        if result:
            success += 1
        else:
            failed += 1

        if not args.dry_run and i < len(characters) - 1:
            time.sleep(RATE_LIMIT_SECONDS)

    print(f"\n{'='*60}")
    print(f"Done! Generated: {success}, Failed: {failed}")
    print(f"Output folder: {OUTPUT_DIR.relative_to(PROJECT_ROOT)}")
    if not args.dry_run and client:
        check_balance(client)


if __name__ == "__main__":
    main()
