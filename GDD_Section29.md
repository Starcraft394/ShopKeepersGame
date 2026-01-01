Section 29 — Save System & Persistence Rules (FULL DRAFT)

Below is a fully filled-out Section 29, copy-paste safe, Claude/Godot friendly, and designed to prevent save corruption, logic ambiguity, or unintended exploits.

29. Save System & Persistence Rules
29.1 Save Philosophy

The save system in Shops & Shadows must be:

Reliable

Transparent

Resistant to corruption

Friendly to iteration and debugging

The game is not permadeath at the campaign level, but individual heroes and towns may suffer permanent consequences.

29.2 Save Types
Campaign Save

Represents one full campaign run

Includes:

World progression

Regions unlocked

Town states

Hero roster

Inventory and storage

Only one active campaign save at a time (initially)

Meta Save

Persists across campaign restarts

Stores:

World Tome progress

Favorite heroes

Unlocked races/classes

Settings & accessibility options

29.3 Autosave Rules

Autosaves occur at safe checkpoints only:

Entering a town

Completing a dungeon floor

Completing a region

Before and after region boss fights

After town defense resolution

Autosaves never occur:

Mid-combat

Mid-floor

Mid-decision prompt

This prevents soft-locks and exploit abuse.

29.4 Manual Saves

Manual saving is allowed only in towns

Manual saves overwrite the current campaign save

No save scumming during combat or dungeon runs

29.5 Hero Persistence Rules

Each hero stores:

Race

Class

Level & XP

Equipped items

Inventory

Status (Alive / Dead / Sacrificed)

Hero Death

Permanent in-campaign

Recorded in the Book of the Dead

Cannot be reverted via reload

29.6 Town Persistence Rules

Each town stores:

Region association

Facility tiers

Assigned heroes

Defense readiness

Damage state (tiered-down buildings)

Town destruction and downgrades are persistent until repaired.

29.7 Dungeon Persistence Rules

Dungeon floors unlock permanently once cleared

Failure resets only the current floor

Floor selection persists between runs

Region Boss charge count is saved persistently.

29.8 Inventory Persistence
Shared Inventory

One global inventory across all towns

Resources are never duplicated

Facility upgrades pull from shared inventory manually

Shopkeeper Bag

Emptied at run start

Filled only during dungeon runs

Lost on mid-run extraction or party wipe

29.9 World Tome Persistence

World Tome progress:

Stored in Meta Save

Persists across campaigns

Cannot be respecced initially (future option)

World Tome points are 0 on first campaign run.

29.10 Book of the Dead Persistence

Records all fallen and sacrificed heroes

Favorites persist across cycles

Used for:

Memorial reference

Lich interactions

Cosmetic callbacks (future)

No mechanical bonuses are granted by default.

29.11 Post-Game & New Cycle Persistence

On campaign completion:

Player selects:

Carryover heroes (limited)

Carryover resources (slot-limited)

World resets:

Towns

Regions

Dungeons

Difficulty increases

Corruption and advanced mechanics activate

Meta progression remains intact.

29.12 Data Integrity & Recovery

To protect player data:

Saves are versioned

Previous save is backed up automatically

Corrupt saves fall back to last valid state

Claude/Godot implementations must:

Validate save schema on load

Gracefully handle missing fields

29.13 Developer / Claude Implementation Notes

Recommended structure:

JSON or Godot Resource-based saves

Separate files for:

Campaign state

Meta progression

Clear schema versioning

No hidden or implicit save logic.