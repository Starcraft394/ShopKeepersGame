ChatGPT said:

Perfect — this completes the dungeon loop and gives us the final missing mechanic:

✔ Floors act as checkpoints
✔ Player chooses to continue or return to town
✔ Continuing gives a stacking XP bonus
✔ Returning resets the shop + banks materials

Now that this is confirmed, I can finalize Section 20 cleanly, coherently, and aligned with all your systems.

Below is the fully polished, plug-and-play GDD version of Section 20, followed by the Fix Notes update for your tracking document.

------------------------------------------------------------
📘 SECTION 20 — DUNGEON NODE & MULTI-FLOOR SYSTEM
Final GDD Version
------------------------------------------------------------

Dungeons in Shops & Shadows are multi-floor, node-based challenges that allow strategic farming, progression, risk-management, and long-term resource building. Each town has a 4-Tier Dungeon Facility, and each Tier unlocks deeper floors.

This system is deeply tied to:

Town progression

Facility upgrades

Hero survival

Materials economy

Shop refresh logic

Late-game scaling

------------------------------------------------------------
20.1 Dungeon Structure Overview
------------------------------------------------------------

Each Town Dungeon contains up to four floors, depending on the Dungeon Facility Tier:

Facility Tier	Floors Available
T1	Floor 1
T2	Floors 1–2
T3	Floors 1–3
T4	Floors 1–4 (Boss Floor)

Each floor is a self-contained map built from a branching series of nodes—combat, resources, events, rest rooms—leading to a floor exit.

Floors increase in difficulty and reward quality as depth increases.

------------------------------------------------------------
20.2 Floor Select Menu (Pre-Run)
------------------------------------------------------------

When entering a dungeon, players may choose which unlocked floor to begin at:

Enter Town Dungeon
[ Floor 1 ] (Easy)
[ Floor 2 ] (Unlocked)
[ Floor 3 ] (Unlocked)
[ Floor 4 – Boss ] (Unlocked when T4)


Choosing a deeper floor:

Does NOT grant rewards from earlier floors

Allows targeted practice and resource farming

Does NOT revive dead heroes

Is fully balanced by increased difficulty

------------------------------------------------------------
20.3 Floor Completion = Checkpoint Choice
------------------------------------------------------------

When the party reaches the end of a floor:

The player chooses:
Floor Complete!
[ Continue to Floor X+1 ]
[ Return to Town ]

✔ If the player Returns to Town:

Shop refreshes using:

Input materials

Facility autocrafting

Rarity rolls

All floor materials go to Town Storage

Heroes keep XP gained

Dungeon resets for future runs

Floors remain unlocked for re-entry

Run ends safely

No additional risk taken

✔ If the player Continues to the next floor:

No Shop Refresh

Resources in Shopkeeper Bag remain

Buffs remain active

XP gain is increased (see below)

Difficulty increases

Floor 4 becomes lethal if unprepared

------------------------------------------------------------
20.4 Continuous Run XP Bonus
------------------------------------------------------------

To reward risk-taking and multi-floor runs:

After each consecutive floor completion without returning to town:
Floor Reached Without Returning	XP Bonus for That Floor
1	+0% (baseline)
2	+10%
3	+20%
4	+30%

This applies only to combat XP, not victory bonuses or boss XP.

Benefits:

Encourages deeper plunges

Efficient for leveling heroes

Balances “floor skipping” strategy

Creates meaningful choice between safety and reward

------------------------------------------------------------
20.5 Mid-Floor Retreat (NOT a Checkpoint)
------------------------------------------------------------

If the player chooses to retreat before completing the floor:

Consequences:

Run ends immediately

All materials gathered this floor are lost

Shop does NOT refresh

Heroes keep XP earned so far

No floor unlock progress is lost

Heroes do not die

This prevents abuse of mid-run farming or shop resets.

------------------------------------------------------------
20.6 Hero Death Rules
------------------------------------------------------------
✔ Death is permanent in dungeons.
✔ Dead heroes cannot re-enter at deeper floors.
✔ They are recorded in the Book of the Dead.
✔ Only the Shopkeeper survives by fleeing with insured items.

There are no redo attempts unless future Undead systems allow revival.

------------------------------------------------------------
20.7 Node Map Structure (Per Floor)
------------------------------------------------------------

Each floor is a branching node map:

3–5 columns

6–10 rows

Start at Row 0

Boss or Exit node at final row

Each row reveals 1 step ahead

Optional deeper visibility through races (e.g., elves)

Node Types:

Combat

Resource

Event

Rest Room

Elite Combat

Floor Exit (special node)

Floor 4 Boss (Town Dungeon)

Nodes connect 1–3 at a time to allow pathing choice.

------------------------------------------------------------
20.8 Room Types (Summary)
------------------------------------------------------------
Combat Rooms

Standard XP

Monster parts

Gold

Tool-based resource chance denied (combat only)

Elite Rooms

Introduced at T3 floors

Better rewards

Harder scaling

Resource Rooms

Require tools (Hatchet, Pickaxe, Herb Pouch, Pole)

Small, controlled yield

Chance of 1 higher-tier drop if tools/affinities allow

NO monster parts

Event Rooms

Lost traveler hero

Item-for-item trades

Feral spirit

World-building encounters

Rest Rooms

HP recovery

Item use (food, potions)

Field Artificer crafting option

Insurance pocket management

------------------------------------------------------------
20.9 Boss Floor (Floor 4)
------------------------------------------------------------

The Town Dungeon Boss Floor:

Only available at T4

One unique boss encounter

Defeating it:

Marks town dungeon as complete

Grants 1 Boss Material

Rolls rarity distribution:

Rarity	Chance
Uncommon	50%
Rare	30%
Epic	15%
Legendary	5%

Refreshes the shop

Unlocks Region Dungeon once both towns’ T4 bosses are defeated

Boss Materials feed the Legendary Crafting subsystem via facilities.

------------------------------------------------------------
20.10 Region Dungeon (1 Floor Only)
------------------------------------------------------------

After both town dungeons are completed, the Region Dungeon unlocks.

✔ One extremely hard floor
✔ No new classes or races here
✔ Beating it unlocks the next region
✔ Drops one Region Boss Material (used for facility upgrades or crafting)
✔ Slightly improved rarity table (+2–5% Epic/Legendary chance)

This forms the structural gate for global progression.

------------------------------------------------------------
20.11 Farming Behavior
------------------------------------------------------------
Players may farm ANY unlocked floor:

Materials

Gold

Monster parts

XP (especially continuous-run XP bonuses)

Floors remain unlocked permanently after first completion.
Region Dungeons are not farmable (once-per-clear per visit).
------------------------------------------------------------
20.12 Data Structure Overview (Claude/Godot Ready)
------------------------------------------------------------
DungeonRun:
  floors: [Floor1, Floor2, Floor3, Floor4]
  current_floor
  materials_collected
  heroes_state
  skip_to_floor_allowed
  continuous_run_counter


Each Floor:

Floor:
  id
  node_map (graph)
  start_node
  exit_node
  boss_node (optional)
  difficulty_multiplier


Simple, scalable, clean for Claude automation.

------------------------------------------------------------
20.13 Dungeon Loop Summary
------------------------------------------------------------

Choose unlocked floor

Run node map

Complete floor

Choose:

Continue → harder enemies, XP bonus, no reset
Return to Town → shop reset, materials delivered


Heroes who die → permanent death

Materials only safe if floor completed

After both town T4 bosses → Region Dungeon unlocks

Region Dungeon beaten → advance region