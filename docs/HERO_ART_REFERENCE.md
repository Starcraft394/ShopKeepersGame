# Hero Art Reference — ShopKeepers Game

> Artist reference for creating pixel art sprites in Aseprite.
> Sprite size: **32x32 px** (displayed at 64x64 with nearest-neighbor upscale)
> Style: SNES 16-bit RPG (FF6 / Chrono Trigger). Chunky readable pixels, large head (40% height), vibrant palette.
> View: Side-facing. Transparent background.

---

## Sprite Sizes Quick Reference

| Asset | Canvas | Display | Folder |
|-------|--------|---------|--------|
| Hero sprite frame | 32x32 | 64x64 | `Assets/Sprites/Heroes/{class}/` |
| Monster portrait | 32x32 | 32-64 | `Assets/_ArtPacks/Monsters_*/` |
| Facility/building | 128x128 | 128x128 | `Assets/Backgrounds/Buildings/R{N}/` |
| Item/ability icon | 32x32 | 16-32 | `Assets/Icons/Items/` |
| Class recruit card | 120x141 | 120x141 | `Assets/UI/Cards/` |

## Hero Animations (per sprite)

| Tag | Frames | FPS | Loop | Export Names |
|-----|--------|-----|------|-------------|
| idle | 4 | 6 | yes | Idle1-4.png |
| attack | 5 | 10 | no | Attack1-5.png |
| cast | 5 | 10 | no | Cast1-5.png |
| hit | 3 | 10 | no | Hit1-3.png |
| death | 5 | 8 | no | Death1-5.png |
| walk | 6 | 8 | yes | Walk1-6.png |

---

# REGION 1 — FOREST HAVEN (Thornhaven)

**Theme:** Lush ancient forest, iron quarries, shadow groves, old oaks
**Colors:** Theme `#4a7a5a` (forest green) / Accent `#6aaa7a` (sage green)
**Races available:** Human, Elf, Dwarf

---

## Defender — Stalwart Protector

> *"A stalwart protector forged in the iron quarries of Thornhaven, who stands as an immovable wall between danger and the innocent. Their oak-and-steel shield bears the old forest runes of protection."*

| Field | Value |
|-------|-------|
| Archetype | Vanguard (Tank) |
| Weapons | Sword, Axe, Mace |
| Ability A | **Guardian Challenge** — iron gauntlet raised in challenge, red bleeding slash |
| Ability B | **Aegis Slam** — golden shield thrust, impact shockwave lines |
| Passive A | Bulwark Stance |
| Passive B | Shielding Presence |

**Visual Theme:** Iron, gold, stone. Solid, planted, unyielding.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#4a5568` | Iron grey |
| Accent | `#c9a94e` | Warm gold |
| BG | `#2d4a2e` | Deep forest green |
| Text | `#c9a94e` | Gold |

**Sprite Notes:**
- Heavy iron-riveted armor, oak-and-steel tower shield
- Golden trim and protection runes on shield
- Stocky, planted stance — feet wide apart
- Icon hint: *"heavy iron tower shield with golden trim and protection rune"*

---

## Striker — Shadow Bladedancer

> *"A bladedancer trained in the shadow groves of Thornhaven, who strikes with the speed of a diving hawk. Their twin blades flash like autumn leaves in a storm."*

| Field | Value |
|-------|-------|
| Archetype | Striker (DPS) |
| Weapons | Sword, Dagger, Bow |
| Ability A | **Twin Strike** — crossed daggers slashing in an X pattern |
| Ability B | **Shadowstep** — dark silhouette dissolving into wispy black shadows, speed lines |
| Passive A | Killer Instinct |
| Passive B | Finisher's Instinct |

**Visual Theme:** Dark leather, crimson, speed streaks, shadows. Lethal and mobile.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#3d2b1f` | Dark brown leather |
| Accent | `#b08d57` | Brass |
| BG | `#3d2b1f` | Dark brown leather |
| Text | `#8b0000` | Deep crimson |

**Sprite Notes:**
- Light leather armor, no heavy plate — needs to look fast
- Twin daggers or a single curved blade
- Dark brown/black clothing with brass buckles
- Red stitching or crimson sash accent
- Icon hint: *"crossed daggers over a red slashing arc with speed lines"*

