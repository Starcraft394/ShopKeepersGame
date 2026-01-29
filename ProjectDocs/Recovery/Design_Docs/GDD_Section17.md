17. MONSTER FAMILY FRAMEWORK

This section defines how enemies are organized, scaled, and expressed in Shops & Shadows. Monsters are grouped into families that share visual identity, behavior, and (from Region 2 onward) a family-wide passive trait.

Complexity is deliberately ramped:

Region 1: No family passives, no active abilities. Basic attacks only.

Regions 2–3: Family passives are introduced. Monsters still only basic-attack + passive triggers.

Regions 4–7: Monsters may gain one active ability with a simple cooldown logic, in addition to their family passive.

This lets players learn safely early, and then adds depth gradually.

17.1 Design Goals

Clarity: Players should be able to glance at a monster and get a basic idea of what it does.

Thematic Consistency: Monster families should reinforce region themes (forest, fungus, tide, desert, etc.).

Scalable Complexity: Early regions stay simple. Later regions add family passives and abilities.

Data-Driven Implementation: Families and monsters should be easy to describe in JSON / data for Godot/Claude.

Reward Clarity: Each family ties to specific resource types and crafting loops.

17.2 Monster Family Structure

A Monster Family is a group like “Forest Wolves” or “Sporekin” that defines:

Visual theme

Preferred combat role(s)

Family-wide passive (Region 2+)

Default drops

Typical AI behavior

Individual monsters in that family vary in stats and small behaviors but stay recognizably related.

17.2.1 MonsterFamily Data Fields (Design-Level)

For each family we define:

family_id: unique string, e.g. "forest_wolves"

display_name: e.g. "Forest Wolves"

region_id: where they first appear (e.g. "forest_haven")

roles: list of typical roles (Tank / Striker / Support / Artillery / Disruptor)

family_passive_id: null for Region 1; a passive from a shared list for Region 2+

behavior_tags: e.g. ["aggressive","pack","flanker"]

base_stat_profile: rough template for HP/ATK/DEF/SPD/MAG/RES

primary_drops: resource categories frequently dropped

secondary_drops: rarer resource types

notes: any designer notes (synergies, cautions, etc.)

17.3 Monster Roles & AI Types

Each monster in a family will lean toward one of a few roles:

Tank: High HP/DEF, slow, takes hits.

Striker: High ATK/SPD, fragile, targets backliners when possible.

Support: Applies buffs/debuffs; lower damage.

Artillery: Ranged damage dealer; lower DEF; prefers back row.

Disruptor: Special targeting, pushes/pulls, or position manipulation.

AI Types (simple):

Frontliner AI: Always target nearest enemy in front rows.

Flanker AI: Prefer lowest-DEF or lowest-HP targets.

Ranged AI: Stay on back tiles if possible, target low-HP or random.

Support AI: Prefer buffing allies or debuffing the most dangerous hero.

Early regions use mostly Frontliner + basic Striker, later regions introduce more roles.

17.4 Early vs Late Complexity
Region 1 — Training Region

No family passives.

No active abilities.

Monsters:

Have basic attack damage, HP, DEF, SPD.

May have slight stat variance to feel distinct (e.g. a tougher wolf vs a quicker one).

This region teaches:

Targeting

Positioning

Item usage

Raw stats vs synergy

Regions 2–3 — Family Passives Only

Every family in Regions 2+ has one universal passive, e.g.:

On-death effects

On-hit effects

Simple tile-responses

Slight synergy with dungeon environment

Still no active abilities.

This adds:

“Kill order” decisions

Awareness of family quirks

Small additional risk/reward layers

Regions 4–7 — Family Passives + 1 Active Ability

Monsters may have one active ability in addition to their basic attack and family passive.

Ability logic is simple:

Ability has a cooldown in turns, e.g. ability_cooldown_turns = 3.

On the monster’s turn:

If ability cooldown is 0 and a simple condition is met (e.g. “any hero in range” or “self HP < 50%”), monster casts the ability, then cooldown is reset.

Otherwise it performs a basic attack.

No complex decision trees; ability use is predictable and data-driven.

17.5 Family Passives (Region 2+ Only)

Family passives are always-on rules that apply to every monster in that family. They are introduced starting in Region 2.

Examples by Region

Region 2 — The Fungalmire

Sporekin (Fungal Shamblers, Myconids)
Passive: Sporeburst

When killed, inflict a small poison or regen-drain effect on adjacent heroes.

Rotcap Brutes
Passive: Rot-Soaked Hide

Takes reduced physical damage, but increased fire damage.

Region 3 — The Sunken Strand

Tidewalkers / Amphibious Beasts
Passive: Amphibious

Gains bonus SPD or Dodge on wet tiles.

Drowned Spirits
Passive: Drowned Echo

On death, they leave a “Lingering Fear” debuff on the attacker (small morale/accuracy penalty).

Region 4 and beyond get more extreme passives (fire retaliation, lifedrain, shield on first hit, etc.), tuned later.

