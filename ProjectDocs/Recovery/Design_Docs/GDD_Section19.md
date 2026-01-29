------------------------------------------------------------
📘 SECTION 19 — TOWN DEFENSE SYSTEM (FINAL VERSION)
------------------------------------------------------------

The Town Defense System represents the resistance of settlements across the world against rising monster threats. This system activates after the destruction of Town 1 at the end of Region 3, and evolves throughout Regions 4–7.

Town Defense is designed to:

Provide strategic structure to the overworld

Reward long-term roster building

Generate extra gold and XP

Apply world pressure without punishing players

Make use of legacy heroes and retired champions

Support the fantasy of a world that reacts dynamically

This system is a training and strategic management loop, not a punishment mechanic.

------------------------------------------------------------
19.1 When Town Attacks Begin
------------------------------------------------------------

Town attacks become part of the core loop once Region 3 is completed.

Trigger	Result
Complete Region 3	One random Region 1 town is destroyed (buildings reset to Tier 1). Town Defense system activates globally.
Complete Region 4	One random Region 2 town is destroyed (reset to Tier 2 baseline).
Complete Region 5	One random Region 3 town is destroyed (reset to Tier 3 baseline).

Only these scripted events can destroy a town entirely.
Regular attacks can never reduce buildings below Tier 1.

------------------------------------------------------------
19.2 How Town Attacks Trigger
------------------------------------------------------------

Whenever the player returns from an expedition:

Step 1 — Select a threatened region

The currently threatened region is based on story progression:

After Region 3 → Region 1 becomes threatened

After Region 4 → Region 2 becomes threatened

After Region 5 → Region 3 becomes threatened

Step 2 — Random town is chosen

Only towns in the currently threatened region are eligible.

Step 3 — Attack chance roll

Base chance: 35%

If the last defense was a win: +5% per win (max 60%)

If both towns have ALL buildings at Tier 1: chance becomes 10%

Step 4 — If attack triggers → run Town Defense Battle

If not → nothing happens.

Attack frequency does NOT escalate per region.
Only enemy strength scales with region.

------------------------------------------------------------
19.3 The Guard Yard (Defense Facility)
------------------------------------------------------------

The Guard Yard appears automatically when the system unlocks.

It provides:

A Defense Grid

Hero placement slots (Offensive + Defensive)

Town Defense Bonuses

Defense Treasury (gold storage)

Battle preview and auto-resolve toggle

Importantly: Defense battles are always safe — heroes cannot die

------------------------------------------------------------
19.4 Guard Yard Grid Layout
------------------------------------------------------------

Defense uses a simplified 3×2 formation:

  [D] [D] [D]
  [O] [O] [O]


D = Defensive Slots (frontline)
O = Offensive Slots (backline)

Slot unlocking by facility tier:

Guard Yard Tier	Defensive Slots	Offensive Slots
T1	1	1
T2	2	1
T3	2	2
T4	3	3

Heroes placed here:

Are removed from the active adventuring roster

Gain passive XP for each Defense Battle

Receive Town Defense Bonuses

Are ideal candidates for Legacy hero placement

------------------------------------------------------------
19.5 Town Defense Bonuses
------------------------------------------------------------

These apply only during Defense Battles:

Tier 1

+5% Max HP

+5% DEF

Tier 2

+10% Max HP

+10% DEF

+5% All Resistances

Tier 3

+15% Max HP

+10% DEF

+10% All Resistances

+5% Damage

Tier 4

+20% Max HP

+15% DEF

+15% All Resistances

+10% Damage

These bonuses reward investment in Guard Yard tier.

------------------------------------------------------------
19.6 Defense Battle Simulation (Safe Outcomes)
------------------------------------------------------------

Defense Battles may be:

Watched manually

Auto-resolved using the same engine as dungeon combat

Heroes cannot die in town defense.

This maintains the system as pressure, not punishment.

Battle Steps

Generate enemy wave based on threatened region

Load hero defenders from Guard Yard

Run battle with full combat logic

Determine outcome (win or lose)

------------------------------------------------------------
19.7 What Happens When Heroes Win
------------------------------------------------------------

Winning grants:

✔ Town Survives

No building damage.

✔ Defense Treasury Gold +XP

Heroes earn XP and gold goes into the Defense Treasury, NOT the player's own gold pool.

Gold is:

Saved indefinitely

Only spent when the player chooses

Used to buy or upgrade equipment for defending heroes

Kept even if defending hero is later replaced

Not auto-spent for any reason

If a defending hero is a Legacy hero, they retain their personal gold pool separate from the Defense Treasury.

✔ Attack chance increases by +5%

Max cap: 60%

------------------------------------------------------------
19.8 What Happens When Heroes Lose
------------------------------------------------------------

Town loses the battle but heroes still survive (safe loss).

Consequences:

⚠ 1. One random building in the town tiers down by 1 level

But cannot fall below Tier 1.

Tier-down chain:
T4 → T3 → T2 → T1 → (never lower)

⚠ 2. Attack chance resets to 35%

Monster morale resets after a victory.

⚠ 3. If BOTH towns reach all Tier 1 buildings:

Attack chance becomes 10% until the player rebuilds something.

This ensures players are never overwhelmed.

------------------------------------------------------------
19.9 Town Defense as a Training & Resource Loop
------------------------------------------------------------

The Defense System is not punitive.
It is a background engine that:

✔ Trains heroes

✔ Generates gold for defenders
✔ Creates meaningful roles for Legacy heroes
✔ Keeps early towns relevant
✔ Encourages long-term roster depth

Players who invest in Guard Yards gain:

Stronger world buffs

Extra resources

More stable towns

Easier late-game progression

------------------------------------------------------------
19.10 Threat Progression (Enemy Strength Increases)
------------------------------------------------------------

While attack frequency is stable, enemy strength escalates:

Region	Threatened Towns	Enemy Strength
After R3	Region 1	Early enemies, scaled
After R4	Region 2	Stronger fungal enemies
After R5	Region 3	Tide monsters with stronger passives
After R6	Region 4	Fire/Arcane threats
After R7	Region 5–6	Extremely strong mixed corruption

This ensures defenders must be upgraded and trained over time.

------------------------------------------------------------
19.11 World Buffs for Maintaining Towns
------------------------------------------------------------

If both towns in a region are functioning (all buildings Tier 1+):

Region grants a World Buff:

Example — Region 1: Woodland Resolve

+1% Max HP for each building level across both towns in Region 1.

Each region has:

A combat-oriented buff

A gathering/economic buff (optional later)

This strongly incentivizes keeping towns repaired and defended.