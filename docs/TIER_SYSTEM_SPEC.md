# Equipment Tier System — Final Spec

**Finalized:** 2026-02-19

---

## Tier Definitions

| Tier | Recipe | Naming | Stats | Special |
|------|--------|--------|-------|---------|
| **T1** | Base materials only (some default, some unlocked with base materials) | Universal names | Baseline | None |
| **T2** | T1 Base Item (same type) + Regional Material | Regional themed | Base + Regional Affix | None |
| **T3** | T2 Item (same type) + Regional Materials | Regional themed | Base + Stronger Regional Affix | None |
| **T4** | T2/T3 Item (same type) + Regional + Regional + Boss Trophy | Boss/Regional themed | Strong (balanced) | Ability or Passive |

## Upgrade Chain

T1 → T2 → T3 → T4 (each step requires the previous tier item of the **same equipment type**)

Example (R2 Fungalmire Sword):
- T1: Rusty Sword (universal)
- T2: Spore Blade = Rusty Sword + Spore Cluster
- T3: Mycelium Saber = Spore Blade + Fungal Fiber + Mycelium Thread
- T4: Fungal Ruin Blade = Mycelium Saber + Spore Cluster + Fungal Fiber + Mycelium Heart

## T4 Special by Slot

| Slot Category | Slots | T4 Grants |
|---------------|-------|-----------|
| **Weapons** | Sword, Bow, Staff, Mace, Dagger | **Ability** (regional-themed) |
| **Offhands** | Shield, Focus | **Ability** (regional-themed) |
| **Armor** | Chest, Helmet, Legs | **Passive** (regional-themed) |
| **Jewelry** | Ring, Amulet | **Passive** (regional-themed) |

## Boss Item Cap

- **Max 3 T4 (Boss) items equipped per hero**
- Only counts equipped gear — T4 items in hero bags do NOT count toward the cap
- Must enforce at equip time, not at acquisition time

## Scope

- Applies to **all regions R1–R7**
- Every region gets T2, T3, T4 for all equipment slots
- T1 items are universal (same across all regions)

## Regions

| Region | ID | Theme |
|--------|----|-------|
| R1 | Greenwood | Natural resilience |
| R2 | Fungalmire | Fungal armor, resilience |
| R3 | Tidelands / Sunken Strand | Swift currents |
| R4 | Ashen Heights | Dragonfire aggression |
| R5 | Starfall Edge | Cosmic precision |
| R6 | Necropolis | Undying fortitude |
| R7 | Fractured Realm | Dimensional power |

## Changes Already Made (Loot Tables)

1. Boss trophies added to R2–R7 boss loot tables (weight 20, qty 1)
2. Orphaned materials given drop sources:
   - honey, glowing_spore → R1 elite
   - honey, aged_cheese → R1 boss
   - wyvern_scale → R2 elite
   - rare_truffle → R2 boss
   - ancient_bone → R3 elite
   - phoenix_ash → R4 elite
   - void_essence → R5 elite
