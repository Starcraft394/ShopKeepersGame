------------------------------------------------------------
📘 SECTION 23 — TURN-BASED ABILITY & COMBAT SYSTEM
------------------------------------------------------------
23.0 Overview

Shops & Shadows uses a strict turn-based combat system built around a tactical grid.
Each unit (hero or enemy) takes one action per turn in an ordered sequence.

Every hero’s combat kit consists of:

1 Basic Attack (from their equipped weapon)

2 Class Abilities (Class Ability A & B)

1 Weapon Ability (from their weapon type)

2 Class Passives (always on)

Race Passives (always on, if any)

There are no ultimate abilities and no real-time timers.
Cooldowns are tracked in turns, not seconds.

23.1 Turn Structure

Combat proceeds in discrete rounds. Each round follows this order:

Status Tick Phase

Apply damage-over-time (burn, poison, bleed, etc.)

Apply heal-over-time effects

Decay temporary shields and round-based buffs/debuffs

KO & Death Check

Units reduced to 0 HP are removed from combat

Special cases (Voidwalker Flicker Step, Lich’s Undying-style passive) resolve here

Initiative Calculation

Determine action order for this round based on:

Class (fast vs slow archetypes)

Weapon type (e.g., daggers faster than hammers)

Occasional initiative-modifying items or passives

Action Phase

Units act one at a time in initiative order

On their turn, a unit chooses one of:

Basic Attack

Class Ability A (if off cooldown)

Class Ability B (if off cooldown)

Weapon Ability (if off cooldown)

End-of-Round Triggers

Any “at end of round” effects resolve

Turn counters for cooldowns and statuses decrement

23.2 Initiative Rules

Initiative is a simple ordering score calculated at the start of each round:

Each class has a base initiative band (e.g., Striker high, Stone Sentinel low).

Each weapon type modifies initiative slightly (daggers > swords > hammers).

Certain passives or items may adjust initiative (rare and tightly controlled).

Final turn order is sorted by this effective initiative, with ties broken by:

Lowest current HP first (for enemies) or

Left-to-right placement on the grid (for heroes).

23.3 Ability Types (Per Hero)

Each hero has the following combat elements:

23.3.1 Basic Attack

Source: Equipped weapon

Always available (no cooldown)

Damage type: physical or magical based on weapon

May apply on-hit effects from items, class passives, or refinements

Single-target by default unless the weapon or ability explicitly says otherwise

23.3.2 Class Ability A

Core tactical skill for the class

1–3 turn cooldown

Examples:

Defender: taunt + small shield

Druid: mid heal on single ally

Fire Dervish: small spin attack with heat stack

Designed to be used regularly in most fights

23.3.3 Class Ability B

Higher impact or more specialized skill

2–5 turn cooldown

Often:

Larger heal, stronger strike, summon, powerful debuff, or battlefield control

Creates meaningful decisions: “Do I use this now or save it?”

23.3.4 Weapon Ability (NEW)

Granted by weapon type, not class

One ability per weapon family (e.g., sword, axe, staff, bow, etc.)

Cooldown: typically 2–4 turns

Encapsulates the fantasy of the weapon:

Examples (conceptual, details in a later section):

Sword → Cleave
Hit target + adjacent unit(s) in same row/column.

Dagger → Quick Strike
High-initiative, low damage attack that may inflict bleed.

Hammer → Crushing Blow
Heavy hit with a small chance to stun.

Axe → Sundering Chop
Hit + apply flat armor-reduction debuff.

Bow → Power Shot
High-damage single-target attack ignoring part of defense.

Crossbow → Piercing Bolt
Line attack hitting multiple units in a straight line.

Throwing Knives → Blade Fan
Low damage attacks spread across 2–3 enemies.

Staff → Arcane Pulse
Magic AoE around a target or small cluster.

Wand → Focus Beam
Concentrated magic hit with good reliability.

Tome → Spellweave
Buff that amplifies the hero’s next class ability.

Weapon abilities make weapon choice tactically meaningful instead of purely stat-based.

23.4 Weapon Tiers & Ability Evolution

Each weapon’s ability belongs to a family that improves as weapon quality increases.

Example — Sword → Cleave I / II / III / IV:

Common Sword (Tier 1): Cleave I
Hit main target + 1 adjacent for small damage.

Uncommon Sword (Tier 2): Cleave II
Slight damage increase; can hit up to 2 adjacent.

Rare Sword (Tier 3): Cleave III
Further damage increase + small bleed or armor shred.

Legendary Sword (Tier 4): Cleave IV
High damage + stronger secondary effect (bleed/blind/etc.).

Rules:

Ability family remains recognizable; numbers and effects scale up simply.

No percentage scaling — only flat damage or fixed additive effects.

Some legendary items may slightly alter targeting shape or status type.

This system ties gear progression directly to combat expression.

23.5 Class Passives

Each class has two passives:

Passive A (Core Identity)

Always active

Defines how the class “feels” to play

Examples:

Fire Dervish: gain Heat stacks when attacking

Stone Sentinel: gain a small armor buff after being hit

Sporemancer: poison stacks applied more efficiently

Passive B (Advanced/Level-Unlocked)

Unlocks at a mid-tier level

Adds depth without overwhelming early players

May interact with:

Class abilities

Basic attacks

Weapon abilities (in some cases, e.g., “your weapon ability also applies X”)

Passives do not directly scale with percentages; they add flat values, stacks, or simple extra effects.

