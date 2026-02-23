#!/usr/bin/env python3
"""Generate Docs/HERO_REFERENCE.md from all hero data.

Reads:
  Data/Classes/*.json   (15 class definitions)
  Data/Races/*.json     (9 race definitions)
  Data/Abilities/*.json (hero + equipment abilities, excludes mon_*)
  Data/Passives/*.json  (class + racial passives)

Output: Docs/HERO_REFERENCE.md

Usage:
    python DevTools/generate_hero_reference.py
"""
import json
import os
import math
from datetime import date

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASSES_DIR = os.path.join(BASE, "Data", "Classes")
RACES_DIR = os.path.join(BASE, "Data", "Races")
ABILITIES_DIR = os.path.join(BASE, "Data", "Abilities")
PASSIVES_DIR = os.path.join(BASE, "Data", "Passives")
OUTPUT = os.path.join(BASE, "Docs", "HERO_REFERENCE.md")

MAX_HERO_LEVEL = 55
XP_THRESHOLDS = [
    0, 18, 50, 99, 168, 260, 377, 521, 694, 899,
    1137, 1410, 1720, 2069, 2459, 2891, 3367, 3889, 4458, 5076,
    5745, 6466, 7240, 8069, 8955, 9899, 10902, 11966, 13093, 14284,
    15540, 16862, 18252, 19711, 21241, 22843, 24518, 26267, 28092, 29994,
    31974, 34034, 36175, 38398, 40704, 43095, 45572, 48135, 50787, 53528,
    56359, 59282, 62298, 65408, 68613,
]
ABILITY_UNLOCK_LEVELS = {"ability_a": 5, "passive_a": 15, "ability_b": 25, "passive_b": 40}
REGION_XP_BASE = {1: 15, 2: 28, 3: 45, 4: 70, 5: 100, 6: 140, 7: 190}

REGION_NAMES = {
    1: "Thornhaven",
    2: "Fungal Marshes",
    3: "Sunken Shores",
    4: "Ashen Highlands",
    5: "Shattered Expanse",
    6: "Necropolis Crypts",
    7: "Fractured Realm",
}


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_json_dir(directory):
    """Load all JSON files from a directory, return list of dicts."""
    items = []
    if not os.path.isdir(directory):
        return items
    for fname in sorted(os.listdir(directory)):
        if not fname.endswith(".json"):
            continue
        with open(os.path.join(directory, fname), "r", encoding="utf-8") as f:
            items.append(json.load(f))
    return items


def load_all_classes():
    return sorted(load_json_dir(CLASSES_DIR), key=lambda c: (c.get("unlock_region", 0), c["id"]))


def load_all_races():
    return sorted(load_json_dir(RACES_DIR), key=lambda r: (r.get("unlock_region", 0), r["id"]))


def load_all_abilities():
    """Load all abilities, excluding mon_* (monster abilities)."""
    all_abs = load_json_dir(ABILITIES_DIR)
    return [a for a in all_abs if not a["id"].startswith("mon_")]


def load_all_passives():
    return load_json_dir(PASSIVES_DIR)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def compute_stats_at_level(cls, level):
    base = cls.get("base_stats", {})
    growth = cls.get("stat_growth", {})
    return {
        "health": base.get("health", 0) + growth.get("health", 0) * (level - 1),
        "attack": base.get("attack", 0) + growth.get("attack", 0) * (level - 1),
        "defense": base.get("defense", 0) + growth.get("defense", 0) * (level - 1),
        "speed": base.get("speed", 0) + growth.get("speed", 0) * (level - 1),
    }


def stat_line(stats):
    return f"HP {stats['health']} | ATK {stats['attack']} | DEF {stats['defense']} | SPD {stats['speed']}"


