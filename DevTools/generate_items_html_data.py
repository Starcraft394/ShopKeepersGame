"""
Generate JavaScript items data for Docs/item_icon_reference.html.
Reads all Data/Items/Templates/*.json and outputs a JS snippet
with ALL_ITEMS array organized by region.

Includes pack_ref resolution: derives "G#20" style codes from icon_path.
"""

import os
import json
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS_DIR = os.path.join(BASE, "Data", "Items", "Templates")

# ============================================================
# Pack code reverse-mapping (icon_path -> pack_ref like "G#20")
# ============================================================

# Folder name -> letter code
FOLDER_TO_CODE = {
    "Swords": "A", "Daggers": "B", "Axes": "C", "Bows": "D",
    "Maces": "E", "Spears": "F", "Helmets": "G", "Cuirass": "H",
    "Trousers": "I", "Sabatons": "J", "Bracers": "K", "Rings": "L",
    "MagicArtifacts": "M", "MagicBooks": "N", "Runes": "O", "Herbs": "P",
    "Mushrooms": "Q", "Berries": "R", "FruitsVegetables": "S", "Food": "T",
    "MeatSkins": "U", "CraftingMaterials": "V", "CraftingMaterials2": "W",
    "AlchemyItems": "X", "Potions": "Y", "Gems": "Z",
    "Loot_Chaos": "AA", "Loot_Demon": "AB", "Loot_Goblin": "AC",
    "Loot_Undead": "AD", "LootDrops": "AE", "Treasure": "AF",
    "BuffIcons": "AG", "BuffSkills": "AH", "Sigils": "AI", "Curses": "AJ",
    "Farming": "BB", "Fishing": "BC", "Mining": "BD",
    "Ingredients": "BM", "ShieldsAmulets": "BN", "RPGThings": "BO",
}

# Reverse lookup for named-file packs: filename (no ext) -> index
BM_REVERSE = {
    "berrys1": 1, "berrys2": 2, "bone": 3, "butterfly_wing1": 4,
    "butterfly_wing2": 5, "cotton": 6, "crystal1": 7, "crystal2": 8,
    "eggs": 9, "feather": 10, "flower1": 11, "flower2": 12, "flower3": 13,
    "flower4": 14, "flower5": 15, "flower6": 16, "flower7": 17, "flower8": 18,
    "flower9": 19, "flower10": 20, "grass": 21, "leaf1": 22, "leaf2": 23,
    "leaf3": 24, "leaf4": 25, "leaf5": 26, "leaf6": 27, "leaf7": 28,
    "leaf8": 29, "leaf9": 30, "leaf10": 31, "mushroom1": 32, "mushroom2": 33,
    "mushroom3": 34, "mushroom4": 35, "mushroom5": 36, "pod": 37,
    "scales": 38, "wood1": 39, "wood2": 40,
}

AF_REVERSE = {
    "bag1": 1, "bag2": 2, "bag3": 3, "black_pearl": 4,
    "Chest1": 5, "Chest2": 6, "Chest3": 7, "Chest4": 8, "Chest5": 9,
    "crown1": 10, "crown2": 11, "crown3": 12, "diamond": 13,
    "emerald": 14, "gold_bars": 15, "gold1": 16, "gold2": 17, "gold3": 18,
    "jevellery1": 19, "jevellery2": 20, "key1": 21, "key2": 22,
    "key3": 23, "key4": 24, "pink_stone": 25, "ring1": 26, "ring2": 27,
    "ruby": 28, "scepter": 29, "scroll": 30, "scull": 31,
    "vessel1": 32, "vessel2": 33, "violet_stone": 34,
    "blue_stone": 35, "white_pearl": 36,
}

