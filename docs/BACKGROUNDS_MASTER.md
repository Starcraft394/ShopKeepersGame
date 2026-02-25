# BACKGROUNDS_MASTER.md

> Unified background system specification for ShopKeepers Game.
> Produced by: Repo Agent (Phase 1), Story Agent (Phase 2), Art Agent (Phase 3).
> Date: 2026-02-17 | Updated: 2026-02-19 (Rev 2 — corruption taxonomy, R4-R7 prompts, canon summary)

---

## Table of Contents

1. [Repo Facts](#1-repo-facts)
2. [Narrative Background Requirements](#2-narrative-background-requirements)
3. [Art System Spec](#3-art-system-spec)
4. [Prompt Library](#4-prompt-library)
5. [Asset Checklist](#5-asset-checklist)
6. [Godot Implementation Notes](#6-godot-implementation-notes)
7. [Open Questions](#7-open-questions)
8. [Confirmed Canon Summary](#8-confirmed-canon-summary)

---

## 1. Repo Facts

### 1.1 Project Resolution & Stretch

| Setting | Value |
|---------|-------|
| Viewport width | **960** |
| Viewport height | **540** |
| Aspect ratio | **16:9** |
| Stretch mode | **NOT SET** (defaults to `disabled`) |
| Stretch aspect | **NOT SET** (defaults to `ignore`) |
| Renderer | **gl_compatibility** (NOT Forward Plus — confirmed from project.godot) |
| Godot version | 4.5 |

**Action required:** Configure `canvas_items` stretch mode (see Section 6).

### 1.2 Scene Inventory — Backgrounds

Every scene uses an identical pattern: a full-rect `ColorRect` named `Background` as the first child of the root Control.

| Scene | File | Background Color | Hex Approx |
|-------|------|-----------------|------------|
| TownHubScene | `Game/UI/TownHub/TownHubScene.tscn` | `Color(0.15, 0.15, 0.2, 1)` | `#262633` |
| CombatScene | `Game/UI/Combat/CombatScene.tscn` | `Color(0.10, 0.09, 0.08, 1)` | `#1A1714` |
| DungeonCampScene | `Game/UI/Dungeon/DungeonCampScene.tscn` | `Color(0.1, 0.12, 0.15, 1)` | `#1A1E26` |
| RoomEventScene | `Game/UI/Rooms/RoomEventScene.tscn` | `Color(0.12, 0.1, 0.15, 1)` | `#1E1A26` |
| ShopScene | `Game/UI/Shop/ShopScene.tscn` | `Color(0.15, 0.15, 0.2, 1)` | `#262633` |
| TownScene (legacy) | `Game/UI/Town/TownScene.tscn` | `Color(0.12, 0.14, 0.18, 1)` | `#1E242E` |

### 1.3 UI Safe Zones

#### TownHubScene (960x540)
- **Left NavRail:** x=16 to x=176 (160px panel + 16px inset)
- **Content panel:** x≈188 to x=944
- **All sides inset:** 16px margin
- **Teal header bars:** 28px tall, inside ContentVBox

#### CombatScene (960x540)
- **Top bar:** y=0 to y=60 (TopBar 40px + DungeonProgressLabel 20px)
- **Battlefield zone:** y=65 to y=340 (275px tall, full width)
- **Bottom panel:** y=340 to y=540 (200px tall — log, buttons)

#### DungeonCampScene
- Centered content box: 360x320, viewport center

#### RoomEventScene
- Centered content box: 440x400, viewport center

#### ShopScene
- Two-panel HBoxContainer, 16px insets all sides

### 1.4 Camera & Parallax

| Item | Status |
|------|--------|
| Camera2D / Camera3D | **NOT FOUND** — pure UI game |
| ParallaxBackground | **NOT FOUND** — no parallax infrastructure |

### 1.5 Theme System

- **Primary theme:** `Themes/CraftPix/craftpix_ui_tinted.tres` (TownHub, Combat, Shop)
- **Legacy theme:** `Themes/game_theme.tres` (TownScene, DungeonCamp, RoomEvent)
- **Key StyleBoxes:** `panel_wood_dark`, `panel_wood_medium`, `header_bar_teal_tinted`, `slot_inventory`
- **Tint color:** `Color(0.75, 0.72, 0.68)` warm-darkening on CraftPix panels

### 1.6 Existing Art Assets

All art packs under `Assets/_ArtPacks/` are icon/sprite-scale only (avatars, equipment, monsters, materials). **No background scene art exists anywhere in the project.**

### 1.7 Lore & Design Documents

- `Shops_And_Shadows_MASTER_GDD.md` — full GDD
- `ProjectDocs/World/REGION_TOWN_INDEX.md` — region/town canonical reference
- `ProjectDocs/World/REGION_TOWN_DUNGEON_OVERVIEW.md`
- `ProjectDocs/World/REGION1_TOWNS_AND_DUNGEONS.md`
- `ProjectDocs/World/CANONICAL_FACILITIES_T1.md`
- `docs/SHOPS_AND_SHADOWS_CANON_OVERVIEW.md`
- `docs/LORE_REFERENCE.md`

---

## 2. Narrative Background Requirements

### 2.1 Town Visual Progression

#### Tier 1 — Baseline Thornhaven

A tiny frontier village at the edge of an ancient forest. Three or four ramshackle wooden buildings with thatched roofs, bark-covered walls, and moss creeping up foundations. A single amber lantern marks the entrance. A crude, half-finished wooden palisade defines the village boundary. Beyond it, dense ancient oaks with thick canopy filter green-gold light. The forest is large but not yet threatening.

**Palette:** Warm amber + deep forest green. Dark brown timber. Desaturated ochre ground. Cool blue-gray shadows.
**Lighting:** Late afternoon golden hour. Single lantern source. Dappled canopy light.
**Key feeling:** "This is mine, and it is small, and that is fine for now."

#### Tier 2 — Expanded Facilities

Six to eight timber-and-stone buildings along a cobblestone path. The blacksmith's forge glows orange. Market stalls with canvas awnings. Multiple lanterns on iron brackets. The palisade is complete and sturdy. Smoke rises from chimneys. Lumber stacks and construction materials suggest ongoing expansion. The forest is pushed back — a cleared perimeter is established.

**Palette:** Amber + stone gray + forge orange. Richer wood tones, warmer gold sky.
**Lighting:** Early evening, multiple warm sources. Forge provides secondary orange glow.
**Key feeling:** "The town is becoming real. There is momentum here."

#### Tier 3 — Corruption-Strained

The same town showing signs of creeping corruption. Timber darkened with faint purple-black discoloration. Some lanterns flickering unstable or shifted to sickly yellow-green. Dark stains spreading along the palisade base. Thorny vines with an unnatural sheen on buildings. Darker forest beyond with faintly luminous fungal growths among the roots. Cracks in cobblestones leaking faint dark mist.

**Palette:** Muted amber competing with sickly olive and corruption purple-black. Faint blue-green fungal glow at edges.
**Lighting:** Twilight, fading warmth. Lanterns feel smaller, more isolated. Unnatural cold ambient from the forest.
**Key feeling:** "We have survived things. The forest remembers what has happened here."

### 2.2 Combat Region Identity

#### Region 1 — Forest Haven (MVP)

Ancient forest, natural magic. Floor themes progress from surface to corrupted core:

- **F1 — Overgrown Trail:** Dappled green-gold canopy light. Soft earth, leaf litter, moss. Calm but enclosed.
- **F2 — Hollow Clearing:** Most open moment — partial canopy gap, brighter. Signs of disruption (broken equipment, scattered supplies). Resource nodes implied at edges.
- **F3 — Darkwood Thicket:** Canopy closes, light dims. Cool blue-grey shadow dominant. Rotting logs, oozing surfaces. Spider silk. Faint bioluminescent moss. First hint the forest's health is compromised.
- **F4 — The Heartwood:** Massive ancient trees, enormous twisted roots. Deep purple-black corruption traces at bark. Luminous amber sap. Cathedral-like reverence. The Thorn-Ent's domain.

**Motifs:** Exposed root systems, hanging moss, dense canopy, warm amber lantern glow.
**Palette progression:** Green → amber → brown → purple-black (corruption traces, F4 only).

#### Region 2 — The Fungalmire

Deep fungal forest, spores, bioluminescence. Two registers: nurturing bioluminescent calm (early) → psychedelic strangeness (deep/boss).

Tall mushroom stalks frame battlefield edges. Ground covered in spore mist at ankle-height. Bioluminescent light is the sole light source — no sky visible. Deeper floors: cap colors more varied, spore mist thicker, shadows strange.

**Palette:** Blue-green bioluminescence → soft purple → warm red-orange (Rotcap corruption) → vivid colors (boss zone).

#### Region 3 — The Sunken Strand

Fog-soaked coastal ruins, shifting tides. Defined by horizontal layers: dense pale fog above, ruins at waterline, implied depths below.

Stone ruin walls worn smooth by tides, covered in kelp and barnacles. Fog thick enough that background is almost entirely mist in upper half. Wet stone or wooden platforms over tidal pools. Storm lighting — grey-green pre-storm sky.

**Palette:** Pale grey-blue fog → grey-green storm → dark teal deep water → ghost-light blue-white.
**Narrative note:** Region 3 completion triggers town destruction. Boss environment must visually reinforce this weight.

#### Region 4 — Ashen Horizons

Scorched sands, volcanic ridges, firestorms. First region where the environment itself is actively hostile.

Dark volcanic rock cracked with deep orange-red glowing fissures. Sand drifts. Volcanic ridge silhouettes black against orange-red sky. Ash particles. Obsidian ruins — angular, sharp, alien. Sky is never comfortable.

**Palette:** Black volcanic rock → deep orange-red → ochre sand → bright orange-white at volcanic core.
**Tone shift:** Midgame boundary. Comfort of Regions 1-3 is definitively gone.

#### Region 5 — Starfall Expanse

Crystal groves, floating stones, distorted reality. Where the game's reality begins to come apart.

Crystal formations (pale blue, purple, white — some intact, some shattered). Floating stone platforms. Deep purple-black sky with slow-motion falling stars. Prismatic crystal light creating rainbow fragments. Deeper floors: irregular geometry, chaotic floating stones, time-ghost silhouettes.

**Palette:** Deep purple sky → pale blue/white crystals → rainbow prismatic → void-black at corruption points.

#### Region 6 — The Necropolis

Bone, grave-dust, lingering souls. First region with fully active Death Corruption.

Massive mausoleums, ornate but crumbling, with bones as structural/decorative elements. Grey dust and packed grave-earth. Soul light — cold thin blue-green — from ground and carved runes. Anti-lantern lighting. Deeper floors: bones become architectural (walls of skulls), soul light brighter and chaotic.

**Palette:** Charcoal grey → bone white → cold blue-green soul light → dark purple death corruption.
**Tone:** Furthest from "cozy." But per GDD: "dangerous but not hopeless" — evidence of the living having been here (torch stub, discarded camp).

#### Region 7 — Final Realm

Collapsing reality, void fissures. Every corruption type converges.

Echoes of all previous regions — broken, fused, wrong. A tree root from R1 twisted into void geometry. Crystal from R5 shattered into void fissures. Mausoleum wall from R6 dissolving. Void fissures in the ground showing nothing below or fragments of other regions. Void energy sickly purple-white with wrong shadow directions.

**Palette:** Void-black → purple-black energy → fragmented region color echoes → zero warmth.

### 2.3 Tone Ladder

| Stage | Region(s) | Emotional Register |
|-------|-----------|-------------------|
| Comfortable Threat | R1, Town T1 | Warm lanterns, living wood, danger at edges only |
| Strange but Benign | R2 | Bioluminescence replaces lanterns, weird but not cruel |
| World Pushes Back | R3 | Fog, ruins, tides — larger, colder, less contained |
| No Comfort Zone | R4 | Heat is threat, not comfort — "the world wants you gone" |
| Reality Negotiable | R5 | Gravity optional, time unstable — dread-adjacent |
| Death Has Primacy | R6 | World actively hostile to the living |
| World Is Over | R7 | All darkness converges — visual thesis of the entire game |

### 2.4 Environmental Storytelling Rules

**Must communicate progression:**
- Town T1→T2→T3: relationship with wilderness (forest pressing close → cleared perimeter → perimeter breached)
- Dungeon F1→F4: surface to corrupted depth, readable without UI text
- Region identity: immediately recognizable without other context

**Must never conflict with UI readability:**
- Center 640px horizontal band: no high-contrast detail or competing focal points
- Top 60px: not the brightest elements
- Bottom 200px: darkest, most diffuse
- Left 200px (TownHub): no key compositional elements
- Status icon colors (white/blue/yellow/red/purple) must not dominate where icons appear
- Purple corruption backgrounds (R6, R7) vs purple damage numbers: resolve by value contrast

**Recurring motifs:**
- **Threshold:** Every combat background has foreground, middle distance (grid), background. Player is always already inside.
- **Corruption at edges:** R1-5 corruption as dark accents at frame edges; R6-7 inversion (corruption center, remnants at edges)
- **Light source character:** Each region has a canonical light type that is the fastest visual differentiator
- **Shopkeeper's presence:** Town backgrounds imply occupation — light left on, path kept clear, door always open

### 2.5 Light Source Progression

| Region | Light Character |
|--------|----------------|
| R1 | Warm amber lantern + filtered green canopy |
| R2 | Cool blue-green bioluminescence |
| R3 | Cold pale fog-diffuse daylight + ghost-light accents |
| R4 | Volcanic orange-red fissure glow, no sky warmth |
| R5 | Prismatic crystal scatter, no single direction |
| R6 | Cold soul-light blue-green, zero warmth |
| R7 | Void energy purple-white, wrong shadow directions |

### 2.6 Corruption Expression Per Region

Corruption is **void radiation** — the emission of altered temporal energy. Each region expresses it differently based on the regional ecosystem it mutates. Corruption visuals must match their region's biome, not be generic purple darkness.

| Region | Corruption Type | Visual Expression |
|--------|----------------|-------------------|
| R1 — Forest Haven | Accelerated growth | Thorny vines with unnatural sheen, bark discoloration, over-dense undergrowth |
| R2 — Fungalmire | Replication / Spore spread | Mycelium network expansion, spore density, bioluminescence intensifying to sickly |
| R3 — Sunken Strand | Environmental instability | Tidal patterns breaking, fog thickening, drowned architecture destabilizing |
| R4 — Ashen Horizons | Volatile amplification | Fissures widening, heat intensifying, lava flows accelerating |
| R5 — Starfall Expanse | Reality fracture | Crystal geometry becoming irregular, floating stones losing coherence |
| R6 — Necropolis | Soul destabilization | Soul-light becoming erratic, bone structures crumbling and reforming |
| R7 — Final Realm | Raw void emission | All corruption types simultaneously, geometry collapsing |

**Critical Art Note — Void vs Death Distinction:**
- **Death (R6):** Cold blue-green soul light, bone-white, gothic architecture, organized decay. Purple is the accent (#6d4c6e), not the dominant.
- **Void (R7):** Crystalline fractures, light-bending, wrong geometry, prismatic distortion. Per Canon Overview Section 11: *"Void is crystalline. Fractured geometry. Subtle time-lag visual artifacts. Light bending, not darkness."* Void is NOT shadow/darkness — that belongs to Death.

### 2.7 Facility Visual Signatures

Facilities that should be implied/visible in T2+ town backgrounds:

| Facility | Visual Signature |
|----------|-----------------|
| Blacksmith | Orange glow from forge window/door |
| Chef | Smoke from chimney, steam suggesting cooking |
| General Store | Wide window with goods suggested |
| Inn | Lit upper windows, warmest building in scene |
| Storage | Larger building at rear, crates/barrels visible |

### 2.8 Non-Combat Scene Narratives

#### Shop Interior

The Shopkeeper's domain — the safest, warmest space in the game. This is the only background the player controls from the inside. Architecture: cozy frontier shop interior, long wooden counter at mid-ground, floor-to-ceiling shelves behind. Contents: bottles, herb bundles, small crates, folded cloth, tools — organized but well-used. Single lantern from ceiling beam. Worn wooden plank floor. Small window on left for daylight fill. Dried herbs on hooks from ceiling beams.

**Key feeling:** "Cluttered but organized — well-used and cared for." Not boutique, not frontier ruin.

#### Dungeon Camp (Per-Region)

The camp is fragile warmth in hostile territory. The campfire-as-center-of-safety motif persists across all regions, but the surrounding environment changes:

| Region | Camp Form | Environmental Detail |
|--------|-----------|---------------------|
| R1 | Root hollow | Sheltered between massive tree roots, campfire on moss, root arch overhead |
| R2 | Fungal alcove | Campfire competing with bioluminescent glow (and losing), mushroom walls |
| R3 | Ruin shelter | Stone archway shelter, campfire on wet flagstones, fog outside |
| R4 | Rock overhang | Campfire barely distinguishable from ambient volcanic glow, obsidian walls |
| R5 | Crystal grotto | Fire reflects prismatically off crystal surfaces, floating stone ceiling |
| R6 | Bone alcove | Fire casts warmth into a space that actively resists warmth, rune-walls |
| R7 | Void fragment | Campfire on a fragment of recognizable ground, void at every edge |

#### Room Events

The event background must be visually neutral enough to support all 9 event types (Animal Den, Fae Bargain, Medicinal Herbs, Lost Satchel, Moss Shrine, Rusted Cache, Workers' Camp, Supply Cart, Bandit Toll). One background per region — curious and uncertain atmosphere, not threatening but clearly not ordinary.

### 2.9 Region Data Reference

| Region | ID | Display Name | Theme Color | Accent Color | Boss | Town | Floors |
|--------|-----|--------------|-------------|--------------|------|------|--------|
| 1 | region_1 | Forest Haven | #4a7a5a | #6aaa7a | Thorn-Ent | Thornhaven | 4 |
| 2 | region_2 | The Fungalmire | #4a6b3a | #8bc34a | Spiral Mycelium | SproutRest | 4 |
| 3 | region_3 | The Sunken Strand | #2c6e7a | #4a90a4 | Tide Sovereign | Shelldrift | 4 |
| 4 | region_4 | Ashen Horizons | #8b3a2a | #d4622a | Cinder Monarch | Embercradle | 4 |
| 5 | region_5 | Starfall Expanse | #4a3a8b | #9c6abf | Shattered Oracle | Crystalhearth | 5 |
| 6 | region_6 | The Necropolis | #3a3a4a | #6d4c6e | Ossuary King | Duskhollow | 5 |
| 7 | region_7 | Final Realm | #1a1a2e | #4a2a6b | Prime Corruptor | Void Threshold | 6 |

### 2.10 Per-Floor Narrative Breakdowns (R2–R7)

#### Region 2 — Fungalmire Floors

- **F1 — Outer Fungal:** Transition zone — dead tree trunks colonized by bracket fungi, waterlogged spongy ground. Bioluminescent mushroom clusters emit cool blue-green glow. Standing water reflects fungal glow. Strange but not cruel — beautiful in a foreign way.
- **F2 — Fungal Bog:** Deeper. Mushroom stalks waist-high and taller. Ground fully mycelium-coated. Spore mist at knee height, faintly luminous. More varied cap colors.
- **F3 — Mycelium Network:** Underground. No sky. Cavern walls coated in fungal growth. Massive shelf fungi form ledges. Spore sac chains hang as natural chandeliers. Two light registers — cool blue-green floor glow and warmer orange-yellow from Rotcap corruption zones.
- **F4 — Spiral Mycelium Arena:** Vast underground cavern. Enormous spiral fungal column at far center, pulsing bioluminescent veins. Floor is thick mat of pale mycelium. The entire space thrums with fungal life.

#### Region 3 — Sunken Strand Floors

- **F1 — Coastal Ruins:** Windswept rocky coast with ancient stone ruins emerging from tidal pools. Broken columns, heavy fog. Overcast gray-green sky. Cold, desaturated. World feels larger and colder than the forest.
- **F2 — Fog Ruins:** Deeper into ruins. More submerged structures. Kelp draped over crumbling walls. Fewer sky gaps. Bioluminescent coral accents.
- **F3 — Drowned Halls:** Partially submerged stone corridors. Tide-line visible on walls. Ghost-light blue-white accents from spectral remains.
- **F4 — Tide Sovereign Arena:** Half-flooded ancient throne hall open to storm-dark sky. Massive stone columns from knee-deep dark seawater. Colossal coral-encrusted throne. Phosphorescent algae at waterline. **Narrative weight:** R3 completion triggers the first Town Destruction Event.

#### Region 4 — Ashen Horizons Floors

- **F1 — Scorched Flats:** Dark volcanic rock cracked with orange-red glowing fissures. Ash-grey sand drifts. First region where the environment itself actively threatens. Sky never comfortable.
- **F2 — Volcanic Ridge:** Obsidian ridges creating choke-point terrain. Angular, sharp, alien formations. Background volcanic ridge silhouettes black against orange-red sky.
- **F3 — Ash Fields:** Dense ash particles. Ground drifts of grey ash. Ruins of a prior civilization buried in ash — angular stonework jutting from sand. The world is trying to bury history.
- **F4 — Cinder Monarch Arena:** Volcanic core. Deep fissures showing lava below. Architecture (if any) is purely obsidian — sharp, geometric, inhuman. Sky entirely orange-red with ash cloud cover.

#### Region 5 — Starfall Expanse Floors

- **F1 — Crystal Groves:** Crystal formations (pale blue, purple, white — intact). Deep purple-black sky with slow-motion falling stars. Prismatic light creating rainbow floor fragments. Gravity feels wrong — some stones float.
- **F2 — Floating Stones:** Crystal formations increasingly shattered. Stone platforms at different heights. Ground surface irregular — geometric, not organic. Time-ghost silhouettes at edges.
- **F3 — Fractured Expanse:** Chaotic floating stones. Crystal geometry irregular and wrong. Light does not travel in expected directions. Shadow falls where it should not.
- **F4 — Shattered Oracle Arena:** Prismatic light everywhere, chaotic and overwhelming. Enormous shattered crystal formation at center — once coherent, now coming apart. Site of reality fragmenting. **Void aesthetic: crystalline, not dark.**
- **F5 — Deep Fracture:** (5-floor region) Reality further degraded. Ground unstable with prismatic void fissures. Time-ghost density increases.

#### Region 6 — Necropolis Floors

- **F1 — Bone Yards:** Massive mausoleums, ornate but crumbling. Bones as structural/decorative elements. Grey dust and packed grave-earth. Soul light — cold thin blue-green — from ground and carved runes. Anti-lantern: cold light that drains rather than warms.
- **F2 — Ossuary Halls:** Interior of necropolis. Bones become architectural (walls lined with skulls). Soul-carved runes. Signs of prior expeditions (torch stub, discarded camp gear) — the living have been here.
- **F3 — Gravefiend Depths:** Deeper ossuary. Soul light brighter and more chaotic. Bone structures crumbling and reforming (Death Corruption = soul destabilization).
- **F4 — Ossuary King Arena:** Throne of death. Enormous bone architecture. The architecture IS the boss. Rune-carved columns of bone. Soul energy gathered to a peak.
- **F5 — Soul Depths:** (5-floor region) Below the Ossuary. Soul energy becomes raw and uncontained.

#### Region 7 — Final Realm Floors

- **F1 — Threshold:** Recognizable fragments from prior regions — tree root from R1, crystal shard from R5, mausoleum wall from R6. Not yet fully dissolved.
- **F2 — Convergence:** Region fragments beginning to fuse wrongly. Forest bark merged with crystal, bone growing from volcanic rock.
- **F3 — Dissolution:** Prior-region references dissolving. Void fissures in ground showing nothing below, or fragments of other regions.
- **F4 — Void Heart:** Predominantly void. Wrong shadow directions. Sickly purple-white void energy. Architecture impossible.
- **F5 — Anchor Approach:** The Anchor Stone's influence becomes visible. Accumulated void pressure warps all surfaces.
- **F6 — Prime Corruptor Arena:** Echoes of all previous regions — broken, fused, wrong. Void fissures everywhere. The Anchor Stone is present. Void energy sickly purple-white with **wrong shadow directions** (shadows fall toward light sources). **Final visual thesis of the entire game.**

---

## 3. Art System Spec

### 3.1 Layer Structure

All backgrounds are assembled from stacked nodes within a `BackgroundRoot` Control node placed as the first child of each scene. Since the game has no Camera2D, ParallaxBackground is not applicable. Layers are implemented as TextureRect children ordered by child index (bottom to top).

| Layer | Node Name | Z-Index | Opacity Range | Purpose |
|-------|-----------|---------|---------------|---------|
| Sky / Distant | `SkyLayer` | -100 | 0.6–1.0 | Sky gradient, distant mountains, horizon line. Sets color temperature. |
| Far | `FarLayer` | -90 | 0.5–0.9 | Treelines, far buildings, fog banks. Provides depth and region identity. |
| Mid | `MidLayer` | -80 | 0.7–1.0 | Primary composition: canopy, buildings, cavern walls. The "postcard" layer. |
| Ground / Combat Plane | `GroundLayer` | -70 | 0.8–1.0 | Floor surface. Low-contrast in center 640px band. |
| Foreground Overlay | `ForegroundLayer` | -60 | 0.2–0.5 | Edge framing: vines, rocks, mist. Transparent center. |
| Atmosphere | `AtmosphereLayer` | -50 | 0.05–0.35 | Corruption veils, weather, light shafts. Only layer that changes for corruption state. |
| UI-Safe Vignette | `VignetteLayer` | -40 | 0.3–0.7 | Dark gradient ensuring UI readability. Constant per scene type. |

**Rules:**
- Every layer: `anchors_preset = FULL_RECT`
- Foreground Overlay: large transparent center, detail only at edges
- UI-Safe Vignette: pre-baked gradient PNG (no shader)
- Atmosphere: the only layer swapped for corruption state (VRAM-efficient)

### 3.2 Folder Structure & Naming

```
Assets/Backgrounds/
  _shared/
    vignette_town.png
    vignette_combat.png
    vignette_camp.png
    vignette_event.png
    vignette_shop.png
  town/
    thornhaven/
      sky_town_thornhaven_T1.png
      far_town_thornhaven_T1.png
      mid_town_thornhaven_T1.png
      ground_town_thornhaven_T1.png
      fg_town_thornhaven_T1.png
      atmo_town_thornhaven_CLEAN.png
      atmo_town_thornhaven_CORRUPT.png
      ...T2, T3 variants...
  combat/
    R1/
      sky_combat_R1_F1.png  ...through F4
      far_combat_R1_F1.png  ...through F4
      mid_combat_R1_F1.png  ...through F4
      ground_combat_R1_F1.png  ...through F4
      fg_combat_R1_F1.png  ...through F4
      atmo_combat_R1_CLEAN.png
      atmo_combat_R1_CORRUPT.png
    R2/ ... R7/
  camp/
    sky_camp_R1.png ... through R7
    ...
  event/
    sky_event_R1.png ... through R7
    ...
  shop/
    sky_shop_interior.png
    far_shop_interior.png
    mid_shop_interior.png
    ground_shop_interior.png
    fg_shop_interior.png
    atmo_shop_interior.png
```

**Naming convention:**
```
{layer}_{scenetype}_{location}_{variant}.png
```

| Segment | Values |
|---------|--------|
| `{layer}` | `sky`, `far`, `mid`, `ground`, `fg`, `atmo`, `vignette` |
| `{scenetype}` | `town`, `combat`, `camp`, `event`, `shop` |
| `{location}` | `thornhaven`, `R1`–`R7` |
| `{variant}` | Town tiers: `T1`/`T2`/`T3` · Floors: `F1`–`F4` · Corruption: `CLEAN`/`CORRUPT` · Interior: `interior` |

### 3.3 Technical Specs

| Spec | Value | Rationale |
|------|-------|-----------|
| **Resolution** | 960x540 (1x native) | Matches viewport exactly |
| **AI gen resolution** | 1920x1080 then downscale | Cleaner detail than upscaling |
| **Format** | PNG-24 (alpha layers), PNG-8 (opaque layers) | Native Godot support, no compression artifacts on gradients |
| **Stretch mode** | `canvas_items` + `keep` aspect | Required for correct scaling on all displays |
| **Filter** | Bilinear (`true`) | Painterly backgrounds need filtering (icons use nearest) |
| **Mipmaps** | `false` | Always displayed at native res |
| **Compress mode** | VRAM Compressed | Uses S3TC/BPTC on desktop |
| **Tileable** | No — all full-width | No scrolling; tiling unnecessary at 960x540 |
| **Color profile** | sRGB, no embedded ICC | Godot assumes sRGB for 2D |

**Transparency rules per layer:**

| Layer | Alpha | Notes |
|-------|-------|-------|
| Sky / Distant | No (opaque) | Base fill, nothing behind it |
| Far | Partial | Lower portion fades to transparent |
| Mid | Partial | Silhouettes with transparent sky regions |
| Ground | Partial | Upper portion transparent |
| Foreground | Heavy | Mostly transparent center |
| Atmosphere | Heavy | Sparse wisps, particles, shafts |
| Vignette | Gradient | Center transparent, edges dark |

---

## 4. Prompt Library

All prompts target AI image generation tools (Midjourney, Stable Diffusion, DALL-E, etc.). Each includes: style, palette, lighting, depth, UI-safe constraints, and negative constraints.

### 4.1 Town Prompts

#### town_thornhaven_T1 (Baseline)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio, 960x540
resolution target. Cozy grim-fantasy style with painterly brushwork and muted detail.

A tiny frontier village at the edge of an ancient forest. Three or four ramshackle wooden
buildings with thatched roofs cluster around a dirt clearing. A single amber lantern hangs
from a crooked post, casting warm golden light across weathered timber. Moss creeps up the
building foundations. A crude wooden palisade, half-finished, marks the village boundary.
Beyond the palisade, dense dark forest looms -- ancient oaks with thick canopy filtering
green-gold light. A narrow dirt path leads from the village into the trees.

PALETTE: Warm amber (#D4A047) and filtered forest green (#3D5C3A) dominate. Building wood
dark brown (#4A3728). Ground desaturated ochre (#8B7355). Sky glimpses pale gold (#E8D5A0).
Shadows cool blue-gray (#2A2D3A).

LIGHTING: Late afternoon golden hour. Single warm lantern at center-left. Dappled forest
light from upper right. Deep shadows at canopy edges. Light falls off dramatically at
forest boundary.

DEPTH: Three planes -- village buildings (mid), forest edge (far), deeper forest/sky
(distant). Atmospheric haze increases with distance. Near warm, far cool.

UI-SAFE: Center 640px band = low contrast dirt clearing. Left 200px darker (NavRail zone).
Bottom 200px darkest (ground shadow). Top 60px = canopy, not brightest elements. Lantern
below top 60px.

NEGATIVE: No characters, no text, no UI, no modern objects, no bright white, no neon, no
high saturation, no busy center patterns, no anime, no photorealism, no symmetry.
```

#### town_thornhaven_T2 (Expanded)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio, 960x540.
Cozy grim-fantasy style with painterly brushwork.

A growing frontier town in a forest clearing. Six to eight timber-and-stone buildings along
a cobblestone path. Blacksmith forge glows orange at one side. Market stalls with canvas
awnings. Multiple amber lanterns on iron brackets. Complete sturdy wooden palisade with gate.
Smoke from chimneys. Forest pushed back but still looms beyond walls. Stone well in square.
Lumber stacks suggest ongoing expansion.

PALETTE: Amber (#D4A047), stone gray (#7A7568), forge orange (#C4632A). Richer wood (#5C4433).
Canvas cream (#C8B894). Cobblestone gray-brown (#6B6155). Forest green-black (#1E3322).
Sky gold (#E0C878).

LIGHTING: Early evening, multiple warm sources. Forge secondary orange from right. Lantern
amber pools. Smoke softens light. Forest edge in deep shadow.

DEPTH: Building corridor (mid), palisade+forest (far), chimney smoke+sky (distant).

UI-SAFE: Center 640px = cobblestone path + ground stalls (low contrast). Left 200px = darker
shadow/palisade. Bottom 200px = dark cobblestone. Top 60px = smoke and canopy, not flames.

NEGATIVE: No characters, no text, no UI, no modern objects, no neon, no anime, no
photorealism, no symmetry. No pristine architecture -- frontier wear throughout.
```

#### town_thornhaven_T3 (Corruption-Strained)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio, 960x540.
Cozy grim-fantasy shifting toward ominous unease.

A strained frontier town showing creeping corruption. Timber buildings lean slightly, wood
darkened with faint purple-black discoloration. Lanterns flicker unstably -- one shifted to
sickly yellow-green. Dark stains spreading along palisade base. Thorny vines with unnatural
sheen climbing one building corner. Forest beyond wall darker, with faint luminous fungal
growths among roots. Olive-gray sky through canopy. Some windows boarded. Cobblestone cracks
leaking faint dark mist.

PALETTE: Muted amber (#D4A047) vs sickly olive (#7A7A3A) and corruption purple-black
(#2A1E2E). Stained wood (#3D2E22). Dark-veined cobblestones (#3A3533). Olive-gray sky
(#8A8A6A). Faint blue-green fungal glow (#4A8A7A) at edges only.

LIGHTING: Twilight, fading warmth. Lanterns feel smaller, isolated. Unnatural cold ambient
from forest edge. Lower illumination than T2. Shadows purple-cast rather than blue.

DEPTH: Same building layout as T2 but far plane (forest/palisade) more oppressive. Thicker
atmosphere, reduced forest visibility. Corruption strongest at edges and far plane.

UI-SAFE: Center 640px = low contrast, corruption details at edges only. Left 200px = darker
palisade with corruption staining. Bottom 200px = darkest (cracked cobblestones, dark mist).
Top 60px = murky sky.

NEGATIVE: No characters, no text, no UI, no bright neon corruption (subtle and organic), no
tentacles, no skulls, no overt horror, no anime, no photorealism, no symmetry.
```

### 4.2 Combat Prompts — Region 1 (Forest Haven)

#### combat_R1_F1 (Overgrown Trail)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Dark forest
trail scene for tactical RPG battlefield.

A narrow overgrown trail through ancient deciduous forest. Path barely visible under fallen
leaves and creeping moss. Young saplings and ferns encroach from both sides. Thick tree trunks
frame left and right edges. Dappled light filters through high canopy in scattered golden
beams. Trail stretches into shadowy forest depth. Mushrooms at tree bases. Fallen log across
one side. Ground is soft earth, leaf litter, and moss.

PALETTE: Forest green (#3D5C3A), moss green (#5A7A4A), bark brown (#4A3728), leaf-litter gold
(#8B7A4A), dappled amber (#D4B870). Shadows cool blue-gray (#2A3040). Distant blue-green
haze (#3A5050).

LIGHTING: Filtered canopy from above, scattered golden pools on ground. Overall dim with
bright accent shafts. Brightest at upper-mid, dims toward bottom and edges.

DEPTH: Trail provides ground-plane recession to center. Tree trunks at edges create framing.
Far trees dissolve into haze. Three clear layers.

UI-SAFE: Center 640px = flat trail surface with leaf litter (low contrast, no bright shafts).
Top 60px = dark canopy. Bottom 200px = dark ground shadow. Dappled light at mid-height
near edges only.

NEGATIVE: No characters, no monsters, no text, no UI, no buildings, no bright sky visible,
no clearings, no anime. Trail feels enclosed, not open.
```

#### combat_R1_F2 (Hollow Clearing)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Forest clearing
battlefield for tactical RPG.

A small natural clearing around a massive hollow tree stump at far center. Stump four meters
wide, broken at two meters high, interior dark and mossy. Clearing floor is thick grass and
clover with scattered muted wildflowers. Ancient trees ring the clearing, canopy partially
closing overhead. Shaft of diffuse green-gold light through canopy gap. Fallen branches and
stones at edges. Fireflies or dust motes in the light shaft.

PALETTE: Rich forest green (#4A6B42), grass green (#5C7A4A), stump dark (#2A1E18), muted
wildflower purple (#6A5A7A) and pale yellow (#C4B878), diffuse pale gold-green (#B8C488).
Shadows deep forest green-black (#1A2A1A).

LIGHTING: Overhead diffuse through partial canopy gap. Brighter than F1 but still enclosed.
Hollow stump interior darkest point. Even light across clearing floor.

UI-SAFE: Center 640px = even-lit clearing floor (grass, low contrast). Hollow stump at
far-center above combat zone. Bottom 200px = darker grass and shadow. Top 60px = dark canopy.

NEGATIVE: No characters, no creatures, no text, no UI, no magical effects, no ruins, no anime,
no bright sky.
```

#### combat_R1_F3 (Darkwood Thicket)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Dense dark
forest battlefield for tactical RPG.

Claustrophobic thicket of ancient trees with gnarled intertwined branches. Canopy nearly
closed -- only thin slivers of gray-green light. Thick roots bulge from ground creating
uneven terrain. Spider silk catches faint light between branches. Dark moss and lichen cover
everything. Thorny undergrowth at edges. A faint bioluminescent fungal glow (blue-green,
very subtle) on one distant trunk. Air feels thick and still.

PALETTE: Dark bark brown (#3A2A1E), deep shadow green-black (#1A2218), moss gray-green
(#4A5A44), spider silk silver (#8A8A8A, thin), faint fungal glow (#3A7A6A at 20%). Ground
dark earth (#2A2218). Significantly darker than F1/F2.

LIGHTING: Minimal. Thin slivers of gray-green ambient from far above. No direct ground light.
Relies on subtle value differences. Faint fungal glow is the only color accent.

UI-SAFE: Center 640px = dark even ground with exposed roots (low contrast). Bottom 200px =
darkest (deep root shadow). Top 60px = dense canopy black. Fungal glow at mid-height
near edge, subtle.

NEGATIVE: No characters, no creatures, no text, no UI, no bright light, no clearings, no
sky visible, no anime. Oppressive, not scary. No glowing eyes.
```

#### combat_R1_F4 (The Heartwood — Boss Arena)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Ancient forest
boss arena for tactical RPG.

A vast ancient tree dominates -- trunk fifteen meters wide, bark deeply furrowed, roots
radiating outward like cathedral floor. Canopy far overhead, unseen. Natural hollow arch at
tree base. Roots create roughly circular clearing. Amber sap weeps from deep bark wounds,
faintly luminous. Moss and ferns in root crevices. Surrounding forest only dark silhouettes.
Atmosphere reverent and ancient.

PALETTE: Ancient bark gray-brown (#5A4A3A), luminous amber sap (#C49A40 at 40% glow), root
wood dark (#3A2E22), moss green (#4A6A3A), surrounding forest black-green (#0E1A0E). Ground
dark earth (#2A2218).

LIGHTING: Luminous sap provides scattered warm accent. No overhead light. Sap IS the lighting.
Cathedral-like intimate quality. Glow reaches ~1m from each sap wound.

UI-SAFE: Center 640px = root-covered ground (dark earth, flat roots, low contrast). Trunk and
sap glow in upper-mid background above combat zone. Bottom 200px = dark roots and shadow.
Top 60px = bark receding to darkness. Sap at mid-to-upper, not where status icons appear.

NEGATIVE: No characters, no creatures, no text, no UI, no magical runes, no carved symbols,
no faces in bark, no anime. Tree is natural, ancient, imposing -- not enchanted or sentient.
```

### 4.3 Combat Prompts — Region 2 (Fungalmire)

#### combat_R2_F1 (Outer Fungal)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Bioluminescent
fungal swamp entry for tactical RPG.

Transition zone: ancient forest gives way to fungal wetland. Dead trees as gray trunks with
no leaves, bark consumed by bracket fungi. Waterlogged spongy ground. Bioluminescent mushroom
clusters -- small caps to waist-high stalks -- emit cool blue-green glow. Spore mist at
knee height, faintly luminous. Standing water reflects fungal glow. Dead tree roots wrapped
in pale mycelium threads.

PALETTE: Bioluminescent blue-green (#4AAFAA at 30%), dead wood gray (#6A6A5A), swamp water
black-brown (#1A1816), mycelium cream (#B8AAA0), spore mist (#3A8A80 at 15%), mud dark
(#2A2218). Background deep blue-black (#0E1420).

LIGHTING: Bioluminescence sole source. Multiple cool blue-green points from mushroom clusters.
No overhead light. Soft falloff. Spore mist scatters and diffuses.

UI-SAFE: Center 640px = waterlogged ground with low, small mushrooms (diffuse glow). Brightest
clusters at edges. Bottom 200px = dark water and mud. Top 60px = dark dead canopy.
Bioluminescent glow specifically teal (#4AAFAA), not status icon blue (#4488FF).

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No neon-bright mushrooms.
No purple (reserve for corruption). No Mario-style cartoonish fungi. No sci-fi.
```

#### combat_R2_F4 (Spiral Mycelium — Boss Arena)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Massive fungal
boss chamber for tactical RPG.

Vast underground cavern dominated by enormous spiral fungal column at far center, spiraling
upward, surface covered in bioluminescent veins pulsing blue-green. Organic cavern walls
coated in fungal growth. Floor is thick mat of pale mycelium fibers with dark gaps revealing
depth. Massive shelf fungi on walls like balconies. Chains of luminous spore sacs hanging
from ceiling like chandeliers. The entire space thrums with fungal life.

PALETTE: Mycelium cream (#C8BAA8), bioluminescent blue-green (#4AAFAA at 50%), cavern dark
(#2A2828), spore sac soft teal (#5AC4B8), fungal vein bright teal (#6AD4C8 at 30%). Floor
off-white with blue-green threading.

LIGHTING: Bioluminescence everywhere. Spiral column is primary source, spore sac chains
secondary. Surfaces near column well-lit; far walls deep shadow.

UI-SAFE: Center 640px = relatively even mycelium floor (pale but low contrast). Spiral column
and brightest glow in upper background. Bottom 200px = darker mycelium with shadowed gaps.
Top 60px = dark cavern ceiling.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. Organic and natural, not
mechanical. No body-horror (alien but beautiful). No purple. No bright saturated green.
```

### 4.4 Combat Prompts — Region 3 (Sunken Strand)

#### combat_R3_F1 (Coastal Ruins)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Fog-soaked
coastal ruin battlefield for tactical RPG.

Windswept rocky coast where ancient stone ruins emerge from tidal pools. Broken columns and
crumbling archways of green-gray stone, half-submerged. Heavy fog from right obscures distant
ocean. Overcast gray-green sky. Kelp and barnacles below tide line. Dark wet sand and gravel
ground with shallow saltwater pools reflecting gray sky. Distant ruin silhouettes in fog.
Sea spray mists the air. Driftwood and broken stone.

PALETTE: Fog gray-green (#7A8A7A), stone gray (#6A6A60), wet sand dark (#3A3530), tidal pool
dark green (#2A3A30), kelp olive (#4A5A38), sky gray (#8A8A80), ghost-light pale (#A8B8C0).
Cold, desaturated overall.

LIGHTING: Flat overcast, heavily diffused by fog. No shadows. Fog seems to glow faintly.
Wetness specular highlights are the only contrast accents.

UI-SAFE: Center 640px = flat wet sand + shallow pools (low contrast, desaturated). Columns at
edges. Bottom 200px = darkest wet sand shadow. Top 60px = flat overcast, no bright patches.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No bright sun or blue sky.
No ships. No dramatic waves. No tropical colors. No intact architecture.
```

#### combat_R3_F4 (Tide Sovereign — Boss Arena)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Submerged
throne room boss arena for tactical RPG.

Half-flooded ancient throne hall open to storm-dark sky. Massive eroded stone columns rise
from knee-deep dark seawater. Colossal stone throne at far end on raised platform above
waterline, encrusted with coral and barnacles. Ceiling partially collapsed revealing churning
gray-green storm sky. Corroded iron chains from ceiling beams. Dark opaque water reflecting
column shapes. Phosphorescent algae at column waterline provides faint cold blue-green light.
Sea mist fills upper space.

PALETTE: Storm sky dark gray-green (#3A4A40), column pale gray (#7A7A70), seawater dark
(#1A2A22), throne dark gray (#4A4A44), coral dull orange-brown (#7A5A3A), phosphorescent
teal-green (#5A9A8A at 25%), corroded iron rust (#5A3A2A).

LIGHTING: Storm-diffuse through collapsed ceiling. Cold, even, directionless. Phosphorescent
accent at waterline. Throne area slightly darker. Overall cold and oppressive.

UI-SAFE: Center 640px = dark seawater with submerged floor (low contrast). Throne and sky gap
in upper background. Bottom 200px = deep water shadow. Top 60px = dark ceiling beams.
Phosphorescent glow specifically teal-green, not status icon blue.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No tentacles or sea monsters.
No bright lightning. No tropical colors. No intact architecture. No glowing treasure.
```

### 4.5 Combat Prompts — Region 4 (Ashen Horizons)

#### combat_R4_F1 (Scorched Flats)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Volcanic
wasteland battlefield for tactical RPG.

Dark volcanic rock plain cracked with deep orange-red glowing fissures. Ash-grey sand drifts
across black basalt. Distant volcanic ridge silhouettes black against orange-red sky. Heat
shimmer distorts far background. Scattered obsidian shards jutting from ground at angles.
No vegetation -- only mineral. Ash particles visible in mid-distance. Sky is dull orange-red
with dense ash cloud cover. No sun visible. Ground radiates more light than sky.

PALETTE: Black volcanic rock (#1A1412), fissure orange-red (#C4522A with 40% glow), ash-grey
sand (#6A6258), obsidian black-purple (#1E1420), distant ridge black (#0E0A08), sky orange-red
(#8B4A2A). No green. No blue.

LIGHTING: Ground-up from fissure glow. No overhead warmth. Orange-red ambient from below
and horizon. Obsidian shards catch fissure light. Sky provides dim even orange wash.

DEPTH: Cracked flats (near), obsidian formations (mid), volcanic ridge silhouettes (far),
ash-clouded sky (distant). Heat shimmer blurs far plane.

UI-SAFE: Center 640px = flat cracked volcanic rock with fissure glow (moderate contrast -- darker
than fissures at edges). Bottom 200px = darkest basalt. Top 60px = dim orange-red sky.
Brightest fissures at edges, not center.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No bright lava rivers
(fissures only). No tropical or warm colors beyond volcanic orange-red. No buildings. No
vegetation. Environment is hostile, not decorative.
```

#### combat_R4_F4 (Cinder Monarch — Boss Arena)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Volcanic core
boss arena for tactical RPG.

Deep volcanic chamber where the floor is cracked obsidian over visible lava below. Massive
angular obsidian formations rise like black crystal spires at edges -- sharp, geometric,
inhuman. No natural curves. Deep fissures show bright orange-white lava through cracks.
Sky (if visible through volcanic vent above) is entirely orange-red with churning ash clouds.
Heat distortion everywhere. The architecture is purely mineral -- no civilization, no history,
just geological violence frozen in obsidian.

PALETTE: Obsidian black (#0E0A08), lava bright orange-white (#E88A3A at 60% glow), fissure
deep orange (#C4522A), ash cloud orange-red (#8B4A2A), volcanic gas yellow (#C4AA5A at 15%).
Ground black with orange veins.

LIGHTING: Lava from below is primary source -- intense orange-white. No overhead light.
Obsidian spires silhouetted against lava glow. Upward-cast shadows on all vertical surfaces.
Most dramatically lit arena in the game.

UI-SAFE: Center 640px = cracked obsidian floor with lava-glow veins (moderate -- lava bright
but thin). Obsidian spires at edges frame composition. Bottom 200px = dark obsidian.
Top 60px = ash cloud or dark vent ceiling.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No throne or furniture.
No symbols or runes. No cool colors. Pure geological, not magical. No cartoon lava.
```

### 4.6 Combat Prompts — Region 5 (Starfall Expanse)

#### combat_R5_F1 (Crystal Groves)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Crystal cave
entry battlefield for tactical RPG.

Crystal formations in pale blue, purple, and white rise from dark rocky ground. Some intact
and geometric, others fractured. Deep purple-black sky visible through cavern opening with
slow-motion falling stars (small white points with faint trails). Prismatic light refracts
through crystal surfaces, creating rainbow fragments on ground. Some stones float at strange
angles -- gravity feels slightly wrong. Ground is dark irregular rock with crystal growths.

PALETTE: Crystal pale blue (#A8B8D8), crystal purple (#8A6AA8), crystal white (#D8D0E0),
dark rock ground (#2A2238), deep purple sky (#1A1430), prismatic rainbow (scattered, small,
not dominant), star-white (#E0E0F0). Overall cool and alien.

LIGHTING: Prismatic crystal scatter from multiple angles. No single direction. Light arrives
from crystal surfaces, not from above. Sky provides dim purple ambient. Falling stars provide
faint white accents. Otherworldly, not theatrical.

UI-SAFE: Center 640px = dark rocky ground with small crystal growths (low contrast -- crystals
bright but sparse in center). Major crystal formations at edges. Bottom 200px = dark rock.
Top 60px = purple-black sky. Prismatic rainbows subtle, not saturated.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No darkness or shadow
corruption (void is CRYSTALLINE, not dark). No generic purple murk. No sci-fi technology.
No symmetrical arrangements. Alien natural, not constructed.
```

#### combat_R5_F4 (Shattered Oracle — Boss Arena)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Shattered
crystal boss arena for tactical RPG.

Enormous shattered crystal formation at far center -- once a single coherent prismatic
structure, now fractured into a constellation of floating shards. Prismatic light refracts
chaotically from every surface. Ground is dark crystal-veined rock with floating fragments
hovering just above surface. The "sky" is prismatic void -- deep purple-black with light
arriving from wrong angles. Shadow falls toward light sources, not away. Some shards slowly
rotating. The space feels like reality coming apart at the seams.

PALETTE: Shattered crystal prismatic (white, blue, purple, faint rainbow), void-dark
(#1A1430), crystal-veined ground (#2A2238 with pale blue threads), bright prismatic accents
(small, chaotic), floating shard edges (#C8C0E0).

LIGHTING: Chaotic prismatic scatter from the shattered formation. Multiple conflicting light
directions. Shadows fall wrong. No calm zone. The light itself communicates that something
fundamental is broken. Brightest at shattered formation, chaotic elsewhere.

UI-SAFE: Center 640px = dark crystal-veined ground (low contrast base). Shattered formation
in upper background. Floating shards sparse in center, denser at edges. Bottom 200px = dark
ground. Top 60px = void-dark with scattered light.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No darkness-as-corruption
(void is light-bending and crystalline). No smooth gradients. No symmetry. No magical runes.
Reality is broken, not enchanted.
```

### 4.7 Combat Prompts — Region 6 (Necropolis)

#### combat_R6_F1 (Bone Yards)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Gothic bone-
architecture exterior battlefield for tactical RPG.

Massive mausoleums with ornate but crumbling facades. Bones used as structural and decorative
elements -- rib-vault archways, skull-embedded walls, femur pillars. Grey dust and packed
grave-earth ground. Cold thin blue-green soul-light emanates from ground-level rune carvings
and structural seams -- the "anti-lantern" (cold light that drains warmth rather than
providing it). Dark charcoal sky. Architecture gothic but decaying. Signs of prior
expeditions: a discarded torch stub, scratched directional marks on a wall.

PALETTE: Charcoal gray (#3A3A4A), bone white (#C8C0B0), grave-earth brown-gray (#4A4440),
soul-light blue-green (#3A8A7A at 25%), rune accent cold blue (#4A7A8A), death-purple accent
(#4A3848 at edges only, dark). Architecture desaturated. No warm tones.

LIGHTING: Cold soul-light from ground and runes -- zero warmth. This is the furthest
departure from the amber lanterns of the starting area. Blue-green emanations from structural
seams. No overhead light. Everything lit from below or from rune-surfaces.

UI-SAFE: Center 640px = grave-earth ground with faint rune glow (low contrast). Mausoleum
facades at edges. Bottom 200px = darkest grave-earth. Top 60px = dark charcoal sky.
Soul-light blue-green must be value-differentiated from UI blues (#4488FF).

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No bright purple (death
purple is DARK, not vivid). No horror imagery (skulls are architectural, not threatening).
No red. No fire. The dead are organized, not chaotic.
```

#### combat_R6_F4 (Ossuary King — Boss Arena)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Bone throne
room boss arena for tactical RPG.

Enormous interior of bone architecture. Walls are stacked femurs and skulls forming gothic
arches. Rune-carved bone columns support a vaulted bone-ceiling. At far center, a massive
throne of interlocking bones -- the Ossuary King's seat. The architecture IS the boss in
visual sense -- it fills the space completely. Soul energy gathered to a peak: blue-green
rune-light brighter here than anywhere in the Necropolis. Grave-dust hangs in air. Floor
is polished bone tile with rune-light seams.

PALETTE: Bone architecture white-gray (#B8B0A0), rune-light blue-green (#4AA08A at 40%),
deep bone shadow (#2A2828), throne bone ivory (#C8C0B0), floor polished bone (#8A8478),
soul-energy bright (#5AC0A8 at 35%). Dark purple (#3A2A3A) only in deepest shadows.

LIGHTING: Concentrated soul-light from rune-carved columns and floor seams. Throne area
brightest due to rune density. Blue-green dominant with no competing warm tones. Dramatic
but cold. High contrast between lit rune-seams and dark bone surfaces.

UI-SAFE: Center 640px = polished bone floor with rune-seams (moderate -- bright seams but
dark bone between). Throne and columns in upper background. Bottom 200px = darker floor
shadow. Top 60px = dark vaulted ceiling. Soul-light teal must not match status icon blue.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No fire or candles. No red.
No bright purple (reserve for void). Architecture is reverent and massive, not horror.
Gothic cathedral of bone, not charnel house.
```

### 4.8 Combat Prompts — Region 7 (Final Realm)

#### combat_R7_F1 (Threshold)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Reality-
collapse entry battlefield for tactical RPG.

Ground composed of recognizable fragments from prior regions fused wrongly together. A section
of forest floor (R1 roots and moss) meets volcanic obsidian (R4) at a jagged seam. Crystal
shards (R5) jut from bone-architecture wall fragments (R6). The seams between fragments glow
with faint void-purple light. Sky is void-black with faint prismatic distortion at edges.
The fragments are still recognizable -- this is where the player realizes all prior corruptions
were symptoms of one source.

PALETTE: Void-black sky (#1A1A2E), fragment-seam purple (#4A2A6B at 25% glow), forest green
fragment (#3A5A3A desaturated), volcanic orange fragment (#8A4A2A desaturated), crystal blue
fragment (#7A8AB0 desaturated), bone-white fragment (#A8A098 desaturated). All region colors
present but muted, damaged.

LIGHTING: Void-seam glow provides dim purple ambient. Each fragment retains a ghost of its
original light character (faint amber from R1, faint orange from R4) but all diminished.
No dominant light source. Shadows begin to behave slightly wrong.

UI-SAFE: Center 640px = fragmented ground plane (low contrast -- fragments dark and muted).
Seam-glow at edges. Bottom 200px = darkest void-ground. Top 60px = void-black sky.
Void purple must be dark enough (value <30%) to not conflict with purple UI elements.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No pure darkness (void is
CRYSTALLINE fracture, not shadow). No tentacles. No generic evil. Fragments are sad, not
scary -- these are broken worlds.
```

#### combat_R7_F6 (Prime Corruptor — Final Boss Arena)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Final boss
arena — reality's end — for tactical RPG.

The ultimate void chamber. Void fissures tear through the ground showing nothing below, or
brief glimpses of other regions through cracks. A massive crystalline formation at far center
(the Anchor Stone) pulses with concentrated void energy -- sickly purple-white with prismatic
distortion. Fragments of all seven regions visible as broken, floating debris: a tree root,
a mushroom stalk, a stone column, an obsidian shard, a crystal cluster, a bone arch. All
wrong, all fused, all dissolving. Shadows fall TOWARD light sources. The space defies geometry.

PALETTE: Void-black (#1A1A2E dominant), void-purple energy (#4A2A6B at 40% glow at Anchor),
prismatic distortion (rainbow fringe at void-crack edges), fragment echoes (all region colors
at <20% saturation). Sickly purple-white (#8A6AA8 at 30%) at Anchor surface. ZERO warmth.
No amber. No green. Any prior-region color appears only as damaged remnant.

LIGHTING: Void energy from Anchor Stone is primary source -- sickly purple-white. Shadows
fall toward it (wrong direction). Secondary light from void fissures (glimpses of other
regions' light through cracks). The wrongness of light direction is the final break from
all established visual language. No sky, no horizon, no ground-plane certainty.

UI-SAFE: Center 640px = void-dark ground with fissure cracks (low base contrast). Anchor
Stone in upper background. Floating fragments at edges. Bottom 200px = darkest void.
Top 60px = void-black. Void purple MUST be dark value (<30%) -- purple UI elements at full
value remain legible.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No generic evil darkness.
No tentacles or eyes. No cartoon void. The visual thesis: this is what happens when reality
gives up. Crystalline fracture, not shadow. Light bending, not absent.
```

### 4.9 Support Scene Prompts (Camp, Event, Shop)

#### camp_R1 (Forest Haven Rest Area)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Forest camp
rest scene for RPG dungeon.

Sheltered hollow between roots of a massive tree, set up as temporary camp. Modest campfire
at center casting warm amber light on surrounding roots and earth. Simple canvas bedrolls on
moss. Backpack against a root. Root arch overhead like low ceiling with glimpses of dark
forest above. Firelight flickering on bark. Small supplies near fire (waterskin, bundled herbs,
sheathed dagger). Intimate and protected -- fragile warmth in dark forest.

PALETTE: Campfire amber (#D4A040), warm bark (#7A5A3A), moss green (#4A6A3A), canvas brown
(#7A6A50), dark forest (#1A2218), firelight gold (#C4A460).

LIGHTING: Single campfire at center. Strong warm falloff all directions. Root surfaces reflect
fire. Beyond hollow: nearly complete darkness.

UI-SAFE: Center 360x320 content zone = moderate even firelit area. Fire offset to upper-center,
warm glow fills content zone. Bottom 200px = dark ground shadow. Top 60px = dark root ceiling.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No tent (too elaborate). No
bright sky. No magic. Grounded and mundane -- survival supplies.
```

#### event_R1 (Forest Haven Encounter)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Mysterious
forest encounter scene for RPG event.

Ring of ancient trees around small clearing where grass grows in unnaturally perfect circle.
Moss-covered stone marker at center (waist-high, roughly carved, slight angle). Faint amber
light with no visible source from below -- grass seems to glow faintly. Surrounding trees
lean inward slightly with unusual knothole patterns. Thin ground mist at ankle height.
Curious and uncertain atmosphere -- not threatening, but clearly not ordinary.

PALETTE: Luminous gold-green grass (#8AA858 with subtle glow), mossy stone (#6A7A5A), dark
bark (#3A2E22), ground-light amber (#C4A848 at 20%), mist pale gold (#B8AA78 at 10%),
dark forest (#1A2218).

LIGHTING: Mysterious ambient from below (grass circle). No overhead light to clearing.
Trees are dark silhouettes. Stone marker casts faint shadow. Ethereal but subtle.

UI-SAFE: Center 440x400 content zone = stone marker and grass circle, low contrast for
event text. No bright glow in center. Bottom 200px = dark forest floor. Top 60px = canopy.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No magical runes, no fairy
imagery, no floating particles. Environmental strangeness, not overt magic. No purple
corruption -- this is R1 mystery.
```

#### shop_interior (Shopkeeper's Shop)

```
Digital painting, pixel-art-inspired fantasy illustration, 16:9 aspect ratio. Fantasy shop
interior for RPG shop scene.

Interior of cozy frontier shop. Long wooden counter across mid-ground. Behind counter,
floor-to-ceiling shelves with bottles, herb bundles, small crates, folded cloth, tools.
Lantern from ceiling beam above counter casts warm amber. Rough timber walls with iron
brackets. Worn wooden plank floor. Small window on left with faint daylight. Exposed ceiling
beams with dried herbs on hooks. Weighing scale on counter. Cluttered but organized --
well-used, cared for.

PALETTE: Warm timber (#6A5038), lantern amber (#D4A040), bottles (#5A3A28), herbs olive
(#6A7A4A), cloth cream (#B8A880), metal gray (#7A7A70), floor worn brown (#5A4A38), window
daylight pale gold (#C4B880 at 30%), ceiling dark (#3A2A1E).

LIGHTING: Primary lantern overhead at center, warm even light on counter and shelves. Window
fill from left. Under-shelf shadow. Dark ceiling corners. Warmest on counter surface.

UI-SAFE: Center and lower = even moderate lighting for inventory panel background. Counter
at mid-height as grounding line. Bottom 200px = dark floor. Top 60px = dark ceiling beams.
Lantern at upper-mid, not very top.

NEGATIVE: No characters, no creatures, no text, no UI, no anime. No modern objects. No glass
display cases (too refined). No glowing magical items. No bright sky through window. Not
overly clean -- frontier, not boutique.
```

### 4.10 Corruption Overlays (All Regions)

#### overlay_nature_corruption (Region 1)

```
Digital painting with transparency, 16:9 aspect ratio, 960x540. OVERLAY LAYER -- majority
transparent (alpha 0). Only corruption elements painted.

Organic corruption on transparent background. Dark thorny vines with unnatural purple-black
sheen (#2A1E2E) creeping inward from edges (left, right, bottom). Thin, tendril-like vines.
Faint purple-gray mist (#3A2A3A at 10-15%) across lower third. Small patches of diseased
bark texture (darkened, cracked, #2A2218) at edges. One or two clusters of sickly pale
mushrooms (#8A7A6A) at bottom corners. Densest at edges/corners, sparser toward center.
Center 640x320 = COMPLETELY TRANSPARENT.

PALETTE: Corruption purple-black (#2A1E2E), vine dark (#1E1418), diseased bark (#2A2218),
sickly mushroom (#8A7A6A), purple mist (#3A2A3A low opacity). All dark, desaturated.

TRANSPARENCY: 80-90% fully transparent. Vines 60-80% opacity, mist 10-15%, mushrooms 50-70%.
Center 640x320 combat zone = 100% transparent.

PURPOSE: Composited over any R1 combat background for corruption state. Must not obscure
base background features. Adds atmosphere -- the forest is sick.

NEGATIVE: No characters, no text, no UI. No bright purple or magenta (corruption is dark,
draining, not vivid). No tentacles, no eyes, no body horror. No solid fills. Do not cover
center combat zone.
```

#### overlay_spore_corruption (Region 2)

```
Digital painting with transparency, 16:9 aspect ratio, 960x540. OVERLAY LAYER.

Spore corruption on transparent background. Dense luminous spore clouds (#8BC34A at 15-20%)
drifting inward from edges. Mycelium threads (#B8AAA0 at 30%) creeping across lower third.
Sickly intensified bioluminescence -- mushroom caps (#5AC4B8 shifting toward yellow-green
#8AAA5A) at bottom corners. Spore density heaviest at edges, thinning toward center.
Center 640x320 = COMPLETELY TRANSPARENT.

PALETTE: Intensified spore yellow-green (#8AAA5A at 15%), mycelium cream (#B8AAA0 at 30%),
sickly teal (#6AAA7A shifting warm). All semi-transparent, atmospheric.

NEGATIVE: No solid fills. No purple. No darkness. Corruption here is OVERABUNDANCE, not decay.
```

#### overlay_tidal_corruption (Region 3)

```
Digital painting with transparency, 16:9 aspect ratio, 960x540. OVERLAY LAYER.

Tidal instability on transparent background. Thickened fog banks (#7A8A7A at 20-25%) pressing
inward from edges, denser than normal. Faint ghost-light streaks (#A8B8C0 at 15%) — spectral
remnants. Water stain marks (#2A3A30 at 20%) at lower third as if tide is rising. Subtle
kelp fronds (#4A5A38 at 25%) at bottom corners. Environmental destabilization, not overt
corruption. Center 640x320 = COMPLETELY TRANSPARENT.

NEGATIVE: No purple. No tentacles. No dramatic waves. Corruption is fog thickening, tide
rising wrong, architecture losing stability.
```

#### overlay_flame_corruption (Region 4)

```
Digital painting with transparency, 16:9 aspect ratio, 960x540. OVERLAY LAYER.

Volcanic intensification on transparent background. Wider, brighter fissure glow (#E88A3A
at 20%) bleeding inward from edges. Heat shimmer distortion (subtle warp, not actual
distortion -- implied through soft edge halos). Ash density increased (#6A6258 at 15%)
across upper half. Volcanic gas wisps (#C4AA5A at 10%) at bottom corners. Lava veins (#C4522A
at 25%) spreading inward from bottom. Center 640x320 = COMPLETELY TRANSPARENT.

NEGATIVE: No fire effects. No explosion imagery. Corruption is intensification of existing
volcanic activity, not new phenomena.
```

#### overlay_arcane_corruption (Region 5)

```
Digital painting with transparency, 16:9 aspect ratio, 960x540. OVERLAY LAYER.

Reality fracture on transparent background. Crystal geometry going WRONG at edges — shards
at impossible angles (#A8B8D8 at 20%), fracture lines in space itself (#4A2A6B at 15%).
Prismatic distortion halos at edges (rainbow fringe, subtle). Floating micro-fragments
(#D8D0E0 at 25%) scattered from edges. Time-ghost silhouettes (#8A6AA8 at 10%) — faint
afterimage shapes at corners. Center 640x320 = COMPLETELY TRANSPARENT.

NEGATIVE: No darkness. No purple murk. Corruption is GEOMETRY BREAKING, not shadow.
Crystalline fracture aesthetic. Light bending, not dimming.
```

#### overlay_death_corruption (Region 6)

```
Digital painting with transparency, 16:9 aspect ratio, 960x540. OVERLAY LAYER.

Soul destabilization on transparent background. Soul-light becoming erratic — brighter,
pulsing blue-green wisps (#4AA08A at 20-30%) at edges, flickering. Bone fragments (#B8B0A0
at 25%) floating slowly at corners. Rune-light seams (#3A8A7A at 15%) appearing on ground
edges where none existed. Grave-dust (#4A4440 at 10%) thickening in air. The organized
architecture of death is losing its structure. Center 640x320 = COMPLETELY TRANSPARENT.

NEGATIVE: No bright purple (that's void, not death). No horror imagery. Soul light is
cold blue-green. Bones are architectural, crumbling and reforming.
```

#### overlay_void_corruption (Region 7)

```
Digital painting with transparency, 16:9 aspect ratio, 960x540. OVERLAY LAYER.

Raw void emission on transparent background. Void fissure cracks (#1A1A2E with #4A2A6B
edge glow at 30%) at edges of frame. Prismatic distortion halos at fissure edges (rainbow
fringe). Fragments of ALL prior corruption types visible at reduced intensity — vine wisps,
spore motes, fog wisps, heat shimmer, crystal shards, soul-sparks — all present, all wrong,
all dissolving. Shadow anomalies — dark shapes that don't correspond to objects. Center
640x320 = MOSTLY TRANSPARENT (faint void ambient #1A1A2E at 5% allowed).

NEGATIVE: No pure darkness fills. No tentacles. Void is crystalline fracture + light bending.
All prior corruptions converge but none dominate.
```

---

## 5. Asset Checklist

### MVP Set (Region 1 + Town + Shop) — 44 Files

#### Shared (2)
| File | Purpose |
|------|---------|
| `_shared/vignette_combat.png` | Combat scene UI darkening |
| `_shared/vignette_town.png` | Town scene UI darkening |

#### Town — Thornhaven T1 (5)
| File |
|------|
| `town/thornhaven/sky_town_thornhaven_T1.png` |
| `town/thornhaven/far_town_thornhaven_T1.png` |
| `town/thornhaven/mid_town_thornhaven_T1.png` |
| `town/thornhaven/ground_town_thornhaven_T1.png` |
| `town/thornhaven/fg_town_thornhaven_T1.png` |

#### Combat — R1 F1 through F4 (20)
| File |
|------|
| `combat/R1/sky_combat_R1_F1.png` |
| `combat/R1/far_combat_R1_F1.png` |
| `combat/R1/mid_combat_R1_F1.png` |
| `combat/R1/ground_combat_R1_F1.png` |
| `combat/R1/fg_combat_R1_F1.png` |
| `combat/R1/sky_combat_R1_F2.png` |
| `combat/R1/far_combat_R1_F2.png` |
| `combat/R1/mid_combat_R1_F2.png` |
| `combat/R1/ground_combat_R1_F2.png` |
| `combat/R1/fg_combat_R1_F2.png` |
| `combat/R1/sky_combat_R1_F3.png` |
| `combat/R1/far_combat_R1_F3.png` |
| `combat/R1/mid_combat_R1_F3.png` |
| `combat/R1/ground_combat_R1_F3.png` |
| `combat/R1/fg_combat_R1_F3.png` |
| `combat/R1/sky_combat_R1_F4.png` |
| `combat/R1/far_combat_R1_F4.png` |
| `combat/R1/mid_combat_R1_F4.png` |
| `combat/R1/ground_combat_R1_F4.png` |
| `combat/R1/fg_combat_R1_F4.png` |

#### Combat Atmosphere — R1 (2)
| File |
|------|
| `combat/R1/atmo_combat_R1_CLEAN.png` |
| `combat/R1/atmo_combat_R1_CORRUPT.png` |

#### Camp — R1 (5)
| File |
|------|
| `camp/sky_camp_R1.png` |
| `camp/far_camp_R1.png` |
| `camp/mid_camp_R1.png` |
| `camp/ground_camp_R1.png` |
| `camp/fg_camp_R1.png` |

#### Event — R1 (5)
| File |
|------|
| `event/sky_event_R1.png` |
| `event/far_event_R1.png` |
| `event/mid_event_R1.png` |
| `event/ground_event_R1.png` |
| `event/fg_event_R1.png` |

#### Shop Interior (5)
| File |
|------|
| `shop/sky_shop_interior.png` |
| `shop/far_shop_interior.png` |
| `shop/mid_shop_interior.png` |
| `shop/ground_shop_interior.png` |
| `shop/fg_shop_interior.png` |

### Production Priority Order
1. Town T1 (5) — most-seen scene
2. Shop interior (5) — second most-seen
3. Combat R1 F1 (5) + atmo CLEAN (1) — first combat encounter
4. Combat R1 F4 (5) — boss arena, high impact
5. Camp R1 (5) — rest area
6. Event R1 (5) — event encounters
7. Combat R1 F2 (5) + F3 (5) — remaining floors
8. Vignettes (2) + atmo CORRUPT (1) — polish pass

---

## 6. Godot Implementation Notes

### 6.1 Stretch Mode Configuration

Add to `project.godot`:

```ini
[display]
window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

Test all existing UI scenes after applying — `canvas_items` scales all Control nodes uniformly.

### 6.2 Replacing Existing ColorRect Backgrounds

Migration path per scene:

1. Add `Control` node named `BackgroundRoot` as **first child** of scene root
2. Move existing `ColorRect` named `Background` inside `BackgroundRoot` as fallback
3. Add 7 TextureRect children to `BackgroundRoot` in layer order (sky → vignette)
4. All TextureRects: `anchors_preset = FULL_RECT`, `stretch_mode = KEEP_ASPECT_COVERED`, `mouse_filter = MOUSE_FILTER_IGNORE`, `texture_filter = LINEAR`
5. Once backgrounds load correctly, the ColorRect fallback can remain (shows through missing layers) or be removed

### 6.3 Node Hierarchy

```
SceneRoot (Control)
  BackgroundRoot (Control)              # anchors: FULL_RECT
    Background (ColorRect)              # legacy fallback, kept behind all layers
    SkyLayer (TextureRect)              # z_index: -100
    FarLayer (TextureRect)              # z_index: -90
    MidLayer (TextureRect)              # z_index: -80
    GroundLayer (TextureRect)           # z_index: -70
    ForegroundLayer (TextureRect)       # z_index: -60
    AtmosphereLayer (TextureRect)       # z_index: -50
    VignetteLayer (TextureRect)         # z_index: -40
  ... existing UI nodes ...
```

### 6.4 BackgroundManager Autoload

Register in `project.godot`:
```ini
[autoload]
BackgroundManager="*res://Game/Core/BackgroundManager.gd"
```

```gdscript
# Game/Core/BackgroundManager.gd
extends Node

var _background_root: Control = null

const LAYER_NAMES := ["SkyLayer", "FarLayer", "MidLayer", "GroundLayer",
                      "ForegroundLayer", "AtmosphereLayer", "VignetteLayer"]

func register_background_root(root: Control) -> void:
    _background_root = root

func load_background(scene_type: String, location: String, variant: String,
                     corruption: String = "CLEAN") -> void:
    var base_path := _resolve_base_path(scene_type, location)
    var layer_map := {
        "SkyLayer": "%s/sky_%s_%s_%s.png" % [base_path, scene_type, location, variant],
        "FarLayer": "%s/far_%s_%s_%s.png" % [base_path, scene_type, location, variant],
        "MidLayer": "%s/mid_%s_%s_%s.png" % [base_path, scene_type, location, variant],
        "GroundLayer": "%s/ground_%s_%s_%s.png" % [base_path, scene_type, location, variant],
        "ForegroundLayer": "%s/fg_%s_%s_%s.png" % [base_path, scene_type, location, variant],
        "AtmosphereLayer": "%s/atmo_%s_%s_%s.png" % [base_path, scene_type, location, corruption],
        "VignetteLayer": "res://Assets/Backgrounds/_shared/vignette_%s.png" % scene_type,
    }
    _apply_layers(layer_map)

func _resolve_base_path(scene_type: String, location: String) -> String:
    match scene_type:
        "combat":
            return "res://Assets/Backgrounds/combat/%s" % location
        "town":
            return "res://Assets/Backgrounds/town/%s" % location
        "camp", "event":
            return "res://Assets/Backgrounds/%s" % scene_type
        "shop":
            return "res://Assets/Backgrounds/shop"
        _:
            push_warning("[BackgroundManager] Unknown scene type: %s" % scene_type)
            return ""

func _apply_layers(layer_map: Dictionary) -> void:
    if not _background_root:
        push_warning("[BackgroundManager] No BackgroundRoot registered")
        return
    for layer_name in LAYER_NAMES:
        var node: TextureRect = _background_root.get_node_or_null(layer_name)
        if not node:
            continue
        var path: String = layer_map.get(layer_name, "")
        if path == "" or not ResourceLoader.exists(path):
            node.texture = null
            continue
        node.texture = load(path)

func set_corruption_state(scene_type: String, location: String,
                          corruption: String) -> void:
    if not _background_root:
        return
    var base_path := _resolve_base_path(scene_type, location)
    var atmo_path := "%s/atmo_%s_%s_%s.png" % [base_path, scene_type, location, corruption]
    var atmo_node: TextureRect = _background_root.get_node_or_null("AtmosphereLayer")
    if atmo_node and ResourceLoader.exists(atmo_path):
        atmo_node.texture = load(atmo_path)

func clear_background() -> void:
    if not _background_root:
        return
    for layer_name in LAYER_NAMES:
        var node: TextureRect = _background_root.get_node_or_null(layer_name)
        if node:
            node.texture = null
```

### 6.5 Per-Scene Integration

```gdscript
# CombatScene.gd — in _ready()
BackgroundManager.register_background_root(%BackgroundRoot)
var region := GameContext.get_current_region()   # e.g. "R1"
var floor_num := GameContext.get_current_floor()  # e.g. 2
var variant := "F%d" % floor_num
var corruption := "CORRUPT" if GameContext.is_region_corrupted(region) else "CLEAN"
BackgroundManager.load_background("combat", region, variant, corruption)
```

```gdscript
# TownHubScene.gd — in _ready()
BackgroundManager.register_background_root(%BackgroundRoot)
var town_tier := GameContext.get_town_tier("thornhaven")  # e.g. 2
BackgroundManager.load_background("town", "thornhaven", "T%d" % town_tier)
```

### 6.6 Floor Transitions (Fade-Through-Black)

```gdscript
func transition_to_floor(new_floor: int) -> void:
    var tween := create_tween()
    for layer_name in BackgroundManager.LAYER_NAMES:
        var node: TextureRect = %BackgroundRoot.get_node_or_null(layer_name)
        if node:
            tween.parallel().tween_property(node, "modulate:a", 0.0, 0.3)
    tween.tween_callback(func():
        var region := GameContext.get_current_region()
        var corruption := "CORRUPT" if GameContext.is_region_corrupted(region) else "CLEAN"
        BackgroundManager.load_background("combat", region, "F%d" % new_floor, corruption)
    )
    for layer_name in BackgroundManager.LAYER_NAMES:
        var node: TextureRect = %BackgroundRoot.get_node_or_null(layer_name)
        if node:
            tween.parallel().tween_property(node, "modulate:a", 1.0, 0.3)
```

### 6.7 Graceful Fallback

If a texture file doesn't exist, BackgroundManager sets `texture = null` for that layer. The legacy `ColorRect` inside `BackgroundRoot` provides the solid-color fallback. Partially-complete background sets still look acceptable.

---

## 7. Open Questions

### Story Gaps (Require Creative Decision)

| # | Gap | Documents Checked | Impact |
|---|-----|------------------|--------|
| SG-1 | **Thornhaven spatial layout** — road-based? ring clearing? multi-level? | LORE_REFERENCE, CANON_OVERVIEW | All town background compositions |
| SG-2 | **Town destruction visual after R3** — fire? corruption-creep? abandonment? | CANON_OVERVIEW (town reset event) | T3 variant and potential T1-RESET variant |
| SG-3 | **R2-R7 camp forms** — root hollow (R1) defined, but R2-R7 not specified | No camp variants in any doc | Camp backgrounds for all regions beyond R1 |
| SG-4 | **Event scene: region-specific or neutral per region?** | No event bg spec | Event background count (7 variants vs. 1) |
| SG-5 | **R4-R6 town visual identity** — only JSON names available (Embercradle, Crystalhearth, Duskhollow) | Region JSONs only | Town background architecture per region |
| SG-6 | **R7 town type** — foothold, camp, or ritual nexus? | REGION_TOWN_INDEX: "Special foothold" | R7 town background architecture |
| SG-7 | **NG+ corruption in R1** — immediate visual on rewrite or progressive? | CANON_OVERVIEW Section 2.3 | Whether T1-CORRUPT variant needed for NG+ |
| SG-8 | **R3 corruption type** — "tidal/environmental instability" but unnamed | LORE_REFERENCE, CANON_OVERVIEW | R3 corruption overlay expression |
| SG-9 | **Anchor Stone visual appearance** — where in R1? What does it look like at different timeline stages? | CANON_OVERVIEW Section 2.3 | R7 boss arena and possible R1 element |
| SG-10 | **Purple conflict resolution** — R6/R7 backgrounds use purple; debuff UI also purple | ART_DIRECTION Section 5 | Value contrast strategy for R6-R7 |
| SG-11 | **Region-specific CanvasModulate values** — per-biome tint/fog shader parameters | ART_DIRECTION Appendix #4 | Atmosphere layer implementation |
| SG-12 | **Iron Foreman alt-boss arena (R1)** — Timberfall lumber mill aesthetic for F4 variant | LORE_REFERENCE | Possible F4 industrial variant |

### Technical Decisions Pending

| # | Decision | Default Assumption |
|---|----------|--------------------|
| 1 | Should stretch mode be added to project.godot now? | Yes — `canvas_items` + `keep` |
| 2 | Generate at 1920x1080 and downscale, or native 960x540? | 1920x1080 → downscale |
| 3 | Flat PNGs or layered approach for MVP? | Layered (7 TextureRects) for future flexibility |
| 4 | BackgroundManager as autoload or per-scene? | Autoload (avoids duplication) |
| 5 | Renderer discrepancy: ART_DIRECTION says Forward Plus, project.godot uses gl_compatibility | gl_compatibility is what's actually set |

---

## 8. Confirmed Canon Summary

The following narrative and technical elements are fully confirmed across multiple sources and require no further creative decisions for background production:

1. **Game tone:** "Cozy grim-fantasy." Town = warm and inhabited, dungeon = dangerous but not hopeless.
2. **Corruption origin:** Void radiation, not evil magic. Each region mutates based on local biome.
3. **Void aesthetic:** Crystalline, fractured geometry, light-bending, prismatic. NOT darkness or shadow.
4. **Death aesthetic (R6):** Cold blue-green soul light, bone architecture, gothic. NOT void purple.
5. **7 distinct region biomes** with defined palettes from JSON `theme_color` + `accent_color`.
6. **Town progression:** T1 (forest adjacent, palisade incomplete) → T2 (forest pushed back, palisade complete) → T3 (corruption returning, palisade stained).
7. **Town names:** Thornhaven, SproutRest, Shelldrift, Embercradle, Crystalhearth, Duskhollow, Void Threshold.
8. **Boss identities:** Defined per region with descriptions — each boss arena reflects their theme.
9. **R3 completion triggers town destruction** — visually and narratively significant.
10. **Shopkeeper absent from scenes** — presence implied through environment (lit lantern, open door, organized goods).
11. **UI safe zones:** Fully specified with pixel measurements (Section 1.3).
12. **Technical spec:** 960x540 viewport, 7-layer TextureRect system, BackgroundManager autoload, gl_compatibility renderer.
13. **MVP scope:** Region 1 (Forest Haven) + Town (Thornhaven) + Shop interior = first playable backgrounds.
14. **Art style:** "Digital painting, pixel-art-inspired" — SNES/GBA era detail level. Not NES, not watercolor, not 3D.
15. **Tone ladder:** Comfortable Threat (R1) → Strange but Benign (R2) → World Pushes Back (R3) → No Comfort Zone (R4) → Reality Negotiable (R5) → Death Has Primacy (R6) → World Is Over (R7).

---

*End of BACKGROUNDS_MASTER.md — Rev 2 (2026-02-19)*
