# Shops & Shadows — Art Direction Master Brief

> **Status:** LOCKED — Art Direction Authority (2026-02-12 Revision 1)
> **Authority:** This document consolidates all visual direction for the project.
> **Source of Truth:** This file supersedes all scattered art references.
> This document now reflects approved visual doctrine and should not contain open aesthetic questions.

---

## 1. Tone & Atmosphere

**"Cozy Grim-Fantasy"** (from Master GDD Section 2.2)

- Warm lantern-lit town interiors contrasted with ominous corrupted forests and ruins
- The world is dangerous but not hopeless
- Humor and charm exist in hero personalities and town events
- Stakes are high, but the player's role (shopkeeper) adds a layer of warmth

**Emotional Palette:**

| Context | Feeling | Visual Temperature |
|---------|---------|-------------------|
| Town (safe) | Cozy, productive, homey | Warm amber/green |
| Shop/Facility | Industrious, rewarding | Warm gold/orange |
| Dungeon (early floors) | Cautious, exploratory | Cool blue-gray |
| Dungeon (deep floors) | Tense, foreboding | Dark purple/red |
| Boss encounter | Dramatic, high-stakes | High contrast, region-specific |
| Hero death | Somber, meaningful | Desaturated, muted |

---

## 2. Visual Style

**Medium:** 2D Pixel Art
**Target Resolution:** 960x540 base window (from project.godot)
**Renderer:** Godot Forward Plus

### Sprite Specifications (LOCKED)

**Base Sprite Size: 32x32** (LOCKED)

Rationale:
- Slightly exaggerated proportions allow readable silhouettes at combat scale
- Supports 135+ race/class combinations without detail loss
- Works cleanly within 960x540 base resolution
- Standard indie pixel scale (Stardew Valley, Crosscode tier)

| Asset Type | Size | Notes |
|------------|------|-------|
| Hero/Monster sprites | 32x32 | Base entity size for combat grid |
| Status icons | 32x32 | Already established (Assets/Icons/) |
| UI buttons/elements | Variable | Kenney UI Pack base, themed overlay |
| Tileset tiles | 32x32 | Matches sprite scale |
| Boss sprites | 64x64 or 96x96 | 2x–3x base for battlefield presence |

### Animation States (from GDD Section 14.5)

Each entity requires these frame-by-frame animations:
1. **Idle** — 2-4 frames, looping
2. **Walk** — 4-6 frames, looping
3. **Attack** — 3-5 frames, one-shot
4. **Hurt** — 2-3 frames, one-shot
5. **Death** — 3-5 frames, one-shot (stays on final frame)

File convention (from GDD Section 14.5):
```
res://Assets/Animations/[entity_id]/idle.png
res://Assets/Animations/[entity_id]/walk.png
res://Assets/Animations/[entity_id]/attack.png
res://Assets/Animations/[entity_id]/hurt.png
res://Assets/Animations/[entity_id]/death.png
```

### Outline Policy

- **Colored outline** — darkened local color, not pure black
- Outline value approximately 20–30% darker than adjacent fill color
- Pure black (`#000000`) is reserved exclusively for UI text and icon strokes
- This keeps sprites feeling integrated with environments rather than "sticker-like"

### Shading Style

- **Clustered soft pixel shading** — 3–4 value ramp maximum per material
- No smooth gradients or anti-aliased blending within sprites
- No heavy dithering patterns
- No dramatic rim lighting or specular highlights
- Lighting is implied through value placement, not theatrical

### Lighting Model

- Character sprites are **neutrally lit** (no baked directional light source)
- Environment provides tint, fog, and ambient mood at the scene level
- This allows sprites to work consistently across all 7 region biomes
- Region-specific color grading is applied via Godot CanvasModulate or shader, not baked into art

---

## 3. Character Design Rules

### Races (9 total — from Master GDD)

| Race | Visual Identity Cues | Region |
|------|---------------------|--------|
| Human | Baseline proportions, versatile gear | Region 1 |
| Elf | Lean, pointed ears, nature motifs | Region 1 |
| Mossfolk | Plant/moss textures, green tones | Region 2 |
| Tidelings | Aquatic features, blue/teal tones | Region 3 |
| Dragonkin | Scales, horns, warm/fire palette | Region 4 |
| Crystalborn | Crystalline growths, prismatic highlights | Region 5 |
| Undead | Pallid skin, dark hollows, bone accents | Region 6 |
| Voidwalkers | Shadowy, phasing effects, purple/void hues | Region 6 |
| (Region 7 Race TBD) | Corruption-touched, final realm aesthetic | Region 7 |

