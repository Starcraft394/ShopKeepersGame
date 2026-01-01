📄 MVP_Exit_Criteria.md

Shops & Shadows — MVP Quality Gate Checklist
Version: 1.0
Status: Locked (QA / Go-No-Go Document)
Scope Authority: MVP_Scope.md + MVP_Milestones.md

🎯 Purpose

This document defines when the MVP is officially “done.”

No feature creep

No “it mostly works”

Either the box is checked, or it isn’t

If any required item fails, MVP is not complete.

🧱 GLOBAL REQUIREMENTS (Must ALL Pass)

 Game boots from a clean project without editor intervention

 No critical errors or crashes during normal play

 All systems function without debug commands

 No placeholder logic remains

 No hardcoded test data in runtime paths

 Save/Load works across sessions

🟦 M0 — Data & Boot Spine

Status: REQUIRED

 DataRegistry loads without errors

 All core data types resolve correctly:

 Classes

 Races

 Items

 Abilities

 Status Effects

 Monsters

 Missing data produces readable errors (not crashes)

 Seeded RNG produces deterministic results when seeded

 No gameplay system bypasses the registry

❌ Fail example: combat works but uses inline stats
✅ Pass example: everything pulls from JSON → Data objects

🟦 M1 — Combat Loop

Status: REQUIRED

 Turn-based combat resolves deterministically

 Grid positioning affects targeting

 Abilities:

 Can be cast

 Obey cooldowns

 Apply effects correctly

 Status effects:

 Apply

 Tick

 Expire

 Death is permanent

 Combat always ends in win or loss (no deadlocks)

❌ Fail: infinite turns, frozen combat
✅ Pass: combat fully resolves every time

🟦 M2 — Town & Shop Loop

Status: REQUIRED

 Global gold system only (no per-hero gold)

 Shop inventory is generated via facilities

 Material costs are visible before confirming slots

 Buying an item removes it from the shop

 Heroes can equip / unequip items safely

 Inventory never duplicates items

❌ Fail: shop refreshes without player action
✅ Pass: refresh only on defined triggers

🟦 M3 — Dungeon Progression

Status: REQUIRED

 Player can select dungeon floor

 Clearing a floor:

 Grants loot

 Refreshes shop

 Mid-floor extraction:

 Cancels loot

 Preserves heroes

 Floor state resets correctly

 Dungeon can be re-entered repeatedly without corruption

❌ Fail: loot persists after failed extraction
✅ Pass: floor logic is airtight

🟦 M4 — Persistence

Status: REQUIRED

 Save file correctly stores:

 Heroes (alive/dead)

 Inventory

 Global gold

 Facility tiers

 Dungeon progress

 Load restores exact previous state

 Save versioning exists

 Corrupt saves fail gracefully

❌ Fail: duplicated items after load
✅ Pass: byte-for-byte state continuity

🟦 M5 — MVP Validation

Status: REQUIRED

 Full loop playable:

Town → Dungeon → Combat → Town

 No console-only interactions required

 Player can lose (soft or hard) without breaking the game

 MVP_Scope.md has zero missing features

 Known issues documented separately

🚦 FINAL GO / NO-GO

✅ GO: All checklists complete

❌ NO-GO: Any unchecked REQUIRED item

🔒 Lock Rule

Once MVP is marked GO:

No changes without a new milestone

No refactors “because it’s easier now”

✅ End of MVP_Exit_Criteria.md