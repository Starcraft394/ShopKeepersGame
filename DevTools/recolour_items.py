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
    "F":  os.path.join(ARTPACKS, "Spears", "PNG", "Transperent"),
    "R":  os.path.join(ARTPACKS, "Berries", "PNG", "Transperent"),
    "S":  os.path.join(ARTPACKS, "FruitsVegetables", "PNG", "Transperent"),
    "U":  os.path.join(ARTPACKS, "MeatSkins", "PNG", "Transperent"),
    "X":  os.path.join(ARTPACKS, "AlchemyItems", "PNG", "Transperent"),
    "AB": os.path.join(ARTPACKS, "Loot_Demon", "PNG", "Transperent"),
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
HUE_NEON_GREEN = 0.300     # ~108° - bright neon
HUE_NEON_BLUE = 0.590      # ~212° - bright electric blue
HUE_LIGHT_PINK = 0.920     # ~331° - light pink/rose
HUE_LIGHT_RED = 0.020      # ~7° - coral/light red


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


# --- New tints for R2-R7 batch ---

def tint_neon_green(img):
    """Neon green — bioluminescent/spore items."""
    return recolour_image(img, HUE_NEON_GREEN, sat_mult=1.3, val_mult=1.1, hue_range=0.04)


def tint_green(img):
    """Green — fungal/mycelium items."""
    return recolour_image(img, HUE_GREEN, sat_mult=1.0, val_mult=1.0, hue_range=0.05)


def tint_light_pink(img):
    """Light pink — crystal/prism/starfall items."""
    return recolour_image(img, HUE_LIGHT_PINK, sat_mult=0.7, val_mult=1.1, hue_range=0.05)


def tint_light_red(img):
    """Light red/coral — shell items."""
    return recolour_image(img, HUE_LIGHT_RED, sat_mult=0.8, val_mult=1.05, hue_range=0.05)


def tint_blue(img):
    """Blue — deep water/tide items."""
    return recolour_image(img, HUE_BLUE, sat_mult=1.0, val_mult=1.0, hue_range=0.05)


def tint_orange(img):
    """Orange — warm ocean items."""
    return recolour_image(img, HUE_ORANGE, sat_mult=1.0, val_mult=1.05, hue_range=0.05)


def tint_spectral_blue(img):
    """Spectral blue — ghostly/wraith items."""
    return recolour_image(img, HUE_LIGHT_BLUE, sat_mult=0.6, val_mult=1.1, hue_range=0.06)


def tint_light_purple(img):
    """Light purple — echo/astral items."""
    return recolour_image(img, HUE_PURPLE, sat_mult=0.7, val_mult=1.1, hue_range=0.05)


def tint_neon_blue(img):
    """Neon blue — bright electric blue for caustic/brine items."""
    return recolour_image(img, HUE_NEON_BLUE, sat_mult=1.3, val_mult=1.1, hue_range=0.04)


