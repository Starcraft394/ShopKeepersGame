# SOUND_MASTER.md

> Unified sound system specification for ShopKeepers Game.
> Maintained by: Sound Director Agent
> Created: 2026-02-19

---

## Table of Contents

1. [Current State Audit](#1-current-state-audit)
2. [Source Pack Inventory](#2-source-pack-inventory)
3. [BGM Assignment Table](#3-bgm-assignment-table)
4. [SFX Assignment Table](#4-sfx-assignment-table)
5. [Sound Needs by Game System](#5-sound-needs-by-game-system)
6. [Directory Structure](#6-directory-structure)
7. [Technical Specs](#7-technical-specs)
8. [Preview Workflow](#8-preview-workflow)
9. [Implementation Priority](#9-implementation-priority)

---

## 1. Current State Audit

### 1.1 Existing Audio Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| UIAudio.gd autoload | Active | `Game/Core/UIAudio.gd` — button clicks, BGM, SFX pool, pause menu |
| Audio Buses | Minimal | Only "Master" bus (no BGM/SFX separation) |
| Button click SFX | Working | Kenney `click3.ogg` auto-wired to all BaseButton nodes |
| Hover SFX | Loaded, unused | `rollover1.ogg` loaded but not connected |
| BGM playback | Working | 7 region + 9 scene tracks, region-mapped, manual looping via `finished` signal |
| BGM system | Single | One soundtrack set (REGION_BGM + SCENE_BGM), no alt/toggle |
| SFX pool | Working | 4 pooled AudioStreamPlayers for overlapping sounds |
| SFX registry | Working | 75 SFX slots registered and integrated across all categories |
| Volume controls | Working | BGM and SFX sliders (0-100%), linear-to-dB conversion |
| Combat SFX | Integrated | 33 combat slots (melee, ranged, magic, status, impact) |
| Town/Shop SFX | Integrated | 12 slots (gold, recruit, facility, buy/sell) |
| Inventory SFX | Integrated | 8 slots (equip by type, unequip, consume) |
| Event SFX | Integrated | 5 slots (trigger, choice, outcomes) |
| Loot SFX | Integrated | 3 slots (appear, assign, discard) |
| Stingers | Integrated | 6 slots (3 BGM stingers + 3 SFX stingers) |
| Ambience | **PLANNED** | No ambient loops for any scene yet |

### 1.2 Current BGM Tracks

| Region | Current File | Display Name | Status |
|--------|-------------|--------------|--------|
| R1 Forest Haven | `Region/bgm_region_1_forest_haven.mp3` | Forest Haven Theme | INTEGRATED |
| R2 Fungalmire | `Region/bgm_region_2_fungalmire.mp3` | Fungalmire Theme | INTEGRATED |
| R3 Sunken Strand | `Region/bgm_region_3_sunken_strand.mp3` | Sunken Strand Theme | INTEGRATED |
| R4 Ashen Horizons | `Region/bgm_region_4_ashen_horizons.mp3` | Ashen Horizons Theme | INTEGRATED |
| R5 Starfall Expanse | `Region/bgm_region_5_starfall_expanse.mp3` | Starfall Expanse Theme | INTEGRATED |
| R6 Necropolis | `Region/bgm_region_6_necropolis.mp3` | Necropolis Theme | INTEGRATED |
| R7 Final Realm | `Region/bgm_region_7_final_realm.mp3` | Final Realm Theme | INTEGRATED |

### 1.3 Current UI SFX (Kenney Pack — KEEP)

| File | Used For | Status |
|------|----------|--------|
| `click3.ogg` | All button presses | KEEP |
| `rollover1.ogg` | Hover (loaded, not wired) | KEEP — wire up |
| 58 other `.ogg` files | Unused | AVAILABLE for variety |

---

## 2. Source Pack Inventory

### 2.1 Dungeon Music Pack (25 tracks)

All tracks are MP3 format, loopable dungeon/exploration themes.

| # | Track Name | Mood/Setting | Candidate For |
|---|-----------|--------------|---------------|
| 1 | Abandoned Spacestation | Eerie sci-fi, isolated | — |
| 2 | African Temple | Tribal, ancient, warm | — |
| 3 | Alien Hive | Creepy, organic, pulsing | R2 Fungalmire? |
| 4 | Ancient Ruins | Mysterious, grand, old | R1 Thornhaven? |
| 5 | Corporation Headquarters | Modern, corporate | — |
| 6 | Crystal Caves | Shimmering, underground, magical | R5 Starfall? |
| 7 | Deceitful Castle | Dark, regal, treacherous | — |
| 8 | Dwarven Settlement | Folk, warm, industrious | Town? |
| 9 | Final Dungeon | Epic, climactic, dread | R7 Final Realm? |
| 10 | Fire Dungeon | Intense, volcanic, danger | R4 Ashen Horizons? |
| 11 | Flying Fortress | Aerial, grand, military | — |
| 12 | Forbidden Tower | Ominous, magical, tall | — |
| 13 | Gearworks Factory | Mechanical, busy, rhythmic | — |
| 14 | Ghost Town | Haunted, desolate, wind | R6 Necropolis? |
| 15 | Ice Cavern | Cold, crystalline, echoing | — |
| 16 | Labyrinth | Tense, winding, lost | Combat Normal? |
| 17 | Mausoleum | Somber, death, cold | R6 Necropolis? |
| 18 | Mines | Underground, echoing, labor | — |
| 19 | Mystical Forest | Enchanted, nature, wonder | R1 Thornhaven? |
| 20 | Necropolis | Dark, undead, grand | R6 Necropolis? |
| 21 | Prison - Storage Room | Confined, tense, dark | — |
| 22 | Sewers | Dank, dripping, oppressive | — |
| 23 | Torture Chamber | Dark, pain, dread | — |
| 24 | Underwater Temple | Submerged, echoing, mystical | R3 Sunken Strand? |
| 25 | Wasteland Ruins | Desolate, wind, post-collapse | — |

> **Location:** `C:\Users\rober\Downloads\Bundles\Dungeon Music Pack\MP3s\`

### 2.2 Fantasy RPG Orchestra Music Pack (11 tracks)

All tracks are WAV format with explicit LOOP points, orchestral quality.

| # | Track Name | Mood/Setting | Candidate For |
|---|-----------|--------------|---------------|
| 1 | A Hero's Journey (LOOP) | Adventurous, uplifting, epic | — |
| 2 | Desperate Moment (LOOP) | Urgent, tense, dire | Combat Boss? |
| 3 | Epilogue (LOOP) | Reflective, bittersweet, ending | Victory/Extraction? |
| 4 | Guiding Spirit (LOOP) | Gentle, mystical, guiding | Town? Event? |
| 5 | Narrow Escape (LOOP) | Frantic, chase, danger | Combat Normal? |
| 6 | Preparing for War (LOOP) | Building tension, martial | Combat Build-up? |
| 7 | Prologue (LOOP) | Opening, curious, setting out | Town? |
| 8 | Provincial Village (LOOP) | Peaceful, pastoral, folk | Town Hub? |
| 9 | Ransacked and Pillaged (LOOP) | Destruction, aftermath, dark | — |
| 10 | Sacred Shrine (LOOP) | Reverent, holy, calm | Dungeon Camp? Shop? |
| 11 | The Apothecary (LOOP) | Quirky, mysterious, crafting | Shop? |

> **Location:** `C:\Users\rober\Downloads\Bundles\Fantasy RPG Orchestra Music Pack\`

### 2.3 RPG Combat SFX Pack (~95 files)

WAV format, combat-focused sound effects.

> **Location:** `C:\Users\rober\Downloads\Bundles\RPG Combat SFX Pack\RPG Combat SFX\SFX\`
> **Format:** WAV, 105 files

**Swords (22 files)**
- Sword 1-14
- Sword Clash, Sword Clash 2-5
- Sword Double Attack, Sword Double Attack 2
- Sword Swipe, Sword Swipe 2, Sword Swipe_1

**Stabs & Slices (10 files)**
- Stab, Stab Damage, Stab Damage 2-3, Stab Damage (Monster)
- Slice, Slice 2-3
- Swipe and Smack

**Swipes (6 files)**
- Swipe, Swipe 2-3
- Swipe (Monster), Swipe (Monster) 2

**Blocks (8 files)**
- Block, Block 1-5, Block 2_1, Block 3_1

**Impacts & Punches (12 files)**
- Punch Flesh, Punch Flesh Damage, Punch Flesh Damage 2
- Punch Gut, Punch Gut Damage, Punch Gut Damage 2
- Hard Punch Flesh, Hard Punch Gut, Punch Damage
- Smack, Smack 2, Hit, Attack

**Spells (8 files)**
- Spell 1-6, Spell Attack 1-2, Spell Miss

**Items & Coins (10 files)**
- Item Equip 1-3, Drop Item 1-2
- Coins 1-5, Metal Jingle, Metal Hit

**Movement (14 files)**
- Jump, Jump 1-2, Jump Landing, Jump Arcade, Jump into Snow, Jump into Water
- Footstep on Gravel, Run on Gravel, Step in Gravel, Land in Gravel, Step Indoors
- Open Door

**Misc & Stingers (11 files)**
- Discovery 1-2, Complete, Completion, Fade, Dodge, Laser
- Patch Up, Retro Sound, Damage Retro, Damaged Retro

### 2.4 Magic Spells SFX Bundle (17 categories, ~234 unique files)

MP3 format, each file exists in Mono and Stereo versions (use Stereo for our game).

> **Location:** `C:\Users\rober\Downloads\Bundles\Magic Spells SFX Bundle\`

| Category | Files | Game Use |
|----------|-------|----------|
| **Bravery** | 1-8 | Buff apply (courage, taunting) |
| **Earthquake** | 1-6, elemental, petrify, Wall summon/collapse | Earth spells, stun |
| **Electric** | 1-6, loop | Lightning abilities |
| **Fear** | 1-10 | Debuff apply (fear, doom) |
| **Fire** | 1-5, elemental, loop, DPS, Wall summon/collapse/loop | Fire abilities |
| **Generic** | Spell end 1-8, loop 1-7, summon 1-8, background, Dissipate 1-2, Regenerate 1-3 + loops | Generic spell cast, status tick, regen |
| **Heal** | 1-11 | Healing abilities |
| **Ice** | 1-8, freeze | Ice abilities |
| **Madness** | 1-10 | Void/shadow debuffs, madness |
| **Misc** | Mana Potion 1-2, Mana Regenerate 1-3, Spell Fail 1-8 | Potion use, spell miss/error |
| **Nature** | 1-6, elemental, trap, Wall summon/collapse | Nature abilities |
| **Revive** | 1-7, loop | Revival, resurrection |
| **Shield** | 1-9 | Buff apply (shield, barrier, reflect) |
| **Sleep-Silence** | 1-11 | Stun, silence, sleep debuffs |
| **Thunder** | 1-8 (8 is long) | Lightning/thunder abilities |
| **Tomes-Books** | Open/Close Scroll 1-2, Open/Close Tome 1-2, Turn Page 1-8 | UI page turns, event, tutorial |
| **Venom** | 1-7, DPS, elemental | Poison abilities, DoT |
| **Water** | 1-9, elemental, loop, Wall summon/collapse/loop | Water abilities |
| **Wind** | 1-9, elemental, loop, fast variants | Wind abilities |

---

## 3. BGM Assignment Table

Fill in the "Assigned Track" column after previewing candidates.

### 3.1 Region Themes (replacing current 7 tracks)

| Slot ID | Region | Mood | Assigned Track | Source Pack | Status |
|---------|--------|------|---------------|-------------|--------|
| `bgm_region_1` | R1 Forest Haven | Warm, adventurous, folk | Mystical Forest.mp3 | Dungeon Music | INTEGRATED |
| `bgm_region_2` | R2 Fungalmire | Mysterious, alien, ethereal | Alien Hive.mp3 | Dungeon Music | INTEGRATED |
| `bgm_region_3` | R3 Sunken Strand | Melancholy, coastal, eerie | Underwater Temple.mp3 | Dungeon Music | INTEGRATED |
| `bgm_region_4` | R4 Ashen Horizons | Intense, hostile, volcanic | Fire Dungeon.mp3 | Dungeon Music | INTEGRATED |
| `bgm_region_5` | R5 Starfall Expanse | Ethereal, fractured, cosmic | Crystal Caves.mp3 | Dungeon Music | INTEGRATED |
| `bgm_region_6` | R6 Necropolis | Dark, gothic, cold | Necropolis.mp3 | Dungeon Music | INTEGRATED |
| `bgm_region_7` | R7 Final Realm | Dread, void, finality | Final Dungeon.mp3 | Dungeon Music | INTEGRATED |

### 3.2 Scene Music

| Slot ID | Context | Mood | Assigned Track | Source Pack | Status |
|---------|---------|------|---------------|-------------|--------|
| `bgm_town` | Town hub | Peaceful, safe, home | Provincial Village (LOOP).wav | Fantasy Orchestra | INTEGRATED |
| `bgm_shop` | Shop interior | Quirky, cozy, trade | The Apothecary (LOOP).wav | Fantasy Orchestra | INTEGRATED |
| `bgm_dungeon_camp` | Dungeon rest camp | Quiet, tense relief | Sacred Shrine (LOOP).wav | Fantasy Orchestra | INTEGRATED |

### 3.3 Combat Music

| Slot ID | Context | Mood | Assigned Track | Source Pack | Status |
|---------|---------|------|---------------|-------------|--------|
| `bgm_combat_normal` | Standard encounters | Energetic, urgent | Narrow Escape (LOOP).wav | Fantasy Orchestra | INTEGRATED |
| `bgm_combat_boss` | Boss fights | Epic, intense, climactic | Desperate Moment (LOOP).wav | Fantasy Orchestra | INTEGRATED |

### 3.4 Stingers (short clips, 3-8 seconds)

| Slot ID | Context | Mood | Assigned Track | Source Pack | Status |
|---------|---------|------|---------------|-------------|--------|
| `stinger_victory` | Combat victory | Triumphant, relief | Complete.wav | RPG Combat SFX | INTEGRATED |
| `stinger_defeat` | Party wipe | Somber, failure | Damage Retro.wav | RPG Combat SFX | INTEGRATED |
| `stinger_extraction` | Dungeon extraction | Success, reward | Completion.wav | RPG Combat SFX | INTEGRATED |

---

## 4. SFX Assignment Table

Fill in after previewing. Use Stereo versions from Magic Spells pack.

### 4.1 Combat SFX

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `sfx_attack_melee_sword` | Sword attack | sword_attack_01.wav | RPG Combat SFX | MVP | INTEGRATED |
| `sfx_attack_melee_axe` | Axe attack | axe_attack_01.wav | RPG Combat SFX | P2 | INTEGRATED |
| `sfx_attack_melee_mace` | Mace attack | mace_attack_01.wav | RPG Combat SFX | P2 | INTEGRATED |
| `sfx_attack_melee_dagger` | Dagger attack | dagger_attack_01.wav | RPG Combat SFX | P2 | INTEGRATED |
| `sfx_attack_ranged_bow` | Bow attack | bow_attack_01.wav | RPG Combat SFX | P2 | INTEGRATED |
| `sfx_attack_generic` | Fallback attack | attack_generic.wav | RPG Combat SFX | MVP | INTEGRATED |
| `sfx_hit_damage` | Target takes damage | hit_damage.wav | RPG Combat SFX | MVP | INTEGRATED |
| `sfx_hit_critical` | Critical hit | hit_critical.wav | RPG Combat SFX | MVP | INTEGRATED |
| `sfx_block` | Attack blocked | block.wav | RPG Combat SFX | P2 | INTEGRATED |
| `sfx_miss` | Attack dodged | miss.wav | RPG Combat SFX | P3 | INTEGRATED |
| `sfx_heal` | Healing ability | heal.mp3 | Magic Spells (Heal) | MVP | INTEGRATED |
| `sfx_buff_apply` | Buff applied | buff_apply.mp3 | Magic Spells (Shield) | MVP | INTEGRATED |
| `sfx_debuff_apply` | Debuff applied | debuff_apply.mp3 | Magic Spells (Fear) | MVP | INTEGRATED |
| `sfx_stun_applied` | Unit stunned | stun_applied.mp3 | Magic Spells (Sleep-Silence) | MVP | INTEGRATED |
| `sfx_status_tick` | Status ticks (DoT) | status_tick.mp3 | Magic Spells (Generic Loop) | P2 | INTEGRATED |
| `sfx_status_expire` | Status wears off | status_expire.mp3 | Magic Spells (Generic Dissipate) | P3 | INTEGRATED |
| `sfx_doom_trigger` | Doom fires | spell_doom.mp3 | Magic Spells (Thunder 8) | P2 | INTEGRATED |
| `sfx_unit_death_hero` | Hero dies | death_hero.wav | RPG Combat SFX | MVP | INTEGRATED |
| `sfx_unit_death_enemy` | Enemy dies | death_enemy.wav | RPG Combat SFX | MVP | INTEGRATED |
| `sfx_spell_fire` | Fire ability | spell_fire.mp3 | Magic Spells (Fire) | P2 | INTEGRATED |
| `sfx_spell_ice` | Ice ability | spell_ice.mp3 | Magic Spells (Ice) | P2 | INTEGRATED |
| `sfx_spell_lightning` | Lightning ability | spell_lightning.mp3 | Magic Spells (Electric) | P2 | INTEGRATED |
| `sfx_spell_nature` | Nature ability | spell_nature.mp3 | Magic Spells (Nature) | P2 | INTEGRATED |
| `sfx_spell_void` | Void ability | spell_void.mp3 | Magic Spells (Madness) | P2 | INTEGRATED |
| `sfx_spell_shadow` | Shadow ability | spell_shadow.mp3 | Magic Spells (Fear 5) | P2 | INTEGRATED |
| `sfx_spell_water` | Water ability | spell_water.mp3 | Magic Spells (Water) | P2 | INTEGRATED |
| `sfx_spell_earth` | Earth ability | spell_earth.mp3 | Magic Spells (Earthquake) | P2 | INTEGRATED |
| `sfx_spell_wind` | Wind ability | spell_wind.mp3 | Magic Spells (Wind) | P3 | INTEGRATED |
| `sfx_spell_generic` | Generic spell cast | spell_generic.mp3 | Magic Spells (Generic Summon) | MVP | INTEGRATED |
| `sfx_passive_trigger` | Passive activates | passive_trigger.mp3 | Magic Spells (Tomes-Books) | P3 | INTEGRATED |
| `sfx_consumable_use` | Item used in combat | consumable_use.mp3 | Magic Spells (Mana Potion) | P2 | INTEGRATED |
| `sfx_combat_start` | Combat begins | combat_start.wav | RPG Combat SFX | MVP | INTEGRATED |

### 4.2 Town/Hub SFX

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `sfx_gold_gain` | Gold received | gold_gain.wav | RPG Combat SFX (Coins 1) | MVP | INTEGRATED |
| `sfx_gold_spend` | Gold spent | gold_spend.wav | RPG Combat SFX (Coins 3) | MVP | INTEGRATED |
| `sfx_hero_recruit` | New hero recruited | hero_recruit.wav | RPG Combat SFX (Discovery 1) | MVP | INTEGRATED |
| `sfx_hero_dismiss` | Hero dismissed | hero_dismiss.wav | RPG Combat SFX (Drop Item 1) | P2 | INTEGRATED |
| `sfx_facility_access` | Click facility | facility_access.wav | RPG Combat SFX (Open Door) | P2 | INTEGRATED |
| `sfx_facility_upgrade` | Facility upgraded | facility_upgrade.wav | RPG Combat SFX (Complete) | P2 | INTEGRATED |
| `sfx_unlock_purchase` | Recipe unlocked | unlock_purchase.wav | RPG Combat SFX (Completion) | P2 | INTEGRATED |
| `sfx_error_insufficient` | Can't afford | error_insufficient.mp3 | Magic Spells (Spell Fail 1) | MVP | INTEGRATED |
| `sfx_travel_region` | Travel to region | travel_region.wav | RPG Combat SFX (Fade) | P3 | INTEGRATED |

### 4.3 Shop SFX

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `sfx_item_buy` | Purchase item | item_buy.wav | RPG Combat SFX (Coins 2) | MVP | INTEGRATED |
| `sfx_item_sell` | Sell item | item_sell.wav | RPG Combat SFX (Coins 4) | P2 | INTEGRATED |
| `sfx_item_select` | Click item in grid | item_select.wav | RPG Combat SFX (Metal Jingle) | P2 | INTEGRATED |

### 4.4 Inventory/Equipment SFX

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `sfx_item_pickup` | Item moved | item_pickup.wav | RPG Combat SFX (Item Equip 1) | P2 | INTEGRATED |
| `sfx_equip_weapon` | Weapon equipped | equip_weapon.wav | RPG Combat SFX (Item Equip 2) | MVP | INTEGRATED |
| `sfx_equip_armor` | Armor equipped | equip_armor.wav | RPG Combat SFX (Item Equip 3) | MVP | INTEGRATED |
| `sfx_equip_accessory` | Ring/amulet equipped | equip_accessory.wav | RPG Combat SFX (Metal Hit) | P2 | INTEGRATED |
| `sfx_equip_bag` | Backpack equipped | equip_bag.wav | RPG Combat SFX (Drop Item 2) | P3 | INTEGRATED |
| `sfx_unequip` | Item removed | unequip.wav | RPG Combat SFX (Drop Item 1) | P2 | INTEGRATED |
| `sfx_consume_potion` | Potion consumed | consume_potion.mp3 | Magic Spells (Mana Potion 2) | MVP | INTEGRATED |
| `sfx_consume_food` | Food consumed | consume_food.wav | RPG Combat SFX (Patch Up) | P2 | INTEGRATED |

### 4.5 Dungeon Camp SFX

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `sfx_room_choice` | Select room A/B | room_choice.mp3 | Magic Spells (Turn Page 5) | P2 | INTEGRATED |
| `sfx_extraction` | Extract from dungeon | extraction.wav | RPG Combat SFX (Complete) | MVP | INTEGRATED |
| `sfx_descend_floor` | Go to next floor | descend_floor.wav | RPG Combat SFX (Footstep on Gravel) | P2 | INTEGRATED |
| `sfx_camp_arrive` | Arrive at camp | camp_arrive.wav | RPG Combat SFX (Step Indoors) | P3 | INTEGRATED |

### 4.6 Event SFX

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `sfx_event_trigger` | Event room entered | event_trigger.mp3 | Magic Spells (Open Scroll 1) | P2 | INTEGRATED |
| `sfx_event_choice` | Choice selected | event_choice.mp3 | Magic Spells (Turn Page 4) | P2 | INTEGRATED |
| `sfx_event_outcome_good` | Positive outcome | event_outcome_good.wav | RPG Combat SFX (Discovery 2) | P2 | INTEGRATED |
| `sfx_event_outcome_bad` | Negative outcome | event_outcome_bad.mp3 | Magic Spells (Spell Fail 3) | P2 | INTEGRATED |
| `sfx_event_outcome_neutral` | Neutral outcome | event_outcome_neutral.mp3 | Magic Spells (Generic Spell End 1) | P3 | INTEGRATED |

### 4.7 Loot SFX

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `sfx_loot_appear` | Loot panel opens | loot_appear.wav | RPG Combat SFX (Discovery 1) | MVP | INTEGRATED |
| `sfx_loot_assign` | Item routed to bag | loot_assign.wav | RPG Combat SFX (Coins 5) | MVP | INTEGRATED |
| `sfx_loot_discard` | Item dropped | loot_discard.wav | RPG Combat SFX (Drop Item 2) | P2 | INTEGRATED |

### 4.8 Stingers

| Slot ID | Trigger | Assigned File | Source Pack | Priority | Status |
|---------|---------|--------------|-------------|----------|--------|
| `stinger_dungeon_enter` | Enter dungeon | dungeon_enter.wav | RPG Combat SFX (Fade) | P2 | INTEGRATED |
| `stinger_extraction_success` | Return to town | extraction_success.wav | RPG Combat SFX (Completion) | MVP | INTEGRATED |
| `stinger_level_up` | Hero levels up | level_up.mp3 | Magic Spells (Bravery 1) | P2 | INTEGRATED |

---

## 5. Sound Needs by Game System

### Priority Summary

| Priority | Count | Description |
|----------|-------|-------------|
| **MVP** | 28 | Core gameplay feel — combat hits, spells, gold, equip, victory/defeat |
| **P2** | 30 | Extended variety — weapon types, spell elements, events, inventory |
| **P3** | 17 | Polish — ambient, passive triggers, wind spells, camp sounds |
| **Total** | **75** | |

### MVP Sound Slots (28)

**Combat (12):** attack_generic, attack_melee_sword, hit_damage, hit_critical, heal, buff_apply, debuff_apply, stun_applied, unit_death_hero, unit_death_enemy, spell_generic, combat_start

**Music (5):** bgm_combat_normal, bgm_combat_boss, stinger_victory, stinger_defeat, bgm_town

**Region BGM (7):** bgm_region_1 through bgm_region_7

**Town/Shop (4):** gold_gain, gold_spend, hero_recruit, error_insufficient, item_buy

**Inventory (3):** equip_weapon, equip_armor, consume_potion

**Dungeon (1):** extraction

**Loot (2):** loot_appear, loot_assign

**Stingers (1):** stinger_extraction_success

---

## 6. Directory Structure

```
Assets/Audio/
├── BGM/
│   ├── Region/          ← 7 region exploration themes
│   ├── Combat/          ← Normal, elite, boss combat music
│   └── Stingers/        ← Victory, defeat, extraction, level-up
├── SFX/
│   ├── Combat/
│   │   ├── Melee/       ← Sword, axe, mace, dagger attacks
│   │   ├── Ranged/      ← Bow, crossbow
│   │   ├── Magic/       ← Fire, ice, lightning, nature, etc.
│   │   ├── Status/      ← Buff/debuff apply, tick, expire
│   │   └── Impact/      ← Hits, blocks, crits, death
│   ├── UI/              ← Clicks, hovers, errors (Kenney + new)
│   ├── Inventory/       ← Equip, unequip, pickup, consume
│   ├── Events/          ← Event triggers, choices, outcomes
│   └── Town/            ← Gold, recruit, facility sounds
└── Ambience/            ← Town, dungeon, shop atmosphere (future)
```

---

## 7. Technical Specs

| Property | Standard |
|----------|----------|
| BGM Format | MP3 or OGG, stereo, 44.1kHz |
| SFX Format | OGG preferred (WAV acceptable), 44.1kHz |
| BGM Default Volume | -20 dB |
| SFX Default Volume | -6 dB |
| File Naming | `snake_case` — e.g., `sword_slash_01.ogg`, `bgm_forest_haven.mp3` |
| Max SFX Variants | 3 per slot (for randomization) |
| Audio Bus Layout | Master → BGM, SFX (→ Combat, UI, Inventory), Ambience |

### Conversion Notes
- WAV files from Fantasy RPG Orchestra need conversion to MP3/OGG before integration
- Magic Spells Bundle has Mono + Stereo versions — **use Stereo**
- RPG Combat SFX Pack extracted (105 WAV files in `RPG Combat SFX\SFX\`)

---

## 8. Preview Workflow

### Step 1: Extract Packs
- [x] Dungeon Music Pack — extracted to `Downloads\Bundles\Dungeon Music Pack\MP3s\`
- [x] Fantasy RPG Orchestra — extracted to `Downloads\Bundles\Fantasy RPG Orchestra Music Pack\`
- [x] RPG Combat SFX Pack — extracted to `Downloads\Bundles\RPG Combat SFX Pack\RPG Combat SFX\SFX\`
- [x] Magic Spells SFX Bundle — extracted to `Downloads\Bundles\Magic Spells SFX Bundle\`

### Step 2: Preview BGM
1. Open the extracted folders in Windows Explorer
2. Double-click tracks to play in default media player
3. For each region, listen to 2-3 candidates from both music packs
4. Write the selected track name in Section 3 tables above

### Step 3: Preview SFX
1. After extracting RPG Combat SFX (with 7-Zip), browse by category folder
2. For Magic Spells, navigate to the Stereo subfolder of each category
3. Play candidates, pick 1-3 per slot
4. Write selections in Section 4 tables above

### Step 4: Integrate
1. Rename selected files to `snake_case` per naming standard
2. Convert WAV → OGG/MP3 if needed
3. Copy into `Assets/Audio/` per directory structure
4. Update UIAudio.gd SFX registry and BGM constants

---

## 9. Implementation Priority

| Phase | What | Depends On |
|-------|------|-----------|
| **Phase 1** | BGM replacement (7 region + town + 2 combat) | User preview & selection |
| **Phase 2** | MVP SFX (28 slots) | RPG Combat SFX extraction (7-Zip), user selection |
| **Phase 3** | P2 SFX (30 slots) — weapon types, spell elements, events | Phase 2 complete |
| **Phase 4** | P3 SFX (17 slots) — polish, ambience | Phase 3 complete |
| **Phase 5** | Audio bus layout, crossfade, stinger ducking | All audio selected |
