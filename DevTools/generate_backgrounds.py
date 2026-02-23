#!/usr/bin/env python3
"""
PixelLab Background Generator for ShopKeepers Game
===================================================
Automates background art generation via the PixelLab API.
Reads prompts from DevTools/pixellab_prompts.json, generates at native pixel-art
resolution, upscales 3x nearest-neighbor, and saves to staging folder for review.

Usage:
  python DevTools/generate_backgrounds.py --list
  python DevTools/generate_backgrounds.py --scene town_thornhaven_T1
  python DevTools/generate_backgrounds.py --category town
  python DevTools/generate_backgrounds.py --all
  python DevTools/generate_backgrounds.py --scene dungeon_R1 --seed 42
  python DevTools/generate_backgrounds.py --all --dry-run
  python DevTools/generate_backgrounds.py --balance

Environment:
  PIXELLAB_API_KEY  — Required. Your PixelLab API secret key.
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
PROMPTS_FILE = SCRIPT_DIR / "pixellab_prompts.json"
STAGING_DIR = PROJECT_ROOT / "Assets" / "Backgrounds" / "_staging"
SOURCES_DIR = STAGING_DIR / "sources"

# Upscale factor: 320x180 * 3 = 960x540
UPSCALE_FACTOR = 3
# Building sprites: 128x128, no upscale needed (used as-is or scaled in Godot)
BUILDING_UPSCALE_FACTOR = 1

# Rate limit: seconds between API calls
RATE_LIMIT_SECONDS = 1.0


def load_prompts() -> dict:
    """Load the prompt library from pixellab_prompts.json."""
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


def filter_scenes(prompts: dict, scene_id: str = None,
                  category: str = None) -> list:
    """Filter scenes from the prompt library."""
    scenes = prompts.get("scenes", [])
    if scene_id:
        matches = [s for s in scenes if s["scene_id"] == scene_id]
        if not matches:
            print(f"ERROR: Scene '{scene_id}' not found in prompt library.")
            print("Available scenes:")
            for s in scenes:
                print(f"  {s['scene_id']} ({s['category']})")
            sys.exit(1)
        return matches
    if category:
        matches = [s for s in scenes if s["category"] == category]
        if not matches:
            categories = sorted(set(s["category"] for s in scenes))
            print(f"ERROR: Category '{category}' not found.")
            print(f"Available categories: {', '.join(categories)}")
            sys.exit(1)
        return matches
    return scenes


def list_scenes(prompts: dict) -> None:
    """Print all available scenes grouped by category."""
    scenes = prompts.get("scenes", [])
    by_category = {}
    for s in scenes:
        by_category.setdefault(s["category"], []).append(s["scene_id"])

    print(f"\nPixelLab Prompt Library — {len(scenes)} scenes\n")
    for cat in sorted(by_category.keys()):
        ids = by_category[cat]
        print(f"  {cat} ({len(ids)}):")
        for sid in ids:
            print(f"    - {sid}")
    print()


def generate_scene(client: Client, scene: dict, settings: dict,
                   building_settings: dict, seed: int = 0,
                   dry_run: bool = False) -> bool:
    """Generate a single scene image via PixelLab API.

    Returns True if image was generated (or would be in dry-run), False on error.
    """
    scene_id = scene["scene_id"]
    category = scene["category"]
    is_building = category == "building"

    # Pick settings based on category
    cfg = building_settings if is_building else settings

    width = cfg.get("width", 320)
    height = cfg.get("height", 180)
    upscale = BUILDING_UPSCALE_FACTOR if is_building else UPSCALE_FACTOR
    final_w = width * upscale
    final_h = height * upscale

    # Merge scene-level negative_description with settings-level
    negative = scene.get("negative_description", cfg.get("negative_description", ""))

    print(f"\n{'='*60}")
    print(f"Scene: {scene_id} ({category})")
    print(f"  Size: {width}x{height} -> {final_w}x{final_h} ({upscale}x upscale)")
    print(f"  Outline: {cfg.get('outline', 'selective outline')}")
    print(f"  Shading: {cfg.get('shading', 'medium shading')}")
    print(f"  Detail: {cfg.get('detail', 'medium detail')}")
    if seed:
        print(f"  Seed: {seed}")
    print(f"  Prompt: {scene['description'][:80]}...")

    if dry_run:
        print(f"  [DRY RUN] Would generate {scene_id}.png")
        return True

    # Build output paths
    source_path = SOURCES_DIR / f"{scene_id}.png"
    final_path = STAGING_DIR / f"{scene_id}.png"

    # Skip if already exists
    if final_path.exists():
        print(f"  SKIP: {final_path.name} already exists. Delete to regenerate.")
        return True

    try:
        # Build API parameters
        params = {
            "description": scene["description"],
            "image_size": {"width": width, "height": height},
            "text_guidance_scale": cfg.get("text_guidance_scale", 8.0),
            "outline": cfg.get("outline", "selective outline"),
            "shading": cfg.get("shading", "medium shading"),
            "detail": cfg.get("detail", "medium detail"),
            "view": cfg.get("view", "side"),
            "no_background": cfg.get("no_background", False),
        }
        if negative:
            params["negative_description"] = negative
        if seed:
            params["seed"] = seed

        print(f"  Generating...")
        response = client.generate_image_pixflux(**params)
        pil_img = response.image.pil_image()

        # Ensure directories exist
        SOURCES_DIR.mkdir(parents=True, exist_ok=True)

        # Save raw source
        pil_img.save(str(source_path), "PNG")
        print(f"  Saved source: {source_path.relative_to(PROJECT_ROOT)}")

        # Upscale with nearest-neighbor
        if upscale > 1:
            upscaled = pil_img.resize((final_w, final_h), Image.NEAREST)
        else:
            upscaled = pil_img

        upscaled.save(str(final_path), "PNG")
        print(f"  Saved final:  {final_path.relative_to(PROJECT_ROOT)}")
        print(f"  OK")
        return True

    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate pixel art backgrounds via PixelLab API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--scene", type=str, help="Generate a single scene by ID")
    group.add_argument("--category", type=str,
                       help="Generate all scenes in a category (town/dungeon/event/shop/building)")
    group.add_argument("--all", action="store_true", help="Generate all scenes")
    group.add_argument("--list", action="store_true", help="List all available scenes")
    group.add_argument("--balance", action="store_true", help="Check API credit balance")

    parser.add_argument("--seed", type=int, default=0,
                        help="Seed for reproducible generation (0 = random)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview what would be generated without calling API")
    parser.add_argument("--force", action="store_true",
                        help="Regenerate even if file already exists")

    args = parser.parse_args()

    # Load prompts
    prompts = load_prompts()

    # List mode
    if args.list:
        list_scenes(prompts)
        return

    # Balance check
    if args.balance:
        client = get_client()
        check_balance(client)
        return

    # Filter scenes
    if args.all:
        scenes = filter_scenes(prompts)
    elif args.category:
        scenes = filter_scenes(prompts, category=args.category)
    else:
        scenes = filter_scenes(prompts, scene_id=args.scene)

    print(f"\nPixelLab Background Generator")
    print(f"Scenes to generate: {len(scenes)}")

    # If force, clean existing files first
    if args.force and not args.dry_run:
        for scene in scenes:
            final_path = STAGING_DIR / f"{scene['scene_id']}.png"
            source_path = SOURCES_DIR / f"{scene['scene_id']}.png"
            if final_path.exists():
                final_path.unlink()
                print(f"  Removed: {final_path.name}")
            if source_path.exists():
                source_path.unlink()

    # Get client (unless dry-run)
    client = None
    if not args.dry_run:
        client = get_client()
        check_balance(client)

    # Ensure staging directories
    STAGING_DIR.mkdir(parents=True, exist_ok=True)
    SOURCES_DIR.mkdir(parents=True, exist_ok=True)

    # Generate
    settings = prompts.get("settings", {})
    building_settings = prompts.get("building_settings", {})

    success = 0
    failed = 0
    skipped = 0

    for i, scene in enumerate(scenes):
        result = generate_scene(
            client=client,
            scene=scene,
            settings=settings,
            building_settings=building_settings,
            seed=args.seed,
            dry_run=args.dry_run
        )
        if result:
            # Check if it was skipped (file existed)
            final_path = STAGING_DIR / f"{scene['scene_id']}.png"
            if not args.dry_run and final_path.exists():
                success += 1
            else:
                success += 1
        else:
            failed += 1

        # Rate limiting between API calls
        if not args.dry_run and i < len(scenes) - 1:
            time.sleep(RATE_LIMIT_SECONDS)

    print(f"\n{'='*60}")
    print(f"Done! Generated: {success}, Failed: {failed}")
    print(f"Staging folder: {STAGING_DIR.relative_to(PROJECT_ROOT)}")
    if not args.dry_run:
        check_balance(client)


if __name__ == "__main__":
    main()
