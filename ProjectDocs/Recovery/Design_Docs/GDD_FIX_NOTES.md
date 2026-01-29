📘 **GDD_FIX_NOTES.md — Shops & Shadows

Version 0.1 — ACTIVE CHANGE LIST**

This document tracks all required refinements, corrections, and rule replacements across all GDD sections.
Once all sections 1–21 are complete, the changes here will be applied to create:

Shops & Shadows — GDD v1.4 (Integrated Clean Edition)
-------------------------------------------
SECTION A — REGION NAME UPDATES
-------------------------------------------
Replace old placeholder region names with final names:

❌ Verdant Isles →
✔ Forest Haven

❌ Timberwild Frontier →
✔ The Fungalmire

❌ Ironmarch Foothills →
✔ The Sunken Strand

❌ Blazewind Barrens →
✔ Ashen Horizons

❌ Shattered Coast →
✔ Starfall Expanse

❌ Shadowdeep →
✔ The Necropolis

❌ Voidlands →
✔ Final Realm

Affected Sections: 3, 9, 14, early drafts of 15, 16 schema references.
Fix: Replace all region name references with the finalized set.

-------------------------------------------
SECTION B — TOWN DEFENSE SYSTEM UPDATE
-------------------------------------------

Replace all early GDD mentions of “legacy town defense,” “simple defense rolls,” or “Town 3 Raid rules” with the modern system:

✔ Guard Yard Facility

Mixed tile grid (defensive/offensive tiles)

Heroes placed according to strategic formation

Bonuses scale by facility tier

Auto-resolve or optional battle view

✔ Tier-Down Logic

If heroes fail defense:

One random building → Tier -1

Buildings stay broken until repaired

Town can be attacked again even before repair

✔ Post-Region 3 Activation

Town Defense only begins after Region 3 completes.

Affected Sections: 6, 9, 11 narrative, 12 progression.
Fix: Replace all previous defense logic with Section 16’s system.

-------------------------------------------
SECTION C — CORRUPTION TIMING CORRECTION
-------------------------------------------

Update corruption rules:

❌ Remove early-game corruption tiles
✔ Corruption tiles only appear late-game or postgame
Correct Model:

Regions 1–3: No corruption tiles.

Region 4: Visual hints only; no tile effects.

Region 5: Event-based tile hazards.

Region 6: Active corruption tiles begin.

Region 7: Fully corrupted tile mechanics.

Affected Sections: 9, 10, 16.
Fix: Remove all references to early corruption mechanics.

-------------------------------------------
SECTION D — TOWN DESTRUCTION SEQUENCE UPDATE
-------------------------------------------
Modern, correct sequence:

After Region 3 completion:

A random Region 1 town is destroyed

All its buildings return to Tier 1

After Region 4 completion:

A random Region 2 town is reduced to Tier 2

After Region 5 completion:

A random Region 3 town is reduced to Tier 3

Replace older references to:

Town 3 Raid

Town wipe/complete destruction

Early threats

Affected Sections: 3, 12, narrative sections.
Fix: Implement progressive-tier destruction instead of complete reset.

-------------------------------------------
SECTION E — HERO UNLOCK SYSTEM CORRECTION
-------------------------------------------
Final Rule:

Town A = Race unlock
Town B = 2-Class Pair unlock

Remove old logic:

❌ “Heroes for hire come pre-classed.”
❌ “Class is chosen by a facility NPC.”

Correct Rule:

✔ Early heroes are classless until they obtain a Class Book from the shop.
✔ Training Hall unlock allows distributing classes manually.
✔ Class Towns (Town B) introduce class pairs.

Affected Sections: 4, 6, 8, 15.
Fix: Replace all references to pre-classed hires.

-------------------------------------------
SECTION F — REFINEMENT & REFORGING REWRITE
-------------------------------------------
Replace early refinement system with:

✔ Refinement unlocks at Tier 3
✔ Player chooses a stat group (Offense / Defense / Utility)
✔ One random stat from the group is increased
✔ Safe zones: 1–4
✔ Increased risk: 5–8
✔ Break chance: 9–10
✔ Legendary upgrades only at Tier 4, depends on the region’s theme