def get_ability_summary(ability):
    """One-line summary: 'damage_type base (scalingx) CD target | status dur'"""
    parts = []
    etype = ability.get("effect_type", "")
    dmg_type = ability.get("damage_type", "")
    base_dmg = ability.get("base_damage", 0)
    scaling = ability.get("attack_scaling", 0)
    cd = ability.get("cooldown", 0)
    target = ability.get("target_type", "")
    hits = ability.get("hit_count", 1)
    status = ability.get("applies_status_id", "")
    status_dur = ability.get("applies_status_duration", 0)
    armor_pierce = ability.get("armor_piercing", False)

    if etype == "damage" or base_dmg > 0:
        dmg_str = f"{dmg_type} {base_dmg} ({scaling}x)"
        if hits > 1:
            dmg_str += f" x{hits}"
        if armor_pierce:
            dmg_str += " pierce"
        parts.append(dmg_str)
    elif etype == "heal":
        heal_val = ability.get("heal_amount", ability.get("base_heal", 0))
        heal_scaling = ability.get("heal_scaling", ability.get("attack_scaling", 0))
        parts.append(f"heal {heal_val} ({heal_scaling}x)")
    elif etype == "buff":
        parts.append("buff")
    elif etype == "debuff":
        parts.append("debuff")
    elif etype == "drain":
        parts.append(f"drain {dmg_type} {base_dmg} ({scaling}x)")
    elif etype == "shield":
        shield_val = ability.get("shield_amount", ability.get("base_damage", 0))
        parts.append(f"shield {shield_val}")
    elif etype:
        parts.append(etype)

    parts.append(f"CD{cd}")

    # Simplify target_type for display
    target_short = target.replace("single_enemy", "single").replace("all_enemies", "all").replace("single_ally", "ally").replace("all_allies", "allies").replace("self", "self")
    parts.append(target_short)

    if status:
        s = f"| {status}"
        if status_dur:
            s += f" {status_dur}t"
        parts.append(s)

    return " ".join(parts)


def get_passive_summary(passive):
    """One-line summary: 'trigger: effect description'"""
    ptype = passive.get("passive_type", "")
    trigger = passive.get("trigger", "")
    effect = passive.get("effect", {})
    desc = passive.get("description", "")

    # For complex passives, just use a shortened description
    if ptype == "level_scaled_stat_bonus":
        stat = effect.get("stat", "?")
        bonus = effect.get("bonus", 0)
        return f"{trigger}: +({bonus}+level) {stat.upper()}"
    elif ptype == "stat_bonus":
        if isinstance(effect, dict):
            parts = [f"+{v} {k.upper()}" for k, v in effect.items() if isinstance(v, (int, float))]
            return f"{trigger}: {', '.join(parts)}" if parts else f"{trigger}: {ptype}"
        return f"{trigger}: {ptype}"
    elif ptype == "race_multi_stat_bonus":
        if isinstance(effect, dict):
            parts = []
            for k, v in effect.items():
                if isinstance(v, (int, float)):
                    parts.append(f"+{v} {k.upper()}")
            return f"{trigger}: {', '.join(parts)}" if parts else desc[:80]
        return desc[:80]
    elif ptype == "on_kill_stacking_buff":
        return f"on_kill: stacking buff"
    elif ptype == "on_hit_retaliation":
        return f"on_hit: retaliation damage"
    elif ptype == "round_start_heal":
        return f"round_start: heal"
    elif ptype == "on_kill_cooldown_reduction":
        return f"on_kill: reduce CDs"
    elif ptype == "regen":
        return f"round_start: regenerate HP"
    elif ptype == "damage_reduction":
        return f"always: reduce incoming damage"
    elif ptype == "on_hit_heal":
        return f"on_hit: heal % of damage"
    elif ptype == "on_enemy_death_heal":
        return f"on_enemy_death: heal"
    elif ptype == "death_prevention":
        return f"on_death: survive once"
    elif ptype == "revive_once":
        return f"on_death: revive once"
    elif ptype == "combat_start_shield":
        return f"combat_start: gain shield"
    elif ptype == "cooldown_reduction":
        return f"always: reduce ability CDs"
    elif ptype == "damage_negate_chance" or ptype == "damage_negation_chance":
        return f"on_hit: % chance negate damage"
    elif ptype == "armor_piercing_chance":
        return f"on_attack: % chance pierce armor"
    elif ptype == "damage_bonus":
        return f"always: +% damage"
    elif ptype == "damage_type_bonus":
        return f"always: +% to specific damage type"
    elif ptype == "conditional_stat_bonus":
        return f"conditional: stat bonus"
    elif ptype == "conditional_damage_bonus":
        return f"conditional: damage bonus"
    elif ptype == "on_kill":
        return f"on_kill: special effect"
    elif ptype == "on_kill_next_ability_bonus":
        return f"on_kill: next ability empowered"
    elif ptype == "on_kill_damage":
        return f"on_kill: AoE damage"
    elif ptype == "on_kill_heal":
        return f"on_kill: heal"
    elif ptype == "on_heal_self_heal":
        return f"on_heal: also heal self"
    elif ptype == "low_hp_stat_bonus":
        return f"low_hp: stat bonus"
    elif ptype == "round_start_shield":
        return f"round_start: gain shield"
    elif ptype == "round_start_enemy_damage":
        return f"round_start: damage enemies"
    elif ptype == "status_duration_bonus":
        return f"always: +status duration"
    elif ptype == "multi_stat_bonus":
        return f"always: multiple stat bonuses"
    elif ptype == "level_scaled_stat_bonus_with_cost":
        stat = effect.get("stat", "?") if isinstance(effect, dict) else "?"
        return f"{trigger}: +level {stat.upper()} (HP cost)"
    else:
        # Fallback: use first 80 chars of description
        return desc[:80] if desc else ptype


