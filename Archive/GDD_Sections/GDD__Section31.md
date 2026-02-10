31. Item System & Generation
31.1 Design Goals

The item system in Shops & Shadows is designed to support strategic preparation, region identity, and long-term progression, without overwhelming the player with excessive loot or micromanagement.

Core goals:

Items are earned through planning, not random drops

Facilities, not heroes, are the primary source of gear

Regions influence item identity and passive traits

Scarcity creates meaningful decisions without hard failure states

Items reinforce the shopkeeper fantasy of provisioning heroes

There is no traditional crafting at the hero level. Instead, facilities consume materials to produce randomized but controlled items for the shop.

31.2 Item Categories

Items are grouped into the following categories:

Equipment

Weapons

Armor (Head, Chest, Legs)

Accessories

Consumables

Health Flask (permanent)

Potions (buff-based)

Tools

Pickaxe (mining)

Hatchet (woodcutting)

Fishing Pole (fishing & rare finds)

Herb Pouch (herb storage)

Special

Blueprint-crafted items

Legendary items

31.3 Item Data Structure (Conceptual)

Each item is defined by:

Item ID

Category & Slot

Rarity

Region Identity

Base Stats

Passive Effects

Weapon Ability (if applicable)

Refinement Count (if applicable)

All item values are flat numeric values, not percentages, unless otherwise specified.

31.4 Item Rarity Tiers
Rarity	Notes
Common	Basic stats, no passives
Uncommon	Slightly improved stats
Rare	One passive effect
Epic	Strong stats, multiple passives
Legendary	Unique effects, crafted only

Legendary items never appear in shops randomly.

31.5 Facility-Based Item Generation

Items are generated exclusively through town facilities.

Shop Slot Selection

At each facility, the player:

Chooses how many shop slots the facility will fill

Selects the item type for each slot (e.g. sword, armor)

Sees a live preview of:

Materials required per slot

Total materials that will be pulled from storage

Materials are not consumed until the next shop refresh.

Generation Timing

Items are generated when returning from an expedition

Only the shop in the current town refreshes

Materials are consumed at refresh time

Material Economy Rules

All towns share one global material inventory

Materials are never auto-pulled

Players must manually commit materials per shop cycle

Dungeon rewards are tuned so:

Basic materials accumulate naturally

Higher tiers require intentional farming

Running out of materials is a player-driven choice, not a punishment.

31.6 Region Identity & Item Passives

Each region contributes 2–3 possible passive effects to items crafted there.

Rules:

Items roll one region passive (two for blueprint items)

Passives are small, focused, and thematic

No item rolls more than two region passives

Examples:

Forest regions favor survivability or regeneration

Fungal regions favor status effects or resource synergy

Volcanic regions favor damage over time or risk/reward

31.7 Weapons & Weapon Abilities

Every weapon type grants a weapon ability.

Weapon abilities are:

Separate from class abilities

Activated manually

Modified by weapon quality and passives

Higher-tier weapons may:

Increase ability damage

Add secondary effects

Alter targeting rules

Weapon abilities provide tactical identity without adding extra UI slots.

31.8 Armor & Defensive Gear

Armor provides:

Flat defensive stats

Occasional passive effects

Armor does not grant active abilities.

Armor types (metal, leather, cloth) influence:

Stat distributions

Refinement options

Facility upgrade requirements

31.9 Inventory & Backpacks
Hero Inventory

Maximum of 6 slots

Typical usage:

Weapon

Armor

Accessory

Health Flask

1–2 flex slots

Gold is tracked separately and does not occupy inventory space.

Shopkeeper Bag

Larger than hero inventories

Used only during expeditions

Must be emptied into town storage on return

Resources are non-stacking, reinforcing strategic inventory use.

31.10 Tools & Resource Gathering

Tools are required to gather specific resources.

Tool	Resource
Pickaxe	Ore, stone
Hatchet	Wood
Fishing Pole	Fish & rare finds
Herb Pouch	Herbs (holds up to 5)

Rules:

If a monster or environment drops a resource and the correct tool is missing, the resource is not obtained

The shopkeeper may comment on missing tools after failed gathers

Tools are crafted at facilities and can be purchased once a T1 facility exists

31.11 Consumables
Health Flask (Permanent)

Every hero has one Health Flask

Occupies one inventory slot

Starts at 5/5 charges

Charges are consumed on use

Automatically refills:

When returning to town

After dungeon completion

The flask cannot be destroyed, duplicated, or traded.

Flask Upgrades

Provided by Glass/Jeweler facilities

May:

Increase max charges

Improve healing amount

Add minor effects

Potions

Crafted by Alchemist facilities

Single-use consumables

Provide buffs, not healing

Can target self or allies

31.12 Refinement & Reforging

Refinement is unlocked at T3 facilities

Max refinement level: 10

Risk Zones

Levels 1–4: Safe

Levels 5–8: Increasing chance of negative effect

Levels 9–10: High risk of item destruction

Players choose a stat group (e.g. Offense, Defense), not a specific stat.

All refinement changes are visually displayed on the item.

31.13 Blueprints & Legendary Crafting
Blueprints

Drop from dungeon floor bosses

Not region-locked

Permanently unlock epic crafting recipes

Blueprint-crafted items:

Are Epic rarity

Roll two region passives

Allow the player to select a stat priority

Guarantee one stat at maximum roll

Blueprints emphasize control and planning.

Legendary Crafting

Requires legendary materials

Crafted at facilities

Produces a random legendary of selected type

No stat guarantees

Legendary crafting emphasizes power and risk.

31.14 Gold Economy & Item Access

Heroes earn gold from:

Combat

Defense battles

Gold is spent by heroes to buy items from the shop

When an item is purchased:

It is removed from the shop

Other heroes cannot buy it

31.15 Item Loss & Risk

Uninsured items are lost on hero death

Insured items are retained

Shopkeeper always escapes with insured items only

This reinforces meaningful risk without full run loss.

31.16 Implementation Notes (Godot / Claude)

Item generation is deterministic after shop selection

Facilities act as item factories

Shared inventory simplifies state tracking

All values use flat numbers for ease of tuning