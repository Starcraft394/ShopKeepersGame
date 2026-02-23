#!/usr/bin/env python3
"""Add new equipment stats (crit_chance, evasion, resist, thorns, armor_penetration, life_steal)
to existing equipment items based on region, tier, and slot.

Run: python DevTools/add_new_equipment_stats.py
"""
import json
import os
import hashlib

ITEMS_DIR = os.path.join(os.path.dirname(__file__), "..", "Data", "Items", "Templates")

# Region stat personalities from the plan
REGION_STATS = {
    "base":     ["crit_chance", "evasion", "resist"],  # Starter variety
    "region_1": ["thorns", "crit_chance", "evasion"],   # Nature's precision
    "region_2": ["thorns", "evasion", "resist"],        # Toxic retaliation
    "region_3": ["evasion", "resist"],                  # Tidal flow, cleansing
    "region_4": ["crit_chance", "thorns", "armor_penetration"],  # Burning precision
    "region_5": ["armor_penetration", "crit_chance"],   # Crystal piercing
    "region_6": ["life_steal", "armor_penetration", "crit_chance"],  # Soul drain
    "region_7": ["evasion", "life_steal", "resist"],    # Dimensional dodge
}

# Slot determines which stats are thematically appropriate
SLOT_STATS = {
    "weapon":  ["crit_chance", "armor_penetration", "life_steal"],
    "armor":   ["resist", "thorns", "evasion"],
    "offhand": ["thorns", "resist", "evasion"],
    "helmet":  ["resist", "evasion", "crit_chance"],
    "legs":    ["evasion", "resist"],
    "ring":    ["crit_chance", "evasion", "life_steal", "armor_penetration"],
    "amulet":  ["resist", "life_steal", "crit_chance"],
    "bag":     [],  # No combat stats on bags
}

# Stat value ranges by tier
STAT_TIERS = {
    "crit_chance":       {1: (2, 3),  2: (4, 6),  3: (7, 10),  4: (12, 15)},
    "evasion":           {1: (2, 3),  2: (4, 6),  3: (7, 10),  4: (12, 15)},
    "resist":            {1: (1, 2),  2: (3, 5),  3: (6, 9),   4: (10, 14)},
    "thorns":            {1: (1, 1),  2: (2, 3),  3: (4, 5),   4: (6, 8)},
    "armor_penetration": {1: (0, 0),  2: (2, 3),  3: (4, 5),   4: (6, 10)},
    "life_steal":        {1: (0, 0),  2: (0, 0),  3: (5, 8),   4: (10, 15)},
}

# Subtype overrides: daggers and bows favor evasion/crit
SUBTYPE_BOOST = {
    "dagger": ["evasion", "crit_chance"],
    "bow":    ["crit_chance", "evasion"],
    "staff":  ["resist"],
    "focus":  ["resist"],
    "shield": ["thorns", "resist"],
}


def deterministic_hash(item_id: str) -> int:
    """Get a deterministic int from item ID for reproducible stat assignment."""
    return int(hashlib.md5(item_id.encode()).hexdigest(), 16)


def get_region(tags: list) -> str:
    for tag in tags:
        if tag.startswith("region_"):
            return tag
    if "base" in tags:
        return "base"
    return "base"


def get_stat_value(stat: str, tier: int, seed: int) -> int:
    """Get a deterministic stat value within the tier range."""
    rng = STAT_TIERS.get(stat, {}).get(tier, (0, 0))
    if rng[0] == 0 and rng[1] == 0:
        return 0
    spread = rng[1] - rng[0]
    if spread == 0:
        return rng[0]
    return rng[0] + (seed % (spread + 1))


def pick_stats_for_item(item: dict) -> dict:
    """Determine which new stats to add and their values."""
    item_id = item["id"]
    tags = item.get("tags", [])
    tier = item.get("tier", 1)
    equip_slot = item.get("equip_slot", "")
    item_subtype = item.get("item_subtype", "")
    existing_bonuses = item.get("stat_bonuses", {})

    # Skip bags and items without equip_slot
    if equip_slot == "bag" or equip_slot == "":
        return {}

    region = get_region(tags)
    seed = deterministic_hash(item_id)

    # Get stats valid for this region AND slot
    region_pool = REGION_STATS.get(region, ["crit_chance", "resist"])
    slot_pool = SLOT_STATS.get(equip_slot, [])

    # Subtype can expand the pool
    subtype_pool = SUBTYPE_BOOST.get(item_subtype, [])

    # Intersection of region + (slot OR subtype)
    combined_slot_pool = set(slot_pool) | set(subtype_pool)
    valid_stats = [s for s in region_pool if s in combined_slot_pool]

    # If no overlap, fall back to slot-appropriate stats regardless of region
    if not valid_stats:
        valid_stats = list(slot_pool) if slot_pool else list(region_pool[:1])
    if not valid_stats:
        return {}

    new_stats = {}

    # Determine how many stats to add (1-2)
    # ~30% get 0 new stats, ~45% get 1, ~25% get 2
    roll = seed % 100
    if roll < 15:
        num_stats = 0
    elif roll < 65:
        num_stats = 1
    else:
        num_stats = 2

    if num_stats == 0:
        return {}

    # Assign stats deterministically
    for i in range(min(num_stats, len(valid_stats))):
        stat = valid_stats[i % len(valid_stats)]
        val = get_stat_value(stat, tier, seed >> (i * 4))
        if val > 0:
            new_stats[stat] = val

    return new_stats


def process_items():
    """Process all equipment items and add new stats."""
    items_modified = 0
    items_skipped = 0
    stat_counts = {}

    all_files = sorted(os.listdir(ITEMS_DIR))
    json_files = [f for f in all_files if f.endswith(".json")]

    for filename in json_files:
        filepath = os.path.join(ITEMS_DIR, filename)
        with open(filepath, "r", encoding="utf-8") as f:
            item = json.load(f)

        # Only process equipment (items with stat_bonuses and equip_slot)
        if "stat_bonuses" not in item or "equip_slot" not in item:
            continue

        equip_slot = item.get("equip_slot", "")
        if equip_slot == "bag":
            continue

        new_stats = pick_stats_for_item(item)

        if not new_stats:
            items_skipped += 1
            continue

        # Add new stats to stat_bonuses (and base_stats for consistency)
        modified = False
        for stat, val in new_stats.items():
            if stat not in item["stat_bonuses"]:
                item["stat_bonuses"][stat] = val
                # Also add to base_stats if it exists
                if "base_stats" in item:
                    item["base_stats"][stat] = val
                modified = True
                stat_counts[stat] = stat_counts.get(stat, 0) + 1

        if modified:
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(item, f, indent=2, ensure_ascii=False)
                f.write("\n")
            items_modified += 1

    print(f"\n{'='*60}")
    print(f"  STAT ASSIGNMENT SUMMARY")
    print(f"{'='*60}")
    print(f"  Items modified: {items_modified}")
    print(f"  Items skipped (no stats / bags): {items_skipped}")
    print(f"")
    print(f"  New stat distribution:")
    for stat, count in sorted(stat_counts.items(), key=lambda x: -x[1]):
        print(f"    {stat:20s}: {count} items")
    print(f"{'='*60}")


if __name__ == "__main__":
    process_items()