### Classes (15 total — visual archetypes)

| Archetype | Classes | Visual Cues |
|-----------|---------|-------------|
| Tank | Defender, Prism Sentinel | Heavy armor, shields, bulky silhouette |
| Healer | Warden, Tidechaser, Druid | Nature/water motifs, flowing garments, staffs |
| Melee DPS | Striker, Fungal Berserker, Ashblade | Light armor, aggressive stance, weapon-forward |
| Ranged DPS | Stormcaller, Prism Lancer | Robes/medium armor, casting pose, elemental effects |
| Dark Caster | Dark Channeler, Lich, Void Herald | Dark robes, skull/bone motifs, glowing eyes |
| Shadow | Voidwalker, Pyrewarden | Cloaked, smoke/shadow effects, asymmetric design |

### Silhouette Rule

Every race/class combination must be distinguishable by silhouette alone at combat grid scale.

---

## 4. Environment Design Rules

### Region Visual Identity

| Region | Biome | Primary Palette | Key Visual Elements |
|--------|-------|----------------|-------------------|
| 1. Forest Haven | Temperate forest | Green, brown, warm amber | Lanterns, wooden buildings, mossy paths |
| 2. The Fungalmire | Toxic swamp | Purple, sickly green, spore clouds | Bioluminescent mushrooms, fog, decay |
| 3. Sunken Strand | Coastal/underwater | Teal, deep blue, coral pink | Tide pools, shipwrecks, kelp |
| 4. Ashen Horizons | Volcanic/desert | Orange, red, charcoal black | Lava flows, ash clouds, cracked earth |
| 5. Starfall Expanse | Crystal caves | Prismatic, white, pale purple | Crystal formations, starlight, geometric shapes |
| 6. Necropolis | Undead wasteland | Gray, bone white, dark purple | Crypts, skeletal structures, void rifts |
| 7. Final Realm | Corrupted nexus | All palettes corrupted/distorted | Reality tears, mixed biome fragments |

### Town Visual Hierarchy

- Town A (Race unlock town) — More residential, market-focused
- Town B (Class unlock town) — More military/training, workshop-focused
- Both towns share region biome but differ in purpose (visible architecturally)

---

## 5. UI/UX Style Rules

### Hybrid UI Direction (LOCKED)

The UI follows a **clean-layout, warm-material** hybrid approach:
- Clean layout hierarchy and readable spacing
- Wood panel framing for major containers
- Brass trim accents on headers and separators
- Soft shadowing on overlapping panels
- Slight asymmetry for cozy charm (not sterile grids)
- **Avoid:** Heavy gothic borders, parchment texture overload, ornate filigree

Kenney UI Pack remains as structural foundation but must visually align with the wood/brass theme through themed overlays or replacement as production matures.

### Current Implementation (from game_theme.tres)

**Base Palette:**
- Background: `#262633` (deep dark blue-gray)
- Panel Border: `#4D5A72` (medium blue-gray)
- Button Normal: `#404759` (slightly lighter than panel)
- Button Hover: `#597F80` (brightened teal)
- Text Default: `#E0E6F0` (light off-white)

**Corner Radius:** 4px globally
**Border Width:** 1-2px
**Default Font Size:** 15pt

### Combat UI Color Language

| Color | Meaning | Used For |
|-------|---------|----------|
| Red `(0.9, 0.5, 0.5)` | Danger / Front row | Enemy labels, damage text, front formation |
| Cyan `(0.6, 0.8, 1.0)` | Allied / Party | Party labels, buff text |
| Gold `(1.0, 0.9, 0.2)` | Active / Important | Active unit highlight, attack lines |
| Green `(0.2, 1.0, 0.4)` | Healing / Positive | Heal lines, success text |
| Gray `(0.7, 0.7, 0.7)` | Neutral / Mid row | Middle formation, disabled states |
| Purple | Special / Doom | Doom triggers, special effects |
| Orange | DoT / Debuff | Damage-over-time indicators |

### Status Effect UI (from GDD Section 28.6)