---

## Warden — Forest Guardian Healer

> *"A forest guardian blessed by the ancient oaks of Thornhaven, who channels the living pulse of the woodland to mend allies. Roots and vines answer their call."*

| Field | Value |
|-------|-------|
| Archetype | Healer |
| Weapons | Staff, Sword, Focus |
| Ability A | **Nature's Grace** — gentle green glow, floating leaves |
| Ability B | **Barkskin Blessing** — bark texture wrapping around ally |
| Passive A | Living Bond |
| Passive B | Verdant Renewal |

**Visual Theme:** Living wood, soft green-gold light, organic warmth.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#5a3e1b` | Warm bark brown |
| Accent | `#3d7a3e` | Verdant green |
| BG | `#3d7a3e` | Verdant green |
| Text | `#e8d98e` | Golden glow |

**Sprite Notes:**
- Gnarled oak staff entwined with green vines and small leaves
- Robes in earthy greens and browns
- Soft golden-green glow around staff/hands
- Nature motifs — leaf patterns on clothing
- Icon hint: *"oak staff entwined with green healing vines and soft golden glow"*

---

# REGION 2 — THE FUNGALMIRE (Sproutrest)

**Theme:** Bioluminescent fungal caverns, mycelium networks, toxic beauty, deep bogs
**Colors:** Theme `#4a6b3a` (olive green) / Accent `#8bc34a` (bright lime)
**Native Race:** Mossfolk

---

## Druid — Fungal Cavern Healer

> *"A nature guardian attuned to the bioluminescent depths of Sproutrest, weaving fungal spores and cave-blooms into restorative magic. The cavern itself breathes at their command."*

| Field | Value |
|-------|-------|
| Archetype | Healer |
| Weapons | Staff, Focus |
| Ability A | **Nature's Embrace** — warm green vines wrapping golden healing glow (HOT) |
| Ability B | **Spore Cloud** — billowing green-purple toxic spore cloud with mushroom caps (AoE damage+poison) |
| Passive A | Verdant Growth |
| Passive B | Fungal Symbiosis |

**Visual Theme:** Bioluminescent caves, gentle heal light mixed with toxic purple-green spores.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#1a3a4a` | Deep cavern blue |
| Accent | `#4ecdc4` | Bioluminescent teal |
| BG | `#1a3a4a` | Deep cavern blue |
| Text | `#9b59b6` | Soft purple |

**Sprite Notes:**
- Staff crowned with blooming cave-flowers and curling moss
- Robes with bioluminescent teal accents — tiny glowing mushroom motifs
- Deep blue-green color scheme, not bright forest green
- Soft purple and teal glow effects
- Icon hint: *"gnarled wooden staff crowned with blooming flowers and curling moss"*

---

## Fungal Berserker — Rage-Fueled Spore Warrior

> *"A rage-fueled warrior bonded with the parasitic fungi of Sproutrest, trading sanity for overwhelming symbiotic power. Purple mycelia pulse through their veins like living armor."*

| Field | Value |
|-------|-------|
| Archetype | DPS |
| Weapons | Axe, Mace |
| Ability A | **Fungal Frenzy** — raging fist bursting through purple mushroom caps, green spore mist |
| Ability B | **Spore Burst** — exploding mushroom cap releasing ring of toxic green-purple spores (AoE poison) |
| Passive A | Mushroom Rage |
| Passive B | Toxic Blood |

**Visual Theme:** Explosive rage, neon toxicity, organic brutality.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#2d1b4e` | Dark purple |
| Accent | `#39ff14` | Toxic neon green |
| BG | `#2d1b4e` | Dark purple |
| Text | `#39ff14` | Neon green |

**Sprite Notes:**
- Bulky, raging stance — leaning forward, fists clenched or holding spiked weapon
- Purple mushroom growths on shoulders, arms, and back (living armor)
- Visible neon green veins/mycelia pulsing through exposed skin
- Dark purple-black base color with toxic green highlights
- Spiked fist or jagged axe dripping with spores
- Icon hint: *"spiked fist wreathed in purple mushroom caps and toxic green spores"*