# ---------------------------------------------------------------------------
# Section builders
# ---------------------------------------------------------------------------

def build_header(classes, races, abilities, passives):
    class_abilities = [a for a in abilities if a.get("ability_type") in ("class_a", "class_b")]
    equip_abilities = [a for a in abilities if a.get("ability_type") == "equipment"]
    class_passives = [p for p in passives if p.get("category") == "class"]
    racial_passives = [p for p in passives if p.get("category") == "racial"]

    lines = [
        "# Hero Reference",
        "",
        f"**Generated**: {date.today().isoformat()}",
        f"**{len(classes)} Classes** | **{len(races)} Races** | "
        f"**{len(class_abilities)} Class Abilities** | **{len(class_passives)} Class Passives** | "
        f"**{len(racial_passives)} Racial Passives** | **{len(equip_abilities)} Equipment Abilities**",
        "",
        "Auto-generated by `DevTools/generate_hero_reference.py` -- do not edit by hand.",
        "",
        "---",
        "",
    ]
    return lines


def build_region_unlock_map(classes, races):
    lines = ["## 1. Region Unlock Map", ""]
    lines.append("| Region | Classes | Races |")
    lines.append("|--------|---------|-------|")

    for region_num in range(1, 8):
        rname = REGION_NAMES.get(region_num, f"Region {region_num}")
        region_classes = [c["display_name"] for c in classes if c.get("unlock_region") == region_num]
        region_races = [r["display_name"] for r in races if r.get("unlock_region") == region_num]
        lines.append(f"| R{region_num}: {rname} | {', '.join(region_classes) or '—'} | {', '.join(region_races) or '—'} |")

    lines.append("")
    return lines


def build_archetype_overview(classes):
    lines = ["## 2. Archetype Overview", ""]
    lines.append("| Archetype | Classes | Role |")
    lines.append("|-----------|---------|------|")

    archetypes = {}
    for c in classes:
        arch = c.get("archetype", "unknown")
        archetypes.setdefault(arch, []).append(f"{c['display_name']} (R{c.get('unlock_region', '?')})")

    role_map = {
        "vanguard": "Tank / frontline",
        "healer": "Support / healing",
        "dps": "Damage dealer",
        "striker": "Damage dealer",
        "warden": "Support / healing",
    }

    for arch, members in sorted(archetypes.items()):
        role = role_map.get(arch, arch.title())
        lines.append(f"| {arch.title()} | {', '.join(members)} | {role} |")

    lines.append("")
    return lines