| Category | Color | Examples |
|----------|-------|----------|
| Damage DoT | Red | Poison, Bleed, Burn |
| Debuff | Purple | Armor Break, Weakness |
| Buff | Green | Regen, Shield |
| Control | Yellow | Stun, Taunt, Root |
| Special | Blue | Doom, Countdown |

---

## 6. Color Philosophy

The game uses **functional color** — every color has a game-meaning.

**Never use color purely decoratively.** If a color appears, it should communicate something.

**Colorblind Considerations (from GDD Section 28.16):**
- Icons never rely on color alone
- All status effects have unique icons + text
- Critical events use motion + sound in addition to color

---

## 7. Animation Style

**Pixel animation, frame-by-frame.**

- No skeletal animation (not appropriate for pixel scale)
- No tweened motion for character sprites (tweens used only for UI effects like attack lines, pop text)
- Sub-pixel movement is acceptable for smooth motion
- Combat animations should feel "snappy" — short hold times, quick transitions

### Idle Motion Policy

- **Minimal idle animation** — subtle breathing or stance shift only
- No exaggerated bounce, sway, or personality loops
- Combat readability is prioritized over charm animation
- Idle should communicate "alive and ready," not "performing"

### UI Animation Timing (established in code)

| Effect | Fade In | Hold | Fade Out |
|--------|---------|------|----------|
| Attack line | 0.05s | 0.15s | 0.10s |
| Pop text | instant | 1.2s | fade over 0.3s |
| Cast callout | instant | 1.0s | fade |
| Active unit pulse | continuous | — | continuous |

---

## 8. Asset Naming Conventions

### Sprites
```
Assets/Animations/[entity_id]/[state].png
```
States: `idle`, `walk`, `attack`, `hurt`, `death`

### Icons
```
Assets/Icons/Status/icon_status_[effect_id].png    (32x32)
Assets/Icons/Buffs/icon_buff_[buff_id].png          (32x32)
```

### UI Assets
```
Assets/UI/Kenney/UI/PNG/[Category]/[filename].png
```

---

## 9. AI Tool Guidelines

### Current Asset Sources

| Source | Used For | License |
|--------|----------|---------|
| Kenney UI Pack | Buttons, sliders, UI chrome | CC0 (Public Domain) |
| game-icons.net | Status/buff icons | CC BY 3.0 (Attribution required) |
| PixelLab (planned) | Sprite generation | TBD |

### PixelLab Usage Rules (when implemented)

1. **Always provide a reference sprite** when generating new entities
2. **Lock base palette per region** before batch generation
3. **Generate at exact target resolution** — do not upscale/downscale
4. **All AI output requires manual consistency review** before integration
5. **Animation frames must be generated as a batch** (not individually) to maintain anatomy consistency
6. **Attribution:** Document all AI-generated assets in `Docs/Attribution/`

### What AI Should NOT Generate

- UI layout or interaction design (already implemented in code)
- Status effect icons (already sourced from game-icons.net)
- Audio assets (separate pipeline)
- Font choices (established in theme)

---

## 10. What This Game Is NOT Visually

- **NOT retro-8bit/NES** — More detail than classic 8-bit, closer to SNES/GBA era
- **NOT hand-painted/watercolor** — Pixel art, not illustration
- **NOT chibi/kawaii** — Characters have proportional anatomy (within pixel constraints)
- **NOT grimdark/horror** — "Cozy grim" means warmth exists; not Darkest Dungeon bleak
- **NOT clean/modern/flat** — The world has texture, grime, and character
- **NOT 3D or 2.5D** — Pure 2D pixel presentation
- **NOT hyper-detailed** — Sprites must read clearly at small scale

---

## Appendix: Remaining Production Questions

1. **Town background style** — Scrolling parallax? Static scene? Tilemap?
2. **Dungeon map style** — Node graph (text)? Illustrated nodes? Full tilemap?
3. **Portrait system** — Do heroes get larger portrait art for menus/shops?
4. **Region-specific CanvasModulate values** — Per-biome tint/fog parameters TBD
5. **PixelLab reference sheet creation** — Who produces the first reference sprites?

---

*LOCKED 2026-02-12 Revision 1. Resolved: base sprite size (32x32), UI direction (wood/brass hybrid), Kenney compatibility (structural base with themed overlay).*