Affected Sections: 7, 10, items documentation.
Fix: Replace all simple upgrade text with the full system above.

-------------------------------------------
SECTION G — REGIONAL BOONS ESTABLISHED
-------------------------------------------

The master GDD must include:

✔ Combat boon
✔ Gathering boon
✔ Boon scaling by total building levels
✔ Only active when both towns are operational
✔ Town destruction reduces boon power

Affected Sections: 3, 6, 12, 16.
Fix: Add boon info or replace older generic region notes.

-------------------------------------------
SECTION H — RESOURCE FLOW UPDATED
-------------------------------------------

Replace earlier notes about random town storage logic with:

✔ Shopkeeper storage = main resource hub
✔ Resources deposited automatically at expedition end
✔ Background-click bonus resources allowed
✔ Tools required to harvest creature/environment resources
✔ Starter tools given when building T1 facilities

Affected Sections: 4, 7, 8.
Fix: Replace outdated inventory/town storage references.

-------------------------------------------
FIX DOCUMENT COMPLETE (v0.1)
Future revisions will append below this line.
-------------------------------------------

Section I — Monster Framework Updates

Update any older mentions of “random monster behavior” to align with the Monster Family Framework in Section 17 (families, roles, family_passives).

Ensure Region 1 monsters are documented as no family passive, no abilities.

Ensure Regions 2–3 monsters are documented as having family passives but no active abilities.

Ensure Regions 4–7 monsters are documented as having at most one active ability + a family passive.

Align resource drop descriptions in Sections 4, 7, and 16 with the “family → resource” mapping in Section 17.

--------------------------------------------
18.8 FIX NOTES — Required Updates
--------------------------------------------

Add this to GDD_FIX_NOTES.md:

Section J — Resource System Expansion (FINAL)
✔ J.1 Regional materials overhaul

Replace older resource lists with the new Region 1–7 material lists including woods, ores, herbs, foods, specialties, and region passive pools.

✔ J.2 Remove references to crafting menus

Player does NOT craft items → facilities autogenerate gear using supplied materials.

✔ J.3 Update tools system in Section 4

Tools = Hatchet, Pickaxe, Herb Pouch, Fishing Pole.

✔ J.4 Update all facilities in Section 7

Facilities craft items into shop slots based on:

Region

Tier

Input materials

Facility type

✔ J.5 Replace “Monster Bones” with Meaty Bone everywhere

Used for food & early upgrades.

✔ J.6 Add region recipe unlock rules

Food & Alchemy only.

✔ J.7 Field Artificer resource privilege clarification

Add final rules for persistent materials & crafted items.

------------------------------------------------------------
19.12 FIX NOTES — SECTION K (FINAL)
------------------------------------------------------------

Add the following to GDD_FIX_NOTES.md:

Section K — Town Defense Adjustments (Final Version)
✔ K.1

Buildings tier down on failed defense but cannot fall below Tier 1 except via scripted story events.

✔ K.2

If both towns in the threatened region have all buildings at Tier 1, attack chance becomes 10%.

✔ K.3

Attack frequency does NOT escalate across regions — only enemy strength escalates.

✔ K.4

Guard Yard must be added to facility master list as a unique global facility.

✔ K.5

Heroes in the Guard Yard:

Gain passive XP for each defense

Cannot die during defense

Receive Town Defense Bonuses

Are removed from adventuring roster

Can be replaced at any time

✔ K.6

Defense Treasury rules:

Gold is never auto-spent

Gold is stored until player chooses to use it

Used only for defender gear upgrades

Legacy heroes retain personal gold if removed

✔ K.7

Defense battles act as a training and resource engine, not a punishment system.

✔ K.8

Threat progression and town destruction timeline updated to match Region 3, 4, and 5 triggers.

------------------------------------------------------------
📝 FIX NOTES — SECTION L (FINALIZED)

Add this to GDD_FIX_NOTES.md