def build_class_definitions(classes, abilities, passives):
    lines = ["## 3. Class Definitions", ""]

    ability_map = {a["id"]: a for a in abilities}
    passive_map = {p["id"]: p for p in passives}

    for i, cls in enumerate(classes):
        cid = cls["id"]
        region = cls.get("unlock_region", "?")
        arch = cls.get("archetype", "?")
        desc = cls.get("description", "")
        weapons = cls.get("weapon_types", [])

        lines.append(f"### 3.{i+1} {cls['display_name']} (R{region}, {arch.title()})")
        lines.append(f"> {desc}")
        lines.append("")

        base = cls.get("base_stats", {})
        growth = cls.get("stat_growth", {})
        lines.append(f"**Base Stats**: HP {base.get('health',0)} | ATK {base.get('attack',0)} | DEF {base.get('defense',0)} | SPD {base.get('speed',0)}")
        lines.append(f"**Stat Growth**: HP +{growth.get('health',0)} | ATK +{growth.get('attack',0)} | DEF +{growth.get('defense',0)} | SPD +{growth.get('speed',0)}")

        for lvl in [10, 25, 55]:
            s = compute_stats_at_level(cls, lvl)
            lines.append(f"**Stats at Lv{lvl}**: {stat_line(s)}")

        lines.append(f"**Weapon Types**: {', '.join(weapons) if weapons else '—'}")
        lines.append("")

        # Ability/Passive table
        lines.append("| Slot | Unlocks | Name | Summary |")
        lines.append("|------|---------|------|---------|")

        for slot, label in [("ability_a", "Ability A"), ("ability_b", "Ability B"),
                            ("passive_a", "Passive A"), ("passive_b", "Passive B")]:
            aid = cls.get(f"{slot}_id", "")
            unlock_lv = ABILITY_UNLOCK_LEVELS.get(slot, "?")
            if aid:
                if slot.startswith("ability"):
                    ab = ability_map.get(aid)
                    if ab:
                        summary = get_ability_summary(ab)
                        lines.append(f"| {label} | Lv {unlock_lv} | {ab.get('display_name', aid)} | {summary} |")
                    else:
                        lines.append(f"| {label} | Lv {unlock_lv} | {aid} | *(not found)* |")
                else:
                    pa = passive_map.get(aid)
                    if pa:
                        summary = get_passive_summary(pa)
                        lines.append(f"| {label} | Lv {unlock_lv} | {pa.get('display_name', aid)} | {summary} |")
                    else:
                        lines.append(f"| {label} | Lv {unlock_lv} | {aid} | *(not found)* |")
            else:
                lines.append(f"| {label} | Lv {unlock_lv} | — | — |")

        lines.append("")

    return lines


def build_race_definitions(races, passives):
    lines = ["## 4. Race Definitions", ""]
    passive_map = {p["id"]: p for p in passives}

    for i, race in enumerate(races):
        region = race.get("unlock_region", "?")
        desc = race.get("description", "")
        mods = race.get("stat_modifiers", {})
        xp_mod = race.get("xp_modifier", 1.0)
        tags = race.get("trait_tags", [])
        pid = race.get("racial_passive_id", "")

        lines.append(f"### 4.{i+1} {race['display_name']} (R{region})")
        lines.append(f"> {desc}")
        lines.append("")
        lines.append(f"**Stat Modifiers**: HP {mods.get('health',0):+d} | ATK {mods.get('attack',0):+d} | DEF {mods.get('defense',0):+d} | SPD {mods.get('speed',0):+d}")
        lines.append(f"**XP Modifier**: {xp_mod}x")
        lines.append(f"**Trait Tags**: {', '.join(tags) if tags else '—'}")

        if pid:
            pa = passive_map.get(pid)
            if pa:
                lines.append(f"**Racial Passive**: {pa.get('display_name', pid)} — {get_passive_summary(pa)}")
            else:
                lines.append(f"**Racial Passive**: {pid} *(not found)*")
        lines.append("")

    return lines


def build_stat_modifier_comparison(races):
    lines = ["## 5. Race Stat Modifier Comparison", ""]
    lines.append("| Race | HP | ATK | DEF | SPD | Total | XP Mod | Traits |")
    lines.append("|------|----|-----|-----|-----|-------|--------|--------|")

    for race in races:
        mods = race.get("stat_modifiers", {})
        hp = mods.get("health", 0)
        atk = mods.get("attack", 0)
        df = mods.get("defense", 0)
        spd = mods.get("speed", 0)
        total = hp + atk + df + spd
        xp = race.get("xp_modifier", 1.0)
        tags = ", ".join(race.get("trait_tags", []))
        lines.append(f"| {race['display_name']} | {hp:+d} | {atk:+d} | {df:+d} | {spd:+d} | {total:+d} | {xp}x | {tags} |")

    lines.append("")
    return lines