# Recolored items: item_id -> (pack_code, icon_num)
# Source: recolour_items.py JOBS list — keep in sync!
RECOLOR_SOURCES = {
    # Base / Starter
    "cloth_cap": ("G", 20), "cloth_robe": ("H", 5),
    # R1 — Thornhaven
    "chainmail_vest": ("H", 20), "gw_ranger_vest": ("H", 7),
    "gw_briar_fang": ("B", 22), "gw_emerald_pendant": ("AD", 30),
    "gw_emerald_ring": ("AD", 19), "gw_longbow": ("D", 24),
    "gw_ironbark_greaves": ("J", 20), "gw_ironbark_helm": ("G", 25),
    "gw_ironbark_maul": ("AC", 26), "gw_ironbark_plate": ("H", 18),
    "gw_ironbark_shield": ("AC", 23), "gw_living_focus": ("M", 8),
    "gw_living_staff": ("M", 37), "gw_living_vest": ("H", 2),
    "gw_verdant_blade": ("B", 45), "gw_ancient_helm": ("G", 42),
    "gw_heartwood_staff": ("D", 36), "gw_thornguard_sword": ("A", 38),
    # R1/R2 Materials
    "aged_cheese": ("AA", 6), "boss_trophy_greenwood": ("AA", 18),
    "mycelium_thread": ("Q", 47), "cursed_dust": ("AF", 1),
    # R3 — Sunken Shoals
    "driftwood": ("W", 27), "ss_kelp_sinew": ("W", 6),
    "stormglass_fragment": ("BM", 7), "boss_trophy_sunken_strand": ("AE", 5),
    # R4 — Ashen Horizons
    "ah_drake_scale": ("AE", 38), "ember_dust": ("AE", 26),
    "magma_core": ("AA", 14), "obsidian_shard": ("M", 4),
    "ah_sulfite_gland": ("AA", 14), "volcanic_glass": ("AA", 22),
    # R5 — Starfall Expanse
    "astral_fragment": ("Z", 15), "starfall_core_fragment": ("Z", 39),
    "starfall_dust": ("W", 4), "boss_trophy_starfall_expanse": ("Z", 45),
    # R6 — Necropolis
    "nc_bone_marrow": ("Y", 16), "deadmans_grass": ("BM", 21),
    "nc_grave_dust": ("W", 4), "soul_ore": ("Z", 30),
    "spectral_log": ("BB", 3), "wailing_shard": ("AD", 4),
    "nc_wraith_thread": ("AA", 33), "boss_trophy_necropolis": ("AA", 23),
    # R7 — Fractured Realm
    "fr_entropy_residue": ("W", 4), "fractured_soulglass": ("W", 39),
    "primordial_essence": ("V", 35), "void_crystal": ("V", 20),
    "boss_trophy_fractured_realm": ("AE", 35),
}


def resolve_pack_ref(icon_path, item_id=""):
    """Derive pack ref like 'G#20' from an icon_path. Returns '' if unknown."""
    if not icon_path:
        return ""

    # Recolored items -> look up source
    if "Items_Recolored/" in icon_path:
        src = RECOLOR_SOURCES.get(item_id)
        if src:
            return f"{src[0]}#{src[1]}*"  # asterisk = recolored
        return ""

    # Custom hand-drawn icons (Assets/Icons/Items/)
    if "Assets/Icons/Items/" in icon_path:
        return ""

    # Standard art pack path: res://Assets/_ArtPacks/{Pack}/PNG/Transperent/{file}.png
    m = re.search(r"_ArtPacks/([^/]+)/PNG/Transper?ent/(.+)\.png", icon_path)
    if not m:
        return ""

    folder = m.group(1)
    filename = m.group(2)
    code = FOLDER_TO_CODE.get(folder, "")
    if not code:
        return ""

    # Standard Icon{N}.png
    icon_m = re.match(r"^Icon(\d+)$", filename)
    if icon_m:
        return f"{code}#{icon_m.group(1)}"

    # BM (Ingredients) custom filenames
    if code == "BM" and filename in BM_REVERSE:
        return f"BM#{BM_REVERSE[filename]}"

    # AF (Treasure) custom filenames
    if code == "AF" and filename in AF_REVERSE:
        return f"AF#{AF_REVERSE[filename]}"

    # BO (RPGThings) icons_30_NN pattern
    if code == "BO":
        bo_m = re.match(r"^icons_30_(\d+)$", filename)
        if bo_m:
            return f"BO#{int(bo_m.group(1))}"

    return ""


# ============================================================
# Item data helpers
# ============================================================

def get_region(tags):
    """Extract region key from tags list."""
    for tag in tags:
        m = re.match(r"^region_(\d+)$", tag)
        if m:
            return f"region_{m.group(1)}"
    return "base"


def get_display_cat(item_type):
    """Map item_type to display category."""
    mapping = {
        "consumable": "consumable",
        "weapon": "equipment",
        "armor": "equipment",
        "offhand": "equipment",
        "accessory": "equipment",
        "bag": "equipment",
        "material": "material",
        "book": "book",
        "tool": "tool",
    }
    return mapping.get(item_type, item_type)


