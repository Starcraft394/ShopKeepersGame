"""
Recolour monster portrait icons for Regions 2-7.
- Copies originals to Assets/_ArtPacks/Monsters_Recolored/ before recolouring
- Uses same HSV recolouring approach as recolour_avatars.py
- Monsters without recolouring get a plain copy for consistent pathing

Source pack mapping:
  BL = Monsters_LowLevel/PNG/Transperent/
  BM = Monsters_Chaos/PNG/Transperent/
  BK = Avatars_Undead/PNG/Transperent/
  BS = Avatars_Tidelings_PNG/
  AV = Skills_Necromancer/PNG/
  AS = Skills_Druid/PNG/
"""

import os
import colorsys
from PIL import Image

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTPACKS = os.path.join(BASE, "Assets", "_ArtPacks")
OUT_DIR = os.path.join(ARTPACKS, "Monsters_Recolored")

# Source pack paths
PACKS = {
    "BL": os.path.join(ARTPACKS, "Monsters_LowLevel", "PNG", "Transperent"),
    "BM": os.path.join(ARTPACKS, "Monsters_Chaos", "PNG", "Transperent"),
    "BK": os.path.join(ARTPACKS, "Avatars_Undead", "PNG", "Transperent"),
    "BS": os.path.join(ARTPACKS, "Avatars_Tidelings_PNG"),
    "AV": os.path.join(ARTPACKS, "Skills_Necromancer", "PNG"),
    "AS": os.path.join(ARTPACKS, "Skills_Druid", "PNG"),
}

# Hue values (0-1 range, mapping from degrees)
HUE_PINK = 0.944       # ~340°
HUE_LIGHT_PINK = 0.95  # ~342°
HUE_BLUE = 0.583       # ~210°
HUE_TEAL = 0.500       # ~180°
HUE_CYAN = 0.520       # ~187°
HUE_RED_ORANGE = 0.03  # ~11°
HUE_RED = 0.00         # ~0°
HUE_PURPLE = 0.778     # ~280°
HUE_LIGHT_PURPLE = 0.760  # ~274°
HUE_GREEN = 0.333      # ~120°
HUE_BROWN = 0.08       # ~29°
HUE_BLUE_SAND = 0.14   # blend


def recolour_pixel_hsv(r, g, b, target_hue, sat_mult=1.0, val_mult=1.0,
                       sat_offset=0.0, val_offset=0.0, hue_range=0.05):
    """Recolour a pixel by shifting hue while preserving variation."""
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    new_h = target_hue + (h - 0.5) * hue_range * 2
    new_h = new_h % 1.0
    s = min(1.0, max(0.0, s * sat_mult + sat_offset))
    v = min(1.0, max(0.0, v * val_mult + val_offset))
    nr, ng, nb = colorsys.hsv_to_rgb(new_h, s, v)
    return (int(nr * 255), int(ng * 255), int(nb * 255))


def recolour_image(img, target_hue, sat_mult=1.0, val_mult=1.0,
                   sat_offset=0.0, val_offset=0.0, hue_range=0.05):
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
    """Desaturate toward white/grey with optional light tint."""
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


