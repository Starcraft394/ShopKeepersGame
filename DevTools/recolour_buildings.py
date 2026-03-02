"""
Recolour building sprites per region.
- Source: 10 base PNGs in Assets/Backgrounds/building_*.png (R1 palette)
- Output: Assets/Backgrounds/Buildings/R{2-7}/building_*.png (60 recoloured PNGs)
- R1 uses the base sprites directly (no recolour needed)

Uses the same HSV recolouring approach as recolour_items.py and recolour_monsters.py.
"""

import os
import colorsys
from PIL import Image

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(BASE, "Assets", "Backgrounds")
OUT_BASE = os.path.join(BASE, "Assets", "Backgrounds", "Buildings")

BUILDING_NAMES = [
    "building_alchemist",
    "building_blacksmith",
    "building_chef",
    "building_dungeon",
    "building_enchanter",
    "building_huntsman",
    "building_inn",
    "building_shop",
    "building_storage",
    "building_training",
]


# ============================================================
# HSV recolouring functions (same as recolour_items.py)
# ============================================================

def recolour_pixel_hsv(r, g, b, target_hue, sat_mult=1.0, val_mult=1.0,
                       sat_offset=0.0, val_offset=0.0, hue_range=0.05):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    new_h = target_hue + (h - 0.5) * hue_range * 2
    new_h = new_h % 1.0
    s = min(1.0, max(0.0, s * sat_mult + sat_offset))
    v = min(1.0, max(0.0, v * val_mult + val_offset))
    nr, ng, nb = colorsys.hsv_to_rgb(new_h, s, v)
    return (int(nr * 255), int(ng * 255), int(nb * 255))


def recolour_image(img, target_hue, sat_mult=1.0, val_mult=1.0,
                   sat_offset=0.0, val_offset=0.0, hue_range=0.05):
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            rgba = pixels[x, y]
            if len(rgba) == 4:
                r, g, b, a = rgba
            else:
                r, g, b = rgba
                a = 255
            if a < 10:
                continue
            nr, ng, nb = recolour_pixel_hsv(
                r, g, b, target_hue, sat_mult, val_mult,
                sat_offset, val_offset, hue_range
            )
            pixels[x, y] = (nr, ng, nb, a)
    return img


def desaturate_image(img, sat_mult=0.15, val_mult=1.0, val_offset=0.2,
                     tint_hue=None, tint_strength=0.0):
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            rgba = pixels[x, y]
            if len(rgba) == 4:
                r, g, b, a = rgba
            else:
                r, g, b = rgba
                a = 255
            if a < 10:
                continue
            hu, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if tint_hue is not None:
                hu = tint_hue
            s = min(1.0, max(0.0, s * sat_mult + tint_strength))
            v = min(1.0, max(0.0, v * val_mult + val_offset))
            nr, ng, nb = colorsys.hsv_to_rgb(hu, s, v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return img


# ============================================================
# Region tint definitions
# ============================================================

# Hue constants (matching recolour_items.py conventions)
HUE_NEON_GREEN = 0.300    # 108 degrees
HUE_TEAL = 0.500          # 180 degrees
HUE_ORANGE_RED = 0.056    # 20 degrees
HUE_LIGHT_PINK = 0.920    # 331 degrees
HUE_PURPLE = 0.778        # 280 degrees
HUE_DARK_PURPLE = 0.800   # 288 degrees

REGION_TINTS = {
    2: {
        "label": "R2 Fungalmire (neon green)",
        "fn": lambda img: recolour_image(img, HUE_NEON_GREEN,
                                         sat_mult=1.1, val_mult=1.0, hue_range=0.06),
    },
    3: {
        "label": "R3 Sunken Strand (teal)",
        "fn": lambda img: recolour_image(img, HUE_TEAL,
                                         sat_mult=0.85, val_mult=1.0, hue_range=0.06),
    },
    4: {
        "label": "R4 Ashen Horizons (orange-red)",
        "fn": lambda img: recolour_image(img, HUE_ORANGE_RED,
                                         sat_mult=1.1, val_mult=1.0, hue_range=0.06),
    },
    5: {
        "label": "R5 Starfall Expanse (pink/orchid)",
        "fn": lambda img: recolour_image(img, HUE_LIGHT_PINK,
                                         sat_mult=0.7, val_mult=1.05, hue_range=0.05),
    },
    6: {
        "label": "R6 Necropolis (desaturated mauve)",
        "fn": lambda img: desaturate_image(img, sat_mult=0.12, val_mult=0.90,
                                           val_offset=0.10, tint_hue=HUE_PURPLE,
                                           tint_strength=0.05),
    },
    7: {
        "label": "R7 Final Realm (dark purple)",
        "fn": lambda img: recolour_image(img, HUE_DARK_PURPLE,
                                         sat_mult=1.1, val_mult=0.75, hue_range=0.04),
    },
}


# ============================================================
# Main
# ============================================================

if __name__ == "__main__":
    total = 0
    for region_num in sorted(REGION_TINTS.keys()):
        tint = REGION_TINTS[region_num]
        out_dir = os.path.join(OUT_BASE, f"R{region_num}")
        os.makedirs(out_dir, exist_ok=True)
        print(f"\n[R{region_num}] {tint['label']}")

        for bld_name in BUILDING_NAMES:
            src_path = os.path.join(SRC_DIR, f"{bld_name}.png")
            dst_path = os.path.join(out_dir, f"{bld_name}.png")

            if not os.path.exists(src_path):
                print(f"  SKIP: {bld_name}.png (source not found)")
                continue

            img = Image.open(src_path).convert("RGBA")
            img = tint["fn"](img)
            img.save(dst_path)
            total += 1
            print(f"  OK: {bld_name}.png")

    print(f"\nDone! {total} building sprites generated across {len(REGION_TINTS)} regions.")