---

# REGION 3 — THE SUNKEN STRAND (Shelldrift)

**Theme:** Fog-soaked coastal ruins, shifting tides, drowned architecture, bioluminescent coral
**Colors:** Theme `#2c6e7a` (dark teal) / Accent `#4a90a4` (medium teal-blue)
**Native Race:** Tidelings

---

## Stormcaller — Tempest Mage

> *"A tempest mage born of Shelldrift's eternal storms, who calls down lightning from the grey coastal skies. Thunder follows where they point."*

| Field | Value |
|-------|-------|
| Archetype | DPS |
| Weapons | Staff, Focus |
| Ability A | **Lightning Bolt** — crackling bolt of electric blue energy |
| Ability B | **Storm Surge** — swirling blue-white tempest vortex with branching lightning arcs (AoE + shocked) |
| Passive A | Static Charge |
| Passive B | Eye of Storm |

**Visual Theme:** Electric blue-white on dark grey. Chaotic, crackling energy.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#2c3e50` | Dark storm grey |
| Accent | `#3498db` | Electric blue |
| BG | `#2c3e50` | Dark storm grey |
| Text | `#ecf0f1` | White lightning |

**Sprite Notes:**
- Staff or focus crackling with blue-white electricity
- Dark grey stormcloud-colored robes
- Electric blue lightning accents along arms/staff
- Windswept appearance — hair/robes blown by wind
- Weathered, coastal look (driftwood, salt-worn)
- Icon hint: *"crackling electric blue storm cloud with lightning bolts arcing downward"*

---

## Tidechaser — Ocean Healer

> *"A water-attuned healer who communes with Shelldrift's restless tides, washing away afflictions with saltwater and pearl-light. The ocean's rhythm is their heartbeat."*

| Field | Value |
|-------|-------|
| Archetype | Healer |
| Weapons | Staff, Focus |
| Ability A | **Healing Tide** — rising teal wave of healing water |
| Ability B | **Cleansing Wave** — sweeping teal wave washing over allies, sparkling purification motes (AoE heal + cleanse) |
| Passive A | Tidal Flow |
| Passive B | Ocean Blessing |

**Visual Theme:** Flowing teal water, warm pearl glow, cleansing sea.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#1a5276` | Deep ocean blue |
| Accent | `#48c9b0` | Healing teal |
| BG | `#1a5276` | Deep ocean blue |
| Text | `#f8e8d0` | Warm pearl white |

**Sprite Notes:**
- Flowing robes in ocean blues and teals — fabric looks wet/flowing like water
- Staff topped with a glowing pearl or shell
- Coral and seashell motifs on clothing
- Warm pearl-white glow around hands/staff
- Serene, graceful pose
- Icon hint: *"flowing teal wave crest encircling a glowing pearl of healing light"*

---

# REGION 4 — ASHEN HORIZONS (Embercradle)

**Theme:** Scorched sands, volcanic ridges, firestorms, obsidian formations, rivers of lava
**Colors:** Theme `#8b3a2a` (dark brick red) / Accent `#d4622a` (burnt orange)
**Native Race:** Dragonkin

---

## Pyrewarden — Flame-Forged Sentinel

> *"A flame-forged sentinel who bathed in the magma of Embercradle to harden their body into living volcanic rock. They draw enemy fury and answer it with burning vengeance."*

| Field | Value |
|-------|-------|
| Archetype | Vanguard (Tank) |
| Weapons | Sword, Mace, Axe |
| Ability A | **Flame Guard** — armored figure wreathed in roaring orange flames, defiant stance (taunt + defense) |
| Ability B | **Pyre Slam** — flaming hammer smashing ground, erupting orange fire burst (fire damage + burning) |
| Passive A | Burning Presence |
| Passive B | Ember Shield |

**Visual Theme:** Molten orange-red on obsidian black. A furnace given armor.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#1a1a2e` | Obsidian black-blue |
| Accent | `#f39c12` | Ember orange |
| BG | `#1a1a2e` | Obsidian black |
| Text | `#e74c3c` | Molten red |

