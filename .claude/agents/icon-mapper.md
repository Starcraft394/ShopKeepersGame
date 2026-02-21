# Icon Mapper Agent

## Purpose
Resolve art pack letter codes (A, AA, BM, etc.) to exact file paths for item icon assignment. Eliminates repeated lookups of `Docs/item_icon_reference.html`.

## When to Use
- When assigning icon_path values to item JSON files using pack references like "B#28" or "BM#7"
- When verifying which file a pack index resolves to
- When checking for index conflicts (two items sharing the same pack+index)

## Pack Letter → Folder Mapping

### Single Letters (A–Z)
| Code | Pack Name | Folder |
|------|-----------|--------|
| A | Swords | `Assets/_ArtPacks/Swords/PNG/Transperent/` |
| B | Daggers | `Assets/_ArtPacks/Daggers/PNG/Transperent/` |
| C | Axes | `Assets/_ArtPacks/Axes/PNG/Transperent/` |
| D | Bows | `Assets/_ArtPacks/Bows/PNG/Transperent/` |
| E | Maces | `Assets/_ArtPacks/Maces/PNG/Transperent/` |
| F | Spears | `Assets/_ArtPacks/Spears/PNG/Transperent/` |
| G | Helmets | `Assets/_ArtPacks/Helmets/PNG/Transperent/` |
| H | Cuirass | `Assets/_ArtPacks/Cuirass/PNG/Transperent/` |
| I | Trousers | `Assets/_ArtPacks/Trousers/PNG/Transperent/` |
| J | Sabatons | `Assets/_ArtPacks/Sabatons/PNG/Transperent/` |
| K | Bracers | `Assets/_ArtPacks/Bracers/PNG/Transperent/` |
| L | Rings | `Assets/_ArtPacks/Rings/PNG/Transperent/` |
| M | MagicArtifacts | `Assets/_ArtPacks/MagicArtifacts/PNG/Transperent/` |
| N | MagicBooks | `Assets/_ArtPacks/MagicBooks/PNG/Transperent/` |
| O | Runes | `Assets/_ArtPacks/Runes/PNG/Transperent/` |
| P | Herbs | `Assets/_ArtPacks/Herbs/PNG/Transperent/` |
| Q | Mushrooms | `Assets/_ArtPacks/Mushrooms/PNG/Transperent/` |
| R | Berries | `Assets/_ArtPacks/Berries/PNG/Transperent/` |
| S | FruitsVegetables | `Assets/_ArtPacks/FruitsVegetables/PNG/Transperent/` |
| T | Food | `Assets/_ArtPacks/Food/PNG/Transperent/` |
| U | MeatSkins | `Assets/_ArtPacks/MeatSkins/PNG/Transperent/` |
| V | CraftingMaterials | `Assets/_ArtPacks/CraftingMaterials/PNG/Transperent/` |
| W | CraftingMaterials2 | `Assets/_ArtPacks/CraftingMaterials2/PNG/Transperent/` |
| X | AlchemyItems | `Assets/_ArtPacks/AlchemyItems/PNG/Transperent/` |
| Y | Potions | `Assets/_ArtPacks/Potions/PNG/Transperent/` |
| Z | Gems | `Assets/_ArtPacks/Gems/PNG/Transperent/` |

### Double Letters (AA–BS)
| Code | Pack Name | Folder |
|------|-----------|--------|
| AA | Loot_Chaos | `Assets/_ArtPacks/Loot_Chaos/PNG/Transperent/` |
| AB | Loot_Demon | `Assets/_ArtPacks/Loot_Demon/PNG/Transperent/` |
| AC | Loot_Goblin | `Assets/_ArtPacks/Loot_Goblin/PNG/Transperent/` |
| AD | Loot_Undead | `Assets/_ArtPacks/Loot_Undead/PNG/Transperent/` |
| AE | LootDrops | `Assets/_ArtPacks/LootDrops/PNG/Transperent/` |
| AF | Treasure | `Assets/_ArtPacks/Treasure/PNG/Transperent/` |
| AG | BuffIcons | `Assets/_ArtPacks/BuffIcons/PNG/` |
| AH | BuffSkills | `Assets/_ArtPacks/BuffSkills/PNG/` |
| AI | Sigils | `Assets/_ArtPacks/Sigils/PNG/Transperent/` |
| AJ | Curses | `Assets/_ArtPacks/Curses/PNG/Transperent/` |
| BB | Farming | `Assets/_ArtPacks/Farming/PNG/Transperent/` |
| BD | Mining | `Assets/_ArtPacks/Mining/PNG/Transperent/` |
| BM | Ingredients | `Assets/_ArtPacks/Ingredients/PNG/Transperent/` |
| BN | ShieldsAmulets | `Assets/_ArtPacks/ShieldsAmulets/PNG/Transperent/` |
| BO | RPGThings | `Assets/_ArtPacks/RPGThings/PNG/Transperent/` |

## File Naming Conventions

### Standard packs (most packs)
Index maps directly to filename: `#{N}` → `Icon{N}.png`
- Example: B#28 → `Icon28.png`
- Full path: `res://Assets/_ArtPacks/Daggers/PNG/Transperent/Icon28.png`

### Named-file packs (customFiles)
Index maps to position in the ordered customFiles array (1-indexed):

**AF (Treasure)** — customFiles:
```
1:bag1  2:bag2  3:bag3  4:black_pearl  5:Chest1  6:Chest2  7:Chest3
8:Chest4  9:coin1  10:coins2  11:coins3  12:coins4  13:coins5
14:crown1  15:crown2  16:crown3  17:Gold_bar  18:Gold_bar2
19:Gold_ring  20:jewelry1  21:jewelry2  22:necklace1  23:necklace2
24:necklace3  25:ring1  26:ring2  27:ring3  28:scroll  29:stone1
30:stone2  31:stone3  32:stone4  33:stone5  34:stone6  35:white_pearl
```

**BM (Ingredients)** — customFiles:
```
1:berrys1  2:berrys2  3:bone  4:butterfly_wing1  5:butterfly_wing2
6:cotton  7:crystal1  8:crystal2  9:eggs  10:feather
11:flower1  12:flower2  13:flower3  14:flower4  15:flower5
16:flower6  17:flower7  18:flower8  19:flower9  20:flower10
21:grass  22:leaf1  23:leaf2  24:leaf3  25:leaf4
26:leaf5  27:leaf6  28:leaf7  29:leaf8  30:leaf9
31:leaf10  32:mushroom1  33:mushroom2  34:mushroom3  35:mushroom4
36:mushroom5  37:pod  38:scales  39:wood1  40:wood2
```

**BO (RPGThings)** — customFiles:
```
1:icons_30_01  2:icons_30_02  ...  83:icons_30_83  ...  100:icons_30_100
```
Pattern: `#{N}` → `icons_30_{NN}.png` (zero-padded to 2 digits for 01-99, 3 digits for 100)

## Resolution Algorithm

Given a reference like `BM#35`:
1. Look up pack code `BM` → Ingredients
2. Check if pack has customFiles → YES
3. Index 35 in customFiles → `mushroom4`
4. Append `.png` → `mushroom4.png`
5. Full path: `res://Assets/_ArtPacks/Ingredients/PNG/Transperent/mushroom4.png`

Given a reference like `G#20`:
1. Look up pack code `G` → Helmets
2. Check if pack has customFiles → NO (standard)
3. Index 20 → `Icon20.png`
4. Full path: `res://Assets/_ArtPacks/Helmets/PNG/Transperent/Icon20.png`
