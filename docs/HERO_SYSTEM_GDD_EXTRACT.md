# Hero System GDD Extract

Extracted from: `Shops_And_Shadows_MASTER_GDD.md`
Generated: 2026-01-10

---

## 1. Hero Definition (Data-Driven)

### Hero Schema (GDD Section 14)
```json
{
  "id": "hero_01",
  "name": "Elin",
  "race": "Elf",
  "class": "Striker",
  "stats": {
    "hp": 100, "mana": 30, "atk": 12, "def": 6, "spd": 5,
    "res": { "physical": 0, "magic": 0, "corruption": 0 }
  },
  "passives": ["keen_sight"],
  "abilities": ["twin_strike", "shadowstep"],
  "inventory": ["starter_dagger"],
  "backpack_size": 3,
  "legacy": false
}
```

### Key Fields
- `id` - Unique hero identifier
- `name` - Display name
- `race` - Race ID (affects racial trait)
- `class` - Class ID (determines abilities, stats)
- `stats` - Base combat stats (hp, mana, atk, def, spd, res)
- `passives` - Array of passive ability IDs
- `abilities` - Array of active ability IDs (from class)
- `inventory` - Equipped items
- `backpack_size` - Consumable slot count
- `legacy` - Whether hero is a legacy worker

---

## 2. Hero Acquisition / Recruitment

### Early Game (Tutorial) - GDD 8.1
- Heroes start with **no classes** initially
- Only Basic Attack available, no abilities
- Tutorial dungeon teaches combat fundamentals

### After First Dungeon - GDD 8.1
- Training Hall sells starter **Class Books**
- Player can assign classes via books

### Recruitment Rules
- Heroes are recruited at the **Inn** facility
- Recruitment costs **gold** (run_gold)
- Region 1 starter classes: **Defender, Warden, Striker**
- New races/classes unlock by progressing to new regions

### Class Assignment - GDD 8.1
- **Class Books** appear in shop once their region unlocks them
- Class Books can **overwrite existing classes** with no penalty
- Class assignment costs gold (possibly some resources)
- Hero retains: **race, gear, and level**

---

## 3. Hero Storage (Roster vs Party)

### Roster (owned_heroes)
- All recruited heroes stored in persistent roster
- Roster persists across sessions (saved)
- Heroes not in party may remain in town roles (Legacy system)

### Party (selected_party)
- Subset of roster selected for dungeon runs
- **Party size fixed by progression** (GDD 36.4)
- Only selected party enters dungeon
- Maximum party size: 2 (MVP), scales with progression

### Data Locations
- `GameContext.owned_heroes` - Full roster array
- `GameContext.selected_party` - Active party hero IDs
- Saved in `save_game()` / loaded in `load_game()`

---

## 4. Combat Spawning

### Party Rules - GDD 36.4
- Only selected party enters dungeon
- Heroes not in party may remain in town roles (Legacy system)

### Equipment Rules - GDD 36.4
Each hero must have:
- Weapon
- Armor
- Accessories
- Health Flask (permanent)

### Spawning Requirements
- Party must be selected before dungeon entry
- Weapon ability is previewed before entry
- Consumables occupy inventory slots

### In-Dungeon - GDD 36.6
- Combat actions allowed
- Movement allowed
- Ability usage allowed
- Consumable usage allowed
- **No equipment changes** in dungeon
- **No class changes** in dungeon

---

## 5. Limits & Restrictions

### Party Size Limits
| Progression | Max Party Size |
|-------------|----------------|
| MVP/Early   | 2              |
| Post-Region 3 | 3 (implied) |

### Duplicate Classes
- **No explicit restriction** on duplicate classes in party
- Multiple heroes can have the same class

### Class Availability by Region - GDD 8.4
| Region | Classes Unlocked |
|--------|------------------|
| Region 1 | Defender, Warden, Striker (3 starters) |
| Region 2 | Druid, Fungal Berserker |
| Region 3 | Tidechaser, Stormcaller |
| Region 4 | Pyrewarden, Ashblade |
| Region 5 | Prism Sentinel, Prism Lancer |
| Region 6 | Dark Channeler, Lich |
| Region 7 | Voidwalker, Void Herald |

### Race Availability by Region - GDD 8.2
| Region | Races |
|--------|-------|
| Region 1 | Human, Elf, Dwarf (starters) |
| Region 2 | Mossfolk |
| Region 3 | Tidelings |
| Region 4 | Dragonkin (locked) |
| Region 5 | Crystalborn (locked) |
| Region 6 | Undead |
| Region 7 | Voidwalkers (locked) |

---

## 6. Hero Death & Persistence

### Death Rules - GDD 36.7
- Death is **permanent**
- Hero recorded in **Book of the Dead**
- Equipment dropped unless insured
- **No revival**

### Legacy Heroes - GDD 5.5
- Heroes that become **Legacy** can be assigned as workers
- At facilities: Improve production quality, reduce crafting time
- At Guard Yard: Improve Town Defense success
- Legacy heroes can be **recalled** for adventuring (temporarily leave job)

---

## 7. Implementation File References

| Component | Expected File Location |
|-----------|------------------------|
| Hero runtime data | `GameContext.owned_heroes` |
| Party selection | `GameContext.selected_party` |
| Class definitions | `Data/Classes/*.json` |
| Race definitions | `Data/Races/*.json` (if exists) |
| Class books | `Data/Items/Templates/book_*.json` |
| Inn recruitment UI | `TownScene._build_inn_ui()` |
| Combat spawning | `CombatController` or `DungeonScene` |

---

## 8. Summary Rules

1. **Heroes are data-driven** - JSON schema with race, class, stats, abilities
2. **Recruited at Inn** - Costs run_gold
3. **Classes assigned via books** - Can overwrite, hero retains race/gear/level
4. **Roster stored persistently** - `owned_heroes` array
5. **Party selected for runs** - `selected_party` subset (max 2 MVP)
6. **Equipment required** - Weapon, Armor, Accessories, Flask
7. **Death is permanent** - Recorded in Book of the Dead
8. **No equipment/class changes in dungeon**
9. **Region 1 classes**: Defender, Warden, Striker
10. **Region 1 races**: Human, Elf, Dwarf

---

*Extracted from: Shops_And_Shadows_MASTER_GDD.md v2.0*
