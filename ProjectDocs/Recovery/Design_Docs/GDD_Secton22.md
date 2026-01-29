------------------------------------------------------------
📘 SECTION 22 — CLASS SYSTEM (FINAL – GDD VERSION)

Hybrid Archetype + Region Unlock Framework

------------------------------------------------------------
22.0 Overview

The Class System defines the playable combat roles for all heroes in Shops & Shadows. Classes are acquired through Class Books, which can be purchased in shops once unlocked. A hero’s class determines:

Their archetype

Their combat abilities

Their passive identities

Their combat role (tank, support, DPS, summoner, manipulator, etc.)

Classes can be overwritten by using a different Class Book, allowing total flexibility in party composition.

------------------------------------------------------------
⭐ 22.1 Class Archetypes
------------------------------------------------------------

All classes belong to one of eight archetypes. Archetypes define:

Behavior in auto-combat (enemy AI + town defense simulations)

Recommended positioning

Scaling tendencies (ATK vs MAG vs utility)

Ability style (burst, sustain, mitigation, etc.)

Eight Archetypes (Final)

Vanguard – Tanks & mitigation specialists

Striker – Melee/Ranged agile DPS

Arcanist – Magic-damage spellcasters

Warden – Healers, buffers, party-support

Ranger – Ranged physical attackers

Invoker – Summoners, minion-based classes

Channeler – HP manipulation, dark magic, curses

Artificer – Utility, dungeon support, blueprint synergy

These archetypes are NOT stat templates, but AI + identity categories.

------------------------------------------------------------
⭐ 22.2 Class Unlock Structure (Region-Based)
------------------------------------------------------------

Each region contains two towns:

Town A → unlocks a NEW RACE

Town B → unlocks two NEW CLASSES

Total classes unlocked across the campaign:

3 starter classes

5 regions × 2 classes = 10

1 final class in Region 7
Grand Total = 16 classes

------------------------------------------------------------
⭐ 22.3 Starter Classes (Region 1)
------------------------------------------------------------

These classes define the game’s foundation.

1. Vanguard — Defender (Archetype: Vanguard)

Absorbs damage

Uses taunts or protective actions

Simple, durable frontline

2. Warden — Cleric (Archetype: Warden)

Direct heals

Early buff support

Essential sustainer for early dungeons

3. Striker — Blade Dancer (Archetype: Striker)

A flexible DPS class supporting TWO weapon paths:

Melee Path: Daggers & blades → high crit, evade

Ranged Path: Throwing knives / light bows → speed-based ranged DPS

This gives players early build expression.

------------------------------------------------------------
⭐ 22.4 Region 2 Classes (Fungalmire)
------------------------------------------------------------
4. Druid (Archetype: Warden)

Healing-over-time

Regeneration

Party sustain and hazard cleansing

5. Sporemancer (Archetype: Invoker)

Summons sporelings

Applies poison and decay

Performs battlefield attrition

------------------------------------------------------------
⭐ 22.5 Region 3 Classes (Sunken Strand)
------------------------------------------------------------
6. Tidehunter (Archetype: Ranger)

Mid-range harpoon user

Crowd control pulls

Reliable physical DPS

7. Siren Mage (Archetype: Arcanist)

Multi-target water magic

Slow effects

High burst–low durability caster

------------------------------------------------------------
⭐ 22.6 Region 4 Classes (Desert / Dragonkin Region)
------------------------------------------------------------
8. Fire Dervish (Archetype: Striker)

Spin attacks

Heat stacking

Burn-focused melee DPS

9. Pyromancer (Archetype: Arcanist)

Explosions and burn DoTs

High-risk, high-damage caster

------------------------------------------------------------
⭐ 22.7 Region 5 Classes (Crystalborn Region)
------------------------------------------------------------
10. Stone Sentinel (Archetype: Vanguard)

Generates fixed-value stone armor

Reactive tanking

Extremely stable frontline

11. Stormcaller (Archetype: Arcanist)

Chain lightning

High speed casting

Minor stun chance

------------------------------------------------------------
⭐ 22.8 Region 6 Classes (Undead Region)
------------------------------------------------------------
12. Dark Channeler (Archetype: Channeler)

Health manipulation (self-harm → power)

Curse spread

Sinister control mage

13. Lich (Archetype: Channeler)

NO tile bonuses (corrected)

Soul harvesting

One-time “Undying” effect (survive lethal hit at 1 HP)

Drains life essence

Can interact with Book of the Dead in future postgame updates

------------------------------------------------------------
⭐ 22.9 Region 7 Class (Final Region)
------------------------------------------------------------
14. Eternal Artificer (Archetype: Artificer)

Prestige class unlocked only after final boss of Region 7.

Interacts with blueprints, legendary crafting, and multi-cycle mechanics

Minor initiative / cooldown manipulation

Perfect NG+ “master class” identity

------------------------------------------------------------
⭐ 22.10 Class Books (Acquisition & Overwrite Rules)
------------------------------------------------------------
✔ Classes are assigned using Class Books

These appear in the shop once their region unlocks them.

✔ Class Books CAN overwrite existing classes

Overwriting:

Costs gold

Instantaneously changes class

Updates ability list & passives

Retains hero’s race, gear, and level

There is no penalty for switching classes.

------------------------------------------------------------
⭐ 22.11 Class Passives (Framework)
------------------------------------------------------------

Each class contains:

1 Core Passive — defines the class identity

1 Secondary Passive — unlocks at a mid-level threshold

Examples:

Fire Dervish → “Heat Cycle: Generate heat stacks during combat.”

Stone Sentinel → “Stone Armor: Gain fixed armor when struck.”

Lich → “Soul Harvest: Killing enemies restores mana or power.”

(Ability specifics defined in Section 23.)

------------------------------------------------------------
⭐ 22.12 Class Ability Framework
------------------------------------------------------------

Each class uses the same structure:

✔ Basic Attack

Weapon- or theme-based automatic action.

✔ Active Ability

Moderate cooldown ability.
Examples:

Druid heal

Stormcaller chain lightning

Sporemancer summon

✔ Ultimate Ability

Long cooldown, used for tactical spikes.
Examples:

Pyromancer inferno

Tidehunter tidal pull

Lich necrotic eruption

This pattern keeps the combat simple, tactical, and easy to visualize.

------------------------------------------------------------
⭐ 22.13 Combat AI (Simplification Rules)
------------------------------------------------------------
For player adventuring parties:

The player sets positions → combat auto-resolves. AI is minimal.

For town defense:

AI uses archetype-based behavior:

Vanguard → protect front

Warden → heal weakest

Striker → attack lowest defense

Arcanist → cast when off cooldown

Invoker → ensure summons are deployed

Channeler → use curses early

Artificer → supportive effects

Enemy AI:

Simple ability timers

Target selection rules

No deep multi-step logic

This keeps defense battles readable and performant.