# SHOPS & SHADOWS — CANON NOTES & SUGGESTIONS

**Purpose:** Working document for lore suggestions, future content ideas, and conflict resolution notes.
This is NOT locked canon — it is a living discussion space.

---

## OPEN QUESTIONS

### Region Structure
- Canon mentions 7 regions with distinct corruption types (Nature, Spore, Tidal, Fire, Arcane, Death, Void).
- Current game data only has `region_1`. How do regions map to towns/dungeons?
- Are Greenroot and Timberfall both in Region 1, or separate regions?

### Faction Leaders
- Each region has a faction leader who becomes the NG+ boss. Who are they?
- Need names, motivations, corruption expressions for each.
- Current monster data has no named boss entities yet.

### The Shopkeeper's Identity
- Canon says "not royal, not arcane elite" — currently no shopkeeper character data exists.
- Do we need a shopkeeper avatar/portrait?
- What is the shopkeeper's relationship to each town?

### Memory Sigil Crafting
- Memory Sigil is an equippable item — hero with it equipped carries over into NG+.
- Crafted from Fractured Grail Shard (first boss drop) and Timeline Cores (NG+ boss drops).
- What equip slot does it use? Accessory? Dedicated "sigil" slot?
- What other materials are needed beyond the shard/core?
- Which facility handles the crafting?

### Timeline Core Integration
- How do Timeline Cores interact with the existing save system?
- NG+ needs a "timeline counter" in GameContext.

### The Anchor Stone
- Canon says Anchor Stone is spatially fixed and the world rearranges around it each rewrite.
- No game data represents the Anchor Stone yet — no item template, no world object, no visual asset.
- How does the Anchor appear in-game? World map marker? Town background element? Interactable object?
- Anchor evolves visually per timeline — needs a visual state system (glow → fractures → oozing → pulsing).
- Does the Anchor have a physical location in Region 1 currently? Should it be near Greenroot?
- Anchor reacts to retained heroes in Timeline 4+ — what mechanical effect? Buff? Unlock? Event trigger?
- "Anchor cracks open after too many rewrites" — is this the true endgame? What timeline count triggers it?
- Anchor could unlock hidden mechanics — what are they? (crafting station? Memory Sigil forge?)
- Shopkeeper awareness arc (no awareness → déjà vu → realization) — how is this delivered in-game? Events? Cutscenes? Dialog?
- "Those Who Remember" camp scene — is this a scripted event or dynamic based on retained hero count?

### NG+ Starting Region
- Each NG+ starts the player in a different region (the corruption origin region).
- That region's native classes/races become the starting options.
- Need to define: which "neutral" classes/races carry over to every timeline? (Defender, Striker, Human, Elf, Dwarf?)
- Item quality_tier scaling per NG+ cycle — how steep? Linear? Exponential?
- **Retained heroes keep:** race, class, all equipped gear, bag contents. They **lose levels** (reset to 1).
- Non-retained heroes are lost entirely.
- Does the Shopkeeper's stash/gold carry over, or only hero-equipped items?

---

## FUTURE CONTENT SUGGESTIONS

### Near-Term (Can build on current systems)
1. **Corruption visual indicators** — Add `corruption_type` field to dungeons/monsters; tint UI elements.
2. **Lore collectibles** — New item_type `"lore_fragment"` with readable text; add to loot tables.
3. **Boss monsters** — Add boss-tier monsters to dungeon data with unique loot tables.
4. **Town atmosphere** — Add description/flavor text to town JSON for mood-setting.
5. **Void crystals as materials** — Add void-themed crafting materials tied to corruption lore.
6. **Fix void icon_hints** — Replace "dark purple/shadow" language with "crystalline/light-bending/refractive" per canon.
7. **Add corruption_type to region data** — Establish the field pattern for all 7 regions.
8. **Cultist faction tags** — Add `"void_cult"` tag to cultist monsters for future story gating.
9. **Anchor Stone world object** — Add Anchor Stone as a background/interactable element in the starting region.
10. **Anchor Stone visual states** — Define 4+ visual states matching timeline evolution (glow, fracture, ooze, pulse).

