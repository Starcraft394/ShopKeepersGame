Excellent — this is a core spine section, and doing it now is exactly right.
Below is SECTION 39 — Status Effects System, fully drafted, Claude/Godot–ready, copy-paste safe, no placeholders, and aligned with everything you’ve already locked (turn-based grid, countdown mechanics, readable UI, no over-stacking bloat).

SECTION 39 — STATUS EFFECTS SYSTEM

This section defines all rules governing status effects, including how they are applied, stacked, displayed, resolved, and removed.

The system is designed to be:

Turn-based

Readable

Composable across abilities, items, and enemies

Expandable without rework

39.1 Design Goals

Clarity First

Every status effect must clearly communicate:

What it does

How long it lasts

What happens when it resolves

Limited Stacking, Meaningful Impact

Fewer stacks, stronger effects

Avoids “spreadsheet combat”

Unified Countdown Logic

No hidden timers

Countdown-based effects resolve predictably

39.2 Status Effect Categories

All status effects fall into one of five categories:

A. Damage Over Time (DoT)

Deals damage each turn or on resolution

Examples:

Burn

Bleed

Shock (non-stun damage component)

Poison

B. Control

Restricts actions or positioning

Examples:

Stun

Root

Daze

Fear

C. Buff

Improves stats or abilities

Examples:

Defense Up

Attack Up

Cooldown Reduction

Shield

D. Debuff

Reduces stats or applies penalties

Examples:

Armor Break

Weakness

Slow

Vulnerability

E. Countdown Effects

Resolve only when timer reaches zero

Damage or transformation occurs on resolution

Examples:

Doom

Delayed Explosion

Crystal Shatter

Void Collapse

39.3 Universal Status Properties

Every status effect has the following properties:

Property	Description
Name	Unique identifier
Category	One of the five categories
Source	Ability / Item / Enemy
Stacks	Current stack count
Max Stacks	Hard cap
Duration / Timer	Turns remaining
Refresh Rule	Replace / Extend / Amplify
Dispel Type	Buff / Debuff / None
Icon	UI reference
Priority	Resolution order
39.4 Stack Behavior Rules
39.4.1 Stack Types

Status effects use one of the following stack models:

A. Linear Stack

Each stack adds flat value

Example:

Burn: +2 damage per stack

B. Threshold Stack

Effects trigger at stack thresholds

Example:

Shock: At 5 stacks → Daze

C. Countdown Extension

Each stack increases resolution timer

Used for Doom-type effects

39.4.2 Stack Limits

Most effects cap at 3–5 stacks

Boss-only effects may cap higher

UI always shows:

Stack count

Max possible

39.5 Countdown Effects (Core Mechanic)

Countdown effects are a key system pillar.

Rules

Countdown decreases at end of unit’s turn

When countdown reaches 0:

Effect resolves

Damage / transformation occurs

Status is removed

Example — Doom

Doom(2):

Resolves in 2 turns

Doom(4):

Resolves in 4 turns

Deals increased damage

Applying additional stacks:

Increases timer

Increases final damage

39.6 Status Application Rules

Status application always succeeds unless:

Target is immune

Status explicitly resists

If status already exists:

Apply stack rules

Refresh or extend duration as defined

Immunity is explicit, not assumed

39.7 Removal & Cleansing
Removal Types

Cleanse Buff

Cleanse Debuff

Full Purge

Manual Removal (Ability-specific)

Rules

Countdown effects are harder to cleanse

Boss effects may be immune to cleanse

39.8 Status Priority & Resolution Order

Statuses resolve in this order:

Control checks (stun, root)

Countdown resolution

DoT ticks

Buff / Debuff expiry

This order is consistent across all combat types.

39.9 UI & Readability Rules

Each status icon shows:

Icon image

Stack number

Countdown (if applicable)

Color coding:

Red: Damage

Blue: Control

Green: Buff

Purple: Countdown / Corruption

Hover tooltip includes:

Full description

Source

Resolution effect

39.10 Enemy vs Hero Status Rules

Heroes and enemies use the same system

Bosses may have:

Stack resistance

Partial immunity

Modified resolution

39.11 Status Synergies

Some statuses interact:

Shock + Wet → Bonus effect

Burn + Oil → Amplified damage

Doom + Void → Extended resolution

Synergies are explicitly defined, never implicit.

39.12 Expansion Hooks

System supports:

New categories

Region-specific effects

Post-campaign corruption mechanics

Item-based status modification

No refactor required.