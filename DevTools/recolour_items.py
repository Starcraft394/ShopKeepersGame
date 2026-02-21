"""
Recolour item icons that need tinting.
- Copies originals to Assets/_ArtPacks/Items_Recolored/ before recolouring
- Uses same HSV recolouring approach as recolour_monsters.py
- Updates JSON icon_path to point to the recoloured copy

Source pack mapping (standard packs use Icon{N}.png):
  A  = Swords          B  = Daggers         D  = Bows
  G  = Helmets         H  = Cuirass         I  = Trousers
  J  = Sabatons        L  = Rings           M  = MagicArtifacts
  Q  = Mushrooms       T  = Food            V  = CraftingMaterials
  W  = CraftingMaterials2   Y  = Potions    Z  = Gems
  AA = Loot_Chaos      AC = Loot_Goblin     AD = Loot_Undead
  AE = LootDrops       AF = Treasure (custom filenames)
  BB = Farming         BM = Ingredients (custom filenames)
  BN = ShieldsAmulets  BO = RPGThings (custom filenames)
"""

import os
import json
import colorsys
from PIL import Image

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTPACKS = os.path.join(BASE, "Assets", "_ArtPacks")
OUT_DIR = os.path.join(ARTPACKS, "Items_Recolored")
TEMPLATES_DIR = os.path.join(BASE, "Data", "Items", "Templates")

# Source pack paths
PACKS = {
    "A":  os.path.join(ARTPACKS, "Swords", "PNG", "Transperent"),
    "B":  os.path.join(ARTPACKS, "Daggers", "PNG", "Transperent"),
    "C":  os.path.join(ARTPACKS, "Axes", "PNG", "Transperent"),
    "D":  os.path.join(ARTPACKS, "Bows", "PNG", "Transperent"),
    "E":  os.path.join(ARTPACKS, "Maces", "PNG", "Transperent"),
    "G":  os.path.join(ARTPACKS, "Helmets", "PNG", "Transperent"),
    "H":  os.path.join(ARTPACKS, "Cuirass", "PNG", "Transperent"),
    "I":  os.path.join(ARTPACKS, "Trousers", "PNG", "Transperent"),
    "J":  os.path.join(ARTPACKS, "Sabatons", "PNG", "Transperent"),
    "L":  os.path.join(ARTPACKS, "Rings", "PNG", "Transperent"),
    "M":  os.path.join(ARTPACKS, "MagicArtifacts", "PNG", "Transperent"),
    "Q":  os.path.join(ARTPACKS, "Mushrooms", "PNG", "Transperent"),
    "T":  os.path.join(ARTPACKS, "Food", "PNG", "Transperent"),
    "V":  os.path.join(ARTPACKS, "CraftingMaterials", "PNG", "Transperent"),
    "W":  os.path.join(ARTPACKS, "CraftingMaterials2", "PNG", "Transperent"),
    "Y":  os.path.join(ARTPACKS, "Potions", "PNG", "Transperent"),
    "Z":  os.path.join(ARTPACKS, "Gems", "PNG", "Transperent"),
    "AA": os.path.join(ARTPACKS, "Loot_Chaos", "PNG", "Transperent"),
    "AC": os.path.join(ARTPACKS, "Loot_Goblin", "PNG", "Transperent"),
    "AD": os.path.join(ARTPACKS, "Loot_Undead", "PNG", "Transperent"),
    "AE": os.path.join(ARTPACKS, "LootDrops", "PNG", "Transperent"),
    "AF": os.path.join(ARTPACKS, "Treasure", "PNG", "Transperent"),
    "BB": os.path.join(ARTPACKS, "Farming", "PNG", "Transperent"),
    "BM": os.path.join(ARTPACKS, "Ingredients", "PNG", "Transperent"),
    "BN": os.path.join(ARTPACKS, "ShieldsAmulets", "PNG", "Transperent"),
    "BO": os.path.join(ARTPACKS, "RPGThings", "PNG", "Transperent"),
}

# BM (Ingredients) has custom filenames instead of Icon{N}.png
BM_FILES = {
    1: "berrys1", 2: "berrys2", 3: "bone", 4: "butterfly_wing1",
    5: "butterfly_wing2", 6: "cotton", 7: "crystal1", 8: "crystal2",
    9: "eggs", 10: "feather", 11: "flower1", 12: "flower2", 13: "flower3",
    14: "flower4", 15: "flower5", 16: "flower6", 17: "flower7", 18: "flower8",
    19: "flower9", 20: "flower10", 21: "grass", 22: "leaf1", 23: "leaf2",
    24: "leaf3", 25: "leaf4", 26: "leaf5", 27: "leaf6", 28: "leaf7",
    29: "leaf8", 30: "leaf9", 31: "leaf10", 32: "mushroom1", 33: "mushroom2",
    34: "mushroom3", 35: "mushroom4", 36: "mushroom5", 37: "pod", 38: "scales",
    39: "wood1", 40: "wood2",
}