**Sprite Notes:**
- Heavy volcanic rock armor with glowing orange lava cracks
- Obsidian black base with pulsing orange-red veins/seams
- Molten shield or heavy weapon wreathed in flame
- Planted, immovable stance
- Ember particles floating off the armor
- Icon hint: *"molten iron shield engulfed in roaring orange flames with ember core"*

---

## Ashblade — Ember Smoke Assassin

> *"A swift assassin born from Embercradle's ash storms, who vanishes into smoke and reappears with burning precision. Embers trail their every strike."*

| Field | Value |
|-------|-------|
| Archetype | DPS |
| Weapons | Dagger, Sword |
| Ability A | **Cinder Strike** — blazing dagger with trailing ember sparks and ash wisps (fire damage + burning) |
| Ability B | **Smoke Dash** — billowing grey smoke cloud, fading silhouette, speed streaks (evasion + speed buff) |
| Passive A | Ash Veil |
| Passive B | Burning Wounds |

**Visual Theme:** Ash grey smoke, orange ember sparks, ghostly silhouettes in haze.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#2c2c2c` | Dark charcoal |
| Accent | `#e67e22` | Cinder orange |
| BG | `#2c2c2c` | Dark charcoal |
| Text | `#e67e22` | Cinder orange |

**Sprite Notes:**
- Light, agile armor in ash grey and charcoal
- Curved dagger trailing smoke and ember sparks
- Grey smoke wisps around the figure — partially obscured
- Cinder orange highlights on blade edges, belt, and eye glow
- Lean, crouched, ready-to-strike pose
- Icon hint: *"curved dagger trailing gray smoke and glowing ember sparks"*

---

# REGION 5 — STARFALL EXPANSE (Crystalhearth)

**Theme:** Crystal groves, floating stones, prismatic geometry, fractured reality, impossible vistas
**Colors:** Theme `#4a3a8b` (deep indigo) / Accent `#9c6abf` (medium purple)
**Native Race:** Crystalborn

---

## Prism Sentinel — Crystal Guardian

> *"A crystalline guardian who absorbed Crystalhearth's prismatic light into their very body, refracting incoming damage into harmless rainbows. They are a living fortress of light."*

| Field | Value |
|-------|-------|
| Archetype | Vanguard (Tank) |
| Weapons | Mace, Sword, Axe |
| Ability A | **Prism Barrier** — crystalline shield wall refracting light |
| Ability B | **Light Refraction** — glowing crystal prism splitting light into reflected rainbow shards (damage reflect) |
| Passive A | Crystal Shell |
| Passive B | Prismatic Ward |

**Visual Theme:** Crystal and light acting as armor. Rainbow deflection. Defensive radiance.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#2c1654` | Deep purple |
| Accent | `#aed6f1` | Crystal ice blue |
| BG | `#2c1654` | Deep purple |
| Text | `#ffffff` | White |

**Sprite Notes:**
- Faceted crystal armor — geometric, angular surfaces catching light
- Deep purple base with ice blue crystalline highlights
- Crystal shield with prismatic rainbow refraction effects
- Glowing white-blue at joints and edges
- Solid, wide stance — immovable like a gemstone formation
- Icon hint: *"faceted crystal tower shield radiating prismatic light barriers"*

---

## Prism Lancer — Radiant Light Warrior

> *"A radiant warrior who channels Crystalhearth's starlight through a crystalline lance, focusing it into devastating piercing beams. Where they aim, light becomes lethal."*

| Field | Value |
|-------|-------|
| Archetype | DPS |
| Weapons | Sword, Bow, Dagger |
| Ability A | **Light Lance** — concentrated beam of white-gold light piercing forward |
| Ability B | **Prismatic Burst** — shattering crystal exploding outward, blinding burst of rainbow shards (AoE blind) |
| Passive A | Focused Light |
| Passive B | Crystal Resonance |

**Visual Theme:** Focused light as weapon. Precision beam, then explosive crystal scatter.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#1a0a3e` | Deep indigo |
| Accent | `#e8daef` | Prismatic lavender |
| BG | `#1a0a3e` | Deep indigo |
| Text | `#f9e79f` | Gold-white |

