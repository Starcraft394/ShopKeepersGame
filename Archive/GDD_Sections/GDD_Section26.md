26. Boss Design Rules
26.1 Boss Design Pillars

Bosses exist to test mastery of systems, not to invalidate them.

A boss encounter must always:

Reinforce mechanics introduced earlier in the region

Be learnable through observation and iteration

Reward positioning, timing, and preparation

Remain fair even when difficult

Bosses must never:

Break core combat rules

React dynamically to player inputs (“AI cheating”)

Hard-counter specific classes or builds

Use ultimate-style abilities

Boss difficulty comes from composition, mechanics, and pressure, not surprise lethality.

26.2 Boss Structure Overview

Every boss encounter is built from the same structural components:

Each boss consists of:

Primary AI Archetype (from Section 25)

1–2 Unique Boss Mechanics

Boss Arena Modifier (optional, region-dependent)

Phase Progression Method (HP or turn-based)

This structure ensures consistency while allowing meaningful variation.

Boss Arena Modifiers (Later Regions)

In later regions (Region 5+), boss arenas may include:

Summoned objects (turrets, anchors, pylons, growths)

Objects may:

Have HP or a countdown timer

Apply pressure (damage, buffs, debuffs, denial)

Objects are:

Limited in number

Clearly telegraphed

Never infinite or self-respawning

Early-region bosses use clean arenas with minimal modifiers.

26.3 Boss Phases

Bosses escalate through phases, not enrages.

Phase Triggers

HP thresholds (e.g. 70%, 40%)

Turn count (e.g. Turn 6)

Phase Effects

Unlock new abilities

Modify existing abilities

Introduce arena pressure

Change targeting patterns

Phases must:

Be predictable

Never reset cooldowns unfairly

Never remove player buffs/debuffs

Never skip turn order

26.4 Boss Ability Rules

Bosses typically have 2–4 abilities

All abilities:

Have visible telegraphs

Obey cooldowns

Respect turn order

No ultimate abilities

No reactive “counterplay AI”

Boss abilities are enhanced expressions of archetype behavior, not new rule systems.

26.5 Arena & Positioning Design

Boss encounters emphasize grid awareness without overwhelming the player.

Design rules:

Early regions: clean grids

Later regions: limited, readable pressure

Hazards are temporary or destructible

Positioning always matters, guessing never does

26.6 Region-Based Boss Identity
Region	Boss Focus
Region 1	Basic damage & positioning
Region 2	Status interaction (simple)
Region 3	Movement & tempo
Region 4	Burst windows
Region 5	Geometry & formation pressure
Region 6	Attrition & inevitability
Region 7	Rule distortion (non-cheating)

Boss mechanics must align with regional themes and class kits.

26.7 Dungeon Bosses vs Region Bosses

There are two boss types, serving different purposes.

Dungeon Bosses

Guard individual dungeon floors

Can be fought repeatedly

Moderate difficulty

Primary purposes:

Teach mechanics

Provide resources

Progress Region Boss access

Dungeon bosses scale slightly with dungeon tier.

Region Bosses

Gate progression to the next region

Single-floor encounters

High mechanical and stat difficulty

Farmable in a controlled way

26.8 Region Boss Access — Charged Key System (Final)

Region Boss access uses a single persistent charge object.

How Charges Work

Each dungeon floor completion grants +1 Region Charge

Completing all 4 floors = 4 charges

Charges are stored up to a maximum of 10

1 Region Charge is consumed per Region Boss attempt

This means:

A full dungeon clear allows 1 boss attempt

Players may stockpile charges (up to 10)

Players can fight the Region Boss multiple times in succession if charged

Design Goals

Encourages dungeon mastery

Allows farming without forcing repetition every time

Prevents infinite boss spam

Respects player time

Charges persist until spent or the region is completed.

26.9 Failure & Retry Rules
Dungeon Failure

If all heroes die mid-floor:

The run ends

The dungeon resets to the start of that floor

On retry, the player may:

Restart the same floor

Choose any previously unlocked lower floor

Region Boss Failure

Shopkeeper survives

Heroes may die permanently

Charges are not refunded

Boss may be retried if charges remain

26.10 Rewards & Drops
Dungeon Boss Rewards

Resources

Gold

Chance at higher-tier materials

No guaranteed high-rarity drops.

Region Boss Rewards
First Defeat (Campaign Clear Only)

Guaranteed Legendary item

Region progression unlock

One region-specific crafting material

Subsequent Defeats

Legendary no longer guaranteed

Drops roll from:

Uncommon

Rare

Epic

Legendary (low chance)

Prevents legendary bloat while keeping farming meaningful.

26.11 Boss Repetition & Scaling

Dungeon bosses:

Scale modestly with dungeon tier

Region bosses:

Fixed difficulty

Serve as progression benchmarks

Do not scale infinitely

26.12 Godot / Claude Implementation Notes

Bosses are implemented using:

Enemy entity

Phase Controller

Ability unlock flags

Fixed trigger logic

No behavior trees required.
Deterministic execution only.