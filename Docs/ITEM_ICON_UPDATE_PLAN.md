# Item Icon Update Plan

## Validated Packs
| Pack | Folder | Indices Used |
|------|--------|-------------|
| AA (Loot_Chaos) | `Assets/_ArtPacks/Loot_Chaos/PNG/Transperent/` | 4, 6, 14, 18, 22, 36, 40 |
| A (Swords) | `Assets/_ArtPacks/Swords/PNG/Transperent/` | 38 |
| AC (Loot_Goblin) | `Assets/_ArtPacks/Loot_Goblin/PNG/Transperent/` | 23, 26 |
| AD (Loot_Undead) | `Assets/_ArtPacks/Loot_Undead/PNG/Transperent/` | 2, 19, 30 |
| AE (LootDrops) | `Assets/_ArtPacks/LootDrops/PNG/Transperent/` | 1, 5, 26, 38 |
| AF (Treasure) | `Assets/_ArtPacks/Treasure/PNG/Transperent/` | 1(bag1), 4(black_pearl) |
| B (Daggers) | `Assets/_ArtPacks/Daggers/PNG/Transperent/` | 22, 28, 45 |
| BD (Mining) | `Assets/_ArtPacks/Mining/PNG/Transperent/` | 2 |
| BM (Ingredients) | `Assets/_ArtPacks/Ingredients/PNG/Transperent/` | 7(crystal1), 8(crystal2), 35(mushroom4), 36(mushroom5) |
| BN (ShieldsAmulets) | `Assets/_ArtPacks/ShieldsAmulets/PNG/Transperent/` | 27 |
| BO (RPGThings) | `Assets/_ArtPacks/RPGThings/PNG/Transperent/` | 83(icons_30_83) |
| D (Bows) | `Assets/_ArtPacks/Bows/PNG/Transperent/` | 21, 24, 36 |
| G (Helmets) | `Assets/_ArtPacks/Helmets/PNG/Transperent/` | 17, 20, 25, 42 |
| H (Cuirass) | `Assets/_ArtPacks/Cuirass/PNG/Transperent/` | 2, 5, 7, 18, 23 |
| I (Trousers) | `Assets/_ArtPacks/Trousers/PNG/Transperent/` | 11 |
| J (Sabatons) | `Assets/_ArtPacks/Sabatons/PNG/Transperent/` | 20 |
| L (Rings) | `Assets/_ArtPacks/Rings/PNG/Transperent/` | 4, 28 |
| M (MagicArtifacts) | `Assets/_ArtPacks/MagicArtifacts/PNG/Transperent/` | 1, 2, 4, 8, 29, 37 |
| Q (Mushrooms) | `Assets/_ArtPacks/Mushrooms/PNG/Transperent/` | 7, 40, 47 |
| T (Food) | `Assets/_ArtPacks/Food/PNG/Transperent/` | 29 |
| U (MeatSkins) | `Assets/_ArtPacks/MeatSkins/PNG/Transperent/` | 48 |
| V (CraftingMaterials) | `Assets/_ArtPacks/CraftingMaterials/PNG/Transperent/` | 42 |
| W (CraftingMaterials2) | `Assets/_ArtPacks/CraftingMaterials2/PNG/Transperent/` | 6, 27 |

## Batch Log

### Pack AA — Loot_Chaos (8 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| honey | Honey | AA#4 | Icon4.png | None (direct) |
| aged_cheese | Aged Cheese | AA#6 | Icon6.png | Yellow Tint |
| magma_core | Magma Core | AA#14 | Icon14.png | Red |
| boss_trophy_greenwood | Elderwood Heart | AA#18 | Icon18.png | Green |
| volcanic_glass | Volcanic Glass | AA#22 | Icon22.png | Purple with Red |
| ah_scorched_fang | Scorched Fang | AA#36 | Icon36.png | None (direct) |
| boss_trophy_fungalmire | Mycelium Heart | AA#40 | Icon40.png | None (direct) |
| ah_sulfite_gland | Sulfite Gland | AA#14 | Icon14.png | Yellow Tint |

**CONFLICT**: AA#14 used by both `magma_core` (Red) and `ah_sulfite_gland` (Yellow Tint).
Both get base icon now. After recolour script produces separate outputs, update each item's icon_path to its recoloured target.

