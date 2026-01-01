27. Status Effect Registry
27.1 Purpose & Design Philosophy

Status effects in Shops & Shadows exist to:

Create tactical pressure

Reinforce class and weapon identity

Reward positioning, timing, and preparation

They are not intended to:

Replace core combat decisions

Create hidden math or opaque scaling

Become mandatory for success

All status effects must be:

Readable at a glance

Predictable in outcome

Limited in scope

If a status effect cannot be clearly understood from its icon, number, and tooltip, it does not belong in the game.

27.2 Status Effect Categories

Every status effect belongs to exactly one category.

Allowed Categories

Damage-over-Time (DoT)

Control & Disruption

Buffs & Enhancements

Debuffs & Weakening

Countdown Effects

Special / Rule-Bending (late-game only)

Categories exist to prevent overlapping mechanics and runaway complexity.

27.3 Global Stack Rules

All status effects obey global stacking rules.

Stack Types

Flat Stacks

Each stack adds a fixed value

Example: +2 damage per stack

Duration Stacks

Adds or refreshes duration

Countdown Extension

Adds time before effect triggers

Global Rules

Status effects may define a max stack cap

Reapplying an effect:

Refreshes duration or

Extends countdown

Effects never scale exponentially

Percentage scaling is avoided unless explicitly stated

27.4 Countdown Status Effects

Countdown effects use a clock icon.

Rules

Number shown = turns remaining

Countdown decreases at end of turn

Effect triggers when countdown reaches 0

Stack Interaction

Adding stacks:

Increases countdown duration

Increases final effect magnitude proportionally

Power is derived from time invested, not burst stacking

Use Cases

Doom

Delayed explosions

Ritual completions

Countdown effects are primarily used by:

Bosses

Late-game classes

High-tier enemies

27.5 Damage-over-Time (DoT) Effects

DoTs represent sustained pressure.

Rules

Trigger at end of affected unit’s turn

Scale linearly

Respect armor and mitigation rules unless stated otherwise

Cannot crit

Are removed on death

Boss Interaction

Bosses may have:

Reduced DoT duration

Reduced max stacks

Bosses are never fully immune unless explicitly stated

27.6 Control & Disruption Effects

Control effects limit enemy actions.

Common Effects

Stun (skip next action)

Daze (reduced accuracy / effectiveness)

Root (movement restricted)

Slow (initiative reduction)

Push / Pull (forced movement)

Rules

Control effects do not stack indefinitely

Bosses resist control:

Reduced duration

Partial effect

Hard immunity is rare and clearly communicated

27.7 Buffs & Debuffs

Buffs and debuffs modify stats temporarily.

Rules

Prefer flat values over percentages

Duration-based

Visible stacking indicators

Buffs and debuffs of same type do not multiply

Priority

Highest magnitude applies

Newer applications refresh duration

27.8 Tile-Based Status Effects

Tiles may apply effects but are not status effects themselves.

Rules

Tiles apply effects on:

Entry

Start of turn

Tile effects:

Are visually distinct

Do not stack infinitely

Leaving a tile may remove the effect unless stated otherwise

This keeps tiles tactical without overwhelming the status system.

27.9 Status Effects & Bosses

Bosses interact with status effects differently.

Boss Rules

Reduced stack caps

Reduced duration

Phase-based cleansing allowed

No full immunity unless explicitly designed

Bosses are meant to be pressured, not disabled.

27.10 Status Effects & Weapons

Weapons are a primary source of status effects.

Rules

Each weapon type may:

Apply a thematic status

Modify how a status behaves

Higher-tier weapons may:

Increase stack cap

Extend duration

Change application timing

Weapon passives enhance statuses — they do not replace them.

27.11 Cleansing, Resistance & Immunity
Cleansing

Removes one or more effects

Does not affect tiles

Rare and intentional

Resistance

Reduces duration or effect

Never nullifies entirely unless stated

Immunity

Extremely rare

Used only for specific boss mechanics

Always communicated clearly

27.12 Visual Language & UI Rules

Status clarity is mandatory.

UI Rules

Each status has:

Unique icon

Consistent color

Stack number or countdown clock

Tooltips always show:

Effect

Stack behavior

Duration logic

Numbers always mean the same thing:

Stacks = power

Clock = time

27.13 Status Effect Registry (Authoritative Placeholder)

This section will contain:

Final list of approved status effects

One-line description

Category

Stack type

No new status effects may be added outside this registry.