17.6 Active Ability Basics (Region 4+)

Monsters in Regions 4–7 can have one active ability, implemented as:

ability_id: unique identifier

ability_type: ["aoe","single_target","self_buff","debuff","tile_effect"]

cooldown_turns: turns between casts (e.g. 3–5)

initial_delay_turns: optional; skip first N turns before first use

trigger_condition: simple condition like:

"always_when_ready"

"self_hp_below_50_percent"

"target_in_melee_range"

effects: list of stat changes, damage, tile changes, etc.

AI rule (simple):

If cooldown == 0 AND trigger_condition is true AND a valid target exists → cast ability.
Else → basic attack.

This respects your wish for “auto-attacks first, simple timers,” and gives a clear path for Claude to implement in Godot.

17.7 Monster Tiers & Scaling

To support roguelite progression, each monster can appear in tiers:

Normal: Baseline stats.

Elite: ~+30–50% HP/ATK, better SPD/RES, maybe an extra minor tag.

Champion: Rare elite variant with boosted passive or extra small effect.

Boss: Unique monster, defined separately but still referencing a family.

Scaling factors:

Region scaling modifier

Floor depth scaling

Difficulty mode modifiers

Town/World boons (player buffs) are separate and do not change monsters; they change heroes.

17.8 Region → Monster Family Mapping (High-Level)

This reuses what we did in Section 16 and groups them as families:

Region 1 — Forest Haven

No passives, no abilities.

Forest Wolves (Striker family)

Rootkin Sprites (Light support / nuisance)

Moss Trolls (Tank family)

Bandit Rabble (Human enemies, basic strikers)

Region 2 — The Fungalmire

First region with family passives.

Sporekin Shamblers (Tank/Striker, Sporeburst)

Rotcap Myconids (Striker, Rot-Soaked Hide)

Bloom Giants (Tank, slow, high HP, fungus-themed)

Region 3 — The Sunken Strand

Passives + tile interactions (still no active abilities yet).

Tidewalkers (Striker, Amphibious)

Crustacean Brutes (Tank, physical armor)

Drowned Spirits (Support/Disruptor, Drowned Echo)

Region 4 — Ashen Horizons

Passives + 1 ability.

Ember Drakes (Artillery, fire breath)

Lava Golems (Tank, fire retaliate)

Ash Wraiths (Support caster, fire/curse)

Region 5 — Starfall Expanse

Arcane/Weird monsters, passives + ability.

Crystal Wraiths

Reality Phantoms

Starfall Beasts

Region 6 — The Necropolis

Undead families, heavy passives + ability.

Bone Legionnaires (Reanimate chance)

Ghoul Stalkers (Bleed on hit)

Wraith Choirs (Magic resist + terror)

Gravefiends

Region 7 — Final Realm

Corruption avatars and mixed-corruption monsters.
Treated as boss/elite heavy; ability use more frequent but still capped to 1 active per creature.

17.9 Monster Drops & Resource Families

Each monster family is tied to specific drop types:

Beasts (wolves, boars, crustaceans): hides, meat, monster parts → Leatherworker, Chef.

Fungi/Myconids: spores, fungal caps → Alchemist, Chef, field crafting.

Constructs/Elementals: ore fragments, cores → Blacksmith, late-game crafting.

Undead: soul shards, bone dust → Necropolis facilities, Lich/Dark Channeler content.

Arcane Beings: crystal shards, stardust → Starfall region crafting.

Drop logic will be formalized in Section 18, but this framework ensures monster → resource → facility clarity.

17.10 Data Schema Hint (for Godot/Claude)

A single monster entry might look like this at data level:

{
  "monster_id": "sporekin_shambler_t1",
  "family_id": "sporekin",
  "region_id": "fungalmire",
  "tier": "normal",
  "role": "tank",
  "base_stats": {
    "hp": 40,
    "atk": 6,
    "def": 5,
    "spd": 3,
    "mag": 2,
    "res": 3
  },
  "behavior_tags": ["frontliner"],
  "family_passive_id": "sporeburst",   // null in Region 1
  "active_ability_id": null,           // only set in Region 4+
  "drops": {
    "primary": ["fungal_cap", "spore_sac"],
    "secondary": ["rare_spore_bloom"]
  }
}


And a family:

{
  "family_id": "sporekin",
  "display_name": "Sporekin",
  "region_id": "fungalmire",
  "roles": ["tank", "striker"],
  "family_passive_id": "sporeburst",
  "primary_drops": ["fungal_cap"],
  "secondary_drops": ["rare_spore_bloom"],
  "notes": "Explodes in a small spore cloud on death."
}

17.11 Future Expansion Hooks

Additional monster variants per family (T2/T3)

Elite-only passives (e.g., “Elite Sporekin also apply slow”)

Region-events that temporarily change family passives (e.g., blood moon variants)

Late-game corruption-touched versions with modified stats/passives