# AF (Treasure) custom filenames
AF_FILES = {
    1: "bag1", 2: "bag2", 3: "bag3", 4: "black_pearl",
    5: "Chest1", 6: "Chest2", 7: "Chest3", 8: "Chest4", 9: "Chest5",
    10: "crown1", 11: "crown2", 12: "crown3", 13: "diamond",
    14: "emerald", 15: "gold_bars", 16: "gold1", 17: "gold2", 18: "gold3",
    19: "jevellery1", 20: "jevellery2", 21: "key1", 22: "key2",
    23: "key3", 24: "key4", 25: "pink_stone", 26: "ring1", 27: "ring2",
    28: "ruby", 29: "scepter", 30: "scroll", 31: "scull",
    32: "vessel1", 33: "vessel2", 34: "violet_stone",
    35: "blue_stone", 36: "white_pearl",
}

# Hue values (0-1 range)
HUE_RED = 0.000            # ~0°
HUE_ORANGE = 0.056         # ~20°
HUE_YELLOW = 0.150         # ~54°
HUE_BROWN = 0.083          # ~30°
HUE_GREEN = 0.333          # ~120°
HUE_LIGHT_GREEN = 0.350    # ~126°
HUE_FOREST_GREEN = 0.370   # ~133°
HUE_DARK_GREEN = 0.400     # ~144°
HUE_TEAL = 0.500           # ~180°
HUE_LIGHT_BLUE = 0.560     # ~202°
HUE_BLUE = 0.583           # ~210°
HUE_PURPLE = 0.778         # ~280°
HUE_DARK_PURPLE = 0.800    # ~288°


# ============================================================
# Core recolouring functions (from recolour_monsters.py)
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
# Tint presets for item recolouring
# ============================================================

# --- Existing R5-R7 tints ---

def tint_light_blue(img):
    """Light blue — cosmic/starfall items."""
    return recolour_image(img, HUE_LIGHT_BLUE, sat_mult=0.8, val_mult=1.05, hue_range=0.05)


def tint_white_grey(img):
    """White/grey — bone/undead items."""
    return desaturate_image(img, sat_mult=0.10, val_mult=0.95, val_offset=0.15)


def tint_white(img):
    """Pure white — ghostly/spectral items."""
    return desaturate_image(img, sat_mult=0.12, val_mult=1.0, val_offset=0.2)


def tint_light_green(img):
    """Light green — soul/necrotic items."""
    return recolour_image(img, HUE_LIGHT_GREEN, sat_mult=0.9, val_mult=1.05, hue_range=0.05)


def tint_purple(img):
    """Purple — void/fractured realm items."""
    return recolour_image(img, HUE_PURPLE, sat_mult=1.1, val_mult=0.95, hue_range=0.04)


def tint_dark_purple(img):
    """Dark purple — entropy/corruption items."""
    return recolour_image(img, HUE_DARK_PURPLE, sat_mult=1.2, val_mult=0.8, hue_range=0.04)


# --- New tints for Base + R1-R4 batch ---

def tint_white_brown(img):
    """White with warm brown undertone — plain cloth items."""
    return desaturate_image(img, sat_mult=0.15, val_mult=1.0, val_offset=0.1,
                            tint_hue=HUE_BROWN, tint_strength=0.08)


def tint_silver(img):
    """Silver/grey — iron/chainmail items."""
    return desaturate_image(img, sat_mult=0.08, val_mult=1.05, val_offset=0.1)


def tint_forest_green(img):
    """Forest green — Thornhaven/Greenwood items."""
    return recolour_image(img, HUE_FOREST_GREEN, sat_mult=0.85, val_mult=1.0, hue_range=0.06)


def tint_green_brown(img):
    """Green with brown/earthy tones — ironbark/living wood items."""
    return recolour_image(img, HUE_FOREST_GREEN, sat_mult=0.7, val_mult=0.9, hue_range=0.08)


def tint_dark_green(img):
    """Dark green — deep sea kelp/algae items."""
    return recolour_image(img, HUE_DARK_GREEN, sat_mult=0.9, val_mult=0.85, hue_range=0.05)


