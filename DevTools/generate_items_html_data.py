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
    # R2 — Fungal Marshes T2
    "fm_bioluminescent_ring": ("V", 34), "fm_fungal_shortbow": ("D", 13),
    "fm_fungal_tunic": ("H", 7), "fm_mycelium_vest": ("H", 1),
    "fm_spore_blade": ("B", 31), "fm_spore_knife": ("B", 30),
    "fm_spore_mace": ("E", 44), "fm_spore_satchel": ("BO", 15),
    "fm_sporeguard_helm": ("G", 6),
    # R2 — Fungal Marshes T3
    "fm_fungal_crown": ("G", 11), "fm_fungal_crusher": ("E", 6),
    "fm_fungal_fang": ("B", 36), "fm_fungal_longbow": ("D", 18),
    "fm_fungal_plate": ("H", 15), "fm_mycelium_focus": ("M", 9),
    "fm_mycelium_saber": ("B", 43), "fm_mycelium_tunic": ("H", 7),
    "fm_sporeguard_pendant": ("AD", 26),
    # R2 — Fungal Marshes T4
    "fm_fungal_heart_focus": ("AA", 39), "fm_fungal_heart_pack": ("BO", 22),
    # R3 — Sunken Shoals Materials
    "driftwood": ("W", 27), "ss_kelp_sinew": ("W", 6),
    "stormglass_fragment": ("BM", 7), "boss_trophy_sunken_strand": ("AE", 5),
    # R3 — Sunken Shoals T2
    "ss_coral_focus": ("AA", 40), "ss_driftwood_bow": ("D", 17),
    "ss_kelp_leggings": ("I", 33), "ss_kelp_satchel": ("BO", 13),
    "ss_pearl_pendant": ("AF", 26), "ss_pearl_ring": ("L", 3),
    "ss_shell_helm": ("G", 22), "ss_tide_sword": ("A", 12),
    # R3 — Sunken Shoals T3
    "ss_abalone_shield": ("AC", 23), "ss_barnacle_plate": ("H", 33),
    "ss_kelp_greaves": ("I", 41), "ss_kelp_vest": ("H", 39),
    "ss_sea_glass_focus": ("BN", 41), "ss_shell_pack": ("BO", 38),
    "ss_tide_fang": ("B", 3),
    # R3 — Sunken Shoals T4
    "ss_leviathan_pack": ("BO", 28), "ss_leviathan_staff": ("F", 25),
    "ss_tidewoven_vest": ("H", 40),
    # R4 — Ashen Horizons Materials
    "ah_drake_scale": ("AE", 38), "ember_dust": ("AE", 26),
    "magma_core": ("AA", 14), "obsidian_shard": ("M", 4),
    "ah_sulfite_gland": ("AA", 14), "volcanic_glass": ("AA", 22),
    # R4 — Ashen Horizons T2
    "ah_cinder_pendant": ("AC", 12), "ah_cinder_satchel": ("BO", 11),
    "ah_cinder_tunic": ("H", 8), "ah_obsidian_mace": ("E", 1),
    "ah_obsidian_ring": ("L", 14), "ah_obsidian_vest": ("H", 9),
    # R4 — Ashen Horizons T3
    "ah_drake_jerkin": ("H", 6), "ah_drake_pack": ("BO", 31),
    "ah_magma_plate": ("H", 26), "ah_obsidian_staff": ("F", 23),
    "ah_scorched_longbow": ("D", 19), "ah_volcanic_helm": ("G", 15),
    # R4 — Ashen Horizons T4
    "ah_drakefang_blade": ("B", 23), "ah_drakescale_greaves": ("I", 43),
    "ah_drakescale_plate": ("H", 27), "ah_draketalon": ("B", 46),
    # R5 — Starfall Expanse Materials
    "astral_fragment": ("Z", 15), "starfall_core_fragment": ("Z", 39),
    "starfall_dust": ("W", 4), "boss_trophy_starfall_expanse": ("Z", 45),
    # R5 — Starfall Expanse T2
    "se_astral_shortbow": ("D", 13), "se_astral_tunic": ("H", 1),
    "se_crystal_knife": ("B", 36), "se_crystal_mace": ("E", 9),
    "se_crystal_pendant": ("M", 28), "se_crystal_ring": ("L", 8),
    "se_crystal_staff": ("F", 24), "se_crystal_sword": ("A", 16),
    # R5 — Starfall Expanse T3
    "se_astral_pack": ("BO", 36), "se_astral_plate": ("H", 13),
    "se_astral_ring": ("L", 18),
    "se_crystal_robe": ("H", 10), "se_prism_edge": ("A", 30),
    "se_prism_fang": ("B", 39), "se_prism_shield": ("BN", 19),
    "se_temporal_maul": ("E", 11),
    # R5 — Starfall Expanse T4
    "se_astral_robe": ("H", 19), "se_chrono_cleaver": ("C", 38),
    "se_crystal_ward": ("H", 36), "se_echo_amulet": ("AD", 30),
    "se_echo_shield": ("BN", 29), "se_prism_helm": ("G", 45),
    "se_prism_staff": ("F", 11), "se_starlight_focus": ("M", 17),
    "se_temporal_dagger": ("B", 18),
    # R6 — Necropolis Materials
    "nc_bone_marrow": ("Y", 16), "deadmans_grass": ("BM", 21),
    "nc_grave_dust": ("W", 4), "soul_ore": ("Z", 30),
    "spectral_log": ("BB", 3), "wailing_shard": ("AD", 4),
    "nc_wraith_thread": ("AA", 33), "boss_trophy_necropolis": ("AA", 23),
    # R6 — Necropolis T2
    "nc_bone_greaves": ("I", 14), "nc_bone_helm": ("G", 16),
    "nc_bone_knife": ("B", 33), "nc_bone_mace": ("E", 2),
    "nc_bone_satchel": ("BO", 19), "nc_bone_shield": ("BN", 3),
    "nc_bone_vest": ("H", 2), "nc_grave_sword": ("A", 22),
    "nc_spectral_bow": ("D", 23),
    # R6 — Necropolis T3
    "nc_deathward_band": ("L", 16), "nc_ossuary_greaves": ("I", 15),
    "nc_ossuary_mail": ("H", 13),
    "nc_ossuary_helm": ("G", 29), "nc_ossuary_maul": ("E", 40),
    "nc_ossuary_pendant": ("L", 42), "nc_ossuary_shield": ("BN", 15),
    "nc_soul_edge": ("A", 27), "nc_wraith_fang": ("B", 17),
    "nc_wraith_pack": ("BB", 17), "nc_wraith_tunic": ("H", 17),
    # R6 — Necropolis T4
    "nc_bone_crown": ("G", 41), "nc_ossuary_plate": ("H", 18),
    "nc_soulfire_focus": ("BN", 43), "nc_spectral_aegis": ("BN", 34),
    "nc_wraith_leggings": ("I", 10), "nc_wraith_robe": ("H", 46),
    # R7 — Fractured Realm Materials
    "fr_entropy_residue": ("W", 4), "fractured_soulglass": ("W", 39),
    "primordial_essence": ("V", 35), "void_crystal": ("V", 20),
    "boss_trophy_fractured_realm": ("AE", 35),
    # R7 — Final Realm T2
    "fr_rift_focus": ("AC", 48), "fr_rift_greaves": ("I", 25),
    "fr_rift_helm": ("G", 28), "fr_rift_knife": ("B", 12),
    "fr_rift_mace": ("E", 19), "fr_rift_satchel": ("BO", 32),
    "fr_rift_shield": ("BN", 31), "fr_rift_sword": ("A", 37),
    "fr_rift_tunic": ("H", 2), "fr_rift_vest": ("H", 1),
    "fr_rift_wand": ("B", 37),
    # R7 — Final Realm T3
    "fr_null_blade": ("A", 35), "fr_null_bow": ("D", 4),
    "fr_null_fang": ("B", 44), "fr_null_greaves": ("I", 42),
    "fr_null_helm": ("G", 43), "fr_null_maul": ("E", 25),
    "fr_null_focus_t3": ("AC", 8), "fr_null_pack": ("BO", 39),
    "fr_null_pendant": ("L", 23), "fr_null_plate": ("H", 31),
    "fr_null_ring": ("L", 26), "fr_null_shield": ("BN", 35),
    "fr_null_shroud": ("H", 19), "fr_null_staff": ("E", 27),
    # R7 — Final Realm T4
    "fr_dimensional_locket": ("L", 29), "fr_entropy_bow": ("D", 21),
    "fr_null_barrier": ("BN", 5), "fr_null_focus": ("AB", 43),
    "fr_rift_band": ("L", 27), "fr_rift_staff": ("F", 47),
    "fr_void_edge": ("A", 46), "fr_void_greaves": ("I", 46),
    "fr_void_helm": ("G", 47), "fr_void_pack": ("BO", 89),
    "fr_void_shroud": ("H", 29),
    # Consumables — R1 Base (Recoloured)
    "minor_healing_tonic": ("S", 40), "healing_tonic": ("S", 42),
    "bandage": ("X", 22), "minor_stamina_snack": ("T", 20),
    "smelling_salts": ("T", 16), "smoke_bomb": ("T", 27),
    "focus_elixir": ("T", 36), "power_elixir": ("T", 26),
    "resistance_salve": ("BB", 45), "stamina_draught": ("AC", 46),
    "strong_healing_tonic": ("AC", 47),
    # Consumables — R2 Fungal Marshes
    "fm_spore_elixir": ("Y", 45),
    # Consumables — R3 Sunken Shoals
    "ss_fog_bomb": ("Y", 28), "ss_kelp_wrap": ("T", 13),
    # Consumables — R4 Ashen Horizons
    "ah_ash_bomb": ("Y", 46), "ah_charred_feast": ("T", 32),
    # Consumables — R5 Starfall Expanse
    "se_starlight_elixir": ("Y", 25),
    # Consumables — R6 Necropolis
    "nc_banshee_vial": ("Y", 2), "nc_phylactery_tonic": ("Y", 34),
    "nc_spectral_draught": ("Y", 11),
    # Consumables — R7 Fractured Realm
    "fr_void_essence_flask": ("Y", 44), "fr_entropy_charge": ("Y", 26),
    "fr_dimensional_flux": ("AC", 46), "fr_void_mend": ("Y", 24),
    "fr_null_feast": ("T", 46),
    # Duplicate Icon Fixes
    "nc_corpsebloom_stew": ("T", 45), "minor_venom_flask": ("T", 29),
    "ss_brine_venom": ("T", 29), "forest_bounty": ("T", 32),
    "honey_roast": ("T", 46), "slime_gel": ("Y", 3),
    "gw_thornhide_vest": ("H", 23), "ah_ember_focus": ("X", 36),
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
