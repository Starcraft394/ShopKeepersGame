"""
Recolour avatar icons for custom races:
- Voidwalkers: Purple tint from Demon (BF) + Undead (BK) source icons
- Tidelings: Dark blue / light teal from existing green-tinted pack
- Crystalborn: White / light brown / pink from existing blue-tinted pack
"""

import os
import colorsys
from PIL import Image

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTPACKS = os.path.join(BASE, "Assets", "_ArtPacks")


def recolour_pixel(r, g, b, target_hue, sat_mult=1.0, val_mult=1.0, sat_offset=0.0, val_offset=0.0):
    """Recolour a single pixel by shifting hue and adjusting sat/val."""
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    # Set hue to target
    h = target_hue
    # Adjust saturation
    s = min(1.0, max(0.0, s * sat_mult + sat_offset))
    # Adjust value
    v = min(1.0, max(0.0, v * val_mult + val_offset))
    nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
    return (int(nr * 255), int(ng * 255), int(nb * 255))


def recolour_image(img, target_hue, sat_mult=1.0, val_mult=1.0, sat_offset=0.0, val_offset=0.0):
    """Recolour an entire RGBA image."""
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
            if a < 10:  # Skip transparent
                continue
            nr, ng, nb = recolour_pixel(r, g, b, target_hue, sat_mult, val_mult, sat_offset, val_offset)
            pixels[x, y] = (nr, ng, nb, a)
    return img


def recolour_image_varied(img, base_hue, hue_range=0.05, sat_mult=1.0, val_mult=1.0, sat_offset=0.0, val_offset=0.0):
    """Recolour preserving hue variation around a base hue."""
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
            orig_h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            # Map original hue variation to a narrow band around target
            new_h = base_hue + (orig_h - 0.5) * hue_range * 2
            new_h = new_h % 1.0
            s = min(1.0, max(0.0, s * sat_mult + sat_offset))
            v = min(1.0, max(0.0, v * val_mult + val_offset))
            nr, ng, nb = colorsys.hsv_to_rgb(new_h, s, v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return img


def recolour_voidwalkers():
    """Create purple-tinted Voidwalker avatars from Demon + Undead sources."""
    out_dir = os.path.join(ARTPACKS, "Avatars_Voidwalkers_PNG")
    os.makedirs(out_dir, exist_ok=True)

    # Source icons: BF#13, BF#29, BF#31, BF#46, BK#43
    sources = [
        (os.path.join(ARTPACKS, "Avatars_Demon", "PNG", "Transperent", "Icon13.png"), "Icon1.png"),
        (os.path.join(ARTPACKS, "Avatars_Demon", "PNG", "Transperent", "Icon29.png"), "Icon2.png"),
        (os.path.join(ARTPACKS, "Avatars_Demon", "PNG", "Transperent", "Icon31.png"), "Icon3.png"),
        (os.path.join(ARTPACKS, "Avatars_Demon", "PNG", "Transperent", "Icon46.png"), "Icon4.png"),
        (os.path.join(ARTPACKS, "Avatars_Undead", "PNG", "Transperent", "Icon43.png"), "Icon5.png"),
    ]

    # Purple hue = ~280° = 0.778 in 0-1 range
    purple_hue = 0.778

    for src_path, out_name in sources:
        if not os.path.exists(src_path):
            print(f"  SKIP (missing): {src_path}")
            continue
        img = Image.open(src_path).convert("RGBA")
        # Deep purple with good saturation, preserve brightness
        img = recolour_image_varied(img, purple_hue, hue_range=0.04, sat_mult=1.1, val_mult=0.95)
        out_path = os.path.join(out_dir, out_name)
        img.save(out_path)
        print(f"  OK: {out_name} <- {os.path.basename(src_path)}")

    print(f"Voidwalkers: {len(sources)} icons -> {out_dir}")


def recolour_tidelings():
    """Recolour existing Tideling pack from green to darker blue / lighter teal."""
    pack_dir = os.path.join(ARTPACKS, "Avatars_Tidelings_PNG")
    if not os.path.isdir(pack_dir):
        print(f"  SKIP: Tidelings pack not found at {pack_dir}")
        return

    # Teal-blue hue = ~195° = 0.542 in 0-1 range
    teal_hue = 0.542
    count = 0
    for fname in sorted(os.listdir(pack_dir)):
        if not fname.lower().endswith(".png"):
            continue
        fpath = os.path.join(pack_dir, fname)
        img = Image.open(fpath).convert("RGBA")
        # Darker blues with teal variation, slightly less bright
        img = recolour_image_varied(img, teal_hue, hue_range=0.08, sat_mult=1.2, val_mult=0.85, val_offset=0.0)
        img.save(fpath)
        count += 1

    print(f"Tidelings: {count} icons recoloured in {pack_dir}")


def recolour_crystalborn():
    """Recolour existing Crystalborn pack to white / light brown / pink."""
    pack_dir = os.path.join(ARTPACKS, "Avatars_Crystalborn_PNG")
    if not os.path.isdir(pack_dir):
        print(f"  SKIP: Crystalborn pack not found at {pack_dir}")
        return

    # Pink-warm hue = ~340° = 0.944 in 0-1 range
    pink_hue = 0.944
    count = 0
    for fname in sorted(os.listdir(pack_dir)):
        if not fname.lower().endswith(".png"):
            continue
        fpath = os.path.join(pack_dir, fname)
        img = Image.open(fpath).convert("RGBA")
        # Heavy desaturation toward white, slight pink/warm tint, brighten
        img = recolour_image_varied(img, pink_hue, hue_range=0.06, sat_mult=0.35, val_mult=1.0, val_offset=0.15)
        img.save(fpath)
        count += 1

    print(f"Crystalborn: {count} icons recoloured in {pack_dir}")


if __name__ == "__main__":
    print("=== Voidwalkers (purple) ===")
    recolour_voidwalkers()
    print()
    print("=== Tidelings (dark blue / teal) ===")
    recolour_tidelings()
    print()
    print("=== Crystalborn (white / pink / light brown) ===")
    recolour_crystalborn()
    print()
    print("Done! Review the results and adjust parameters if needed.")
