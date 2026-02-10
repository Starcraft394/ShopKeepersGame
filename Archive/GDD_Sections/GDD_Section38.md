SECTION 38 — ENEMY AI & TARGETING LOGIC

This section defines how enemies think, how they choose targets, and how they act in combat.

Enemy AI is designed to be:

Predictable but not trivial

Readable to the player

Scalable across regions

Compatible with turn-based grid combat

38.1 AI Design Goals

Clarity Over Complexity

The player should understand why enemies act the way they do

Intent indicators always reflect next action

Threat-Based, Not Random

Enemies evaluate targets based on threat and opportunity

Randomness is used only as a tiebreaker

Tiered Intelligence

Early regions use simple AI

Later regions unlock advanced behaviors

Bosses override standard rules

38.2 Enemy AI Tiers

Enemy behavior is defined by AI Tier, not enemy type.

AI Tier 0 — Feral

(Region 1)

Always attacks nearest valid target

No ability usage

No positioning logic

Ignores status effects

Used for:

Wildlife

Early corrupted creatures

AI Tier 1 — Basic Combatant

(Region 2–3)

Chooses targets based on proximity + low HP

May avoid heavily armored targets

Can use one basic ability on cooldown

Understands taunt

Used for:

Trained humanoids

Organized monsters

AI Tier 2 — Tactical

(Region 4–5)

Evaluates threat score

Prioritizes:

Healers

Low-defense units

Units with dangerous status effects

Uses abilities intelligently

Can reposition

Used for:

Elite enemies

Dungeon captains

AI Tier 3 — Strategic

(Region 6–7, Bosses)

Predicts player formations

Baits cooldowns

Targets synergies

Spawns or commands sub-units

Used for:

Bosses

Commanders

Void entities

38.3 Target Evaluation System

Each enemy calculates a Target Score for every valid enemy unit.

Base Formula (Conceptual)
Target Score =
    Threat Value
  + Vulnerability Value
  + Opportunity Modifiers
  - Deterrents

38.3.1 Threat Value

Calculated from:

Damage dealt recently

Healing performed

Buffs applied

Aggro-generating abilities

High threat = more likely target.

38.3.2 Vulnerability Value

Increases when:

HP is low

Armor / defense is low

Unit is crowd-controlled

Unit is isolated

38.3.3 Opportunity Modifiers

Bonuses applied for:

Backline access

AoE potential

Ability synergy (e.g., shock stacks present)

Finishing blow potential

38.3.4 Deterrents

Reduces score when:

Target has taunt

Target has thorns / retaliation

Target has high defense

Target is guarded

38.4 Taunt & Forced Targeting Rules

Taunt overrides target scoring

If multiple taunts exist:

Highest taunt strength wins

Bosses may partially resist taunt

Taunt duration is always visible to the player.

38.5 Enemy Ability Usage Logic

Enemies with abilities follow this order:

Check Ability Availability

Cooldown

Resource cost

Check Value

Will it hit multiple targets?

Will it interrupt?

Will it secure a kill?

Execute Ability

If no valid ability → basic attack

Abilities are never wasted randomly.

38.6 Movement & Positioning Rules

Enemies may reposition if:

A better target is reachable

They can avoid retaliation

A formation bonus is disrupted

Restrictions:

One movement per turn

No movement if rooted

Boss movement rules may override

38.7 Enemy Intent System

Before acting, each enemy displays an Intent Icon:

Attack target

Ability type

AoE indicator (if applicable)

Intent is:

Locked once shown

Only changed by interrupts or forced movement

38.8 Status Effect Awareness

Enemy AI:

Understands stuns, roots, taunts

Partially understands DoTs

Fully understands countdown effects (e.g., Doom)

Higher AI tiers respond more intelligently.

38.9 Boss AI Overrides

Bosses may:

Ignore taunt

Target objectives instead of units

Spawn hazards or turrets

Act on multiple initiative counts

Boss logic is scripted on top of AI Tier 3.

38.10 Defense Battle AI Adjustments

In Town Defense:

Enemies prioritize structures only if allowed

Otherwise follow standard targeting

No permanent death for heroes

AI difficulty scales with region progression

38.11 Difficulty Scaling Hooks

Enemy AI scaling knobs:

Target score weights

Ability cooldown efficiency

Willingness to reposition

Coordination between enemies

Used by:

Region

Dungeon tier

Post-campaign mode