def tint_teal(img):
    """Teal — ocean/sea items."""
    return recolour_image(img, HUE_TEAL, sat_mult=0.85, val_mult=1.0, hue_range=0.05)


def tint_blue_green(img):
    """Blue-green — deep sea/leviathan items."""
    return recolour_image(img, HUE_TEAL, sat_mult=0.75, val_mult=1.05, hue_range=0.06)


def tint_yellow(img):
    """Yellow tint — warm/golden items."""
    return recolour_image(img, HUE_YELLOW, sat_mult=0.85, val_mult=1.05, hue_range=0.06)


def tint_yellow_to_purple(img):
    """Shift yellow/warm tones to purple — cursed items."""
    return recolour_image(img, HUE_PURPLE, sat_mult=0.9, val_mult=0.9, hue_range=0.06)


def tint_red(img):
    """Red — fire/drake items."""
    return recolour_image(img, HUE_RED, sat_mult=1.1, val_mult=0.95, hue_range=0.04)


def tint_orange_red(img):
    """Orange-red — ember/flame items."""
    return recolour_image(img, HUE_ORANGE, sat_mult=1.1, val_mult=1.0, hue_range=0.05)


def tint_black(img):
    """Very dark — obsidian/void items."""
    return desaturate_image(img, sat_mult=0.15, val_mult=0.5, val_offset=-0.1)


def tint_purple_red(img):
    """Purple with red undertones — volcanic glass."""
    return recolour_image(img, HUE_PURPLE, sat_mult=1.0, val_mult=0.9,
                          hue_range=0.08)


# ============================================================
# Helpers
# ============================================================

def get_source_path(pack_code, icon_num):
    """Get the full path to a source icon."""
    pack_dir = PACKS[pack_code]
    if pack_code == "BM":
        fname = BM_FILES.get(icon_num, f"Icon{icon_num}")
        return os.path.join(pack_dir, f"{fname}.png")
    if pack_code == "AF":
        fname = AF_FILES.get(icon_num, f"Icon{icon_num}")
        return os.path.join(pack_dir, f"{fname}.png")
    if pack_code == "BO":
        return os.path.join(pack_dir, f"icons_30_{icon_num:02d}.png")
    return os.path.join(pack_dir, f"Icon{icon_num}.png")


def process_job(item_id, pack_code, icon_num, recolour_fn):
    """Process a single item recolour job. Returns (success, output_path)."""
    src = get_source_path(pack_code, icon_num)
    dst = os.path.join(OUT_DIR, f"{item_id}.png")

    if not os.path.exists(src):
        print(f"  SKIP (missing): {item_id} <- {pack_code}#{icon_num}: {src}")
        return False, ""

    img = Image.open(src).convert("RGBA")
    img = recolour_fn(img)
    img.save(dst)
    print(f"  OK: {item_id}.png <- {pack_code}#{icon_num} (recoloured)")
    return True, dst


def update_json_icon_path(item_id, new_icon_path):
    """Update the icon_path in the item's JSON template."""
    json_path = os.path.join(TEMPLATES_DIR, f"{item_id}.json")
    if not os.path.exists(json_path):
        print(f"  WARN: JSON not found for {item_id}: {json_path}")
        return False

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    data["icon_path"] = new_icon_path

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    return True


# ============================================================
# Job definitions: (item_id, pack_code, icon_num, recolour_fn)
# ============================================================