**Sprite Notes:**
- Sleek angular armor in deep indigo with lavender crystal inlays
- Crystalline lance — long, pointed, refracting white-gold light
- Prismatic light trail behind the weapon
- Dynamic forward-leaning pose — lunging or aiming
- Gold-white glow at the lance tip
- Icon hint: *"crystalline lance refracting a focused beam of prismatic light"*

---

# REGION 6 — THE NECROPOLIS (Duskhollow)

**Theme:** Gothic bone realm, grave-dust, lingering souls, ossuary depths, forbidden magic
**Colors:** Theme `#3a3a4a` (dark blue-grey) / Accent `#6d4c6e` (muted mauve)
**Native Race:** Undead

---

## Dark Channeler — Shadow Priest Healer

> *"A shadow priest who walks Duskhollow's boundary between life and death, draining the living to restore the wounded. Their dark tome whispers with the voices of the almost-departed."*

| Field | Value |
|-------|-------|
| Archetype | Healer |
| Weapons | Staff, Focus |
| Ability A | **Life Drain** — wisp of draining purple energy flowing from dark hand to green glow (damage + heal) |
| Ability B | **Shadow Mend** — dark purple shadows weaving into soft green healing threads (big heal, self-damage cost) |
| Passive A | Dark Pact |
| Passive B | Soul Siphon |

**Visual Theme:** Purple-black shadow torn open to bleed green healing light. Sacrifice and corruption in service of the team.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#1a2e1a` | Dark crypt green |
| Accent | `#6c3483` | Shadow purple |
| BG | `#1a2e1a` | Dark crypt green |
| Text | `#abebc6` | Faint healing green |

**Sprite Notes:**
- Dark hooded robes in crypt green and shadow purple
- Floating dark tome with faint green glow (the whispering book)
- One hand dark/shadow, other hand faint green healing light
- Skull or bone motifs on the robe hem
- Eerie dual-nature: half dark, half light
- Icon hint: *"dark purple tome radiating shadow tendrils entwined with faint healing light"*

---

## Lich — Undying Necromancer

> *"An undying master of Duskhollow's death magic who has transcended mortality, commanding necrotic forces that wither the living and puppet the dead. Their phylactery pulses with stolen souls."*

| Field | Value |
|-------|-------|
| Archetype | DPS |
| Weapons | Staff, Focus |
| Ability A | **Death Bolt** — crackling bolt of necrotic green energy with swirling skull wisps (massive single-target) |
| Ability B | **Raise Dead** — skeletal hands rising from dark ground with green necrotic aura (all-ally ATK+SPD buff) |
| Passive A | Phylactery |
| Passive B | Necrotic Aura |

**Visual Theme:** Necrotic green energy on pure black. Skull motifs. Soul-fire. Oppressive power.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#0d0d0d` | Crypt black |
| Accent | `#27ae60` | Soul-fire green |
| BG | `#0d0d0d` | Crypt black |
| Text | `#f0e6d2` | Bleached bone white |

**Sprite Notes:**
- Skeletal figure in tattered black robes
- Bone staff topped with a necrotic green-flaming skull
- Glowing green eyes visible under hood
- Green soul-fire wisps floating around the body
- Phylactery (small glowing orb/gem) visible at chest or belt
- Bleached bone visible at hands and face
- Icon hint: *"necrotic green skull wreathed in dark flame atop a bone staff"*

---

# REGION 7 — FINAL REALM (Voidreach)

**Theme:** Reality collapsing, void fissures, fractured geometry, entropy, the abyss
**Colors:** Theme `#1a1a2e` (near-black navy) / Accent `#4a2a6b` (dark purple)
**Native Race:** Voidwalkers

---

## Voidwalker — Dimensional Tank

> *"A dimensional warrior who stepped through Voidreach's rift and returned forever half-phased, flickering between planes to absorb attacks that pass through their shifting form."*

