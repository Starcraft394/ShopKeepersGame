------------------------------------------------------------
📘 SECTION 24 — CLASS ABILITY KITS
------------------------------------------------------------
⭐ 24.1 DEFENDER (Region 1 Class | Vanguard Archetype)

Role: Tank / Protector
Fantasy: A heavily armored frontline hero who protects allies, absorbs hits, controls enemy focus, and stabilizes early- to mid-game runs.

Defenders define the combat pacing in early regions and remain relevant into late game due to their exceptional stability, grid control, and ability to save weaker backline heroes.

24.1.0 CLASS IDENTITY SUMMARY
🎭 Theme

Heavy shield, steadfast stance, unwavering resolve.
Defenders serve as the group’s anchor — predictable, safe, and incredibly valuable for inexperienced and veteran players alike.

🧩 Gameplay Identity

Consistent turn order (slow but reliable)

High HP

Flat damage reduction

Access to Taunt, Shield, and Control

Lower damage output than other classes

Outstanding defensive synergy with any race

🪓 Recommended Weapons

Sword (Cleave)

Hammer (Stun chance)

Shield-type Ability Modifiers (special legendary variants later)

Axe (Armor shred + tank hybrid builds)

🧱 Grid Presence

Always in the front row, and many abilities reference adjacent allies or enemies targeting others.

------------------------------------------------------------
⭐ 24.1.1 PASSIVE A — “Bulwark Stance”

(Always Active)

Description:
The Defender gains a small amount of flat damage reduction whenever they start their turn, stacking gradually through the fight.

Effect:

At the start of the Defender’s turn → gain +1 Flat Armor (capped at 5)

Lost at end of combat

Applies to all incoming hits (physical & magical)

Why this works:

Flat reduction is extremely stable for early game

Allows Defenders to withstand multi-hit enemies later

Simple to compute and easy for players to understand

GDD Note: This passive interacts naturally with Section 23’s flat-value-only philosophy.

------------------------------------------------------------
⭐ 24.1.2 PASSIVE B — “Shielding Presence”

(Unlocks at mid-level)

Description:
Nearby allies feel safer while standing next to a Defender.

Effect:

Allies adjacent to the Defender gain +2 Shield at the start of their turn.

Shields do not stack; refreshed each turn.

Why this works:

Encourages positional play

Benefits squishy healers/supports

Helps new players who naturally group units together

------------------------------------------------------------
⭐ 24.1.3 CLASS ABILITY A — “Guardian’s Challenge”

(Low cooldown, core tank action)

Property	Value
Cooldown	2 turns
Targeting	Single enemy
Effect	Apply Taunt for 1 turn + deal light damage
Additional	Defender gains +2 Armor for 1 turn

Description:
The Defender strikes an enemy and forces it to target them next turn. Great for controlling dangerous attackers or bosses.

Design Goals:

Defines the Defender role

Works in every region

Synergizes with flat damage reduction from Passive A

Prevents burst damage on healer classes

------------------------------------------------------------
⭐ 24.1.4 CLASS ABILITY B — “Aegis Slam”

(High-impact, defensive AoE hybrid)

Property	Value
Cooldown	4 turns
Targeting	2x2 cluster around the Defender or single heavy hit
Effect	Moderate physical damage + applies Slow
Additional	Grants the Defender +10 Shield

Description:
A powerful shield bash that disrupts enemy formations and buys time for allies to act.

Design Notes:

Slow fits into initiative-based combat

Creates space for healers to recover

Optional targeting flexibility (single or small AoE)

------------------------------------------------------------
⭐ 24.1.5 WEAPON SYNERGY NOTES

Defenders work well with all frontline weapons:

🗡 Sword (“Cleave” Weapon Ability)

Allows Defender to contribute small AoE damage

Works great with Slow from Aegis Slam

Good all-around option

🔨 Hammer (“Crushing Blow” Weapon Ability)

Occasional stun → perfect tank synergy

Slow + Stun is potent crowd control

Works in both dungeons and town defense

🪓 Axe (“Sundering Chop” Weapon Ability)

Reduces enemy armor

Helps compensate for Defender’s normally low damage

Enables hybrid tank/off-tank builds

🛡 Legendary Shields (later regions)

Some legendary shields may modify Aegis Slam or Guardian’s Challenge.
These will be introduced around Regions 5–7.

------------------------------------------------------------
⭐ 24.1.6 FULL ABILITY DEFINITIONS (For Claude & Godot)

Following Section 23’s schema.

Ability: Basic Attack

Source: Weapon
Type: Basic
Cooldown: 0
Targeting: Single enemy
Effect: Flat damage based on weapon → physical or magical
Status: None

Ability: Guardian’s Challenge

Source: Class A
Cooldown: 2 turns
Targeting: Single enemy
Effect:

Deal light physical damage

Apply Taunt (1 turn)
Additional:

Defender gains +2 Armor (1 turn)
Tags: Physical, Control, Tank

Ability: Aegis Slam

Source: Class B
Cooldown: 4 turns
Targeting:

Either single target (heavy hit)

Or 2x2 area centered on chosen enemy
Effect:

Apply Slow (1 turn)

Deal moderate physical damage
Additional:

Defender gains +10 Shield
Tags: Physical, Control, Shield, Tank

Passive A: Bulwark Stance

Effect: At start of Defender’s turn, gain +1 Flat Armor (max 5).
Tags: Defense, Scaling

Passive B: Shielding Presence

Effect: Adjacent allies gain +2 Shield at start of their turn (refreshes).
Tags: Support, Positioning