### Pack AA — Recolour Specs
```
SOURCE: Assets/_ArtPacks/Loot_Chaos/PNG/Transperent/
OUTPUT: Assets/_Generated/Recolours/AA/

AA#6  -> aged_cheese_yellow.png     | Yellow Tint
AA#14 -> magma_core_red.png         | Red (all colours -> red shift)
AA#14 -> sulfite_gland_yellow.png   | Yellow Tint
AA#18 -> elderwood_heart_green.png  | Green
AA#22 -> volcanic_glass_purple_red.png | Purple with Red
```

---

### Pack A — Swords (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| gw_thornguard_sword | Thornguard Sword T4 | A#38 | Icon38.png | None (direct) |

---

### Pack AC — Loot_Goblin (2 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| gw_ironbark_maul | Ironbark Maul T3 | AC#26 | Icon26.png | None (direct) |
| gw_ironbark_shield | Ironbark Shield T3 | AC#23 | Icon23.png | None (direct) |

---

### Pack AD — Loot_Undead (3 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| ancient_bone | Ancient Bone | AD#2 | Icon2.png | None (direct) |
| gw_emerald_ring | Emerald Ring T4 | AD#19 | Icon19.png | None (direct) |
| gw_emerald_pendant | Emerald Pendant T4 | AD#30 | Icon30.png | None (direct) |

---

### Pack AE — LootDrops (5 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| phoenix_ash | Phoenix Ash | AE#1 | Icon1.png | None (direct) |
| boss_trophy_sunken_strand | Leviathan Scale | AE#5 | Icon5.png | None (direct) |
| ember_dust | Ember Dust | AE#26 | Icon26.png | None (direct) |
| wyvern_scale | Wyvern Scale | AE#38 | Icon38.png | None (direct) |
| ah_drake_scale | Drake Scale | AE#38 | Icon38.png | Red Recolour |

**CONFLICT**: AE#38 used by both `wyvern_scale` (direct) and `ah_drake_scale` (Red recolour).
Both get base icon now. After recolour script produces separate outputs, update `ah_drake_scale` icon_path to its recoloured target.

### Pack AE — Recolour Specs
```
SOURCE: Assets/_ArtPacks/LootDrops/PNG/Transperent/
OUTPUT: Assets/_Generated/Recolours/AE/

AE#38 -> drake_scale_red.png | Red (all colours -> red shift)
```

---

### Pack AF — Treasure (2 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| tidal_pearl | Tidal Pearl | AF#4 | black_pearl.png | None (direct) |
| cursed_dust | Cursed Dust | AF#1 | bag1.png | Yellow → Purple |

**RESOLVED**: `cursed_dust` overwritten from AA#22 → AF#1 (bag1.png) per user decision. Needs yellow-to-purple recolour.

### Pack AF — Recolour Specs
```
SOURCE: Assets/_ArtPacks/Treasure/PNG/Transperent/
OUTPUT: Assets/_Generated/Recolours/AF/

AF#1 -> cursed_dust_purple.png | Yellow → Purple
```

---

### Pack B — Daggers (3 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| gw_thorn_dagger | Thorn Dagger T2 | B#28 | Icon28.png | None (direct) |
| gw_briar_fang | Briar Fang T3 | B#22 | Icon22.png | None (direct) |
| gw_verdant_blade | Verdant Blade T3 | B#45 | Icon45.png | None (direct) |

---

### Pack BD — Mining (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| bone_charm | Bone Charm T1 | BD#2 | Icon2.png | None (direct) |

---

### Pack BM — Ingredients (4 items, named files)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| stormglass_fragment | Stormglass Fragment | BM#7 | crystal1.png | None (direct) |
| sea_salt_crystal | Sea Salt Crystal | BM#8 | crystal2.png | None (direct) |
| spore_cluster | Spore Cluster | BM#35 | mushroom4.png | None (direct) |
| glowing_spore | Glowing Spore | BM#36 | mushroom5.png | None (direct) |

---

### Pack BN — ShieldsAmulets (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| gw_ancient_aegis | Ancient Aegis T4 | BN#27 | Icon27.png | None (direct) |

---

### Pack BO — RPGThings (1 item, named files)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| gw_ranger_pack | Ranger's Pack T3 | BO#83 | icons_30_83.png | None (direct) |

---

### Pack D — Bows (4 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| composite_bow | Composite Bow T2 | D#10 | Icon10.png | None (direct) |
| gw_longbow | Greenwood Longbow T3 | D#24 | Icon24.png | None (direct) |
| gw_thornshot_bow | Thornshot Bow T4 | D#21 | Icon21.png | None (direct) |
| gw_heartwood_staff | Heartwood Staff T4 | D#36 | Icon36.png | None (direct) |