| Field | Value |
|-------|-------|
| Archetype | Vanguard (Tank) |
| Weapons | Sword, Axe, Dagger |
| Ability A | **Void Anchor** — dark purple anchor of void energy with gravity distortion (all-enemy taunt + speed debuff) |
| Ability B | **Phase Strike** — ghostly purple blade phasing through dimensional tear (armor-piercing void damage) |
| Passive A | Dimensional Shift |
| Passive B | Void Shell |

**Visual Theme:** Existing in two dimensions simultaneously. Iron permanence fighting dissolution. Purple-black void tendrils.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#0a0a1a` | Void black |
| Accent | `#7d3c98` | Deep purple |
| BG | `#0a0a1a` | Void black |
| Text | `#5dade2` | Dimensional blue |

**Sprite Notes:**
- Half-solid, half-phasing appearance — left side looks like normal iron armor, right side dissolves into purple void particles
- Heavy shield that's also partially phasing
- Deep purple void energy swirling around the body
- Dimensional blue glow at eyes and weapon edge
- Edges of the silhouette should look unstable/blurred
- Icon hint: *"heavy shield half-phased into a dark purple void rift"*

---

## Void Herald — Entropy Mage

> *"A harbinger of Voidreach's entropy who tears unstable portals in the fabric of reality, unleashing devastating dimensional energy. Each rift they open weakens the world a little more."*

| Field | Value |
|-------|-------|
| Archetype | DPS |
| Weapons | Staff, Focus |
| Ability A | **Void Tear** — jagged rift torn in the air leaking purple energy |
| Ability B | **Entropy Blast** — expanding wave of chaotic purple void energy distorting reality (AoE void damage + ATK debuff) |
| Passive A | Reality Warp |
| Passive B | Void Resonance |

**Visual Theme:** Reality itself breaking apart. Red-purple entropy tears. Violent, chaotic, destabilizing.

**Color Palette:**
| Role | Hex | Color |
|------|-----|-------|
| Border | `#0a0012` | Pitch black with purple tinge |
| Accent | `#8e44ad` | Entropy purple |
| BG | `#0a0012` | Pitch black |
| Text | `#e74c3c` | Rift red |

**Sprite Notes:**
- Floating/levitating pose — not fully touching ground
- Pitch black robes with jagged purple-red tears/cracks in the fabric
- Staff or focus pulsing with unstable purple-red energy
- Hands outstretched with dimensional rift cracks around fingers
- Violent, crackling energy — the most chaotic/unstable looking class
- Red highlights mixed with purple (unique among void classes)
- Icon hint: *"jagged dimensional tear with unstable purple energy spilling outward"*

---

# RACES — Visual Appearance Guide

Each race can be recruited into any class. These are the physical features that distinguish them regardless of what class armor they wear.

---

## Human
**Region:** R1 — Thornhaven | **Trait:** Adaptable, Balanced

> *"Versatile and adaptable, humans excel through determination and balance. Their quick learning makes them natural adventurers."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Warm peach | Warm peach |
| Hair | Brown, short | Auburn, medium length |
| Eyes | Standard | Standard |
| Build | Average humanoid | Average humanoid |
| Distinctive | None — the readable baseline | None — the readable baseline |

**Stat Mods:** No bonuses or penalties (perfectly balanced)
**Racial Passive:** Human Adaptability (+10% XP)
**Notes:** The "default" silhouette. Other races should be visually distinct FROM this baseline.

---

## Elf
**Region:** R1 — Thornhaven | **Traits:** Agile, Perceptive, Resist Bleed

> *"Agile and perceptive, elves have keen senses that reveal hidden paths. Their natural grace aids in precision work."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Fair with slight greenish tint | Fair with slight greenish tint |
| Hair | Pale blonde, long | Silver-white, flowing |
| Eyes | Sharp, perceptive | Sharp, perceptive |
| Build | Slender, taller than human | Slender, graceful |
| Distinctive | **Pointed ears** (must be clearly visible at 32x32) | **Pointed ears** |

**Stat Mods:** HP -5, DEF -2, SPD +3
**Racial Passive:** Elf Keen Sight
**Notes:** Slender silhouette. The pointed ears are the key identifier at small sizes.

---

## Dwarf
**Region:** R1 — Thornhaven | **Traits:** Durable, Stubborn, Resist Poison

