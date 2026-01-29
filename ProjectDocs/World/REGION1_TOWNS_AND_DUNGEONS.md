# Region 1: Forest Haven — Towns & Dungeons

## Overview

Region 1 (Forest Haven) is the starter region. It contains two towns that introduce the player to core gameplay systems.

---

## Towns

### Town A: Greenroot (Starter Town)

| Field | Value |
|-------|-------|
| town_id | `town_greenroot` |
| display_name | Greenroot |
| region_id | `region_1` |
| dungeon_id | `dungeon_greenroot` |

**Theme:** A quiet forest settlement nestled among ancient oaks. The first safe haven for new shopkeepers. Warm lantern-lit interiors, overgrown paths, and the smell of fresh timber.

**Facilities:** All 8 canonical base facilities (no suffix):
- blacksmith, leatherworker, woodsman, chef, alchemist, training_hall, storage, housing

---

### Town B: Timberfall (Starter Class Town)

| Field | Value |
|-------|-------|
| town_id | `town_timberfall` |
| display_name | Timberfall |
| region_id | `region_1` |
| dungeon_id | `dungeon_timberfall` |

**Theme:** A logging outpost at the forest's edge where woodcutters and rangers gather. More rugged than Greenroot, with sawdust-covered streets and the constant ring of axes.

**Facilities:** All 8 canonical facilities with `_tf` suffix:
- blacksmith_tf, leatherworker_tf, woodsman_tf, chef_tf, alchemist_tf, training_hall_tf, storage_tf, housing_tf

---

## Dungeons

### Dungeon: Greenroot Woods

| Field | Value |
|-------|-------|
| dungeon_id | `dungeon_greenroot` |
| display_name | Greenroot Woods |
| region_id | `region_1` |
| town_id | `town_greenroot` |
| floor_count | 4 |
| boss_id | `thorn_ent` |

**Floor Themes:**

1. **Floor 1 — Overgrown Trail**
   Tangled roots and mossy stones. Goblins and wolves patrol the winding paths.

2. **Floor 2 — Hollow Clearing**
   A sunlit glade invaded by bandits and giant spiders. Resource nodes appear here.

3. **Floor 3 — Darkwood Thicket**
   Dense canopy blocks the sun. Slimes ooze from rotting logs. Elite encounters possible.

4. **Floor 4 — The Heartwood**
   Ancient trees twisted by corruption. The Thorn Ent guards the forest's core.

---

### Dungeon: Timberfall Depths

| Field | Value |
|-------|-------|
| dungeon_id | `dungeon_timberfall` |
| display_name | Timberfall Depths |
| region_id | `region_1` |
| town_id | `town_timberfall` |
| floor_count | 4 |
| boss_id | `` |

> **TODO:** Boss not created yet. Assign boss_id when a Timberfall-specific boss is added to Data/Monsters.

**Floor Themes:**

1. **Floor 1 — Abandoned Lumber Camp**
   Collapsed scaffolding and rusted saws. Bandits have claimed the ruins.

2. **Floor 2 — Fungal Hollows**
   Damp tunnels beneath the logging site. Slimes and spore-touched creatures lurk.

3. **Floor 3 — The Sunken Mill**
   A flooded sawmill overrun by corrupted wildlife. Watch for ambushes.

4. **Floor 4 — The Sawblade Pit**
   Industrial machinery fused with corruption. The dungeon boss awaits.