**REPLACED**: `composite_bow` had `Icon13.png` → now `Icon10.png` per user instruction.

---

### Pack G — Helmets (4 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| cloth_cap | Cloth Cap T1 | G#20 | Icon20.png | None (direct) |
| padded_coif | Padded Coif T1 | G#17 | Icon17.png | None (direct) |
| gw_ironbark_helm | Ironbark Helm T3 | G#25 | Icon25.png | None (direct) |
| gw_ancient_helm | Ancient Helm T4 | G#42 | Icon42.png | None (direct) |

---

### Pack H — Cuirass (7 items, 1 CONFLICT)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| cloth_robe | Cloth Robe T1 | H#5 | Icon5.png | None (direct) |
| padded_mail | Padded Mail T1 | H#2 | Icon2.png | None (direct) |
| chainmail_vest | Chainmail Vest T2 | H#20 | Icon20.png | None (direct) |
| gw_ranger_vest | Ranger's Vest T2 | H#7 | Icon7.png | None (direct) |
| gw_ironbark_plate | Ironbark Plate T3 | H#18 | Icon18.png | None (direct) |
| gw_living_vest | Living Vest T3 | H#2 | Icon2.png | Recolour Greens |
| gw_thornhide_vest | Thornhide Vest T4 | H#23 | Icon23.png | None (direct) |

**REPLACED**: `chainmail_vest` had `Icon3.png` → now `Icon20.png` per user instruction.

**CONFLICT**: H#2 used by both `padded_mail` (direct) and `gw_living_vest` (Recolour Greens).
Both get base icon now. After recolour script produces separate output, update `gw_living_vest` icon_path.

### Pack H — Recolour Specs
```
SOURCE: Assets/_ArtPacks/Cuirass/PNG/Transperent/
OUTPUT: Assets/_Generated/Recolours/H/

H#2 -> living_vest_green.png | Recolour Greens (shift to green/leaf tones)
```

---

### Pack I — Trousers (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| cloth_leggings | Cloth Leggings T1 | I#11 | Icon11.png | None (direct) |

---

### Pack J — Sabatons (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| gw_ironbark_greaves | Ironbark Greaves T3 | J#20 | Icon20.png | None (direct) |

---

### Pack L — Rings (2 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| copper_band | Copper Band T1 | L#28 | Icon28.png | None (direct) |
| gw_heartwood_ring | Heartwood Ring T4 | L#4 | Icon4.png | None (direct) |

---

### Pack M — MagicArtifacts (6 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| warriors_pendant | Warrior's Pendant T2 | M#29 | Icon29.png | None (direct) |
| gw_living_focus | Living Focus T3 | M#8 | Icon8.png | None (direct) |
| gw_living_staff | Living Staff T3 | M#37 | Icon37.png | None (direct) |
| molten_core | Molten Core | M#1 | Icon1.png | None (direct) |
| obsidian_shard | Obsidian Shard | M#4 | Icon4.png | None (direct) |
| void_essence | Void Essence | M#2 | Icon2.png | None (direct) |

**REPLACED**: `warriors_pendant` had existing icon `Rings/Icon34.png` → now `MagicArtifacts/Icon29.png` per user instruction.

---

### Pack Q — Mushrooms (3 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| fungal_fiber | Fungal Fiber | Q#40 | Icon40.png | None (direct) |
| mycelium_thread | Mycelium Thread | Q#47 | Icon47.png | None (direct) |
| rare_truffle | Rare Truffle | Q#7 | Icon7.png | None (direct) |

---

### Pack T — Food (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| ss_brine_venom | Brine Venom | T#29 | Icon29.png | None (direct) |

---

### Pack U — MeatSkins (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| bone_dagger | Bone Dagger T1 | U#48 | Icon48.png | None (direct) |

---

### Pack V — CraftingMaterials (1 item)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| ss_crustacean_shell | Crustacean Shell | V#42 | Icon42.png | None (direct) |

---

### Pack W — CraftingMaterials2 (2 items)
| Item ID | Display Name | Ref | icon_path | Recolour |
|---------|-------------|-----|-----------|----------|
| driftwood | Driftwood | W#27 | Icon27.png | None (direct) |
| ss_kelp_sinew | Kelp Sinew | W#6 | Icon6.png | None (direct) |

---