def build_class_stat_comparison(classes):
    lines = ["## 6. Class Stat Comparison", ""]
    lines.append("| Class | R | Arch | HP | ATK | DEF | SPD | HP/lv | ATK/lv | DEF/lv | SPD/lv | Growth Total |")
    lines.append("|-------|---|------|----|-----|-----|-----|-------|--------|--------|--------|-------------|")

    for cls in classes:
        base = cls.get("base_stats", {})
        growth = cls.get("stat_growth", {})
        gtotal = sum(growth.values())
        lines.append(
            f"| {cls['display_name']} | R{cls.get('unlock_region','?')} | {cls.get('archetype','?')} "
            f"| {base.get('health',0)} | {base.get('attack',0)} | {base.get('defense',0)} | {base.get('speed',0)} "
            f"| +{growth.get('health',0)} | +{growth.get('attack',0)} | +{growth.get('defense',0)} | +{growth.get('speed',0)} "
            f"| {gtotal} |"
        )

    lines.append("")
    return lines


def build_leveling_curve():
    lines = ["## 7. Hero Leveling Curve", ""]

    lines.append("### XP Thresholds (Key Levels)")
    lines.append("")
    lines.append("| Level | Total XP | Delta | Milestone |")
    lines.append("|-------|----------|-------|-----------|")

    milestones = {5: "Ability A unlocks", 15: "Passive A unlocks", 25: "Ability B unlocks", 40: "Passive B unlocks", 55: "Max level"}
    key_levels = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    for lvl in key_levels:
        xp = XP_THRESHOLDS[lvl - 1]
        delta = f"{xp - XP_THRESHOLDS[lvl - 2]:,}" if lvl > 1 else "—"
        ms = milestones.get(lvl, "")
        lines.append(f"| {lvl} | {xp:,} | {delta} | {ms} |")

    lines.append("")

    lines.append("### Ability/Passive Unlock Thresholds")
    lines.append("")
    lines.append("| Slot | Required Level | XP Required |")
    lines.append("|------|---------------|-------------|")
    for slot, lvl in sorted(ABILITY_UNLOCK_LEVELS.items(), key=lambda x: x[1]):
        lines.append(f"| {slot} | {lvl} | {XP_THRESHOLDS[lvl-1]:,} |")
    lines.append("")

    lines.append("### Regional XP per Combat")
    lines.append("")
    lines.append("| Region | Normal | Elite (1.5x) | Boss (2x) |")
    lines.append("|--------|--------|--------------|-----------|")
    for r in range(1, 8):
        base_xp = REGION_XP_BASE.get(r, 0)
        lines.append(f"| R{r}: {REGION_NAMES.get(r, '')} | {base_xp} | {int(base_xp * 1.5)} | {base_xp * 2} |")
    lines.append("")

    return lines


def build_abilities_table(abilities):
    lines = ["## 8. Hero Abilities (Full List)", ""]

    class_abs = [a for a in abilities if a.get("ability_type") in ("class_a", "class_b")]
    equip_abs = [a for a in abilities if a.get("ability_type") == "equipment"]
    other_abs = [a for a in abilities if a.get("ability_type") not in ("class_a", "class_b", "equipment")]

    lines.append("### Class Abilities")
    lines.append("")
    lines.append("| ID | Name | Class | Slot | Summary |")
    lines.append("|----|------|-------|------|---------|")

    for ab in sorted(class_abs, key=lambda a: (a.get("source_class_id", ""), a.get("ability_type", ""))):
        slot = ab.get("ability_type", "").replace("class_", "").upper()
        lines.append(f"| {ab['id']} | {ab.get('display_name', '')} | {ab.get('source_class_id', '')} | {slot} | {get_ability_summary(ab)} |")

    lines.append("")

    if equip_abs:
        lines.append("### Equipment Abilities")
        lines.append("")
        lines.append("| ID | Name | Category | Summary |")
        lines.append("|----|------|----------|---------|")

        for ab in sorted(equip_abs, key=lambda a: a["id"]):
            # Derive region from prefix
            prefix = ab["id"].split("_")[0]
            region_map = {"gw": "R1", "fm": "R2", "ss": "R3", "ah": "R4", "se": "R5", "nc": "R6", "fr": "R7"}
            region = region_map.get(prefix, "?")
            lines.append(f"| {ab['id']} | {ab.get('display_name', '')} | {region} | {get_ability_summary(ab)} |")

        lines.append("")

    if other_abs:
        lines.append("### Other Abilities")
        lines.append("")
        lines.append("| ID | Name | Type | Summary |")
        lines.append("|----|------|------|---------|")

        for ab in sorted(other_abs, key=lambda a: a["id"]):
            lines.append(f"| {ab['id']} | {ab.get('display_name', '')} | {ab.get('ability_type', '')} | {get_ability_summary(ab)} |")

        lines.append("")

    return lines


