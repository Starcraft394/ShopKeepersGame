#!/usr/bin/env python3
"""
PixelLab Class Card Generator for ShopKeepers Game
====================================================
Generates pixel art card frame backgrounds for each hero class.
Reads prompts from DevTools/pixellab_card_prompts.json, generates at native
40x47 pixel-art resolution, upscales 3x nearest-neighbor to 120x141, and
saves to Assets/UI/Cards/.

Usage:
  python DevTools/generate_class_cards.py --list
  python DevTools/generate_class_cards.py --class defender
  python DevTools/generate_class_cards.py --all
  python DevTools/generate_class_cards.py --all --dry-run
  python DevTools/generate_class_cards.py --all --seed 42
  python DevTools/generate_class_cards.py --balance

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
PROMPTS_FILE = SCRIPT_DIR / "pixellab_card_prompts.json"
OUTPUT_DIR = PROJECT_ROOT / "Assets" / "UI" / "Cards"
SOURCES_DIR = OUTPUT_DIR / "_sources"

# Upscale factor: 1 = native resolution (120x141 generated directly)
# Set > 1 only if generating at smaller native size (e.g. 40x47 * 3 = 120x141)
UPSCALE_FACTOR = 1

# Rate limit: seconds between API calls
RATE_LIMIT_SECONDS = 1.0


def load_prompts() -> dict:
    """Load the card prompt library from pixellab_card_prompts.json."""
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


def filter_cards(prompts: dict, class_id: str = None) -> list:
    """Filter cards from the prompt library."""
    cards = prompts.get("cards", [])
    if class_id:
        matches = [c for c in cards if c["class_id"] == class_id]
        if not matches:
            print(f"ERROR: Class '{class_id}' not found in prompt library.")
            print("Available classes:")
            for c in cards:
                print(f"  {c['class_id']} (R{c['region']})")
            sys.exit(1)
        return matches
    return cards


def list_cards(prompts: dict) -> None:
    """Print all available class cards."""
    cards = prompts.get("cards", [])
    print(f"\nPixelLab Class Card Library — {len(cards)} cards\n")
    by_region = {}
    for c in cards:
        by_region.setdefault(c["region"], []).append(c)

    for region in sorted(by_region.keys()):
        entries = by_region[region]
        print(f"  Region {region} ({len(entries)} cards):")
        for entry in entries:
            print(f"    - {entry['card_id']} ({entry['class_id']})")
    print()


def generate_card(client: Client, card: dict, settings: dict,
                  seed: int = 0, dry_run: bool = False) -> bool:
    """Generate a single class card image via PixelLab API.

    Returns True if image was generated (or would be in dry-run), False on error.
    """
    card_id = card["card_id"]
    class_id = card["class_id"]

    width = settings.get("width", 40)
    height = settings.get("height", 47)
    final_w = width * UPSCALE_FACTOR
    final_h = height * UPSCALE_FACTOR

    negative = card.get("negative_description", settings.get("negative_description", ""))

    print(f"\n{'='*60}")
    print(f"Card: {card_id} (class: {class_id}, region: {card['region']})")
    print(f"  Size: {width}x{height} -> {final_w}x{final_h} ({UPSCALE_FACTOR}x upscale)")
    print(f"  Prompt: {card['description'][:80]}...")

    if dry_run:
        print(f"  [DRY RUN] Would generate {card_id}.png")
        return True

    # Build output paths
    source_path = SOURCES_DIR / f"{card_id}.png"
    final_path = OUTPUT_DIR / f"{card_id}.png"

    # Skip if already exists
    if final_path.exists():
        print(f"  SKIP: {final_path.name} already exists. Delete to regenerate.")
        return True

    try:
        params = {
            "description": card["description"],
            "image_size": {"width": width, "height": height},
            "text_guidance_scale": settings.get("text_guidance_scale", 8.0),
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

        print(f"  Generating...")
        response = client.generate_image_pixflux(**params)
        pil_img = response.image.pil_image()

        # Ensure directories exist
        SOURCES_DIR.mkdir(parents=True, exist_ok=True)

        # Save raw source
        pil_img.save(str(source_path), "PNG")
        print(f"  Saved source: {source_path.relative_to(PROJECT_ROOT)}")

        # Upscale with nearest-neighbor
        upscaled = pil_img.resize((final_w, final_h), Image.NEAREST)
        upscaled.save(str(final_path), "PNG")
        print(f"  Saved final:  {final_path.relative_to(PROJECT_ROOT)}")
        print(f"  OK")
        return True

    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate pixel art class card backgrounds via PixelLab API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--class", dest="class_id", type=str,
                       help="Generate a single class card by class ID")
    group.add_argument("--all", action="store_true",
                       help="Generate all 15 class cards")
    group.add_argument("--list", action="store_true",
                       help="List all available class cards")
    group.add_argument("--balance", action="store_true",
                       help="Check API credit balance")

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
        list_cards(prompts)
        return

    # Balance check
    if args.balance:
        client = get_client()
        check_balance(client)
        return

    # Filter cards
    if args.all:
        cards = filter_cards(prompts)
    else:
        cards = filter_cards(prompts, class_id=args.class_id)

    print(f"\nPixelLab Class Card Generator")
    print(f"Cards to generate: {len(cards)}")

    # If force, clean existing files first
    if args.force and not args.dry_run:
        for card in cards:
            final_path = OUTPUT_DIR / f"{card['card_id']}.png"
            source_path = SOURCES_DIR / f"{card['card_id']}.png"
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

    # Ensure output directories
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SOURCES_DIR.mkdir(parents=True, exist_ok=True)

    # Generate
    settings = prompts.get("settings", {})
    success = 0
    failed = 0

    for i, card in enumerate(cards):
        result = generate_card(
            client=client,
            card=card,
            settings=settings,
            seed=args.seed,
            dry_run=args.dry_run
        )
        if result:
            success += 1
        else:
            failed += 1

        # Rate limiting between API calls
        if not args.dry_run and i < len(cards) - 1:
            time.sleep(RATE_LIMIT_SECONDS)

    print(f"\n{'='*60}")
    print(f"Done! Generated: {success}, Failed: {failed}")
    print(f"Output folder: {OUTPUT_DIR.relative_to(PROJECT_ROOT)}")
    if not args.dry_run and client:
        check_balance(client)


if __name__ == "__main__":
    main()