def build_meta(data):
    """Build a human-readable meta string from item data."""
    parts = []
    item_type = data.get("item_type", "")
    subtype = data.get("item_subtype", "")

    if subtype:
        parts.append(subtype)
    elif item_type:
        parts.append(item_type)

    # Stats for equipment
    stats = data.get("stat_bonuses") or data.get("base_stats") or {}
    stat_parts = []
    for stat_key in ["attack", "health", "defense", "speed"]:
        val = stats.get(stat_key, 0)
        if val:
            abbrev = {"attack": "ATK", "health": "HP", "defense": "DEF", "speed": "SPD"}
            stat_parts.append(f"{abbrev.get(stat_key, stat_key)} +{val}")
    if stat_parts:
        parts.append(" ".join(stat_parts))

    # Heal for consumables
    use_effect = data.get("use_effect", "")
    use_value = data.get("use_value", 0)
    if use_effect == "heal" and use_value:
        parts.append(f"heal {use_value}")

    # Tier
    tier = data.get("tier", 0)
    if tier and tier > 1:
        parts.append(f"tier {tier}")

    return " | ".join(parts) if parts else item_type


def js_escape(s):
    """Escape a string for JS single-line use."""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


def main():
    items = []

    for fname in sorted(os.listdir(ITEMS_DIR)):
        if not fname.endswith(".json"):
            continue
        path = os.path.join(ITEMS_DIR, fname)
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

        item_id = data.get("id", fname.replace(".json", ""))
        tags = data.get("tags", [])
        region = get_region(tags)
        item_type = data.get("item_type", "")
        # Books have item_type "consumable" but "book" in tags
        if "book" in tags:
            display_cat = "book"
        else:
            display_cat = get_display_cat(item_type)
        tier = data.get("tier", 1) or 1

        # Convert icon_path from res:// to relative ../
        raw_icon_path = data.get("icon_path", "")
        icon_path = raw_icon_path
        if icon_path.startswith("res://"):
            icon_path = "../" + icon_path[6:]

        # Resolve pack reference
        pack_ref = resolve_pack_ref(raw_icon_path, item_id)

        items.append({
            "id": item_id,
            "name": data.get("display_name", item_id),
            "region": region,
            "cat": display_cat,
            "type": item_type,
            "tier": tier,
            "meta": build_meta(data),
            "hint": data.get("icon_hint", ""),
            "icon": icon_path,
            "ref": pack_ref,
        })

    # Sort: by region order, then category, then tier, then name
    region_order = ["base", "region_1", "region_2", "region_3", "region_4",
                    "region_5", "region_6", "region_7"]

    def sort_key(item):
        r_idx = region_order.index(item["region"]) if item["region"] in region_order else 99
        cat_order = {"consumable": 0, "equipment": 1, "material": 2, "book": 3, "tool": 4}
        c_idx = cat_order.get(item["cat"], 9)
        return (r_idx, c_idx, item["tier"], item["name"])

    items.sort(key=sort_key)

    # Count by region
    region_counts = {}
    ref_count = 0
    for it in items:
        region_counts[it["region"]] = region_counts.get(it["region"], 0) + 1
        if it["ref"]:
            ref_count += 1

    print(f"// Total items: {len(items)}")
    for r in region_order:
        c = region_counts.get(r, 0)
        if c:
            print(f"//   {r}: {c}")
    print(f"// Items with pack_ref: {ref_count}")
    print()

    # Output JS
    print("const ALL_ITEMS = [")
    current_region = None
    for it in items:
        if it["region"] != current_region:
            current_region = it["region"]
            print(f'  // {current_region}')

        parts = [
            f'id:"{js_escape(it["id"])}"',
            f'name:"{js_escape(it["name"])}"',
            f'region:"{it["region"]}"',
            f'cat:"{it["cat"]}"',
            f'type:"{it["type"]}"',
            f'tier:{it["tier"]}',
            f'meta:"{js_escape(it["meta"])}"',
            f'hint:"{js_escape(it["hint"])}"',
            f'icon:"{js_escape(it["icon"])}"',
            f'ref:"{js_escape(it["ref"])}"',
        ]
        print(f'  {{{", ".join(parts)}}},')

    print("];")


if __name__ == "__main__":
    main()