### Mid-Term (Requires new systems)
1. **NG+ framework** — Timeline counter, corruption origin selection, difficulty scaling.
2. **Memory Sigil system** — Special equipment slot for timeline-persistent items.
3. **Faction reputation** — Track player standing with regional factions.
4. **Lore codex UI** — In-game readable collection of earned lore fragments.
5. **Corruption meter** — Per-region corruption level affecting enemy spawns and events.
6. **Class/race region gating** — Gate classes and races by `unlock_region` as regions are built.
7. **Corruption overlay shader** — Define 7 visual overlays for NG+ timeline variant system.
8. **Anchor Stone interaction system** — Shopkeeper awareness arc events triggered by timeline count.
9. **"Those Who Remember" scene** — Camp event with retained heroes commenting on the Anchor Stone.

### Long-Term (Endgame)
1. **7 region world map** — Full region progression with distinct biomes.
2. **Void Sovereign boss fight** — Multi-phase endgame encounter.
3. **Timeline variant system** — NG+ corruption origin changes enemy types globally.
4. **Hero memory retention** — Persistent hero progression across timelines.
5. **Grail Nexus** — Region 7 final area with unique mechanics.
6. **Void/temporal art pack** — Crystalline fracture imagery, light distortion effects.
7. **Boss arena art** — Environment art reflecting each boss's ideological theme.
8. **Anchor Stone endgame** — Anchor cracks open after critical rewrite count; final-final-boss location.
9. **Anchor Stone as franchise hook** — Persistent visual evolution marker, hidden mechanic unlocks, Memory Sigil forge.

---

## CONFLICT RESOLUTION LOG

_Conflicts between canon and existing game data are logged here with resolution decisions._

| Date | Conflict | Resolution | Status |
|------|----------|------------|--------|
| 2026-02-15 | All 15 classes have `unlock_region: 1`, canon says classes tied to specific regions | **Intentional for dev testing.** Will gate when regions built. | Wontfix (Dev) |
| 2026-02-15 | All 9 races have `unlock_region: 1`, canon says races tied to regions | **Intentional for dev testing.** Will gate when regions built. | Wontfix (Dev) |
| 2026-02-15 | Void classes (Voidwalker, Void Herald) available in Region 1, canon says void is heretical | **Intentional for dev testing.** All classes accessible for balance testing. | Wontfix (Dev) |
| 2026-02-15 | Void visual language uses "dark purple/shadow", canon says "crystalline/light-bending" | Needs icon_hint rewrites across ~15 assets | Open |
| 2026-02-15 | "Corruption" used generically, canon says Nature-region corruption = accelerated growth | Non-breaking. Refine dungeon/monster descriptions when polishing. | Open |
| 2026-02-15 | Undead monsters in Region 1 (Nature), canon says Death = Region 6 | Minor — undead can appear as outposts. Reduce density later. | Deferred |
| 2026-02-15 | Cultist monsters lack faction allegiance, canon says Void Sovereign cultists | Non-breaking. Add `"void_cult"` tag when implementing faction system. | Open |
| 2026-02-15 | Cursed Dust described as "dark magic", canon says corruption = void radiation | Rewrite description when polishing item lore | Open |

---

## AGENT REVIEW NOTES

### Story Architect Review (2026-02-15)

**Overall Assessment:** Game data is in remarkably good structural alignment with canon. The 15-class system, 9-race system, and damage type framework map almost perfectly onto the 7-region structure. Primary conflicts are about *gating* — content that thematically belongs to later regions is available in Region 1 because only Region 1 exists.

