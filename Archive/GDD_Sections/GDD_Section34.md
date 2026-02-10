SECTION 34 — ITEM SYSTEM & PROCEDURAL GENERATION FRAMEWORK
34.1 Item Design Philosophy

Items in Shops & Shadows are procedurally generated, facility-driven, and risk-oriented. They are designed to support a long-term roguelite loop where gear is constantly replaced, refined, salvaged, or lost.

Core principles:

Items are primarily acquired through shops, not drops

Facilities influence item output; players do not hand-craft items

Items must be readable, replaceable, and disposable

True BiS items are possible, but only through:

Long-term RNG

Refinement risk

Repeated investment over time

There is no guaranteed path to BiS

Losing or breaking a near-BiS item is an intended outcome

Non-goals:

No deterministic crafting trees

No static, fixed legendary uniques

No durability micromanagement

No inventory clutter systems

34.2 Item Categories
Category	Procedurally Generated	Notes
Weapons	Yes	Primary source of combat abilities
Armor	Yes	Defensive stats
Accessories	Yes	Utility and passive effects
Tools	Yes	Resource-gathering gating
Consumables	Semi	Flask is permanent; others generated
Class Books	No	Quality-only, no rarity
34.3 Item Identity Model

Each item is defined by a small, composable identity:

Item =
  Base Item
  + Quality Tier
  + Affix Set
  + (Optional) Region Passive Influence


Items are not stored as named entities. Names, stats, and descriptors are derived dynamically from their properties.

34.4 Quality System

Quality determines stat magnitude and risk, not mechanics.

Quality Tiers
Quality	Descriptor Examples	Stat Range	Refinement Risk	Salvage Yield
Common	Rusty, Worn	Low	None (1–4 safe)	Low
Uncommon	Sturdy, Sharpened	Low–Mid	Very Low	Low–Mid
Rare	Fine, Exceptional	Mid–High	Moderate	Mid
Epic	Masterwork	High	High	High
Legendary	Mythic	Very High	Very High	Very High

Quality affects:

Stat roll ranges

Consumable potency

Refinement risk scaling

Salvage output

Quality does NOT affect:

Ability mechanics

Class access

Core gameplay rules

34.5 Procedural Naming Rules
Standard Naming Grammar
[Quality Descriptor] – [Base Item] – Of [Affix Theme]

Examples

Rusty Sword

Exceptional Dagger of Precision

Masterwork Axe of Rupture

Mythic Greataxe (legendary override)

Rules:

“Of X” appears only if an affix theme exists

Legendary items may override grammar for thematic names

Names are derived; they are not manually authored

34.6 Affix System

Items may roll 1–3 affixes maximum depending on quality and facility tier.

Affix Categories
Offense

+Flat Damage

+Crit Chance

+Crit Damage

+Ability Damage (flat)

Defense

+Max HP

−Damage Taken

+Block Chance

−Status Stack Received

Utility

+Speed (Turn Order)

−Ability Cooldown (minimum 1 turn)

+Resource Yield

+Gold Gain

Cooldown reduction rules:

Cannot reduce abilities below 1 turn

Appears only on Rare+

Epic rolls higher values

Economy

+Salvage Yield

+Rare Material Chance

−Shop Purchase Cost

Affix rules:

No region affects affix pools

Regions influence passives, not affixes

Higher quality improves roll values, not mechanics

34.7 Facility-Based Item Generation

Facilities do not craft items directly. They generate shop inventory.

Shop Slot Selection

Player selects item type per slot

UI displays:

Materials required

Quality floor and ceiling

Possible affix categories

Material Consumption

Materials are pulled from shared storage

Pull occurs on return from dungeon

If insufficient materials:

Slot is skipped

No partial generation

34.8 Consumables
Health Flask

Permanent inventory item

Starts at 5/5 charges

Refills on town return

Upgraded via Jeweler / Glass facility

Quality does not affect base flask

Potions

Buff-only consumables

Single-use

Quality increases:

Buff duration

Buff potency

Food

Always provides small healing

Higher quality adds buffs

Chef can enhance food using herbs

Quality improves duration and effect strength

No consumable tiers; quality only.

34.9 Tools
Tool	Purpose
Pickaxe	Ore
Hatchet	Wood
Fishing Pole	Fish + rare drops
Herb Pouch	Holds up to 5 herbs

Tool Scaling Model

Quality → Resource quantity bonus

Rarity → Rare resource chance

No tool = no resource

Example:

Exceptional Hatchet → +1 Wood, +5% rare chance

Epic Hatchet → +2 Wood, +15% rare chance

34.10 Blueprints

Blueprints are recipes, not items.

Rules:

Dropped from dungeon floor bosses

Not region-locked

Enable Epic-quality crafting

Blueprint crafting allows:

Dual-region passive pools

Player-selected stat priority

Output remains random within constraints

Blueprint crafting:

Requires facility interaction

Consumes special materials

Produces one Epic item

34.11 Legendary Items

Legendary items:

Never appear in shop rolls

Require:

Facility Tier 4

Legendary material

Item type selection

Output:

Random Legendary of chosen type

No static uniques

Region-themed passives may appear

34.12 Salvaging

Salvaging destroys an item to return materials.

Rules:

Yield scales with quality

Prevents hoarding

Feeds upgrade, refinement, and blueprint loops

Essential economic sink

34.13 Class Books (Special Case)
Property	Rule
Rarity	None
Quality	Yes
Stackable	No
Overwrites Class	Yes

Quality improves:

Passive values

Ability numbers

Class books do not use affixes or rarity tiers.

34.14 UI & Player Readability

Tooltips explain:

Quality

Affixes

Facility source

No hidden math

Complexity introduced gradually

Refinement and risk clearly communicated

34.F Internal Notes (Not Fix Notes)

Enchanting: future system

Corruption: post/post-campaign

Refinement rules defined in Section 31