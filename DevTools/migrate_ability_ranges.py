#!/usr/bin/env python3
"""
migrate_ability_ranges.py — Grid Combat v1 Data Migration

Adds movement_range to monster JSONs based on combat_role:
  - melee:  2 (standard movement)
  - ranged: 1 (less mobile)
  - mage:   1 (less mobile)
  - boss:   2 (standard movement)

Also validates ability JSONs have valid aoe_shape values if present.

Usage:
  python DevTools/migrate_ability_ranges.py           # Dry run (preview only)
  python DevTools/migrate_ability_ranges.py --apply    # Apply changes
"""

import json
import os
import sys
from pathlib import Path

# Movement range by combat_role
MOVEMENT_RANGE_BY_ROLE = {
    "melee": 2,
    "ranged": 1,
    "mage": 1,
}

# Boss override
BOSS_MOVEMENT_RANGE = 2

# Elite override (slightly more mobile than base)
ELITE_MOVEMENT_RANGE_OVERRIDE = {
    "melee": 3,
    "ranged": 2,
    "mage": 2,
}

VALID_AOE_SHAPES = {"none", "square"}

def get_project_root():
    """Find project root (parent of DevTools/)."""
    script_dir = Path(__file__).resolve().parent
    return script_dir.parent

def migrate_monsters(project_root, apply=False):
    """Add movement_range to monster JSONs."""
    monsters_dir = project_root / "Data" / "Monsters"
    if not monsters_dir.exists():
        print(f"[ERROR] Monsters directory not found: {monsters_dir}")
        return 0, 0

    modified = 0
    skipped = 0
    errors = 0

    for json_file in sorted(monsters_dir.glob("*.json")):
        try:
            with open(json_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Skip if already has movement_range
            if "movement_range" in data:
                skipped += 1
                continue

            # Determine movement_range
            combat_role = data.get("combat_role", "melee")
            is_boss = data.get("is_boss", False)
            is_elite = data.get("is_elite", False)

            if is_boss:
                move_range = BOSS_MOVEMENT_RANGE
            elif is_elite:
                move_range = ELITE_MOVEMENT_RANGE_OVERRIDE.get(combat_role, 2)
            else:
                move_range = MOVEMENT_RANGE_BY_ROLE.get(combat_role, 2)

            # Add field after combat_role for readability
            new_data = {}
            for key, value in data.items():
                new_data[key] = value
                if key == "combat_role":
                    new_data["movement_range"] = move_range

            # If combat_role wasn't found, add at end
            if "movement_range" not in new_data:
                new_data["movement_range"] = move_range

            if apply:
                with open(json_file, "w", encoding="utf-8") as f:
                    json.dump(new_data, f, indent=2, ensure_ascii=False)
                    f.write("\n")

            print(f"  {'WRITE' if apply else 'WOULD'} {json_file.name}: "
                  f"role={combat_role} boss={is_boss} elite={is_elite} "
                  f"-> movement_range={move_range}")
            modified += 1

        except Exception as e:
            print(f"  [ERROR] {json_file.name}: {e}")
            errors += 1

    return modified, skipped, errors


def validate_abilities(project_root):
    """Validate ability JSONs for valid aoe_shape values."""
    abilities_dir = project_root / "Data" / "Abilities"
    if not abilities_dir.exists():
        print(f"[ERROR] Abilities directory not found: {abilities_dir}")
        return 0, 0

    valid = 0
    issues = 0

    for json_file in sorted(abilities_dir.glob("*.json")):
        try:
            with open(json_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Check aoe_shape if present
            aoe_shape = data.get("aoe_shape", "none")
            if aoe_shape not in VALID_AOE_SHAPES:
                print(f"  [ISSUE] {json_file.name}: invalid aoe_shape='{aoe_shape}'")
                issues += 1
                continue

            # Check aoe_size consistency
            aoe_size = data.get("aoe_size", 0)
            if aoe_shape != "none" and aoe_size < 0:
                print(f"  [ISSUE] {json_file.name}: negative aoe_size={aoe_size}")
                issues += 1
                continue

            valid += 1

        except Exception as e:
            print(f"  [ERROR] {json_file.name}: {e}")
            issues += 1

    return valid, issues


def main():
    apply = "--apply" in sys.argv
    project_root = get_project_root()

    print("=" * 60)
    print("Grid Combat v1 — Data Migration")
    print(f"Mode: {'APPLY' if apply else 'DRY RUN (use --apply to write)'}")
    print(f"Project: {project_root}")
    print("=" * 60)

    # 1. Monster movement_range
    print("\n--- Monster movement_range ---")
    modified, skipped, errors = migrate_monsters(project_root, apply)
    print(f"\nMonsters: {modified} modified, {skipped} already had field, {errors} errors")

    # 2. Ability validation
    print("\n--- Ability aoe_shape validation ---")
    valid, issues = validate_abilities(project_root)
    print(f"\nAbilities: {valid} valid, {issues} issues")

    # Summary
    print("\n" + "=" * 60)
    if errors > 0 or issues > 0:
        print(f"DONE with {errors + issues} issues")
    else:
        print("DONE — all clean!")
    if not apply and modified > 0:
        print(f"Run with --apply to write {modified} monster files")
    print("=" * 60)


if __name__ == "__main__":
    main()