def tint_brown(img):
    """Brown — earthy/hide/leather items."""
    return recolour_image(img, HUE_BROWN, sat_mult=0.9, val_mult=0.9, hue_range=0.06)


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

    # ========== R2 — Fungal Marshes T2 ==========
    ("fm_bioluminescent_ring",       "V",  34, tint_neon_green),
    ("fm_fungal_shortbow",           "D",  13, tint_green),
    ("fm_fungal_tunic",              "H",   7, tint_neon_green),
    ("fm_mycelium_vest",             "H",   1, tint_dark_green),
    ("fm_spore_blade",               "B",  31, tint_neon_green),
    ("fm_spore_knife",               "B",  30, tint_green),
    ("fm_spore_mace",                "E",  44, tint_neon_green),
    ("fm_spore_satchel",             "BO", 15, tint_neon_green),
    ("fm_sporeguard_helm",           "G",   6, tint_green),

    # ========== R2 — Fungal Marshes T3 ==========
    ("fm_fungal_crown",              "G",  11, tint_green),
    ("fm_fungal_crusher",            "E",   6, tint_green),
    ("fm_fungal_fang",               "B",  36, tint_green),
    ("fm_fungal_longbow",            "D",  18, tint_green),
    ("fm_fungal_plate",              "H",  15, tint_green),
    ("fm_mycelium_focus",            "M",   9, tint_neon_green),
    ("fm_mycelium_saber",            "B",  43, tint_neon_green),
    ("fm_mycelium_tunic",            "H",   7, tint_green),
    ("fm_sporeguard_pendant",        "AD", 26, tint_green),

    # ========== R2 — Fungal Marshes T4 ==========
    ("fm_fungal_heart_focus",        "AA", 39, tint_green),
    ("fm_fungal_heart_pack",         "BO", 22, tint_dark_green),

    # ========== R3 — Sunken Shoals T2 ==========
    ("ss_coral_focus",               "AA", 40, tint_light_pink),
    ("ss_driftwood_bow",             "D",  17, tint_teal),
    ("ss_kelp_leggings",             "I",  33, tint_dark_green),
    ("ss_kelp_satchel",              "BO", 13, tint_dark_green),
    ("ss_pearl_pendant",             "AF", 26, tint_teal),
    ("ss_pearl_ring",                "L",   3, tint_teal),
    ("ss_shell_helm",                "G",  22, tint_light_red),
    ("ss_tide_sword",                "A",  12, tint_teal),

    # ========== R3 — Sunken Shoals T3 ==========
    ("ss_abalone_shield",            "AC", 23, tint_teal),
    ("ss_barnacle_plate",            "H",  33, tint_teal),
    ("ss_kelp_greaves",              "I",  41, tint_dark_green),
    ("ss_kelp_vest",                 "H",  39, tint_dark_green),
    ("ss_sea_glass_focus",           "BN", 41, tint_light_blue),
    ("ss_shell_pack",                "BO", 38, tint_orange),
    ("ss_tide_fang",                 "B",   3, tint_blue),

    # ========== R3 — Sunken Shoals T4 ==========
    ("ss_leviathan_pack",            "BO", 28, tint_blue),
    ("ss_leviathan_staff",           "F",  25, tint_blue),
    ("ss_tidewoven_vest",            "H",  40, tint_teal),

    # ========== R4 — Ashen Horizons T2 ==========
    ("ah_cinder_pendant",            "AC", 12, tint_red),
    ("ah_cinder_satchel",            "BO", 11, tint_red),
    ("ah_cinder_tunic",              "H",   8, tint_red),
    ("ah_obsidian_mace",             "E",   1, tint_black),
    ("ah_obsidian_ring",             "L",  14, tint_black),
    ("ah_obsidian_vest",             "H",   9, tint_black),

    # ========== R4 — Ashen Horizons T3 ==========
    ("ah_drake_jerkin",              "H",   6, tint_red),
    ("ah_drake_pack",                "BO", 31, tint_red),
    ("ah_magma_plate",               "H",  26, tint_red),
    ("ah_obsidian_staff",            "F",  23, tint_black),
    ("ah_scorched_longbow",          "D",  19, tint_red),
    ("ah_volcanic_helm",             "G",  15, tint_red),

    # ========== R4 — Ashen Horizons T4 ==========
    ("ah_drakefang_blade",           "B",  23, tint_red),
    ("ah_drakescale_greaves",        "I",  43, tint_red),
    ("ah_drakescale_plate",          "H",  27, tint_red),
    ("ah_draketalon",                "B",  46, tint_red),

    # ========== R5 — Starfall Expanse T2 ==========
    ("se_astral_shortbow",           "D",  13, tint_purple),
    ("se_astral_tunic",              "H",   1, tint_light_pink),
    ("se_crystal_knife",             "B",  36, tint_light_blue),
    ("se_crystal_mace",              "E",   9, tint_light_pink),     # was DIRECT dupe w/ nc_soul_staff
    ("se_crystal_pendant",           "M",  28, tint_light_blue),
    ("se_crystal_ring",              "L",   8, tint_light_pink),     # was DIRECT dupe w/ silver_ring
    ("se_crystal_staff",             "F",  24, tint_light_pink),
    ("se_crystal_sword",             "A",  16, tint_light_blue),

    # ========== R5 — Starfall Expanse T3 ==========
    ("se_astral_pack",               "BO", 36, tint_light_pink),
    ("se_astral_plate",              "H",  13, tint_light_pink),     # was DIRECT dupe w/ nc_ossuary_mail
    ("se_astral_ring",               "L",  18, tint_light_blue),
    ("se_crystal_robe",              "H",  10, tint_light_blue),
    ("se_prism_edge",                "A",  30, tint_light_pink),
    ("se_prism_fang",                "B",  39, tint_light_pink),
    ("se_prism_shield",              "BN", 19, tint_light_pink),
    ("se_temporal_maul",             "E",  11, tint_light_pink),

    # ========== R5 — Starfall Expanse T4 ==========
    ("se_astral_robe",               "H",  19, tint_light_blue),
    ("se_chrono_cleaver",            "C",  38, tint_light_pink),
    ("se_crystal_ward",              "H",  36, tint_light_blue),
    ("se_echo_amulet",               "AD", 30, tint_purple),
    ("se_echo_shield",               "BN", 29, tint_light_purple),
    ("se_prism_helm",                "G",  45, tint_light_pink),
    ("se_prism_staff",               "F",  11, tint_light_pink),
    ("se_starlight_focus",           "M",  17, tint_light_pink),
    ("se_temporal_dagger",           "B",  18, tint_light_pink),

    # ========== R6 — Necropolis T2 ==========
    ("nc_bone_greaves",              "I",  14, tint_white),
    ("nc_bone_helm",                 "G",  16, tint_white),
    ("nc_bone_knife",                "B",  33, tint_white),
    ("nc_bone_mace",                 "E",   2, tint_white),
    ("nc_bone_satchel",              "BO", 19, tint_white),
    ("nc_bone_shield",               "BN",  3, tint_white),
    ("nc_bone_vest",                 "H",   2, tint_white),
    ("nc_grave_sword",               "A",  22, tint_white),
    ("nc_spectral_bow",              "D",  23, tint_light_blue),

    # ========== R6 — Necropolis T3 ==========
    ("nc_deathward_band",            "L",  16, tint_white),
    ("nc_ossuary_greaves",           "I",  15, tint_light_blue),
    ("nc_ossuary_helm",              "G",  29, tint_white),
    ("nc_ossuary_mail",              "H",  13, tint_white),          # was DIRECT dupe w/ se_astral_plate
    ("nc_ossuary_maul",              "E",  40, tint_white),
    ("nc_ossuary_pendant",           "L",  42, tint_light_blue),
    ("nc_ossuary_shield",            "BN", 15, tint_white),
    ("nc_soul_edge",                 "A",  27, tint_light_blue),
    ("nc_wraith_fang",               "B",  17, tint_light_blue),
    ("nc_wraith_pack",               "BB", 17, tint_spectral_blue),
    ("nc_wraith_tunic",              "H",  17, tint_light_blue),

    # ========== R6 — Necropolis T4 ==========
    ("nc_bone_crown",                "G",  41, tint_white),
    ("nc_ossuary_plate",             "H",  18, tint_white),
    ("nc_soulfire_focus",            "BN", 43, tint_light_blue),
    ("nc_spectral_aegis",            "BN", 34, tint_spectral_blue),
    ("nc_wraith_leggings",           "I",  10, tint_light_blue),
    ("nc_wraith_robe",               "H",  46, tint_light_blue),

    # ========== R7 — Final Realm T2 ==========
    ("fr_rift_focus",                "AC", 48, tint_purple),
    ("fr_rift_greaves",              "I",  25, tint_purple),
    ("fr_rift_helm",                 "G",  28, tint_purple),
    ("fr_rift_knife",                "B",  12, tint_purple),
    ("fr_rift_mace",                 "E",  19, tint_purple),
    ("fr_rift_satchel",              "BO", 32, tint_purple),
    ("fr_rift_shield",               "BN", 31, tint_purple),
    ("fr_rift_sword",                "A",  37, tint_purple),
    ("fr_rift_tunic",                "H",   2, tint_purple),
    ("fr_rift_vest",                 "H",   1, tint_purple),
    ("fr_rift_wand",                 "B",  37, tint_purple),

    # ========== R7 — Final Realm T3 ==========
    ("fr_null_blade",                "A",  35, tint_dark_purple),
    ("fr_null_bow",                  "D",   4, tint_dark_purple),
    ("fr_null_fang",                 "B",  44, tint_dark_purple),
    ("fr_null_greaves",              "I",  42, tint_dark_purple),
    ("fr_null_helm",                 "G",  43, tint_dark_purple),
    ("fr_null_maul",                 "E",  25, tint_dark_purple),
    ("fr_null_focus_t3",             "AC",  8, tint_dark_purple),
    ("fr_null_pack",                 "BO", 39, tint_dark_purple),
    ("fr_null_pendant",              "L",  23, tint_dark_purple),
    ("fr_null_plate",                "H",  31, tint_dark_purple),
    ("fr_null_ring",                 "L",  26, tint_dark_purple),
    ("fr_null_shield",               "BN", 35, tint_dark_purple),
    ("fr_null_shroud",               "H",  19, tint_dark_purple),
    ("fr_null_staff",                "E",  27, tint_dark_purple),

    # ========== R7 — Final Realm T4 ==========
    ("fr_dimensional_locket",        "L",  29, tint_dark_purple),
    ("fr_entropy_bow",               "D",  21, tint_purple),
    ("fr_null_barrier",              "BN",  5, tint_dark_purple),
    ("fr_null_focus",                "AB", 43, tint_dark_purple),
    ("fr_rift_band",                 "L",  27, tint_purple),
    ("fr_rift_staff",                "F",  47, tint_purple),
    ("fr_void_edge",                 "A",  46, tint_purple),
    ("fr_void_greaves",              "I",  46, tint_purple),
    ("fr_void_helm",                 "G",  47, tint_purple),
    ("fr_void_pack",                 "BO", 89, tint_purple),
    ("fr_void_shroud",               "H",  29, tint_purple),

    # ========== Consumables — R1 Base (Recoloured) ==========
    ("minor_healing_tonic",          "S",  40, tint_green),          # Green
    ("healing_tonic",                "S",  42, tint_green),          # Green
    ("bandage",                      "X",  22, tint_white),          # White
    ("minor_stamina_snack",          "T",  20, tint_yellow),         # Yellow Tint
    ("smelling_salts",               "T",  16, tint_white),          # White
    ("smoke_bomb",                   "T",  27, tint_white),          # White
    ("focus_elixir",                 "T",  36, tint_blue),           # Blue
    ("power_elixir",                 "T",  26, tint_red),            # Red
    ("resistance_salve",             "BB", 45, tint_orange),         # Orange
    ("stamina_draught",              "AC", 46, tint_yellow),         # Yellow
    ("strong_healing_tonic",         "AC", 47, tint_green),          # Green

    # ========== Consumables — R2 Fungal Marshes (Recoloured) ==========
    ("fm_spore_elixir",              "Y",  45, tint_neon_green),     # Neon Green

    # ========== Consumables — R3 Sunken Shoals (Recoloured) ==========
    ("ss_fog_bomb",                  "Y",  28, tint_blue),           # Blue
    ("ss_kelp_wrap",                 "T",  13, tint_green),          # Green

    # ========== Consumables — R4 Ashen Horizons (Recoloured) ==========
    ("ah_ash_bomb",                  "Y",  46, tint_silver),         # Grey
    ("ah_charred_feast",             "T",  32, tint_black),          # Black

    # ========== Consumables — R5 Starfall Expanse (Recoloured) ==========
    ("se_starlight_elixir",          "Y",  25, tint_light_pink),     # Pink

    # ========== Consumables — R6 Necropolis (Recoloured) ==========
    ("nc_banshee_vial",              "Y",   2, tint_white),          # White
    ("nc_phylactery_tonic",          "Y",  34, tint_spectral_blue),  # Spectral Blue
    ("nc_spectral_draught",          "Y",  11, tint_spectral_blue),  # Spectral Blue

    # ========== Consumables — R7 Fractured Realm (Recoloured) ==========
    ("fr_void_essence_flask",        "Y",  44, tint_purple),         # Purple
    ("fr_entropy_charge",            "Y",  26, tint_purple),         # Purple
    ("fr_dimensional_flux",          "AC", 46, tint_purple),         # Purple
    ("fr_void_mend",                 "Y",  24, tint_purple),         # Purple
    ("fr_null_feast",                "T",  46, tint_purple),         # Purple

    # ========== Duplicate Icon Fixes ==========
    ("nc_corpsebloom_stew",          "T",  45, tint_light_blue),     # Light Blue (was same as legendary_feast)
    ("minor_venom_flask",            "T",  29, tint_light_green),    # Light Green (was same as ss_brine_venom)
    ("ss_brine_venom",               "T",  29, tint_neon_blue),      # Neon Blue (was same as minor_venom_flask)
    ("forest_bounty",                "T",  32, tint_green),          # Green (was same as hero_banquet)
    ("honey_roast",                  "T",  46, tint_yellow),         # Yellow (was same as hunters_feast)
    ("slime_gel",                    "Y",   3, tint_neon_green),     # Neon Green (was same as antidote)
    ("gw_thornhide_vest",            "H",  23, tint_brown),          # Brown (was same as fm_mycelium_ruin_plate)
    ("ah_ember_focus",               "X",  36, tint_red),            # Red (changed icon from M#1 to X#36)
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