23.6 Race Passives (Integration)

Race passives are:

Always on

Simple, thematic

Not weapon-type dependent

Do not directly scale or amplify weapon abilities by default

Examples (conceptual recap):

Dragonkin: reduced damage from large single hits; small self-regen when low HP.

Crystalborn: reduced damage from magic; one-time echo effect per fight.

Voidwalker: immune to corruption debuffs; one avoided fatal hit per fight.

Mossfolk: extra small heal when receiving healing; better resource path sense.

Tidelings: reduced damage from multi-hit attacks; occasional small shield.

Race passives are identity modifiers, not build-defining combos with specific weapon types.

23.7 Cooldowns (Turn-Based)

Cooldowns are stored as turn counters on the acting unit:

When an ability is used, its cooldown is set (e.g., 3 turns).

Each time that hero takes a turn (whether they attack or skip), the cooldown reduces by 1.

When it reaches 0, the ability becomes available again.

Constraints:

Most Class A abilities: 1–3 turns.

Most Class B abilities: 2–5 turns.

Weapon Abilities: typically 2–4 turns.

No global haste system, to keep logic simple and predictable.

23.8 Status Effect System

Status effects follow a consistent structure:

Each status has:

Name (Poison, Burn, Bleed, Shock, Regen, Shield, etc.)

Duration (in turns)

Magnitude (flat value per tick or flat effect amount)

Tick Timing (usually “start of linked unit’s turn”)

Stack Rule:

Stackable (Poison, Bleed)

Refresh-only (Burn extends duration)

Single-charge (Shock consumes on next hit)

Core status types:

Damage-over-Time:

Poison (stacks)

Bleed (stacks, often from physical abilities)

Burn (stronger but refreshes rather than stacking magnitude)

Heal-over-Time:

Regeneration (flat heal at start of turn)

Control:

Slow (initiative penalty / pushed later in turn order)

Stun (lose one action) — used sparingly

Shields:

Temporary flat HP buffer that absorbs damage before HP

Status effects are applied by:

Class abilities

Weapon abilities

Certain item effects

Enemy abilities

Undead, Voidwalkers, and other races may ignore or alter some statuses (e.g., poison immunity).

23.9 Targeting & Grid Interaction

Abilities must define explicit targeting:

Single Target:

Frontline enemy

Lowest HP enemy

Selected ally

Random enemy

Pattern Targeting:

Row

Column

2x2 cluster

Cross around target

Movement:

Pull or push effects (Tidehunter, certain monsters)

Teleport (Voidwalkers in rare cases, boss skills)

Tile hazards and special tiles (when used) are interpreted through movement and position, not separate ability logic.

23.10 Dungeon vs Town Defense Behavior

The same ability system is used in:

Dungeon Combat (player party vs monsters)

Town Defense Combat (defense roster vs attacking monsters)

Differences:

Town defense heroes do not die permanently; they “retreat” if defeated.

Town defense enemies may have slightly tuned numbers (e.g., more HP or small initiative boosts).

Player cannot reorder town defense abilities mid-fight; they rely on AI using the same logic framework.

Otherwise, abilities behave identically.

23.11 Enemy Ability System

Enemies follow the exact same rules but with simpler loadouts:

Basic monsters:

Basic attack

Occasionally one simple ability

Elite monsters:

Basic attack

1 ability

1 passive (e.g., innate resistance, extra damage to a type of target)

Bosses:

Basic attack

2 abilities

1 passive

Sometimes a health-threshold scripted special move (telegraphed)

Enemy abilities use the same template as hero abilities (Name, Type, Cooldown, Targeting, Effect, Status, Notes).

23.12 Field Artificer & Weapon Gadgets

The Field Artificer (Artificer archetype) is a specialized class/facility interaction that augments weapon abilities without overlapping with herbs or alchemy.

Resource Inputs for Gadgets:

Metals / ores

Leather / hardened hides

Monster parts (claws, teeth, scales, etc.)

Crystals / glass shards

Mechanical scrap or “gear fragments”

No herbs are used by the Field Artificer. Herbs remain in the Chef/Alchemist domain.

Gadget Effects (Conceptual Examples):

“Overcharged Mechanism” → next weapon ability deals extra flat damage

“Gyro Stabilizer” → next weapon ability cannot miss and gains micro-stun

“Reinforced Joint” → next weapon ability grants temporary armor

“Recoil Dampener” → reduces the cooldown of the next weapon ability by 1 turn (minimum 1)

Gadgets:

Are crafted outside combat

May be single-use consumables or limited-stack buffs

Do not replace the weapon ability — they modify the next use

23.13 Ability Definition Template (For Claude/Godot)

Every hero/enemy ability should be defined with this schema:

Metadata

Name

Source: (Class / Weapon / Enemy / Item)

Type: (Basic / ClassA / ClassB / WeaponAbility / EnemyAbility)

Mechanics

Cooldown (in turns; 0 for basic attacks)

Initiative impact (if any, e.g., “acts late when using this ability”)

Targeting rule (single, row, etc.)

Effect description (damage/heal/buff)

Flat values (damage, shield, etc.)

Status applied (if any)

Status details (duration, magnitude, stack rule)

Tags

Damage type: (Physical / Magical / Element)

Archetype tags: (Vanguard, Striker, etc.)

Synergy notes (e.g., “Consumes Heat stacks”)

Visual Notes (Optional)

Short description for VFX/animation flavor.

This template will be used in Section 24 to define actual ability kits for each class.