> *"Durable and stubborn, dwarves are natural miners who find extra ore in the depths. Their resilience is legendary."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Ruddy | Ruddy |
| Hair | Large bushy red-brown beard | Long braided copper hair |
| Eyes | Standard | Standard |
| Build | Short and stocky (75% normal height), broad shoulders | Short and stocky, broad |
| Distinctive | **Huge beard** (m), **Short + Wide** silhouette | **Braids**, **Short + Wide** |

**Stat Mods:** HP +10, DEF +3, SPD -3
**Racial Passive:** Dwarf Deep Miner
**Notes:** Must read as SHORT at 32x32. The beard (m) or braids (f) are key identifiers. Broad shoulders.

---

## Mossfolk
**Region:** R2 — Fungalmire | **Traits:** Nature, Regenerative

> *"Plant-like beings born from the deep forests. Their connection to nature grants regenerative abilities and an affinity for fungi."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Green mossy, bark-textured | Green mossy, bark-textured |
| Hair | Dark green vine-like | Dark green vine-like with flower buds |
| Eyes | Amber, glowing | Amber, glowing |
| Build | Non-human, organic protrusions | Non-human, organic, flower buds |
| Distinctive | **Mushroom growths** on shoulders/head, bark skin | **Flower buds** + mushrooms, bark skin |

**Stat Mods:** HP +15, ATK -2, DEF +5, SPD -5
**Racial Passive:** Mossfolk Regeneration
**Notes:** Clearly non-human. Green bark skin, mushroom/flower growths, vine hair. Amber glowing eyes.

---

## Tidelings
**Region:** R3 — Sunken Strand | **Traits:** Aquatic, Elemental

> *"Amphibious people from coastal regions who draw power from the sea and storms. Fluid in combat and resilient against elemental forces."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Blue-teal scales | Light teal scales |
| Hair | Dark blue-green, wet-look | Sea-green, flowing |
| Eyes | Deep blue | Deep blue |
| Build | Humanoid with aquatic features | Humanoid, graceful aquatic |
| Distinctive | **Fin-like ears**, scaled skin | **Fin ears**, lighter scaled skin |

**Stat Mods:** HP +5, SPD +5
**Racial Passive:** Tideling Flow
**Notes:** The fin ears are the key identifier (like elf ears but fin-shaped). Scaled blue-teal skin.

---

## Dragonkin
**Region:** R4 — Ashen Horizons | **Traits:** Draconic, Fire, Immune to Fire

> *"Descendants of ancient dragons, blessed with scales and inner fire. They command respect through raw power and elemental fury."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Red scales | Dark red-orange scales |
| Hair | **None** — draconic head, brow ridges | **None** — sleek horns |
| Eyes | Orange, slit-pupil | Amber, slit-pupil |
| Build | Powerful, wide, horned head | Powerful, sleek horns |
| Distinctive | **Dark horns curving back**, no hair, scaled, draconic face | **Sleek horns**, scaled |

**Stat Mods:** HP +10, ATK +5, DEF +5, SPD -5
**Racial Passive:** Dragonkin Scales (fire immune)
**Notes:** Most visually distinct from human baseline. Dragon head with horns, no hair, red scales. Immediately recognizable.

---

## Crystalborn
**Region:** R5 — Starfall Expanse | **Traits:** Crystalline, Prismatic

> *"Beings formed from living crystal, resonating with prismatic energy. They refract magic and possess unparalleled clarity of purpose."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Pale blue-white crystalline | Pale pink-white translucent |
| Hair | Crystal formations (crown) | Crystal formations (crown) |
| Eyes | White-blue glowing | Pink-white glowing |
| Build | Angular, faceted surfaces | Angular, slightly softer facets |
| Distinctive | **Crystal crown/formations** on head, glowing body, faceted | **Crystal crown**, pink glow |

**Stat Mods:** ATK +3, DEF +8, SPD -3
**Racial Passive:** Crystalborn Refraction
**Notes:** Not organic — made of living crystal. Faceted surfaces, internal glow. Blue (m) or pink (f) tint.

---

## Undead
**Region:** R6 — The Necropolis | **Traits:** Undead, Dark