def build_passives_table(passives):
    lines = ["## 9. Passives (Full List)", ""]

    class_passives = [p for p in passives if p.get("category") == "class"]
    racial_passives = [p for p in passives if p.get("category") == "racial"]
    other_passives = [p for p in passives if p.get("category") not in ("class", "racial")]

    lines.append("### Class Passives")
    lines.append("")
    lines.append("| ID | Name | Class | Type | Summary |")
    lines.append("|----|------|-------|------|---------|")

    for p in sorted(class_passives, key=lambda x: (x.get("source_class_id", ""), x["id"])):
        lines.append(f"| {p['id']} | {p.get('display_name', '')} | {p.get('source_class_id', '')} | {p.get('passive_type', '')} | {get_passive_summary(p)} |")

    lines.append("")

    lines.append("### Racial Passives")
    lines.append("")
    lines.append("| ID | Name | Type | Summary |")
    lines.append("|----|------|------|---------|")

    for p in sorted(racial_passives, key=lambda x: x["id"]):
        lines.append(f"| {p['id']} | {p.get('display_name', '')} | {p.get('passive_type', '')} | {get_passive_summary(p)} |")

    lines.append("")

    if other_passives:
        lines.append("### Regional / Equipment Passives")
        lines.append("")
        lines.append("| ID | Name | Type | Summary |")
        lines.append("|----|------|------|---------|")

        for p in sorted(other_passives, key=lambda x: x["id"]):
            lines.append(f"| {p['id']} | {p.get('display_name', '')} | {p.get('passive_type', '')} | {get_passive_summary(p)} |")

        lines.append("")

    return lines


def build_stat_synergies(classes):
    lines = ["## 10. New Combat Stat Synergies", ""]
    lines.append("*Equipment-only stats added in Phase 1 of the stat expansion.*")
    lines.append("")
    lines.append("| Stat | Cap | Source | Best Archetypes |")
    lines.append("|------|-----|--------|-----------------|")
    lines.append("| crit_chance | 50% | Equipment | DPS multi-hitters, weapon-focused classes |")
    lines.append("| evasion | 50% | Equipment | Light armor classes, speed-focused builds |")
    lines.append("| resist | soft-cap | Equipment | Frontliners vs fire/dark/void abilities |")
    lines.append("| thorns | flat | Equipment | Tanks with taunt, high-DEF builds |")
    lines.append("| armor_penetration | flat | Equipment | Physical DPS, boss-killer builds |")
    lines.append("| life_steal | 50% (T3+) | Equipment | Sustained melee damage dealers |")
    lines.append("")
    return lines


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    classes = load_all_classes()
    races = load_all_races()
    abilities = load_all_abilities()
    passives = load_all_passives()

    lines = []
    lines.extend(build_header(classes, races, abilities, passives))
    lines.extend(build_region_unlock_map(classes, races))
    lines.extend(build_archetype_overview(classes))
    lines.extend(build_class_definitions(classes, abilities, passives))
    lines.extend(build_race_definitions(races, passives))
    lines.extend(build_stat_modifier_comparison(races))
    lines.extend(build_class_stat_comparison(classes))
    lines.extend(build_leveling_curve())
    lines.extend(build_abilities_table(abilities))
    lines.extend(build_passives_table(passives))
    lines.extend(build_stat_synergies(classes))

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    # Summary
    class_abs = [a for a in abilities if a.get("ability_type") in ("class_a", "class_b")]
    equip_abs = [a for a in abilities if a.get("ability_type") == "equipment"]
    class_passives = [p for p in passives if p.get("category") == "class"]
    racial_passives = [p for p in passives if p.get("category") == "racial"]

    print(f"\n{'='*60}")
    print(f"  HERO REFERENCE GENERATED")
    print(f"{'='*60}")
    print(f"  Output: {OUTPUT}")
    print(f"  Classes: {len(classes)}")
    print(f"  Races: {len(races)}")
    print(f"  Class Abilities: {len(class_abs)}")
    print(f"  Equipment Abilities: {len(equip_abs)}")
    print(f"  Class Passives: {len(class_passives)}")
    print(f"  Racial Passives: {len(racial_passives)}")
    print(f"  Other Passives: {len(passives) - len(class_passives) - len(racial_passives)}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
