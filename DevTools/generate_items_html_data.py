"""
Generate JavaScript items data for Docs/item_icon_reference.html.
Reads all Data/Items/Templates/*.json and outputs a JS snippet
with ALL_ITEMS array organized by region.
"""

import os
import json
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS_DIR = os.path.join(BASE, "Data", "Items", "Templates")


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
        icon_path = data.get("icon_path", "")
        if icon_path.startswith("res://"):
            icon_path = "../" + icon_path[6:]

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
    for it in items:
        region_counts[it["region"]] = region_counts.get(it["region"], 0) + 1

    print(f"// Total items: {len(items)}")
    for r in region_order:
        c = region_counts.get(r, 0)
        if c:
            print(f"//   {r}: {c}")
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
        ]
        print(f'  {{{", ".join(parts)}}},')

    print("];")


if __name__ == "__main__":
    main()
