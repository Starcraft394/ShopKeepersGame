SECTION 37 — UI STATE MAPPING & INTERACTION RULES

This section defines all UI states, what is visible, what is interactive, and what is locked at any given time.

Its purpose is to:

Prevent UI overlap and clutter

Ensure Godot scenes are cleanly separated

Make interaction rules unambiguous for automation

Avoid “can I do X right now?” edge cases

This section is authoritative for UI behavior.

37.1 UI Design Principles

Single Primary Focus Rule

Only one primary interaction panel may be active at a time

Secondary info panels may appear only if contextual

Context-Driven Visibility

UI appears only when relevant

No persistent clutter

Hidden by default, revealed by intent

State-Locked Interactions

If an action is not allowed in the current phase, the UI element:

Is hidden OR

Is visible but disabled with tooltip

Explicit Player Feedback

Every locked action explains why it is locked

37.2 Global UI Layers (Always Available)

These elements are always present regardless of state:

Top Bar

Global Gold

Region Name

Current Town Name

World Tome access (post-campaign only)

Bottom Bar

Party Summary (portraits only)

Current Phase Indicator (Town / Dungeon / Defense)

Overlay Tooltips

Hover-based explanations

No modal blocking unless explicitly stated

37.3 Town Phase UI States
37.3.1 Town Overview Screen (Default)

Visible

Town map background

Facility icons

Shop icon

Dungeon entrance icon

Defense facility icon

Hidden

Inventory

Hero details

Shop contents

Actions

Click facility → Facility UI

Click shop → Shop UI

Click dungeon → Dungeon Select

Click hero portrait → Hero Detail

37.3.2 Facility UI State

Visible

Facility name & tier

Assigned heroes

Upgrade button

Facility-specific controls (refine, blueprint, etc.)

Hidden

Shop inventory

Dungeon UI

Rules

Material requirements shown before confirmation

No auto-pulling from inventory

Locked features show unlock conditions

37.3.3 Shop UI State

Visible

Shop item grid

Item costs

Item stats & passives

Shop slot configuration (if editing)

Hidden

Facility UI

Dungeon UI

Rules

Purchasing removes item from shop globally

No item duplication

Shop refresh only via rules (Section 36)

37.3.4 Hero Detail UI

Visible

Stats

Equipment

Abilities

Passives

Inventory

Flask charges

Expandable Panels

Ability details

Weapon ability

Refinement history (hover)

Rules

No equipment changes outside town

Class books usable only here

Warnings shown for irreversible actions

37.4 Dungeon Selection UI

Visible

Dungeon list

Floor selection

Floor completion indicators

Region charge progress (if applicable)

Locked

Floors not yet unlocked

Region boss if insufficient charges

Rules

Player explicitly selects floor

Last selected floor remembered

Entry confirmation required

37.5 In-Dungeon Combat UI
37.5.1 Combat Grid View

Visible

Grid tiles

Units

Active effects (icons only)

Enemy intent indicators

Hidden

Inventory management

Shop

Facility UI

37.5.2 Selected Unit Panel (Bottom)

Appears when a unit is selected.

Shows

HP / Mana

Active status effects (with countdown icons)

Abilities

Weapon ability

Equipped items (icons only)

Rules

One selected unit at a time

Switching selection collapses previous panel

37.5.3 Tile Inspection Mode

Activated by:

Holding inspect key

Clicking inspect icon

Shows

Tile effects

Duration (∞ or countdown)

Source (enemy / environment / ability)

Hidden otherwise

37.6 Extraction & Floor Completion UI
End-of-Floor Panel

Options

Continue to next floor

Return to town

Displays

XP gained

Items collected

Warnings about continuing

Rules

Extraction only allowed here

Autosave triggers on choice

37.7 Defense Resolution UI

Triggered On

Return to town

Defense event roll

Displays

Outcome (Victory / Failure)

Gold gained

Building tier changes (if any)

XP gained by defenders

Rules

No interaction during resolution

Option to view replay (optional)

37.8 Modal UI Rules
Hard Modal (Blocks Everything)

Class overwrite confirmation

Hero sacrifice

Item destruction

Town destruction events

Soft Modal (Non-Blocking)

Tooltips

Info panels

Warnings

37.9 Error Handling & Edge Cases

Invalid actions never fail silently

UI must explain:

Why something is locked

What is required to unlock it

No overlapping modals

No action chains without confirmation

37.10 Accessibility & Clarity (Baseline)

Icons always paired with tooltip text

Status effects use:

Color

Symbol

Countdown number

No color-only indicators