JOBS = [
    # ========== Base / Starter ==========
    ("cloth_cap",                    "G",  20, tint_white_brown),   # White/Off-brown
    ("cloth_robe",                   "H",   5, tint_white),         # White

    # ========== R1 — Thornhaven T2 ==========
    ("chainmail_vest",               "H",  20, tint_silver),        # Silver/Grey
    ("gw_ranger_vest",               "H",   7, tint_forest_green),  # Greens

    # ========== R1 — Thornhaven T3 ==========
    ("gw_briar_fang",                "B",  22, tint_forest_green),  # Green
    ("gw_emerald_pendant",           "AD", 30, tint_forest_green),  # Green
    ("gw_emerald_ring",              "AD", 19, tint_forest_green),  # Purple Stone -> Green
    ("gw_longbow",                   "D",  24, tint_forest_green),  # Green
    ("gw_ironbark_greaves",          "J",  20, tint_forest_green),  # Green
    ("gw_ironbark_helm",             "G",  25, tint_green_brown),   # Green/Browns
    ("gw_ironbark_maul",             "AC", 26, tint_green_brown),   # Green/Browns
    ("gw_ironbark_plate",            "H",  18, tint_green_brown),   # Green/Browns
    ("gw_ironbark_shield",           "AC", 23, tint_green_brown),   # Greens/browns
    ("gw_living_focus",              "M",   8, tint_forest_green),  # Green
    ("gw_living_staff",              "M",  37, tint_green_brown),   # Greens/Browns
    ("gw_living_vest",               "H",   2, tint_forest_green),  # Greens
    ("gw_verdant_blade",             "B",  45, tint_forest_green),  # Better Green Tint

    # ========== R1 — Thornhaven T4 ==========
    ("gw_ancient_helm",              "G",  42, tint_forest_green),  # Greens
    ("gw_heartwood_staff",           "D",  36, tint_green_brown),   # Browns/Greens
    ("gw_thornguard_sword",          "A",  38, tint_forest_green),  # Green

    # ========== R1/R2 Materials ==========
    ("aged_cheese",                  "AA",  6, tint_yellow),        # Yellow Tint
    ("boss_trophy_greenwood",        "AA", 18, tint_forest_green),  # Green (Elderwood Heart)
    ("mycelium_thread",              "Q",  47, tint_forest_green),  # Green
    ("cursed_dust",                  "AF",  1, tint_yellow_to_purple),  # Yellow → Purple

    # ========== R3 — Sunken Shoals Materials ==========
    ("driftwood",                    "W",  27, tint_teal),          # Teal
    ("ss_kelp_sinew",                "W",   6, tint_dark_green),    # Dark Green
    ("stormglass_fragment",          "BM",  7, tint_teal),          # Teal
    ("boss_trophy_sunken_strand",    "AE",  5, tint_blue_green),    # Blue/Green Tint (Leviathan Scale)

    # ========== R4 — Ashen Horizons Materials ==========
    ("ah_drake_scale",               "AE", 38, tint_red),           # Red
    ("ember_dust",                   "AE", 26, tint_orange_red),    # Orange/Red
    ("magma_core",                   "AA", 14, tint_red),           # Red
    ("obsidian_shard",               "M",   4, tint_black),         # Black
    ("ah_sulfite_gland",             "AA", 14, tint_yellow),        # Yellow Tint (shares AA#14 with magma_core)
    ("volcanic_glass",               "AA", 22, tint_purple_red),    # Purple with Red

    # ========== R5 — Starfall Expanse (Light Blue) ==========
    ("astral_fragment",              "Z",  15, tint_light_blue),
    ("starfall_core_fragment",       "Z",  39, tint_light_blue),
    ("starfall_dust",                "W",   4, tint_light_blue),
    ("boss_trophy_starfall_expanse", "Z",  45, tint_light_blue),

    # ========== R6 — Necropolis (White/Grey, Light Green, Light Blue) ==========
    ("nc_bone_marrow",               "Y",  16, tint_white_grey),
    ("deadmans_grass",               "BM", 21, tint_white),
    ("nc_grave_dust",                "W",   4, tint_white),
    ("soul_ore",                     "Z",  30, tint_light_blue),
    ("spectral_log",                 "BB",  3, tint_light_blue),
    ("wailing_shard",                "AD",  4, tint_light_green),
    ("nc_wraith_thread",             "AA", 33, tint_white),
    ("boss_trophy_necropolis",       "AA", 23, tint_light_green),

    # ========== R7 — Fractured Realm (Purple, Dark Purple) ==========
    ("fr_entropy_residue",           "W",   4, tint_dark_purple),
    ("fractured_soulglass",          "W",  39, tint_purple),
    ("primordial_essence",           "V",  35, tint_purple),
    ("void_crystal",                 "V",  20, tint_purple),
    ("boss_trophy_fractured_realm",  "AE", 35, tint_purple),
]


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Output directory: {OUT_DIR}")
    print(f"Total jobs: {len(JOBS)}")
    print()

    ok = 0
    skip = 0
    updated = 0
    for item_id, pack, icon, fn in JOBS:
        success, dst = process_job(item_id, pack, icon, fn)
        if success:
            ok += 1
            # Update JSON to point to recoloured copy
            res_path = f"res://Assets/_ArtPacks/Items_Recolored/{item_id}.png"
            if update_json_icon_path(item_id, res_path):
                updated += 1
                print(f"       JSON updated: {item_id} -> {res_path}")
        else:
            skip += 1

    print()
    print(f"Done! {ok} recoloured, {skip} skipped, {updated} JSONs updated.")
    print(f"Recoloured images saved to: {OUT_DIR}")