------------------------------------------------------------
📘 SECTION 24.2 — WARDEN (Region 1 Class #2 | Healer–Protector Hybrid)
------------------------------------------------------------
24.2.0 CLASS IDENTITY SUMMARY
🎭 Theme

A keeper of life, nature, and protective rituals.
Not a cleric of divine magic — more of a forest guardian whose healing feels organic and grounded.

🧩 Gameplay Identity

Low–moderate HP

Low physical damage

High sustain & healing

Excellent with shields + regen

Area support but not overpowering

Helps stabilize early dungeon runs

Synergizes extremely well with every race (especially Mossfolk and Elves)

🪓 Recommended Weapons

Staff (Arcane Pulse) → AoE heal/damage hybrids work well

Wand (Focus Beam) → Single-target supportive damage

Tome (Spellweave) → Enhances next class ability (best synergy)

🧱 Grid Presence

Primarily back row.
Some abilities target rows/columns for strategic positioning.

------------------------------------------------------------
⭐ 24.2.1 PASSIVE A — “Living Bond”

(Always Active)

Description:
Whenever the Warden heals an ally, they also heal the lowest-HP ally for a small amount.

Effect:

When Warden heals any ally →
Heal lowest-HP ally for +2 HP

Triggers once per Warden action (not per target)

Why this works:

Provides stabilization, not burst

Helps inexperienced players keep parties alive

Encourages Warden to use regular heals frequently

------------------------------------------------------------
⭐ 24.2.2 PASSIVE B — “Verdant Renewal”

(Unlocks at mid-level)

Description:
Nature energy flows through the Warden, granting gentle ongoing regeneration to the party.

Effect:

At end of each round, all allies gain +1 Regen (1 turn)

If an ally already has Regen → refresh duration

Stacks do not increase magnitude

Why this works:

Soft sustain over time

Scales smoothly across regions

Encourages long fights for defensive teams

------------------------------------------------------------
⭐ 24.2.3 CLASS ABILITY A — “Nature’s Grace”

(Core heal, low cooldown)

Property	Value
Cooldown	2 turns
Targeting	Single ally
Effect	Restore moderate HP
Additional	Apply Regen (2 turns) to target

Description:
A simple, reliable heal that stacks with passive regen.

Design Notes:

Bread-and-butter sustain

Not too strong but very consistent

Regen synergy between A and Passive B feels natural

------------------------------------------------------------
⭐ 24.2.4 CLASS ABILITY B — “Barkskin Blessing”

(Hybrid defensive buff)

Property	Value
Cooldown	4 turns
Targeting	Single ally OR self
Effect	Apply +8 Shield
Additional	Apply +2 Flat Armor (2 turns)

Description:
A burst of natural armor plating that strengthens the frontline or rescues a squishy backliner.

Why this works:

Perfect early-game defensive spike

Helps protect Striker/Bladedancer/low-HP classes

Combines well with Defender and Dragonkin

------------------------------------------------------------
⭐ 24.2.5 WEAPON SYNERGY NOTES

Warden does not rely on weapon damage.
They rely on weapon abilities for utility or supplemental effects.

📘 Tome (“Spellweave”) — Best Overall

Tome ability buffs your next Class Ability

Perfect for Barkskin or Nature’s Grace

Lets Warden hit higher-tier thresholds smoothly

Allows a “burst heal turn” pattern (Tome → Grace)

🔮 Staff (“Arcane Pulse”)

AoE pulse lets Warden contribute a little damage

Staff builds help in Town Defense where healing alone may stall

Combos with Barkskin to keep frontlines stable

✨ Wand (“Focus Beam”)

Most single-target value

Allows Warden to snipe weakened enemies without wasting healing turns

Low cooldown helps maintain turn rhythm

------------------------------------------------------------
⭐ 24.2.6 FULL ABILITY DEFINITIONS (Claude/Godot Ready)
Ability: Basic Attack

Source: Weapon
Type: Basic
Cooldown: 0
Targeting: Single enemy
Effect: Light magical/physical damage depending on weapon
Status: None

Ability: Nature’s Grace

Source: Class A
Cooldown: 2
Targeting: Single ally
Effect:

Heal target for moderate HP

Apply Regen (2 turns)
Additional:

Triggers Living Bond (+2 heal to lowest-HP ally)
Tags: Healing, Regen, Support

Ability: Barkskin Blessing

Source: Class B
Cooldown: 4
Targeting: Self or single ally
Effect:

Apply +8 Shield

Apply +2 Flat Armor (2 turns)
Tags: Shield, Armor, Targeted Support

Passive A: Living Bond

Effect: When Warden heals any ally → heal lowest-HP ally for +2 HP.
Tags: Sustain, Multi-target healing

Passive B: Verdant Renewal

Effect: At end of round → all allies gain +1 Regen (1 turn).
Tags: Sustain, Auto-heal

------------------------------------------------------------
📘 24.3 STRIKER — Region 1 Class #3 (Agile DPS / Dual-Path Fighter)
------------------------------------------------------------
24.3.0 CLASS IDENTITY SUMMARY
🎭 Theme

A fast, precise combatant skilled with both blades and light ranged weapons.
Strikers excel at:

Finishing weakened enemies

Acting early in turn order

Applying debuffs through speed and finesse

Flexible positioning

🧩 Gameplay Identity

High initiative (often acts first)

Low HP and low defenses → fragile

High single-target damage

Able to reposition or react to openings

Flexible builds thanks to melee or ranged weapon paths

🪓 Recommended Weapons

Daggers → Bleed builds, fast ability cycling

Throwing knives → Lightweight ranged multi-target

Short bow → Early long-range pressure

Sword → Balanced melee DPS (some players prefer the consistency)

🧱 Grid Presence

Backline for ranged builds
Frontline/second-row for melee builds
Tile-neutral class

------------------------------------------------------------
⭐ 24.3.1 PASSIVE A — “Momentum Edge”

(Always Active)

Description:
The Striker becomes more lethal when acting before their target.

Effect:
If the Striker acts before their target this turn:
→ Their first damaging action deals +2 bonus damage.

Why this works:

Simple, initiative-based DPS identity

Promotes agility weapons (daggers, knives, bows)

Does not scale into absurdity

Gives early tactical value to speed

------------------------------------------------------------
⭐ 24.3.2 PASSIVE B — “Finisher’s Instinct”

(Unlocks at mid-level)

Description:
Striker excels at finishing weakened foes.

Effect:
When the Striker attacks an enemy below 25% HP:
→ Deal +3 bonus damage
(Triggers once per attack action)

Why this works:

Helps remove threats efficiently

Makes Striker feel good even when basic attacking

Stays relevant throughout the campaign

------------------------------------------------------------
⭐ 24.3.3 CLASS ABILITY A — “Twin Strike”

(Fast, low cooldown burst)

Property	Value
Cooldown	2 turns
Targeting	Single enemy
Effect	Two separate light hits
Additional	Each hit can trigger on-hit effects (bleed, burn, etc.)

Description:
A rapid two-hit combo that synergizes extremely well with:

Bleed weapons

Poison items

Monster weakness windows

Design Notes:

More reliable for damage than basic attack

Momentum Edge applies to the first hit

Finisher's Instinct may apply to both hits if enemy is low

------------------------------------------------------------
⭐ 24.3.4 CLASS ABILITY B — “Shadowstep”

(Mobility + defense tool)

Property	Value
Cooldown	4 turns
Targeting	Self
Effect	Gain Evasion (1 turn): next enemy attack against Striker deals 0 damage
Additional	Striker may reposition to any other tile (optional)

Description:
A survival tool that allows the fragile Striker to:

Avoid lethal hits

Escape AoE patterns

Change to back row or flank positions

Trigger tactical setups in certain fights

Why this works:

Reinforces Striker fantasy without making them tanky

Uses grid mechanics meaningfully

Turn-based clarity → simple and understandable

------------------------------------------------------------
⭐ 24.3.5 WEAPON SYNERGY NOTES
🗡 Daggers

Fastest initiative

Bleed synergy (Twin Strike applies bleed twice)

Shadowstep complements close-range play

🔪 Throwing Knives

Multi-target weapon ability fits the Striker’s speed theme

Great for finishing low enemies across the grid

Good mid-range flexibility

🏹 Short Bow

Keeps Striker in the backline

High initiative synergizes with Momentum Edge

Power Shot weapon ability helps break armored enemies

🗡 Sword

Balanced path for players who want less fragile melee builds

Cleave helps Striker contribute slight AoE damage

Striker is the only Region 1 class capable of acting effectively in both melee and ranged roles depending on weapon choice.

------------------------------------------------------------
⭐ 24.3.6 FULL ABILITY DEFINITIONS (Claude/Godot Ready)
Ability: Basic Attack

Source: Weapon
Type: Basic
Cooldown: 0
Targeting: Single enemy
Effect: Deal flat physical damage based on weapon
Notes:

Triggers Momentum Edge if Striker goes first

Can trigger Finisher’s Instinct

Ability: Twin Strike

Source: Class A
Cooldown: 2
Targeting: Single enemy
Effect:

Hit 1: light damage

Hit 2: light damage

Each hit may apply weapon status effects
Tags: Physical, Multi-hit, DPS

Ability: Shadowstep

Source: Class B
Cooldown: 4
Targeting: Self
Effect:

Gain Evasion (1 turn) → ignore next incoming attack

Optional: Move Striker to any tile
Tags: Defense, Mobility, Utility

Passive A: Momentum Edge

Effect:
If Striker acts before their target → first damaging action deals +2 damage.
Tags: Initiative, Burst

Passive B: Finisher’s Instinct

Effect:
Deal +3 damage to enemies under 25% max HP.
Tags: Execute, Cleanup

------------------------------------------------------------
📘 24.4 DRUID — Region 2 Class #1 (Sporecaster / Nature Manipulator)
------------------------------------------------------------
24.4.0 CLASS IDENTITY SUMMARY
🎭 Theme

A fungal-channeling mystic who manipulates life cycles—growth, decay, and renewal.
Not a Warden-style “healer,” but a tactical support + damage-over-time caster.

🧩 Gameplay Identity

Specializes in DoT, spores, regen, and debuffs

Moderate initiative

Moderate HP, low defense

Backline class

Excels at prolonged fights, whittling bosses down

Excellent synergy with Mossfolk race

🪄 Recommended Weapons

Staff → AoE pulse that spreads spores

Tome → Empower next spore or heal

Wand → Single-target DoT amplification

🧱 Grid Presence

Primarily back row, but abilities affect clusters, rows, or all enemies.

------------------------------------------------------------
⭐ 24.4.1 PASSIVE A — “Spore Bloom”

(Always Active)

Description:
Whenever the Druid damages an enemy with an ability, that enemy gains 1 stack of Spores.

Effect:

Spores: At end of enemy’s turn → take +1 damage per stack

Max stacks: 3 per enemy

Lasts until fight ends unless overwritten by Druid ability

Why this works:

Encourages sustained damage

Rewards staff + AoE builds

Simple, trackable DoT mechanic

Does not overwhelm early-game players

------------------------------------------------------------
⭐ 24.4.2 PASSIVE B — “Mycelial Renewal”

(Unlocks at mid-level)

Description:
The Druid’s spores don’t just harm — they heal.

Effect:
At end of each round →
The ally with the lowest HP gains +3 healing for each enemy currently affected by Spores.

Example:
If 2 enemies have Spores → lowest ally heals for +6.

Why this works:

Perfect Region 2 flavor (spores both harm and heal)

Gives the Druid a “sustain engine” without duplicating the Warden

Encourages using AoE weapons

------------------------------------------------------------
⭐ 24.4.3 CLASS ABILITY A — “Sporeburst”

(DoT-inflicting AoE)

Property	Value
Cooldown	3 turns
Targeting	2×2 cluster
Effect	Deal light magic damage + apply 2 stacks of Spores
Additional	If target already had Spores → increase to max (3 stacks)

Description:
A fungal explosion that rapidly spreads spores across enemy ranks.

Design Notes:

Core DoT-spreader

Works for melee and ranged clusters

Powerful setup ability especially for bosses

------------------------------------------------------------
⭐ 24.4.4 CLASS ABILITY B — “Cycle of Life”

(Mixed heal + damage conversion ability)

Property	Value
Cooldown	5 turns
Targeting	Single ally + global enemy check
Effect	

Heal an ally for moderate HP

For each enemy with Spores: deal +1 damage to a random enemy
| Additional | The healed ally gains Regen (1 turn) |

Description:
A ritual channeling fungal life force — healing allies while radiating damage outward.

Why it works:

Hybrid ability: both healing and damage

Synergizes strongly with Spore Bloom

Tremendous value in multi-enemy encounters

Not overwhelming for new players due to small numbers

------------------------------------------------------------
⭐ 24.4.5 WEAPON SYNERGY NOTES
💠 Staff

Best AoE application of Spores

Staff’s Arcane Pulse applies Spore Bloom → excellent synergy

📘 Tome

Strongest synergy with Cycle of Life

Allows burst healing or spore amplification

Good for support-focused builds

🔮 Wand

Best for single-target spore stacking

Helps in boss fights

Wand’s Focus Beam allows targeted damage where spores matter most

Design note:
Druid remains a caster, but weapon path determines whether they prefer:

AoE DoT (Staff)

Support (Tome)

Single-target boss pressure (Wand)

------------------------------------------------------------
⭐ 24.4.6 FULL ABILITY DEFINITIONS (Claude/Godot Ready)
Ability: Basic Attack

Source: Weapon
Cooldown: 0
Target: Single enemy
Effect: Deal light magic damage
Additional: Does not apply Spores unless weapon allows it

Ability: Sporeburst

Source: Class A
Cooldown: 3
Targeting: 2×2 cluster
Effect:

Deal light magic damage

Apply 2 Spores to each target

If target had Spores → increase to 3
Tags: Magic, AoE, DoT

Ability: Cycle of Life

Source: Class B
Cooldown: 5
Targeting: Single ally (heal)
Effect:

Heal ally (moderate HP)

Apply Regen (1 turn)

For each enemy with Spores → deal +1 damage to a random enemy
Tags: Hybrid, Healing, DoT synergy

Passive A: Spore Bloom

Effect: Damaging abilities apply 1 Spore (max 3).
Tags: DoT, Scaling

Passive B: Mycelial Renewal

Effect: At round end → lowest-HP ally gains +3 healing per spored enemy.
Tags: Sustain, Spore synergy

------------------------------------------------------------
📘 24.5 FUNGAL BERSERKER — Region 2 Class #2 (FINAL REFINED VERSION)
------------------------------------------------------------
24.5.0 CLASS IDENTITY

A toxic frontline bruiser who converts pain and decay into raw fungal power.
Consumes DoTs from allies and enemies alike to ramp into irresistible damage.

24.5.1 SIGNATURE MECHANIC — FERAL CHARGES (Revised)

Feral Charges = stacks of fungal adrenaline.

Rules

Max stacks: 5

Gained by:

Consuming DoTs on enemies (Devour Affliction)

Consuming DoTs on allies (Cannibalize Affliction)

Lost when:

Spent by abilities

End of combat

Each Feral Charge grants:
→ +1 flat damage to all Berserker attacks

Why flat damage is perfect:

Simple, predictable, and stays meaningful from early to late game.

------------------------------------------------------------
⭐ 24.5.2 PASSIVE A — “Devour Affliction”

When the Berserker attacks an enemy with any DoT, they:

Consume 1 stack of that DoT

Deal +1 bonus damage on that attack

Gain +1 Feral Charge

DoTs include: Bleed, Poison, Burn, Spore, Hex, Curse, Frostbite, etc.

------------------------------------------------------------
⭐ 24.5.3 PASSIVE B — “Feral Resilience”

The Berserker becomes tougher as their fungal rage grows.

Effect

Gain +1 Armor for every 2 Feral Charges

When reaching 5 charges for the first time each combat → Heal +3 HP

This makes “holding” charges a defensive choice.

------------------------------------------------------------
⭐ 24.5.4 ACTIVE ABILITY A — “Cannibalize Affliction”

Cooldown: 5
Target: 1 ally

Effect:

Cleanse ALL DoT stacks from the ally

For each DoT stack removed:

Gain +1 Stored Agony

Gain +1 Feral Charge

Berserker’s next attack deals +Stored Agony bonus damage

Stored Agony is consumed after the next attack.

Purpose:

Creates huge swing turns, removes lethal DoTs from the frontline, and fuels Berserker’s power loop.

------------------------------------------------------------
⭐ 24.5.5 ACTIVE ABILITY B — “Retching Frenzy”

Cooldown: 4
Targets: Enemy frontline row

Base Effect:

Deal moderate physical damage to all enemies in the front row

If Berserker has Feral Charges:

Spend up to 2 Feral Charges

For each charge spent:

Deal +2 bonus damage

Apply 1 random DoT (Bleed, Poison, or Spore) to each hit enemy

Why this ability matters:

Creates a strategic choice:

Bank charges → tanky bruiser

Spend charges → explosive AoE damage

Keeps the DoT loop dynamic and satisfying

------------------------------------------------------------
⭐ 24.5.6 WEAPON SYNERGY
⚔ Axes — Best Damage Scaling

Perfect synergy with bonus flat damage from Feral Charges.

🔪 Daggers — High Frequency

More attacks → more Devour Affliction triggers.

🪓 Greatswords — Massive Stored Agony Hits

Slow but devastating when empowered.

🧪 Toxic Blades (later upgrade path)

Generate Poison on hit → self-contained DoT engine → pure synergy.

------------------------------------------------------------
⭐ 24.5.7 CLAUDE/GODOT IMPLEMENTATION SNIPPETS
Devour Affliction (Passive)
on_basic_attack(target):
    if target.has_any_DoT():
        target.consume_DoT_stack(1)
        self.damage_bonus_temp += 1
        self.feral_charges = min(self.feral_charges + 1, 5)

Cannibalize Affliction (Active)
stored = ally.count_all_DoT_stacks()
ally.remove_all_DoTs()
self.feral_charges = min(self.feral_charges + stored, 5)
self.stored_agony = stored

Retching Frenzy (Active)
charges_spent = min(self.feral_charges, 2)
self.feral_charges -= charges_spent
bonus_damage = charges_spent * 2
apply_random_DoT_to_each_frontline_enemy()

Feral Resilience (Passive)
self.armor = floor(self.feral_charges / 2)
if self.feral_charges == 5 and not self.healed_this_combat:
    self.heal(3)
    self.healed_this_combat = true

------------------------------------------------------------
📘 24.6 TIDECHASER — Region 3 Class #1 (Wave-Mage / Flow Manipulator)
------------------------------------------------------------
24.6.0 CLASS IDENTITY SUMMARY
🎭 Theme

A water-shaping battle mage who commands tides, undertows, and swirling currents.
Unlike Warden or Druid, the Tidechaser focuses on:

Grid manipulation

Turn order manipulation

Target repositioning

Movement-based utility

Flow-themed battlefield tempo control

🧩 Gameplay Identity

Midline or backline caster

Medium HP, low armor

Strong control capabilities

Not a healer, not a tank

Very high tactical utility

Synergizes with ANY frontline heroes (Defender, Striker, Berserker)

🌊 Class Fantasy

Where the Warden protects, and the Druid decays, the Tidechaser shifts the flow of combat itself.

------------------------------------------------------------
⭐ 24.6.1 PASSIVE A — “Flow State”

(Always Active)

Description:
The Tidechaser moves like water, reacting faster when controlling the battlefield.

Effect:

Whenever the Tidechaser uses an ability that moves an ally or enemy (push/pull/reposition), they gain:

+2 Initiative (1 turn)

+1 Shield

Why this works:

Encourages frequent use of control abilities

Enables early-round combo setups

Differentiates the Tidechaser from Warden/Druid (pure support)

------------------------------------------------------------
⭐ 24.6.2 PASSIVE B — “Undertow Pressure”

(Mid-level unlock)

Description:
Enemies displaced by water magic become unsettled and vulnerable.

Effect:

When the Tidechaser pushes or pulls an enemy:
→ That enemy takes +1 damage the next time it is struck.

Only triggers once per enemy displacement.

Why this works:

Rewards tactical grid play

Works with Striker and Berserker burst windows

Does not require tracking long-lasting debuffs

Still flat-value and intuitive

------------------------------------------------------------
⭐ 24.6.3 ACTIVE ABILITY A — “Tidal Push”

(Low CD battlefield repositioning)

Property	Value
Cooldown	2 turns
Targeting	Single enemy
Effect	Deal light magic damage + push enemy back 1 tile
Additional	If enemy cannot be pushed → apply +1 Slow

Description:
A short wave that knocks an enemy off balance, disrupting their line and delaying their strike.

Grid Interaction:

Frontline enemies pushed into backline

Backline enemies cannot move → get Slowed

Why this works:

Clean, readable control

Synergizes with Undertow Pressure

Useful in nearly every region

------------------------------------------------------------
⭐ 24.6.4 ACTIVE ABILITY B — “Crashing Wake”

(Medium CD AoE + team reposition tool)

Property	Value
Cooldown	4 turns
Targeting	Choose 1 ally and affect surrounding tiles
Effect	Move ally to any other tile + deal magic splash damage (small AoE around landing tile)
Additional	Allies adjacent to new position gain +2 Shield

Description:
A surge of water lifts an ally and crashes them into a new position, sending a wave outward.

Why this is great:

Introduces ally repositioning (new mechanic)

Grants a micro-defensive buff (Shield)

Perfect synergy with frontliners who want to engage/disengage

Helps squishy classes escape danger

Creates setup opportunities for Berserker, Defender, Striker, etc.

This is one of the most tactically interesting moves so far, but still simple to execute.

------------------------------------------------------------
⭐ 24.6.5 WEAPON SYNERGY NOTES
🌊 Staff

Best for maximizing AoE effects

Helps apply pressure while controlling flow

📘 Tome

Enables heavy utility builds

Amplifies movement-based abilities

Great for players who prefer control over damage

✨ Wand

Single-target pressure

Makes Tidal Push more threatening

Helps “clean up” displaced enemies

Summary

Tidechaser weapons modify how the class pressures the field, not its identity.

------------------------------------------------------------
⭐ 24.6.6 FULL ABILITY DEFINITIONS (Claude/Godot-ready)
Ability: Basic Attack

Single-target magic damage

Does NOT apply DoTs

Light scaling; control-focused class

Ability: Tidal Push

Cooldown: 2
Target: Enemy

Deal light magic damage.
If target can move backward 1 tile:
    push(target, back 1)
Else:
    apply Slow (1 turn)

Ability: Crashing Wake

Cooldown: 4
Target: Ally

Move ally to any tile.
Deal small AoE damage around new tile.
For each adjacent ally:
    apply +2 Shield

Passive: Flow State
After any push/pull/reposition effect:
    self.initiative += 2 for 1 turn
    self.gainShield(1)

Passive: Undertow Pressure
When enemy is pushed or pulled:
    enemy.markedForBonusDamage = true
Next time that enemy is hit:
    deal +1 damage
    enemy.markedForBonusDamage = false

    ------------------------------------------------------------
📘 24.7 STORMCALLER — Region 3 Class #2 (Lightning Caster / Control DPS)
------------------------------------------------------------
24.7.0 CLASS IDENTITY
🎭 Theme

A volatile lightning mage who builds electrical charge across the battlefield, unleashing violent Overloads that daze enemies and disrupt enemy turns.

🧩 Combat Role

Backline or midline caster

Damage-over-time + control hybrid

Excels at enemy lockdown and tempo disruption

Strong against clustered enemies

Medium HP, low armor

⚡ Signature Mechanic

Shock → Overload → Daze

Stormcaller is the first class to introduce Shock, a lightning-based DoT with a powerful payoff.

------------------------------------------------------------
⭐ 24.7.1 STATUS EFFECT — SHOCK (Global Definition)

Shock (DoT):

Max stacks: 3

At the end of the unit’s turn, take 1 lightning damage per stack

Shock counts as a DoT for all systems (Berserker, cleansing, etc.)

Overload Trigger

When a target with 3 Shock stacks is hit by a Stormcaller lightning ability:

Deal +3 bonus lightning damage

Remove all Shock stacks

Apply Dazed (1 turn)

------------------------------------------------------------
⭐ 24.7.2 STATUS EFFECT — DAZED

Dazed (1 turn):

On the unit’s next turn → skip their action

Dazed is removed after triggering

Cannot stack

This is a soft stun, gated behind Shock buildup.

------------------------------------------------------------
⭐ 24.7.3 PASSIVE A — “Static Charge”

(Always Active)

Description:
The Stormcaller builds electrical pressure with every strike.

Effect:

Basic attacks apply 1 Shock to the target

If the target already has Shock, refresh duration (stacks remain capped at 3)

Why this works:

Makes basic attacks meaningful

Smoothly ramps into Overload

No RNG, no tracking overload

------------------------------------------------------------
⭐ 24.7.4 PASSIVE B — “Storm Feedback”

(Mid-level unlock)

Description:
Each Overload feeds energy back into the Stormcaller.

Effect:

Whenever Overload triggers:

Gain +2 Shield

Gain +1 Initiative next turn

Why this works:

Rewards proper Shock setup

Encourages active spell usage

Keeps Stormcaller fragile but slippery

------------------------------------------------------------
⭐ 24.7.5 ACTIVE ABILITY A — “Lightning Lance”

(Single-target setup & pop tool)

Property	Value
Cooldown	2 turns
Target	Single enemy
Damage	Moderate lightning damage
Additional	Apply 1 Shock

Special Interaction:

If target has 3 Shock, this ability triggers Overload

Design Purpose:

Primary Shock popper

Short cooldown for tactical play

Reliable control against priority targets

------------------------------------------------------------
⭐ 24.7.6 ACTIVE ABILITY B — “Storm Surge”

(AoE pressure & multi-pop tool)

Property	Value
Cooldown	5 turns
Targeting	2×2 cluster
Damage	Light lightning damage
Additional	Apply 1 Shock to all targets

Special Interaction:

Any target at 3 Shock triggers Overload individually

Design Purpose:

Devastating against clustered enemies

High skill ceiling positioning tool

Creates chain reactions when set up properly

------------------------------------------------------------
⭐ 24.7.7 WEAPON SYNERGY
🔮 Staff

Best AoE Stormcaller builds

Strong synergy with Storm Surge

Enables multi-target Overloads

📘 Tome

Increases consistency and survivability

Excellent for control-focused Stormcaller

Pairs well with Storm Feedback

✨ Wand

Strong single-target pressure

Best Lightning Lance builds

Ideal for boss-focused strategies

------------------------------------------------------------
⭐ 24.7.8 CLAUDE / GODOT IMPLEMENTATION NOTES
Static Charge (Passive)
on_basic_attack(target):
    apply Shock +1 (max 3)

Lightning Lance
deal lightning damage
apply Shock +1
if target.Shock == 3:
    trigger Overload

Storm Surge
for each target in area:
    deal lightning damage
    apply Shock +1
    if Shock == 3:
        trigger Overload

Overload Resolution
deal +3 lightning damage
remove all Shock stacks
apply Dazed (1 turn)

Storm Feedback
on Overload trigger:
    gain Shield +2
    gain Initiative +1 next turn

    ------------------------------------------------------------
📘 24.8 PYREWARDEN — Region 4 Class #1 (Dragonkin Vanguard / Fire Control)
------------------------------------------------------------
24.8.0 CLASS IDENTITY
🎭 Theme

A disciplined Dragonkin frontline controller who channels internal flame into controlled bursts of power.
Unlike berserkers or pure fire mages, the Pyrewarden focuses on fire pressure, zone control, and attrition.

🧩 Combat Role

Frontline or midline

High HP, medium armor

Fire-based damage-over-time and control

Excels at holding choke points and punishing grouped enemies

Strong in longer fights

🔥 Signature Mechanic

Ember Stacks → Ignite Pressure

The Pyrewarden builds and maintains Ember stacks to empower their fire abilities.

------------------------------------------------------------
⭐ 24.8.1 STATUS EFFECT — EMBER

Ember (Stacking Fire Mark):

Max stacks: 3

Ember does not deal damage on its own

Ember stacks are consumed by Pyrewarden abilities for additional effects

Ember is a setup mechanic, not a DoT — Burn remains the actual DoT.

------------------------------------------------------------
⭐ 24.8.2 PASSIVE A — “Living Furnace”

(Always Active)

Description:
The Pyrewarden’s body radiates constant heat, marking enemies who stay too close.

Effect:

At the end of Pyrewarden’s turn, apply 1 Ember to all adjacent enemies

If an enemy already has 3 Ember → apply Burn (1) instead

Why this works:

Encourages frontline positioning

Natural Ember generation without micromanagement

Transitions cleanly into Burn pressure

------------------------------------------------------------
⭐ 24.8.3 PASSIVE B — “Forged in Flame”

(Mid-level unlock)

Description:
The Pyrewarden grows tougher as the battlefield heats up.

Effect:

Gain +1 Armor while any enemy has Ember or Burn

When an enemy gains Burn → Pyrewarden gains +1 Shield

This keeps them durable without becoming immortal.

------------------------------------------------------------
⭐ 24.8.4 ACTIVE ABILITY A — “Scorching Thrust”

(Single-target pressure & Ember spender)

Property	Value
Cooldown	2 turns
Target	Single enemy
Damage	Moderate physical + fire damage
Additional	Consume all Ember on target

Consume Effect (per Ember):

Deal +1 bonus fire damage

If 3 Ember consumed → apply Burn (2)

Design Purpose:

Reliable single-target finisher

Clean Ember → Burn conversion

Strong against elites and bosses

------------------------------------------------------------
⭐ 24.8.5 ACTIVE ABILITY B — “Blazing Line”

(Zone control & AoE pressure)

Property	Value
Cooldown	4 turns
Targeting	Line (up to 3 tiles forward)
Damage	Light fire damage
Additional	Apply 1 Ember to all hit targets

Special Interaction:

Targets with 3 Ember instead receive Burn (1)

Design Purpose:

Battlefield shaping

Soft crowd control through attrition

Great synergy with Living Furnace

------------------------------------------------------------
⭐ 24.8.6 WEAPON SYNERGY
🗡 Spear / Polearm

Best positioning control

Works perfectly with Blazing Line

Enables midline Pyrewarden builds

🪓 Axe

Higher single-target damage

Excellent Scorching Thrust builds

🛡 Shield

Maximizes durability

Best for tank-forward Pyrewarden setups

------------------------------------------------------------
⭐ 24.8.7 CLAUDE / GODOT IMPLEMENTATION NOTES
Living Furnace
on_end_turn():
    for enemy in adjacent_enemies:
        if enemy.Ember < 3:
            enemy.Ember += 1
        else:
            apply Burn (1)

Scorching Thrust
deal base damage
consume Ember stacks
bonus_damage = Ember_consumed * 1
if Ember_consumed == 3:
    apply Burn (2)

Blazing Line
for each enemy in line:
    deal fire damage
    if enemy.Ember < 3:
        enemy.Ember += 1
    else:
        apply Burn (1)

Forged in Flame
if any_enemy_has_Ember_or_Burn:
    self.armor += 1
on_enemy_gain_Burn:
    self.gainShield(1)

    📘 24.9 ASHBLADE — Region 4 Class #2

(Assassin / Execution Specialist)

24.9.0 CLASS IDENTITY

🎭 Theme
A disciplined killer forged in volcanic conflict.
Ashblades strike from smoke and shadow, marking targets for execution before vanishing back into the chaos.

They are not chaotic rogues — they are methodical executioners.

🧩 Combat Role

Backline or flank assassin

Very high single-target burst

Low HP, low armor

Excels at deleting priority enemies

Weak in prolonged, unfocused fights

🔥 Signature Mechanic
Ash Marks → Execution Windows

The Ashblade applies Ash Marks to enemies, then consumes them for devastating execution strikes.

⭐ 24.9.1 STATUS EFFECT — ASH MARK

Ash Mark

Max stacks: 3

Does not deal damage on its own

Applied by Ashblade abilities and some weapon abilities

Consumed by Ashblade execution skills

Execution Rule
If an Ashblade consumes 3 Ash Marks on a target:

Bonus execution damage is applied

Additional secondary effect triggers (defined per ability)

Ash Marks are unique to Ashblade and do not count as DoTs.

⭐ 24.9.2 PASSIVE A — “Cinder Focus”

(Always Active)

Description
The Ashblade thrives when isolating prey.

Effect

When attacking an enemy with no adjacent allies:
→ Deal +2 bonus damage

Why this works

Encourages assassination positioning

Rewards player setup, not RNG

Strong in dungeon and defense encounters

Simple conditional check (Claude/Godot friendly)

⭐ 24.9.3 PASSIVE B — “Smoke Veil”

(Mid-level unlock)

Description
After striking, the Ashblade fades back into smoke.

Effect

After the Ashblade defeats an enemy:
→ Gain Evasion (1 turn)
→ Gain +1 Initiative next turn

Why this works

Prevents instant retaliation

Reinforces hit-and-run assassin fantasy

Keeps Ashblade fragile but slippery

⭐ 24.9.4 ACTIVE ABILITY A — “Ash Brand”

(Setup / Marking Tool)

Property	Value
Cooldown	2 turns
Target	Single enemy
Damage	Light physical
Additional	Apply 1 Ash Mark

Description
The Ashblade slices through armor, leaving a burning brand behind.

Special Interaction

If the target already has Ash Marks:
→ This ability deals +1 bonus damage per existing Ash Mark

Purpose

Primary Ash Mark generator

Rewards repeated focus on priority targets

Scales smoothly into execution turns

⭐ 24.9.5 ACTIVE ABILITY B — “Execution Cut”

(Primary Burst Ability)

Property	Value
Cooldown	5 turns
Target	Single enemy
Damage	Heavy physical
Additional	Consume all Ash Marks

Consume Effect

For each Ash Mark consumed:
→ Deal +2 bonus damage

If 3 Ash Marks are consumed:
→ Apply Bleed (2)
→ Gain +1 Initiative next turn

Description
A decisive killing stroke that turns setup into devastation.

Design Notes

Clear payoff moment

Strong boss and elite killer

Encourages patience and timing

⭐ 24.9.6 WEAPON SYNERGY

🗡 Daggers (Best-in-slot)

High initiative

Fast Ash Mark generation

Perfect execution windows

🪓 Short Swords

More reliable base damage

Safer for new players

🏹 Thrown Blades / Light Ranged Weapons

Enables backline assassination

Less burst, more safety

🔥 Legendary Ash Weapons (Later Regions)
May:

Apply bonus Ash Marks

Modify Execution Cut

Trigger smoke reposition effects

⭐ 24.9.7 GRID PRESENCE

Backline by default

Can operate from flank tiles if protected

Extremely vulnerable to AoE and focus fire

Ashblade must be protected or timed correctly — intentional risk.

⭐ 24.9.8 FULL ABILITY DEFINITIONS (Claude / Godot Ready)

Passive — Cinder Focus

If target has no adjacent allies:
    deal +2 damage


Passive — Smoke Veil

On enemy kill:
    gain Evasion (1 turn)
    gain +1 Initiative next turn


Ability — Ash Brand

Deal light physical damage
Apply Ash Mark +1
If target already has Ash Marks:
    deal +1 bonus damage per stack


Ability — Execution Cut

Deal heavy physical damage
Consume all Ash Marks
For each Ash Mark:
    deal +2 bonus damage
If Ash Marks consumed == 3:
    apply Bleed (2)
    gain +1 Initiative next turn

    Perfect — below is the FULL, FINALIZED Section 24.10 with your refinement fully integrated, written in the same tone, structure, and precision as the rest of Section 24.

This is copy-paste ready.
Nothing is abbreviated.
No placeholders.
Includes fix notes at the end.

------------------------------------------------------------
📘 24.10 PRISM SENTINEL — Region 5 Class #1 (Crystalborn)
------------------------------------------------------------
24.10.0 CLASS IDENTITY
🎭 Theme

A living crystalline guardian who bends force, light, and impact through refractive plating.
Prism Sentinels do not simply absorb damage — they redirect, delay, and weaponize it.

Unlike earlier frontline classes, the Prism Sentinel introduces positional defense and delayed retaliation, marking Region 5 as a shift away from stacking statuses and toward battlefield manipulation.

🧩 Combat Role

Frontline or midline controller

Medium HP, high mitigation

Defensive anchor and formation shaper

Strong against burst damage

Weaker against prolonged attrition

💠 Signature Mechanic

Refraction Zones — tile-based defensive constructs that redirect damage and can be detonated offensively.

This is a zone mechanic, not a status effect.

24.10.1 MECHANIC — REFRACTION ZONE

Refraction Zone

A temporary tile effect created by Prism Sentinel abilities

Only one Refraction Zone may exist at a time

Duration: 2 turns

Tracks how many turns it has remained active

Refraction Effect

The first instance of damage each turn dealt to any ally standing in the zone:

Damage is reduced by 3

The reduced amount is reflected to a random enemy as pure damage

The zone can trigger once per turn

Reflected damage does not trigger on-hit effects.

24.10.2 PASSIVE A — “Crystalline Poise”

(Always Active)

Description:
The Prism Sentinel becomes sturdier when holding ground.

Effect:

If the Prism Sentinel does not change tiles during their turn:

Gain +2 Shield

Gain +1 Armor until the start of their next turn

Design Intent:

Encourages anchoring and formation play

Differentiates from Defender’s reactive tanking

Simple positional rule, easy to implement

24.10.3 PASSIVE B — “Refractive Memory”

(Mid-level unlock)

Description:
Crystal surfaces retain the memory of force.

Effect:

Whenever a Refraction Zone redirects damage:

Prism Sentinel gains +1 Initiative on their next turn

Why this matters:

Defense converts into tempo

Makes protecting allies feel proactive

Rewards good zone placement

24.10.4 ACTIVE ABILITY A — “Prism Anchor”

(Zone Creation)

Property	Value
Cooldown	3 turns
Target	Any empty tile
Effect	Create a Refraction Zone
Rules

If a Refraction Zone already exists, it is replaced

Allies may move freely into or out of the zone

The zone begins tracking duration immediately

Purpose

Pre-emptive defense

Enables formation-based play

Excellent synergy with fragile backliners

24.10.5 ACTIVE ABILITY B — “Shatter Pulse” (Refined)

(Reactive Zone Detonation)

Property	Value
Cooldown	5 turns
Target	Active Refraction Zone
Effect	Consume the zone
Base Effect

Deal moderate crystal damage to all enemies adjacent to the zone

Apply Slow (1 turn) to affected enemies

Charge Bonus — Crystal Buildup

For each full turn the Refraction Zone remained active before detonation:

Deal +2 bonus damage (flat) to all affected enemies

Maximum Bonus

Zone duration: 2 turns

Maximum bonus damage: +4

Examples

Detonate immediately → base damage only

Detonate after 1 turn → base +2 damage

Detonate after full duration → base +4 damage

Design Notes

This is not a stacking status

Only the zone tracks duration

No per-enemy tracking required

Encourages patience and planning

Fits Crystalborn fantasy of stored energy

24.10.6 WEAPON SYNERGY
🛡 Shield

Maximum survivability

Best for pure defensive builds

🔨 Hammer

Strong Shatter Pulse detonations

Ideal for clustered fights

🗡 Sword

Balanced offense/defense option

Flexible positioning

💎 Legendary Crystal Weapons (Later Regions)

May:

Extend Refraction Zone duration

Increase redirected damage

Allow rare multi-zone effects (very limited)

24.10.7 GRID PRESENCE

Frontline or center-column anchor

Allies are encouraged to play around the zone

Extremely effective in town defense formations

24.10.8 CLAUDE / GODOT IMPLEMENTATION NOTES
Prism Anchor
create RefractionZone(tile, duration=2)
if existing zone:
    remove old zone

Refraction Zone Trigger
on ally in zone takes damage:
    reduce damage by 3
    reflect reduced amount to random enemy
    mark zone as triggered for this turn

Shatter Pulse
turns_active = RefractionZone.turnsElapsed
bonus_damage = turns_active * 2
for each adjacent enemy:
    deal (base_damage + bonus_damage)
    apply Slow (1 turn)
remove RefractionZone

Crystalline Poise
if did_not_move_this_turn:
    gain Shield +2
    gain Armor +1

Refractive Memory
on zone_redirect_damage:
    gain Initiative +1 next turn

    ------------------------------------------------------------
📘 24.11 PRISM LANCER — Region 5 Class #2 (Crystal DPS)
------------------------------------------------------------
24.11.0 CLASS IDENTITY
🎭 Theme

A Crystalborn damage specialist who refracts destructive energy through hardened prisms, firing focused beams that punish poor positioning.

The Prism Lancer does not rely on stacks or lingering effects.
Instead, they excel at line damage, angle control, and precision bursts.

🧩 Combat Role

Midline or backline DPS

High burst potential

Low HP, low armor

Extremely position-dependent

Strong against clustered or linear enemy formations

💎 Signature Mechanic

Refraction Beams — abilities that gain power based on alignment, positioning, and line-of-sight.

This class introduces directional damage rules, not new statuses.

24.11.1 PASSIVE A — “Perfect Alignment”

(Always Active)

Description:
The Prism Lancer’s attacks become deadlier when enemies line up just right.

Effect:

When the Prism Lancer hits 2 or more enemies in a straight line with an ability:

Deal +2 bonus damage to all hit enemies

Design Notes:

No stacking

No status effects

Simple geometric condition

Rewards smart positioning

24.11.2 PASSIVE B — “Crystalline Focus”

(Mid-level unlock)

Description:
Remaining stationary allows the Prism Lancer to channel destructive clarity.

Effect:

If the Prism Lancer does not move during their turn:

Their next damaging ability deals +3 bonus damage

Bonus is consumed after the next ability.

Why this works:

Encourages turret-style play

Creates tension between repositioning and damage

Cleanly mirrors Prism Sentinel’s anchoring theme without overlap

24.11.3 ACTIVE ABILITY A — “Prism Beam”

(Core DPS Tool)

Property	Value
Cooldown	2 turns
Targeting	Straight line (up to 3 tiles)
Damage	Moderate crystal damage
Special Rules

Hits all enemies in the line

Triggers Perfect Alignment if applicable

Consumes Crystalline Focus bonus if active

Description:
A focused blast of refracted crystal energy cuts through enemies standing in formation.

Purpose:

Reliable damage tool

Excellent against narrow dungeon layouts

Strong baseline DPS without complexity

24.11.4 ACTIVE ABILITY B — “Shattering Convergence”

(High-Impact Precision Burst)

Property	Value
Cooldown	5 turns
Targeting	Choose 1 enemy
Damage	Heavy crystal damage
Additional	Conditional splash
Special Interaction

If the target has another enemy directly behind it:

Deal +4 bonus damage to the primary target

Deal moderate crystal damage to the secondary target

Additional Rule

If both enemies are hit:

Apply Armor Break (1 turn) to both

Description:
The Prism Lancer compresses refracted energy into a single point, shattering through layered defenses.

Design Intent:

Encourages tactical targeting

Punishes poor enemy spacing

High payoff without RNG

24.11.5 WEAPON SYNERGY
🪄 Staff

Best range and line control

Maximizes Prism Beam effectiveness

📘 Tome

Enables safer turret builds

Strong synergy with Crystalline Focus

✨ Wand

Better single-target pressure

Improves Shattering Convergence reliability

💎 Legendary Crystal Weapons (Later Regions)

May:

Extend beam length

Allow Prism Beam to bend once

Add bonus damage when breaking armor

24.11.6 GRID PRESENCE

Prefers backline center columns

Strongest when enemies funnel forward

Vulnerable to flanks and AoE pressure

Excellent synergy with Prism Sentinel zones and Tidechaser positioning

24.11.7 CLAUDE / GODOT IMPLEMENTATION NOTES
Perfect Alignment
if ability_hits_enemies_in_line >= 2:
    add +2 bonus damage to all hits

Crystalline Focus
if did_not_move_this_turn:
    next_damage_ability_bonus += 3

Prism Beam
for each enemy in line up to 3 tiles:
    deal crystal damage
apply alignment bonuses if applicable
consume focus bonus if present

Shattering Convergence
deal heavy damage to target
if enemy directly behind target:
    deal moderate damage to secondary target
    apply Armor Break (1 turn) to both

------------------------------------------------------------
📘 24.12 DARK CHANNELER — Region 6 Class #1 (Necropolis)
------------------------------------------------------------
24.12.0 CLASS IDENTITY
🎭 Theme

A disciplined practitioner of forbidden rites who siphons lingering souls and bends fate toward inevitable collapse.
Dark Channelers do not overwhelm enemies quickly — they decide when enemies are allowed to fall.

They represent controlled necromancy, inevitability, and delayed execution rather than chaotic death magic.

🧩 Combat Role

Midline control specialist

Medium HP, low armor

Excellent against elites and bosses

Weak in fast, chaotic encounters

Thrives in prolonged, deliberate fights

☠ Signature Mechanics

Soul Charges (resource) + Doom (countdown execution)

Neither mechanic is a damage-over-time effect.

24.12.1 RESOURCE — SOUL CHARGES

Soul Charges

Stored on the Dark Channeler

Maximum: 5

Reset at the end of combat

Gaining Soul Charges

When any enemy dies

When Doom resolves on an enemy

Soul Charges are spent to manipulate fate, not to spam damage.

24.12.2 STATUS EFFECT — DOOM (Refined)

Doom is a countdown-based execution effect, not a DoT.

Doom (X)

X = number of turns before Doom resolves

At the end of the target’s turn, Doom decreases by 1

When Doom reaches 0:

The target takes heavy true damage

Doom is removed

Damage Scaling

Doom damage scales based on the initial Doom value applied

Higher Doom values:

Take longer to resolve

Deal more damage when they trigger

Example:

Doom (2)
→ Triggers after 2 turns
→ Deals base Doom damage

Doom (4)
→ Triggers after 4 turns
→ Deals approximately double Doom damage

(Exact tuning values are handled in balance passes.)

Stacking Rule

Applying Doom to a target that already has Doom:

Increases the countdown value

Does not reset the timer

Effectively delays execution while amplifying its severity

This gives the Dark Channeler fine control over timing vs lethality.

Additional Rules

Doom damage:

Ignores armor

Cannot crit

Does not trigger on-hit effects

Doom is not a DoT

Doom deals no damage until it resolves

UI Representation

Doom uses a clock icon

The displayed number represents turns remaining

This visually distinguishes Doom from:

DoTs

Stack-based buffs/debuffs

24.12.3 PASSIVE A — “Grave Resonance”

(Always Active)

Description:
The Dark Channeler draws strength from nearby deaths.

Effect:

Whenever an enemy dies:

Gain +1 Soul Charge

If the enemy had Doom when it died:

Gain +1 additional Soul Charge

Design Intent:

Encourages methodical execution

Rewards Doom planning

Smooth soul economy without micromanagement

24.12.4 PASSIVE B — “Inevitable Collapse”

(Mid-level unlock)

Description:
Enemies marked for death falter as the end approaches.

Effect:

Enemies with Doom deal –1 damage

When an enemy reaches Doom (1):

Apply Slow (1 turn)

This adds control pressure without extra tracking.

24.12.5 ACTIVE ABILITY A — “Soul Brand”

(Primary Doom Application)

Property	Value
Cooldown	2 turns
Target	Single enemy
Damage	Light dark damage
Additional	Apply Doom (2)
Empowered Use

If the Dark Channeler has 2+ Soul Charges:

Spend 2 Soul Charges

Apply Doom (3) instead

Purpose:

Reliable Doom setup

Resource-driven escalation

Flexible pacing tool

24.12.6 ACTIVE ABILITY B — “Fate Sever”

(Doom Manipulation / Finisher)

Property	Value
Cooldown	5 turns
Target	Single enemy
Base Effect

If the target has Doom:

Reduce Doom by 1 immediately

If Doom reaches 0, resolve Doom damage instantly

Empowered Effect

If the Dark Channeler spends 3 Soul Charges:

Resolve Doom damage immediately, regardless of remaining countdown

Gain +1 Soul Charge afterward

Design Notes:

Allows acceleration or patience

Strong boss pressure tool

Resource-neutral when used optimally

24.12.7 WEAPON SYNERGY
📘 Tome

Best for control-heavy play

Safest positioning

Enhances Doom pacing

🪄 Staff

Higher dark damage output

Faster inevitability pressure

✨ Wand

Strong single-target focus

Best Fate Sever builds

Legendary necrotic weapons may:

Increase Doom duration

Reduce Soul Charge costs

Trigger Doom on kill (rare)

24.12.8 GRID PRESENCE

Midline preferred

Requires protection

Synergizes strongly with:

Prism Sentinel (zones)

Defender (frontline)

Tidechaser (repositioning)

24.12.9 CLAUDE / GODOT IMPLEMENTATION NOTES
Soul Charges
on_enemy_death:
    soul_charges += 1
    if enemy.had_Doom:
        soul_charges += 1
soul_charges = min(soul_charges, 5)

Doom Countdown
on_end_enemy_turn:
    if enemy.has_Doom:
        enemy.Doom -= 1
        if enemy.Doom == 1:
            apply Slow (1 turn)
        if enemy.Doom == 0:
            deal true_damage (scaled by initial Doom)
            remove Doom

Soul Brand
apply Doom (2)
if soul_charges >= 2:
    consume 2
    increase Doom to (3)

Fate Sever
if enemy.has_Doom:
    enemy.Doom -= 1
    if enemy.Doom == 0:
        resolve Doom immediately
if empowered:
    consume 3 Soul Charges
    resolve Doom immediately
    gain 1 Soul Charge

24.13 — Lich (Region 6 Class #2) — FINAL REFINED VERSION
Class Role

Primary Role: Arcane Commander / Execution Mage

Secondary Role: Minion Control / Sacrifice Engine

Grid Preference: Flexible

Lich typically occupies backline

Phylact Minion occupies mid or frontline

24.13.1 Class Fantasy

The Lich is a master of death through binding, sacrifice, and inevitability.

By sacrificing a powerful hero, the Lich binds their soul into a permanent undead construct — the Phylact Minion. Temporary undead are raised only to be destroyed, fueling devastating rituals that grow stronger as death piles up around the Lich.

This is a class built around long fights, attrition, and grim momentum.

24.13.2 Core Mechanic — Phylact Binding (Refined)
Phylact Minion Creation

Created when unlocking the Lich class by sacrificing a Legacy Hero

The sacrificed hero’s:

Race

Class

Base Active Ability

Both Class Passives
are inherited by the Phylact Minion

⚠️ Some classes may have specific exclusions or tuning when used as Phylact Minions (to be refined later).

Permanent Record

The sacrificed hero is:

Recorded in the Book of the Dead

Permanently removed from all rosters

If the Lich dies permanently, the Phylact Minion is lost forever, as the soul was already recorded.

Phylact Minion Rules

Only one Phylact Minion may exist

If destroyed during combat:

It reforms after combat ends

Acts immediately before the Lich each turn

Occupies a normal grid tile

Can be targeted, healed, buffed, or destroyed

24.13.3 Passive A — Bound Beyond Death (Refined)

While the Phylact Minion is alive:

Lich gains +3 flat damage to all abilities

Phylact Minion gains:

+20 Max HP

+1 Armor

If the Phylact Minion is destroyed:

These bonuses are disabled for the remainder of combat

24.13.4 Passive B — Harvest the Unliving (Refined)

Whenever a unit dies, the Lich gains Harvest Stacks:

Unit Type	Harvest Gained
Temporary Undead (Husk)	+1
Enemy Unit	+2
Ally Hero	+4
Harvest Rules

Harvest Stacks:

Grant +1 flat damage per stack to Lich abilities

Maximum Harvest Stacks: 8

Stacks reset at the end of combat

Certain abilities consume Harvest Stacks

This creates powerful momentum without infinite scaling.

24.13.5 Active Ability A — Raise Husk

Cooldown: 2 turns

Target: Adjacent empty tile

Summons a Temporary Husk:

Low HP

No abilities

Basic melee attack

Automatically attacks nearest enemy

Temporary Husks:

Exist to:

Block attacks

Generate Harvest

Be sacrificed

Are removed at end of combat

24.13.6 Active Ability B — Rite of Final Offering (Refined)

Cooldown: 4 turns

Consumes:

All Harvest Stacks

All Temporary Husks

Effect

For each consumed unit or stack:

Heals the Lich for 3 HP

Heals the Phylact Minion for 5 HP

Deals 2 damage to all enemies

If no Temporary Husks exist:

The ability still consumes Harvest Stacks only (reduced effect)

This is the Lich’s fight-swinging ritual, rewarding careful setup.

24.13.7 Weapon Ability Synergy

Staff:
+1 Harvest when any unit dies (once per turn)

Wand:
Reduce Raise Husk cooldown by 1 (minimum 1)

Tome / Relic:
Phylact Minion gains a 5 HP shield at start of combat

Weapon abilities modify the sacrifice engine — they do not add new actions.

24.13.8 Combat Identity Summary

Thrives in long fights

Stronger as units die

Sacrifice-focused gameplay

Extremely powerful in:

Boss encounters

Town defense

High-attrition dungeons

24.13.9 Restrictions & Balance Rules

No ultimate abilities

No percentage scaling

No infinite loops

Phylact Minion cannot be transferred or duplicated

Lich cannot target living allies with abilities

24.13.10 Unlock Condition

Lich class book is created by:

Sacrificing a high-level Legacy Hero

The sacrificed hero becomes the Phylact Minion permanently

24.14 — Voidwalker (Region 7 Class #1)
Class Role

Primary Role: Control / Assassin Hybrid

Secondary Role: Threat Denial / Reality Manipulation

Grid Preference: Flexible (Frontline or Midline)

24.14.1 Class Fantasy

Voidwalkers are entities that do not fully exist in the same space as their enemies.
They slip between moments, step out of reality, and strike when opponents are least able to respond.

Rather than overpowering foes, Voidwalkers deny actions, invalidate targeting, and control engagement rules.

This class represents the final evolution of combat mastery — not stronger, but unfair in precise ways.

24.14.2 Core Mechanic — Phased State
Phased

The Voidwalker can enter a Phased state through abilities

While Phased:

Cannot be directly targeted by enemies

Cannot be affected by enemy abilities or attacks

Can still occupy and block tiles

Phase ends automatically at the start of the Voidwalker’s next turn unless extended

This is not invisibility — enemies are aware the Voidwalker exists but cannot interact with them.

24.14.3 Passive A — Unstable Presence

When the Voidwalker enters Phased:

The nearest enemy suffers Disorientation

Disorientation Effect:

Enemy loses their next attack action

Does not stack

Cannot be refreshed until it triggers

This ensures the Voidwalker controls tempo without hard-stunning enemies repeatedly.

24.14.4 Passive B — Fractured Reality

When the Voidwalker exits Phased:

Gain +2 flat damage for their next attack or ability

This bonus is consumed on use

Rewards timing and intentional phase cycling.

24.14.5 Active Ability A — Phase Step

Cooldown: 2 turns

Target: Self or adjacent tile

The Voidwalker:

Instantly moves to the target tile

Enters Phased state

Removes all movement-impairing effects

This ability is the core mobility and survivability tool.

24.14.6 Active Ability B — Void Rend

Cooldown: 3 turns

Target: Adjacent enemy

The Voidwalker tears reality around the target:

Deals 8 flat damage

Ignores armor

If cast while Phased:

Immediately exits Phase

Triggers Fractured Reality bonus

Void Rend does not apply statuses — it enforces inevitability.

24.14.7 Weapon Ability Synergy

Weapon type modifies Voidwalker behavior:

Dagger:
Void Rend cooldown reduced by 1

Short Sword:
Phase Step grants +1 armor until next turn

Void Relic / Artifact:
Entering Phase also grants a 4 HP shield

Weapon synergy enhances survivability or execution — never raw damage scaling.

24.14.8 Combat Identity Summary

Extremely hard to lock down

Controls enemy turns indirectly

Excels at:

High-value target disruption

Boss fights with predictable patterns

Town defense denial roles

Weakness:

Poor sustained AoE

Requires positioning mastery

24.14.9 Restrictions & Balance Rules

No stacking effects

No permanent Phase state

No ally targeting

Phase cannot be refreshed without exiting first

All bonuses are flat values

24.14.10 Unlock Condition

Unlocked in Region 7

Requires:

Completion of Region 6

Void-themed materials

Available through Training Hall once unlocked

24.15 — Void Herald (Region 7 Class #2)
Class Role

Primary Role: Support / Corruptor

Secondary Role: Battlefield Control

Grid Preference: Backline or midline (must be protected)

24.15.1 Class Fantasy

Void Heralds do not heal wounds or deal heavy damage.

They rewrite expectations.

By whispering impossible truths into reality, the Void Herald weakens enemy resolve, distorts threat perception, and empowers allies through corruption rather than purity. Their presence makes the battlefield feel wrong — allies act beyond their limits, enemies hesitate, and plans collapse under unseen pressure.

24.15.2 Core Mechanic — Corruption Threshold

Void Heralds apply Corruption to enemies and allies.

Corruption is a non-damaging counter

Corruption does nothing by itself

Effects only trigger when a threshold is reached

Corruption Rules

Corruption stacks are tracked per unit

Threshold: 3 Corruption

Upon reaching threshold:

Corruption is consumed

A corruption effect triggers

No stacking damage over time

No permanent debuffs

This keeps the system readable and intentional.

24.15.3 Passive A — Whispered Collapse

Whenever an enemy reaches Corruption Threshold:

Enemy:

Loses 1 Armor

Suffers –2 damage on their next attack

This passive applies once per threshold trigger, not per stack.

24.15.4 Passive B — Profane Benediction

Whenever an ally reaches Corruption Threshold:

Ally gains:

+2 damage

+2 Armor

Buff lasts 1 full round

This allows the Void Herald to buff allies through corruption, creating risk/reward play.

24.15.5 Active Ability A — Mark of the Void

Cooldown: 2 turns

Target: Any unit (ally or enemy)

Applies 2 Corruption to the target.

If the target already has Corruption:

Applies only 1 Corruption instead

This prevents rapid threshold looping.

24.15.6 Active Ability B — Reality Fracture

Cooldown: 4 turns

Target: All enemies in a row or column

Applies 1 Corruption to each affected enemy.

If at least one enemy triggers a threshold:

All affected enemies take 3 damage

Damage is conditional, not guaranteed.

24.15.7 Weapon Ability Synergy

Weapon type modifies Corruption behavior:

Staff:
Corruption thresholds on enemies also reduce movement by 1 tile on next turn

Relic / Tome:
Corruption thresholds on allies grant +1 healing received for the round

Void Focus Item:
Mark of the Void applies +1 additional Corruption once per combat

Weapon synergy adjusts effects, not thresholds.

24.15.8 Combat Identity Summary

No direct healing

No burst damage

Wins fights by:

Weakening enemy output

Temporarily empowering allies

Enabling combo turns

Extremely strong with:

Voidwalker

Lich

High-damage Strikers

24.15.9 Restrictions & Balance Rules

Corruption does not persist between combats

No infinite loops (threshold consumes stacks)

No raw stat scaling

Void Herald abilities do not directly kill units

24.15.10 Unlock Condition

Unlocked upon reaching Region 7

Available via Class Book in shop

No sacrifice required