Section L — Dungeon System Fixes (Final)

L.1
Dungeons are multi-floor; each floor is a node map. Update all earlier references to “single dungeon maps.”

L.2
Completing a floor creates a checkpoint; player may Continue or Return to Town.

L.3
Shop resets ONLY when the player returns to town after finishing a floor.

L.4
Mid-floor retreat causes:

Loss of all materials collected on that floor

No shop reset

Safe hero extraction

L.5
Boss Material drops:

Always 1 drop

Rarity rolled Uncommon→Legendary

Legendary never guaranteed

L.6
All floors remain unlocked after their first completion, even after boss defeat.

L.7
Region Dungeon = one very hard floor; beating it unlocks next region.

L.8
Permanent death rules apply to all dungeon floors, including skipped floors.

L.9
Add XP bonus scaling for consecutive floor completions: +10%, +20%, +30%.

L.10
Dungeon Facility Tiers determine floor access (T1–T4).

------------------------------------------------------------
📝 FIX NOTES — SECTION M (Postgame System)
------------------------------------------------------------

M.1 Campaign completion triggers NG+ world reset, not partial reset.
M.2 Carryover heroes retain all gear, traits, and levels.
M.3 Memorial Heroes provide cosmetic hire-pool options only.
M.4 Town Defense activation moved to Region 1 for NG+.
M.5 Shared global storage replaces per-town storage.
M.6 All races remain unlocked in NG+ regardless of region.
M.7 Tome Points cost set to 5 per rank (10 for Shop Rarity Floor).
M.8 Tome total cost = 225 points.
M.9 Facility Node 5 replaced with Worker XP from Production system.
M.10 Prestige material carryover limits defined (10/5/1).
M.11 Manual facility resource loading replaces auto-pull.
M.12 Only the active town’s shop refreshes on floor completion.

------------------------------------------------------------
📝 SECTION N — FIX NOTES FOR SECTION 22
------------------------------------------------------------

These changes must be applied across the entire GDD to maintain full consistency.

N.1

Regions 4, 5, and 7 now have locked races:

Region 4 → Dragonkin

Region 5 → Crystalborn

Region 7 → Voidwalkers

Update all earlier race lists accordingly.

N.2

Racial passives updated:

Dragonkin: Scaled Hide / Embersoul

Crystalborn: Refraction Field / Resonance Echo

Voidwalkers: Voidborne / Flicker Step

Remove any placeholder or earlier mentions of “TBD race traits.”

N.3

Lich class no longer uses tile-based mechanics.
Remove any statements implying:

Bonus in darkness

Bonus on corrupted tiles

Position-dependent power boosts

N.4

Striker (Region 1) is now dual-path: melee OR ranged.
Ensure the weapon guides and early-game tutorials reflect this.

N.5

Total classes updated to 16, not 14.
Adjust documentation anywhere totals are referenced.

N.6

Region unlock flow must now reflect:

3 classes in Region 1

2 classes per class town in Regions 2–6

1 final class in Region 7

N.7

Any references to “race/class synergies” must use the final rules:

NO stat-based synergy

Only unique mechanical traits per race

Remove any previous references to bonuses like +crit, +ATK, etc.

N.8

Clarify in all sections:
Class Books can overwrite existing class assignments with no penalty.

------------------------------------------------------------
📝 SECTION N — FIX NOTES FOR SECTION 23
------------------------------------------------------------

These notes describe changes that must be reflected across earlier sections of the GDD.

N.23.1 Turn-Based System Confirmed

All earlier mentions of tick-based or “0.25s loop” combat should be replaced with this turn-based model.

Any references to real-time cooldowns must be updated to turn-based cooldowns.

N.23.2 No Ultimate Abilities

Remove or revise any prior mention of “ultimate” or “once-per-fight super abilities.”

Classes now use: Basic Attack + Class Ability A + Class Ability B + Weapon Ability + Passives.

N.23.3 Weapon Ability System

Update class & equipment sections (especially Section 7 and race/class overview sections) to reflect that:

Each weapon type grants a weapon ability.

