Section 25 — Enemy AI Archetypes & Behavior Rules
Why this is the correct next section

This section will:

Bridge Class Kits (24) → Bosses (26) cleanly

Give Claude behavior logic, not just stats

Prevent enemies from feeling like “heroes but worse”

Keep combat readable in a turn-based grid

Avoid needing per-enemy bespoke AI early

This also directly supports:

Town Defense auto-resolve

Dungeon difficulty scaling

Region identity

Late-game Void / Necropolis enemies

Below is the FULL, copy-paste-safe Section 25, written in the same studio GDD style, with explicit rules, Godot-friendly logic, and Fix Notes at the end.

25. Enemy AI Archetypes & Behavior Rules
25.1 Design Goals

Enemy AI is designed to be:

Readable — players can predict intent

Consistent — same archetype behaves the same everywhere

Composable — bosses and elites build on archetypes

Non-cheaty — no hidden stat inflation or reaction timing

Enemy AI does not adapt dynamically to player strategy mid-combat. Difficulty is created through composition, positioning, and ability timing, not reactive intelligence.

25.2 Turn-Based AI Core Rules

All enemies follow these universal rules:

Enemies act once per turn

Enemies choose one action:

Move

Attack

Use ability

Enemies do not change targets mid-action

Enemies do not pre-calculate future turns

Enemies never break grid rules

This keeps AI deterministic and debuggable in Godot.

25.3 Enemy Targeting Priority System

Enemies select targets using the following priority order:

Forced Targeting
(Taunt, Doom effects, AI overrides)

Threat Value

Units dealing highest recent damage

Units applying control effects

Proximity

Nearest reachable target

Role Bias

Archetype-specific preference (see below)

If multiple targets tie, selection is random.

25.4 Enemy Archetype List (Core)

Each enemy belongs to one primary archetype.

25.4.1 Bruiser

Role: Frontline pressure

Behavior:

Prioritizes nearest enemy

Moves forward aggressively

Rarely retreats

Ability Use:

Uses abilities on cooldown

No target switching logic

Examples:

Orc Warriors

Undead Knights

Crystal Sentinels

25.4.2 Skirmisher

Role: Flanking damage

Behavior:

Prioritizes low-armor or isolated units

Avoids heavily defended tiles

Will reposition if blocked

Ability Use:

Prefers attacking backline

Uses mobility abilities first

Examples:

Ashblades

Void Stalkers

Beast Hunters

25.4.3 Caster

Role: Pressure & control

Behavior:

Stays at max range

Avoids frontline engagement

Repositions if threatened

Ability Use:

Uses abilities before basic attacks

Prioritizes clustered targets

Examples:

Dark Acolytes

Storm Shamans

Crystal Channelers

25.4.4 Support

Role: Sustain & disruption

Behavior:

Positions behind allies

Avoids danger zones

Retreats when threatened

Ability Use:

Buffs allies under threat

Debuffs highest-damage hero

Examples:

Void Herald enemies

Fungal Shamans

Cult Priests

25.4.5 Sentinel

Role: Area denial

Behavior:

Holds position

Controls chokepoints

Rarely advances

Ability Use:

Uses zone or reaction abilities

Punishes movement

Examples:

Crystal Wardens

Living Statues

Void Anchors

25.5 Elite Enemy Modifiers

Elite enemies are not new archetypes.

Instead, they gain 1–2 modifiers:

+1 ability

Enhanced version of an archetype rule

Increased HP / armor

Minor immunity (e.g., cannot be slowed)

Elites do not gain new AI logic.

25.6 Boss AI Rules

Bosses are composed of:

1 primary archetype

1–2 phase triggers

Scripted ability timing

Bosses:

Do not react to player actions dynamically

Do not change archetypes mid-fight

Use abilities at fixed HP thresholds or turn counts

This keeps bosses fair and learnable.

25.7 Region-Based AI Flavor

Regions modify how archetypes express, not their rules:

Region	AI Flavor
Region 1	Simple, direct
Region 2	Aggressive, swarm behavior
Region 3	Control-heavy, movement denial
Region 4	Burst windows, execution
Region 5	Position punishment
Region 6	Attrition & inevitability
Region 7	Target denial & rule bending
25.8 Town Defense AI Simplification

Town Defense battles use the same archetypes with simplifications:

No repositioning logic

No retreat logic

Reduced target priority layers

This allows fast auto-resolution without invalid outcomes.

25.9 Godot Implementation Notes

Enemy AI can be implemented as:

EnemyArchetype enum

Shared ChooseAction() function

Per-archetype targeting bias

Fixed priority weights

No behavior trees or planners required.

25.10 AI Debug Visibility (Developer Only)

For development:

Display enemy archetype icon

Optional debug overlay showing chosen target

This is not player-facing.