> *"Risen souls who have returned from beyond death. Their connection to dark energies grants them resilience but at a cost to their vitality."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Pale grey-green, drawn over bones | Pale grey-blue, ghostly translucence |
| Hair | None or sunken skull | Wispy white-grey |
| Eyes | Sunken, faint green-blue soul glow | Faint blue soul glow |
| Build | Gaunt, thin frame, visible bone structure | Gaunt, ethereal |
| Distinctive | **Sunken eyes with soul glow**, exposed bone, tattered | **Wispy ghost hair**, soul glow |

**Stat Mods:** HP -10, ATK +5, DEF +10
**Racial Passive:** Undead Persistence
**Notes:** Gaunt and skeletal. The soul-glow eyes are the key feature. Tattered clothing. Visible bone at hands.

---

## Voidwalkers
**Region:** R7 — Final Realm | **Traits:** Void, Dimensional

> *"Entities touched by the void between worlds. They phase between dimensions and command powers that defy natural law."*

| Feature | Male | Female |
|---------|------|--------|
| Skin | Dark purple-black | Dark purple-grey |
| Hair | Dark, tips fade into void particles | Long dark, dissolving into purple void wisps |
| Eyes | Glowing purple | Glowing violet |
| Build | Indistinct, phasing edges | Indistinct, phasing edges |
| Distinctive | **Edges blur/phase into void particles**, glowing eyes | **Hair dissolves into void wisps**, glowing eyes |

**Stat Mods:** HP -5, ATK +8, DEF -3, SPD +10
**Racial Passive:** Voidwalker Phase
**Notes:** The most alien-looking race. Edges of their silhouette should be unstable — pixels fading into nothing. Purple glow.

---

# Class-by-Region Summary

| Region | Town | Classes | Native Race |
|--------|------|---------|-------------|
| R1 Forest Haven | Thornhaven | Defender (tank), Striker (dps), Warden (healer) | Human, Elf, Dwarf |
| R2 Fungalmire | Sproutrest | Druid (healer), Fungal Berserker (dps) | Mossfolk |
| R3 Sunken Strand | Shelldrift | Stormcaller (dps), Tidechaser (healer) | Tidelings |
| R4 Ashen Horizons | Embercradle | Pyrewarden (tank), Ashblade (dps) | Dragonkin |
| R5 Starfall Expanse | Crystalhearth | Prism Sentinel (tank), Prism Lancer (dps) | Crystalborn |
| R6 Necropolis | Duskhollow | Dark Channeler (healer), Lich (dps) | Undead |
| R7 Final Realm | Voidreach | Voidwalker (tank), Void Herald (dps) | Voidwalkers |

# Animation Mapping per Class

Which animation plays for each class's abilities:

| Class | `attack` anim triggers on | `cast` anim triggers on |
|-------|--------------------------|------------------------|
| Defender | Shield Bash, Aegis Slam | Fortify (buff glow) |
| Striker | Twin Strike, Crippling Blow | Shadowstep (vanish) |
| Warden | basic weapon swing | Nature's Grace, Barkskin |
| Druid | basic weapon swing | Nature's Embrace, Spore Cloud |
| Fungal Berserker | Fungal Frenzy (fist/axe) | Spore Burst (AoE explode) |
| Stormcaller | basic weapon swing | Lightning Bolt, Storm Surge |
| Tidechaser | basic weapon swing | Healing Tide, Cleansing Wave |
| Pyrewarden | Pyre Slam (hammer smash) | Flame Guard (taunt glow) |
| Ashblade | Cinder Strike (dagger) | Smoke Dash (vanish) |
| Prism Sentinel | basic weapon swing | Prism Barrier, Light Refraction |
| Prism Lancer | Light Lance (beam thrust) | Prismatic Burst (explode) |
| Dark Channeler | basic weapon swing | Life Drain, Shadow Mend |
| Lich | basic weapon swing | Death Bolt, Raise Dead |
| Voidwalker | Phase Strike (phasing lunge) | Void Anchor (gravity pulse) |
| Void Herald | basic weapon swing | Void Tear, Entropy Blast |