def darken_with_tint(img, tint_hue=0.0, sat_mult=0.8, val_mult=0.4,
                     sat_offset=0.15, val_offset=0.0):
    """Darken image with a color tint (for black/dark recolours)."""
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
            hu = tint_hue
            s = min(1.0, max(0.0, s * sat_mult + sat_offset))
            v = min(1.0, max(0.0, v * val_mult + val_offset))
            nr, ng, nb = colorsys.hsv_to_rgb(hu, s, v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return img


def get_source_path(pack_code, icon_num):
    """Get the full path to a source icon."""
    pack_dir = PACKS[pack_code]
    return os.path.join(pack_dir, f"Icon{icon_num}.png")


def process_job(monster_id, pack_code, icon_num, recolour_fn=None):
    """Process a single monster portrait job."""
    src = get_source_path(pack_code, icon_num)
    dst = os.path.join(OUT_DIR, f"{monster_id}.png")

    if not os.path.exists(src):
        print(f"  SKIP (missing): {monster_id} <- {pack_code}#{icon_num}: {src}")
        return False

    img = Image.open(src).convert("RGBA")
    if recolour_fn:
        img = recolour_fn(img)
    img.save(dst)
    print(f"  OK: {monster_id}.png <- {pack_code}#{icon_num}" +
          (" (recoloured)" if recolour_fn else " (copy)"))
    return True


# ============================================================
# Recolour functions for each colour profile
# ============================================================

def tint_pink(img):
    return recolour_image(img, HUE_PINK, sat_mult=0.8, val_mult=1.0, hue_range=0.04)

def tint_light_pink(img):
    return recolour_image(img, HUE_LIGHT_PINK, sat_mult=0.6, val_mult=1.05, hue_range=0.04)

def tint_green(img):
    return recolour_image(img, HUE_GREEN, sat_mult=1.0, val_mult=1.0, hue_range=0.05)

def tint_blue(img):
    return recolour_image(img, HUE_BLUE, sat_mult=1.1, val_mult=0.9, hue_range=0.06)

def tint_blue_teal(img):
    return recolour_image(img, HUE_TEAL, sat_mult=1.2, val_mult=0.85, hue_range=0.08)

def tint_cyan_dark(img):
    return recolour_image(img, HUE_CYAN, sat_mult=1.2, val_mult=0.8, hue_range=0.06)

def tint_blue_sand(img):
    """Blue body with sandy/warm highlights."""
    return recolour_image(img, HUE_BLUE, sat_mult=0.8, val_mult=0.95, hue_range=0.15)

def tint_red_orange(img):
    return recolour_image(img, HUE_RED_ORANGE, sat_mult=1.1, val_mult=1.0, hue_range=0.06)

def tint_red(img):
    return recolour_image(img, HUE_RED, sat_mult=1.2, val_mult=0.95, hue_range=0.03)

def tint_light_red_orange(img):
    return recolour_image(img, HUE_RED_ORANGE, sat_mult=0.9, val_mult=1.05, hue_range=0.08)

def tint_purple(img):
    return recolour_image(img, HUE_PURPLE, sat_mult=1.1, val_mult=0.95, hue_range=0.04)

def tint_light_purple_transparent(img):
    """Light purple with reduced opacity feel (brighten + desaturate slightly)."""
    return recolour_image(img, HUE_LIGHT_PURPLE, sat_mult=0.7, val_mult=1.1, hue_range=0.05)

def tint_brown(img):
    return recolour_image(img, HUE_BROWN, sat_mult=0.9, val_mult=0.85, hue_range=0.05)

def tint_blue_white(img):
    """Blue/white — desaturated blue, bright."""
    return recolour_image(img, HUE_BLUE, sat_mult=0.5, val_mult=1.1, hue_range=0.04)

def desaturate_white(img):
    """Heavy desaturation toward white/bone look."""
    return desaturate_image(img, sat_mult=0.12, val_mult=1.0, val_offset=0.2)

def desaturate_white_grey(img):
    """White/grey bone look."""
    return desaturate_image(img, sat_mult=0.10, val_mult=0.95, val_offset=0.15)

def desaturate_grey_white(img):
    """Grey/white for armoured undead."""
    return desaturate_image(img, sat_mult=0.08, val_mult=0.85, val_offset=0.2)

def tint_black_red(img):
    """Dark with red tint — for dark wraith/wight."""
    return darken_with_tint(img, tint_hue=HUE_RED, sat_mult=0.6, val_mult=0.35,
                            sat_offset=0.2, val_offset=0.05)

def tint_black(img):
    """Very dark with slight red eyes effect."""
    return darken_with_tint(img, tint_hue=HUE_RED, sat_mult=0.4, val_mult=0.3,
                            sat_offset=0.1, val_offset=0.0)

def reduce_sunflower(img):
    """Less yellow/sunflower — shift toward green-brown."""
    return recolour_image(img, 0.22, sat_mult=0.7, val_mult=0.9, hue_range=0.08)

def green_spikes_white_body(img):
    """Complex: make bright/saturated areas green, desaturate body toward white."""
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
            if s > 0.4:  # Saturated areas (spikes/details) -> green
                hu = HUE_GREEN
                s = min(1.0, s * 0.9)
            else:  # Low saturation areas (body) -> white/light grey
                s = s * 0.15
                v = min(1.0, v * 1.0 + 0.25)
            nr, ng, nb = colorsys.hsv_to_rgb(hu, s, v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return img

def glass_look(img):
    """Translucent glass look — high value, low saturation, slight cyan tint."""
    return recolour_image(img, HUE_CYAN, sat_mult=0.3, val_mult=1.15, hue_range=0.06,
                          val_offset=0.1)


# ============================================================
# Job definitions: (monster_id, pack_code, icon_num, recolour_fn or None)
# ============================================================

JOBS = [
    # ========== R2 — The Fungalmire ==========
    ("fm_bog_wisp",           "BM", 47, tint_pink),
    ("fm_cave_shroom",        "BL",  3, None),
    ("fm_mire_toad",          "BL", 48, None),
    ("fm_rot_beetle",         "BL", 36, tint_green),
    ("fm_slime_mold",         "BL", 28, None),
    ("fm_sporekin_shambler",  "BL",  4, None),
    ("fm_bloom_giant",        "BL", 20, None),
    ("fm_cordyceps_host",     "BL", 32, green_spikes_white_body),
    ("fm_fungal_lurker",      "BL",  2, None),
    ("fm_hallucinogenic_cap", "BL",  6, None),
    ("fm_rotcap_myconid",     "BL",  9, None),
    ("fm_spore_knight",       "BL",  7, None),
    ("fm_mycelium_brute",     "BL", 10, None),
    ("fm_sporewarden",        "BL", 16, None),
    ("fm_blight_mother",      "BL", 13, None),
    ("fm_spiral_mycelium",    "BL", 18, reduce_sunflower),

    # ========== R3 — Sunken Strand ==========
    ("ss_drift_jelly",        "BL", 40, tint_cyan_dark),
    ("ss_reef_snapper",       "BL",  7, tint_blue),
    ("ss_salt_lurker",        "BL",  2, tint_blue),
    ("ss_sandpiper_imp",      "BM", 11, tint_blue_sand),
    ("ss_shore_crawler",      "BM",  6, None),
    ("ss_tidewalker",         "BM", 23, None),
    ("ss_abyssal_angler",     "BM",  1, tint_blue_teal),
    ("ss_coral_golem",        "BM", 41, tint_blue),
    ("ss_crustacean_brute",   "BM", 37, tint_blue),
    ("ss_drowned_mariner",    "BM", 50, tint_blue_teal),
    ("ss_mistborn_serpent",   "BM",  3, tint_blue),
    ("ss_riptide_wraith",     "AV", 27, tint_blue_teal),
    ("ss_deepcaller_shaman",  "AS", 35, tint_blue_teal),
    ("ss_leviathan_spawn",    "BL", 35, tint_brown),
    ("ss_mistborn_leviathan", "BL", 35, tint_blue_white),
    ("ss_tide_sovereign",     "BS",  5, None),

    # ========== R4 — Ashen Horizons ==========
    ("ah_ash_crawler",        "BM", 33, tint_red_orange),
    ("ah_cinder_beetle",      "BL", 36, tint_red_orange),
    ("ah_ember_drake",        "BL", 34, None),
    ("ah_magma_mite",         "BL", 29, tint_red_orange),
    ("ah_scorched_viper",     "BM",  3, tint_red_orange),
    ("ah_soot_imp",           "BM", 11, None),
    ("ah_ash_wraith",         "AV", 27, None),
    ("ah_flame_stalker",      "BM",  7, tint_red_orange),
    ("ah_inferno_djinn",      "BM", 22, None),
    ("ah_lava_golem",         "BM", 41, tint_red_orange),
    ("ah_pyroclast_hurler",   "BM", 28, None),
    ("ah_scorpion_ravager",   "BM", 48, tint_light_red_orange),
    ("ah_fire_djinn_lord",    "BM", 19, None),
    ("ah_scorpion_titan",     "BM", 48, tint_red),
    ("ah_magma_wyrm",         "BM", 43, tint_red),
    ("ah_cinder_monarch",     "BM", 14, tint_red_orange),

    # ========== R5 — Starfall Expanse ==========
    ("se_echo_wisp",          "BM", 47, tint_light_pink),
    ("se_glass_viper",        "BM", 13, glass_look),
    ("se_prism_scarab",       "BL", 36, tint_pink),
    ("se_reality_flicker",    "BL", 39, tint_pink),
    ("se_shard_sprite",       "BL", 42, tint_pink),
    ("se_starfall_hare",      "BL", 33, tint_pink),
    ("se_crystal_wraith",     "AV", 27, tint_pink),
    ("se_paradox_shade",      "BL", 47, tint_pink),
    ("se_refraction_golem",   "BM", 41, tint_pink),
    ("se_starfall_stalker",   "BM", 34, None),
    ("se_timelost_knight",    "BM", 50, tint_pink),
    ("se_void_moth",          "BM", 49, tint_purple),
    ("se_astral_colossus",    "BM", 38, tint_pink),
    ("se_chrono_warden",      "BM", 39, tint_pink),
    ("se_starfall_titan",     "BM", 12, tint_pink),
    ("se_shattered_oracle",   "BM", 44, tint_pink),

    # ========== R6 — The Necropolis ==========
    ("nc_bone_legionnaire",   "BM", 24, desaturate_white_grey),
    ("nc_carrion_beetle",     "BL", 36, desaturate_grey_white),
    ("nc_crypt_rat",          "BL", 31, desaturate_white),
    ("nc_ghoul_stalker",      "BL", 28, desaturate_white),
    ("nc_shambling_husk",     "BL", 25, desaturate_white),
    ("nc_tombdust_wraith",    "AV", 27, desaturate_white),
    ("nc_bone_colossus",      "BM", 50, desaturate_white_grey),
    ("nc_death_knight",       "BM", 30, desaturate_grey_white),
    ("nc_gravefiend",         "BM", 26, desaturate_grey_white),
    ("nc_plague_revenant",    "BM",  9, None),
    ("nc_spectral_binder",    "BM", 15, None),
    ("nc_wraith_chorister",   "AV", 27, tint_black_red),
    ("nc_dread_wight",        "BK", 18, tint_black),
    ("nc_wraith_choir_conductor", "BK", 36, None),
    ("nc_lich_eternal",       "BK", 20, None),
    ("nc_ossuary_king",       "BK", 15, None),

    # ========== R7 — Final Realm (Void) ==========
    ("fr_blighted_echo",      "BL", 44, tint_light_purple_transparent),
    ("fr_corruption_tendril", "BM", 13, tint_purple),
    ("fr_entropy_slug",       "BL",  5, tint_purple),
    ("fr_null_wisp",          "BL", 19, tint_purple),
    ("fr_rift_imp",           "BM", 11, tint_purple),
    ("fr_void_mite",          "BL",  2, tint_purple),
    ("fr_abyssal_sentinel",   "BM", 41, tint_purple),
    ("fr_corruption_avatar",  "BL", 25, tint_purple),
    ("fr_entropy_colossus",   "BM", 50, tint_purple),
    ("fr_reality_shredder",   "BL", 39, tint_purple),
    ("fr_thoughtrender",      "BM", 29, tint_purple),
    ("fr_void_weaver",        "BM", 25, tint_purple),
    ("fr_corruption_champion", "BK", 44, tint_purple),
    ("fr_dimensional_horror", "BK", 46, None),
    ("fr_prime_corruptor",    "BK", 42, tint_purple),
    ("fr_void_sovereign",     "BK",  5, tint_purple),
]


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Output directory: {OUT_DIR}")
    print(f"Total jobs: {len(JOBS)}")
    print()

    ok = 0
    skip = 0
    for monster_id, pack, icon, fn in JOBS:
        if process_job(monster_id, pack, icon, fn):
            ok += 1
        else:
            skip += 1

    print()
    print(f"Done! {ok} processed, {skip} skipped.")
    print(f"Recoloured images saved to: {OUT_DIR}")