Higher tier weapons evolve the same ability family.

Legendary weapons may have enhanced versions of these abilities.

N.23.4 Race Passives & Weapon Abilities

Race passives should not directly multiply or scale weapon abilities unless explicitly designed later.

They remain always-on identity modifiers (resistances, vision, pathfinding, etc.).

N.23.5 Class Passives & Weapon Abilities

When writing/revising class passives in Section 24, some may reference weapon ability usage for extra flavor (e.g., “gain X after using your weapon ability”), but this is optional and should be done carefully to avoid hardlocking classes into one weapon type.

N.23.6 Field Artificer Resource Usage

Any previous mention of the Field Artificer using herbs should be removed.

Field Artificer gadgets are crafted from:

Metals, leather, monster parts, crystals/glass, mechanical scrap.

Herbs remain dedicated to Chef and Alchemist style facilities.

N.23.7 Enchanter (Future Expansion)

Reserve enchantment-based weapon modification (using herbs + jewelry/glass) for a potential future Enchanter class/facility, not the Field Artificer.

Any speculative notes about enchantments should be clearly labeled as “post-launch expansion ideas.”

FIX 24.1 — Defender Ability Kit
• Section 7 (Facilities): No direct interaction needed; Defender’s kit fits existing systems.
• Section 15 (Classes): Update class summary to reflect confirmed ability kit (2 actives, 2 passives).
• Section 22 (Races): No race conflict; Defender works with all races.
• Section 23 (Ability System): Weapon synergy aligned; no changes needed.
• Section 19 (Town Defense): Add note that Defenders are strongly recommended for defense grid front row.
• Section 20 (Dungeons): Add minor note that Defenders help stabilize patterns of early floors.

FIX 24.2 — Warden Ability Kit
• Section 7 (Facilities): No changes; Warden does not interact with crafting systems.
• Section 15 (Classes): Add full description of Warden’s role, passives, and abilities.
• Section 18 (Resources): Warden does not consume herbs (healing is magical/natural, not alchemical).
• Section 20 (Dungeons): Add note that Warden greatly increases success chance on early floors for new players.
• Section 23 (Ability System): Update examples to include heals and regen consistent with Warden’s abilities.
• Town Defense: Note that Warden in back row adds strong sustain but low damage.

FIX 24.3 — Striker Class Kit
• Update Section 15 (Class Overview) to include Striker’s dual-path identity.
• Ensure Section 23’s initiative system includes Striker as a high-initiative class.
• Update weapon ability synergy notes in Section 23 to reflect Striker’s flexibility (melee or ranged).
• Add note to Section 20 (Dungeon Floors) that Striker builds excel at finishing enemies quickly but require protection.
• Add note in Section 19 (Town Defense) that Striker AI should prioritize low-HP targets when possible.

FIX 24.4 — Druid Ability Kit
• Section 15 (Classes): Add Region 2 Druid overview.
• Section 18 (Resources): Ensure spores are treated as combat-only statuses, not inventory items.
• Section 20 (Dungeons): Add note that Druid excels in multi-enemy floors but has slow boss ramp.
• Section 22 (Races): Mossfolk gain thematic synergy but no mechanical bonuses; update notes for flavor.
• Section 23 (Ability System): Include spore DoT behavior in the status effect examples.
• Section 19 (Town Defense): Druid in defense should value AoE spore application early.

FIX 24.5 — Fungal Berserker
• Section 15 (Classes): Add Berserker as Region 2 Class #2.
• Section 16 (Region Map): Ensure Magic Caps Rest unlocks Berserker.
• Section 18 (Resources): Update DoT list to include Bleed, Poison, Burn, Hex, etc.
• Section 20 (Dungeons): Add note that Berserker excels in long boss fights and DoT-heavy regions.
• Section 23 (Ability System): Add Feral Charge as a new resource type and DoT-consuming mechanics.
• Section 22 (Races): Mossfolk synergy cosmetic only; no mechanical bonuses added.