**Key Conflicts Found:**
1. **Region count (expected):** Only 1 of 7 regions exists
2. **Class/race gating:** All 15 classes and 9 races have `unlock_region: 1`. Canon maps them to specific regions:
   - Region 1 (Nature): Defender, Striker, Warden, Druid + Human, Elf, Dwarf, Mossfolk
   - Region 2 (Spore): Fungal Berserker
   - Region 3 (Tidal): Tidechaser, Stormcaller + Tidelings
   - Region 4 (Fire): Pyrewarden, Ashblade + Dragonkin
   - Region 5 (Arcane): Prism Sentinel, Prism Lancer + Crystalborn
   - Region 6 (Death): Dark Channeler, Lich + Undead
   - Region 7 (Void): Voidwalker, Void Herald + Voidwalkers
3. **Void/Death classes in Region 1 shop:** Training Hall sells all class books including void (heretical per canon)
4. **Generic corruption language:** "Corrupted Heartwood" should reflect Nature corruption = accelerated growth
5. **Cultists lack faction identity:** Should serve Void Sovereign agenda

**Strong Alignments:**
- Class ecosystem maps perfectly to 7-region structure (2 classes per region + 2 neutral starters)
- Race system maps perfectly to 7 regions
- Shopkeeper identity matches canon core fantasy ("you do not fight, you build")
- Town warmth / dungeon danger contrast matches canon tone guidelines
- Event system tone nails "cozy grim-fantasy"
- Damage type system already supports regional distinctions

**Suggestions (see full report for details):**
- S1: Gate classes by `unlock_region` when regions built
- S2: Gate races by `unlock_region` when regions built
- S3: Remove void/death books from Region 1 Training Hall
- S4: Add `corruption_type` field to region data
- S5: Refine corruption references to match Nature-expression
- S6: Add cultist faction allegiance tags
- S7: Add `corruption_emitter` field to boss monsters
- S8: Prepare Memory Sigil / Timeline Core data structures

### Art Director Review (2026-02-15)

**Overall Assessment:** Excellent foundation for the "cozy" half of "cozy grim-fantasy." Town items, forest region, equipment, and event text all nail the warm, handcrafted tone. Critical failure point is the void/corruption visual language, which defaults to generic "shadow/darkness" instead of canon's "crystalline, light-bending, fractured geometry."

**Visual Conflicts:**
1. **CRITICAL — Void aesthetic systematically wrong:** Every void asset (~15 files) uses "dark purple / shadow / darkness" when canon demands "crystalline / fractured geometry / light bending / NOT darkness"
   - Voidwalker, Void Herald, all void abilities, all void passives, void race
   - Ironically, the Prism/Crystal classes already have the visual language void *should* have
2. **Dark Channeler:** Uses generic "shadow tendrils" instead of corruption-as-radiation imagery
3. **Cursed Dust:** "Dark magic" framing instead of "void radiation residue"
4. **Shadow Oil:** "Inky black" instead of light-refracting material

**Art Alignment Grades:**
- Town cozy aesthetic: **A**
- Nature/forest corruption: **A**
- Spore/fungal corruption: **B+**
- Fire corruption: **B+**
- Death corruption: **B**
- Tidal corruption: **B-**
- Void corruption: **F** (systematically wrong)
- Art pack coverage (town): **A**
- Art pack coverage (void): **F** (missing)
- Monster sprites: **D** (all unassigned)
- Event storytelling: **A**

**Art Gaps:**
1. No void/crystalline art pack exists
2. No corruption variant visuals for NG+ system
3. No boss arena art
4. No NG+ timeline visual system
5. All 47 monsters have empty `sprite_path`
6. Regions 2-7 have no art
7. No Memory Sigil / Timeline Core item visuals
8. No key NPC art (King, Void Sovereign, Shopkeeper)
9. No town background/environment art

**Priority Recommendations:**
1. Fix void icon_hints immediately (text-only change, no art needed)
2. Source or commission void/crystalline art pack
3. Differentiate void (pale crystalline) from death (green necrotic + amber soul-fire)
4. Assign monster sprites from existing Monsters packs
5. Design corruption overlay shader system for NG+ scalability
