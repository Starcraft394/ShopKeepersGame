ECTION 36 — PLAYER FLOW, MENUS & CORE GAME LOOP

This section defines the authoritative player flow for Shops & Shadows.
It governs when systems are accessible, how state changes, and what is saved or lost, ensuring consistent behavior across UI, combat, and progression.

This section supersedes any implied flow from earlier sections.

36.1 Core Gameplay Loop (Authoritative)

The game operates on the following loop:

Town Phase
 → Shop & Facilities
 → Party Assembly
 → Dungeon Selection
 → Dungeon Floors (1–4)
 → Floor Completion / Failure
 → Resolution (Loot / Death / Defense)
 → Return to Town

Hard Rules

The player may only be in one phase at a time

Phase transitions are explicit and saved

No system is accessible outside its allowed phase

36.2 Town Phase Rules

The Town Phase is the only phase where management actions occur.

Allowed Actions

Buy items from the shop

Assign facility slots

Upgrade facilities

Assign heroes to facilities

Change hero equipment

Use class books

Refine items

Salvage items

Craft via blueprints

Configure town defense

View world map

Select dungeon / floor

Locked Actions

No combat

No dungeon events

No resource gathering

No shop refresh unless triggered by rules

Town Inventory Rules

Inventory is shared globally

Gold is global

Materials are never auto-consumed

All facility material pulls require player confirmation

36.3 Shop Interaction Flow
Shop Availability

Only accessible in the current town

Only refreshes when:

A dungeon floor is completed

The player returns to town after extraction

A defense resolution completes

Shop Slot Selection

When selecting shop slots:

Player sees:

Required materials per slot

Material source (global storage)

Resulting item types

Materials are only consumed after confirmation

Cancelling reverts all changes

Shop Restrictions

No shop access inside dungeons

No mid-run refresh

Legendary items never appear naturally

36.4 Party Assembly & Preparation
Party Rules

Party size is fixed by progression

Only selected party enters dungeon

Heroes not in party may remain in town roles

Equipment Rules

Each hero must have:

Weapon

Armor

Accessories

Health Flask (permanent)

Weapon ability is previewed before entry

Consumables occupy inventory slots

Class Rules

Class books overwrite existing class

Class changes only allowed in town

Lich class obeys sacrifice rules

36.5 Dungeon Entry & Floor Selection
Dungeon Entry

Player selects:

Dungeon

Floor (if unlocked)

Floor selection persists between runs

Floor Rules

Floors unlock sequentially

Once a dungeon boss is defeated:

All floors remain unlocked permanently

Region dungeon access requires charged progress (Section 26)

36.6 In-Dungeon Rules
Allowed Actions

Combat actions

Movement

Ability usage

Consumable usage

Environmental interactions

Locked Actions

No shop access

No equipment changes

No class changes

No refining or salvaging

Extraction Rules

Extraction allowed only at end of floor

Player chooses:

Continue to next floor

Return to town

Early Exit

Exiting mid-floor:

Heroes survive

All run loot is lost

No shop refresh

No progress saved

36.7 Death, Failure & Resolution
Hero Death

Death is permanent

Hero recorded in Book of the Dead

Equipment dropped unless insured

No revival

Floor Failure

Party wiped:

Player restarts at beginning of that floor

Player may choose earlier floor instead

Floor Completion

Loot finalized

Shop refresh triggered

Autosave occurs

Optional XP bonus if continuing run

36.8 Town Defense Resolution
Timing

Town defense resolves:

When player returns to town

After dungeon completion or extraction

Outcomes

Victory:

Defense gold added to global pool

Heroes gain XP

Failure:

One random building tiers down (min T1)

Attack chance resets per rules

Defense Rules

No hero death

No item loss

Formation matters

Defensive bonuses apply only to assigned units

36.9 Save System & Autosaves

Autosaves occur:

On floor completion

On town return

After defense resolution

After boss defeat

After campaign completion

Manual saving is not required.

36.10 Player Information Guarantees

The game must always clearly display:

Material costs before commitment

Refinement risks

Permanent loss warnings

Boss requirements

Region charge progress

Inventory limits

No hidden mechanics or silent failures.

36.11 Explicit Non-Goals

The game does not include:

Real-time combat

Manual defense combat (viewing optional only)

Per-hero gold tracking

Timed crafting queues

Hidden stat scaling

Forced grind loops