FIX 24.6 — Tidechaser Class Kit
• Section 15 (Classes): Add Tidechaser to Region 3 class list.
• Section 16 (Regions): Ensure Sunken Strand’s first class unlock is Tidechaser.
• Section 17 (Monsters): Add note for Tidechaser interactions with displacement-sensitive enemies.
• Section 20 (Dungeons): Update movement rules with push/pull clarity.
• Section 23 (Ability System): Add displacement + initiative gain interactions.
• Section 24 (Grid Rules): Confirm allies and enemies can be moved without collision errors.

FIX 24.7 — Stormcaller Class Kit
• Section 15 (Classes): Add Stormcaller as Region 3 Class #2.
• Section 17 (Status Effects): Add Shock and Dazed definitions.
• Section 18 (Resources): Confirm Shock counts as a DoT globally.
• Section 20 (Dungeons): Note Stormcaller excels at clustered encounters.
• Section 23 (Ability System): Add Overload trigger rules and Daze timing.
• Section 24 (Class Kits): Ensure Stormcaller uses flat values only.

FIX 24.8 — Pyrewarden Class Kit
• Section 15 (Classes): Add Pyrewarden as Region 4 Class #1.
• Section 17 (Status Effects): Add Ember definition.
• Section 18 (Resources): Confirm Burn is fire DoT, Ember is setup-only.
• Section 20 (Dungeons): Note Pyrewarden excels at choke-point fights.
• Section 23 (Ability System): Add Ember as non-damaging stack mechanic.
• Section 24 (Class Kits): Ensure no tile dependency for Dragonkin classes.

📝 FIX NOTES — SECTION 24.9

Section 15 (Classes)
Add Ashblade as Region 4 Class #2 (Assassin role)

Section 22 (Races)
No race synergy required; Ashblade works with all races

Section 23 (Ability System)
Ash Marks are not DoTs and should be excluded from DoT systems

Section 19 (Town Defense)
Ashblades are high-risk defenders; recommended for assassination tiles, not frontline

FIX 24.10 — Prism Sentinel Class Kit
• Section 15 (Classes): Add Prism Sentinel as Region 5 Class #1.
• Section 23 (Ability System): Introduce tile-based mechanics distinct from status effects.
• Section 24 (Class Kits): Establish Region 5 pivot toward positional gameplay.
• Section 19 (Town Defense): Prism Sentinel excels in defensive formations.
• Section 20 (Dungeons): Prism Sentinel strong vs burst-heavy encounters.

FIX 24.11 — Prism Lancer Class Kit
• Section 15 (Classes): Add Prism Lancer as Region 5 Class #2.
• Section 23 (Ability System): Introduce directional damage rules (line checks).
• Section 24 (Class Kits): Establish Crystal DPS archetype without stacking mechanics.
• Section 20 (Dungeons): Prism Lancer excels in narrow or linear encounters.

FIX 24.12 — Dark Channeler Class Kit
• Section 15 (Classes): Add Dark Channeler as Region 6 Class #1.
• Section 17 (Status Effects): Redefine Doom as countdown-based execution.
• Section 23 (Ability System): Add Soul Charges as combat-only resource.
• Section 24 (Class Kits): Establish Region 6 as inevitability/timing pivot.
• UI Notes: Doom uses clock icon showing turns remaining.

Fix Notes — Section 24.13

Phylact Minion now inherits class ability + passives

Sacrificed hero recorded in Book of the Dead

All bonuses converted to flat values

Harvest stacks now scale by unit type

Added hard cap to Harvest (max 8)

Clarified cooldowns and healing/damage values

Removed all percentage scaling

Fix Notes — Section 24.14

Introduced Phase as a presence/targeting mechanic

Avoided stacking statuses and DoTs

Ensured compatibility with turn-based combat

No overlap with Assassin or Control classes from earlier regions

Final-region complexity without systemic bloat

Fix Notes — Section 24.15

Introduced Corruption as a threshold-based mechanic

Avoided DoTs, stacking damage, and tile effects

Ensured synergy with Voidwalker Phase State

Ensured compatibility with turn-based grid combat

No changes required to earlier sections