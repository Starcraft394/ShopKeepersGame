# Class Passives GDD Extract

**Source:** `Shops_And_Shadows_MASTER_GDD.md`
**Extracted:** 2026-01-16

---

## 1. Combat Kit Structure (#6.6)

Every hero's combat kit consists of:
1. **Basic Attack** (from equipped weapon) - always available, no cooldown
2. **Class Ability A** - core tactical skill, 1-3 turn cooldown
3. **Class Ability B** - higher impact skill, 2-5 turn cooldown
4. **Weapon Ability** - granted by weapon type, 2-4 turn cooldown
5. **2 Class Passives** - always on
6. **Race Passives** - always on, if any

---

## 2. Class System Overview (#22)

### 22.1 Archetypes
Classes belong to one of eight archetypes:
- **Vanguard** - Tanks & mitigation specialists
- **Striker** - Agile melee/ranged DPS
- **Warden** - Healers, buffers, party-support
- **Arcanist** - Magic-damage spellcasters
- **Ranger** - Ranged physical attackers
- **Invoker** - Summoners, minion-based classes
- **Channeler** - HP manipulation, dark magic, curses
- **Artificer** - Utility, dungeon support, blueprint synergy

### 22.2 Class Kit Definition
Each class has:
- 2 Class Abilities (A and B)
- 2 Passives (A and B)
- **No ultimate abilities**

---

## 3. Region 1 Classes (#24.1 - #24.3)

### 24.1 Defender (Vanguard)
**Role:** Tank / Protector
**Fantasy:** Heavily armored frontline who absorbs hits and controls enemy focus

#### Passive A - Bulwark Stance
At start of Defender's turn -> gain +1 Flat Armor (capped at 5)

#### Passive B - Shielding Presence
Adjacent allies gain +2 Shield at start of their turn (refreshes)

---

### 24.2 Warden (Healer-Protector)
**Role:** Support / Healer
**Fantasy:** Forest guardian with organic, grounded healing

#### Passive A - Living Bond
When Warden heals any ally -> heal lowest-HP ally for +2 HP

#### Passive B - Verdant Renewal
At end of each round -> all allies gain +1 Regen (1 turn)

---

### 24.3 Striker (Dual-Path DPS)
**Role:** Agile DPS (melee OR ranged)
**Fantasy:** Fast, precise combatant with flexible weapon paths

#### Passive A - Momentum Edge
If Striker acts before target -> first damaging action deals +2 damage

#### Passive B - Finisher's Instinct
Deal +3 damage to enemies under 25% max HP

---

## 4. Combat Resolution Rules (#6.3)

Combat round flow:
1. **Start-of-Round Triggers** - "at start of round" effects resolve
2. **Initiative Roll** - All units get ordered by initiative
3. **Turn Order Locked** - Turn order for the round is fixed
4. **Action Phase** - Units act one at a time in initiative order
5. **End-of-Round Triggers** - "at end of round" effects resolve
6. **Cooldown Decrement** - Turn counters for cooldowns and statuses decrement

Passives must integrate into these phases:
- **Combat start passives**: Apply during initialization
- **Turn start passives**: Apply at start of unit's turn
- **Round start passives**: Apply during Start-of-Round Triggers
- **Round end passives**: Apply during End-of-Round Triggers
- **On-kill passives**: Trigger when a unit lands a killing blow

---

## 5. Implementation Constraints

Per GDD:
- Passives are "always on" - no activation cost
- No random rolls in core passive effects (deterministic)
- Passives should scale appropriately with hero progression
- Effects should stack cleanly with equipment bonuses

---

## 6. V1 Implementation Mapping

For MVP Class Passives v1, we implement simplified versions that:
1. Scale with hero level
2. Are deterministic (no RNG)
3. Don't require new UI

| Class | Passive | GDD Spec | V1 Implementation |
|-------|---------|----------|-------------------|
| Defender | bulwark_stance | +1 Armor/turn (cap 5) | +DEF at combat start = (2 + level) |
| Striker | killer_instinct | - | On kill: +ATK = (1 + floor(level/2)) per kill, stacking |
| Warden | verdant_renewal | +1 Regen/round to all | At round start: heal lowest HP% ally by (3 + level) |

Note: V1 simplifies GDD passives for rapid implementation while preserving the class fantasy and scaling model.
