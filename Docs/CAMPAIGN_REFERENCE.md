# Shops & Shadows — Campaign Reference

> **Status**: Draft v1.0 — Story arc, dialog triggers, and character definitions.
> **Maintained by**: Story, Art, Gameplay, UI agents.
> **Data files**: `Data/Campaign/*.json` (machine-readable dialog data)
> **Canon source**: `Docs/SHOPS_AND_SHADOWS_CANON_OVERVIEW.md`

---

## Core Story Summary

The Shopkeeper was sent to Thornhaven by the Crown to supply frontier settlements threatened by spreading corruption. What begins as a logistics mission becomes a journey through seven increasingly dangerous regions, uncovering the truth behind the corruption: a temporal artifact called the Grail of Life, a grief-stricken King who caused its rupture, and a former royal tactician — the Void Sovereign — who weaponizes corruption to seize the Grail for himself.

**Thematic Core**: Regret vs Resilience / Grief vs Growth / Rewrite vs Rebuild

---

## Key Characters

### The Shopkeeper (Player)
- **Role**: Silent protagonist — never speaks, NPCs address them directly
- **Origin**: Sent to Thornhaven on royal orders to supply the frontier
- **Secret**: Always remembers timeline rewrites (revealed in NG+)
- **Motivation**: Build infrastructure, support heroes, push back corruption

### The King (Absent Ruler)
- **Name**: Referred to as "The King" or "His Majesty" (no personal name — maintains distance)
- **Personality**: Regret-driven, not tyrannical. Injured, unable to produce heir.
- **Backstory**: Funded Grail research, overrode safety warnings, caused the temporal rupture that created void corruption. Buried records, declared void heretical.
- **First Appearance**: Referenced by NPCs from R1, but does not appear directly until R3-R4
- **Communication**: Through a Royal Herald (major beats) and royal letters/scrolls (minor updates)
- **Arc**: Benefactor -> Questioned authority -> Revealed as the cause -> Seeks redemption or doubles down

### Sir Cedric Ashmore — The Royal Herald
- **Role**: Recurring NPC who delivers the King's messages to the Shopkeeper
- **Personality**: Loyal, formal, increasingly conflicted as the King's true role becomes clear
- **Arc**: Dutiful messenger (R1-R2) -> Begins questioning orders (R3-R4) -> Crisis of loyalty (R5-R6) -> Makes a choice (R7)
- **Portrait**: `res://Assets/_ArtPacks/Avatars_MedievalPeople/PNG/Transperent/Icon39.png` (BJ#39)
- **Appears in**: Town, after major story beats. Has his own small dialog moments.

### The Void Sovereign (Grand Strategist)
- **True Name**: Valdric (referred to as "???" in R1-R4, "The Void Sovereign" in R5+, true name revealed in R6 Lira scene)
- **Personality**: Escalating intensity — dismissive to curious to threatening
- **Backstory**: Former royal tactician, lost his lover in the Grail rupture. Remembers due to direct void exposure. Believes the King is unfit. Seeks Grail to rewrite the timeline.
- **First Appearance**: Mysterious voice after R1 boss kill
- **Communication Style Progression**:
  - R1-R2: Disembodied voice (dismissive, barely notices the Shopkeeper)
  - R3-R5: Dark apparition with partial portrait (curious, studying the Shopkeeper)
  - R6-R7: Full confrontation with complete portrait (personal, threatening)
- **Motivation**: "Grief-driven, not chaotic" — genuinely believes rewriting the timeline is mercy

### Facility Keepers (Existing NPCs)
All keepers are established characters with portraits and dialog. Key story-relevant keepers:
- **Mira** (Inn) — Warm, community-focused. Source of rumors and town morale.
- **Thalric** (Training Hall) — Scarred veteran. Delivers combat wisdom and hero loss context.
- **Pemberton** (Thornhaven Shop) — Elderly, warm. First friendly face. Tutorial narrator.
- **The Null Merchant** (R7 Shop) — Existential, phasing. Knows more than they should.

---

## Dialog Trigger Points & Display Types

### Display Types

| Type | Use For | Visual |
|------|---------|--------|
| **Full-Screen Overlay** | Major story beats (boss kills, new region arrival, King revelations) | Dark overlay, centered portrait + text, click to advance |
| **Portrait + Text Box** | NPC conversations (Herald visits, keeper story dialog) | Portrait left, text right, RPG dialog style |
| **Event Popup** | In-dungeon story moments, camp encounters | Reuses existing event system with story flag |
| **Ambient Ticker** | Flavor text, minor hints, atmosphere | Bottom bar scrolling text during gameplay |

### Trigger System

| Trigger | When | Display Type | Example |
|---------|------|-------------|---------|
| `region_first_arrival` | First time entering a new region's town | Full-Screen Overlay | Region intro text, keeper welcome |
| `boss_first_kill` | After defeating a region's final boss for first time | Full-Screen Overlay | Void Sovereign taunt, loot celebration |
| `herald_visit` | After specific story flags are set | Portrait + Text Box | Sir Cedric delivers King's message |
| `dungeon_camp_story` | At camp on specific dungeon floors | Event Popup | Lore fragments, NPC reactions |
| `keeper_story` | When visiting a keeper after a story flag | Portrait + Text Box | Keeper comments on recent events |
| `ambient_hint` | During town/dungeon gameplay | Ambient Ticker | Flavor text, world-building |

---

## Campaign Arc — Region by Region

### Region 1: Forest Haven (Thornhaven)

**Theme**: Establishment — The Shopkeeper arrives, learns the basics, faces first corruption.

#### R1 — First Arrival (region_first_arrival)
- **Display**: Full-Screen Overlay
- **Speaker**: Mira (Inn)
- **Content**: Welcome to Thornhaven. Town is struggling. Corruption creeping in from the forest. The Crown sent you — make yourself useful. Brief intro to the ShopKeeper role.

#### R1 — Herald's First Visit (herald_visit)
- **Trigger**: After first dungeon room cleared
- **Display**: Portrait + Text Box
- **Speaker**: Sir Cedric Ashmore
- **Content**: Formal introduction. "By order of His Majesty, you are appointed Crown Supplier to the frontier settlements. The corruption must be contained. Resources will follow your progress." Stiff, formal. Leaves quickly.

#### R1 — Boss Kill: Thorn-Ent / Iron Foreman (boss_first_kill)
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign (voice only, no portrait)
- **Content**: *"...Hm. Noise."* — A whisper at the edge of hearing. Barely acknowledged. The player might not even realize it's significant. Brief, dismissive, unsettling.

#### R1 — Post-Boss Herald Visit (herald_visit)
- **Trigger**: Return to town after R1 boss kill
- **Display**: Portrait + Text Box
- **Speaker**: Sir Cedric
- **Content**: "Well done. His Majesty is... pleased. The Fungalmire to the east reports increased corruption. You are to establish supply lines there. The Crown provides." — Hands the Shopkeeper a royal letter with travel authorization + starting funds for R2.

---

### Region 2: The Fungalmire (SproutRest)

**Theme**: Escalation — Corruption is more aggressive. The Void Sovereign notices.

#### R2 — First Arrival (region_first_arrival)
- **Display**: Full-Screen Overlay
- **Speaker**: Sporella (Shop)
- **Content**: SproutRest is struggling with spore corruption. The Mossfolk are resilient but overwhelmed. "Your supplies may be the difference between our survival and becoming part of the Mycelium."

#### R2 — Boss Kill: The Spiral Mycelium (boss_first_kill)
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign (voice only)
- **Content**: *"A shopkeeper. The Crown sends a shopkeeper to fight corruption. How... economical."* — Dismissive but now aware. A dry, almost amused observation.

#### R2 — Post-Boss Herald Visit (herald_visit)
- **Display**: Portrait + Text Box
- **Speaker**: Sir Cedric
- **Content**: More formal praise. But a small crack — "I confess, I did not expect you to survive the Mycelium. His Majesty's faith in unconventional assets appears... well-placed." First hint of humanity. Travel authorization to R3.

---

### Region 3: The Sunken Strand (Shelldrift)

**Theme**: Mystery — Something doesn't add up. The King's interest feels too specific.

#### R3 — First Arrival (region_first_arrival)
- **Display**: Full-Screen Overlay
- **Speaker**: Barnacle Bill (Shop)
- **Content**: Shelldrift is barely holding together. The tides bring corruption inland. "Every salvage run gets worse. Whatever's down in those depths, it's angry."

#### R3 — Herald's Letter (herald_visit — letter, not in person)
- **Trigger**: After arriving in R3
- **Display**: Portrait + Text Box (scroll/letter visual)
- **Speaker**: The King (via letter)
- **Content**: First direct communication from the King. Formal, but oddly specific: "The Sunken Strand contains ruins of... historical significance. Ensure nothing of value is lost to the tides." — Why does the King care about specific ruins?

#### R3 — Keeper Story Beat (keeper_story)
- **Trigger**: Visit Mira equivalent in Shelldrift after clearing floor 2
- **Speaker**: Barnacle Bill
- **Content**: "Strange folk been asking about old ruins down there. Royal types. Before you even arrived. Makes a sailor wonder..."

#### R3 — Boss Kill: The Tide Sovereign (boss_first_kill)
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign (apparition — shadowy figure, partial portrait)
- **Content**: *"You've reached the Strand. Interesting. The Crown sent you here specifically, didn't they? Ask yourself why."* — No longer dismissive. Curious. First visual manifestation — a dark silhouette that flickers and vanishes.

#### R3 — Post-Boss Herald Visit (herald_visit — in person)
- **Display**: Portrait + Text Box
- **Speaker**: Sir Cedric
- **Content**: Cedric is tense. "His Majesty wishes to know — did you find anything unusual in the depths? Artifacts? Inscriptions?" When the Shopkeeper has nothing specific: visible relief from Cedric, but also confusion. "Very well. Proceed to the Ashen Horizons. The corruption... accelerates." First sign Cedric doesn't know everything.

---

### Region 4: Ashen Horizons (Embercradle)

**Theme**: Confrontation — The Void Sovereign becomes a direct presence. The King's agenda sharpens.

#### R4 — First Arrival (region_first_arrival)
- **Display**: Full-Screen Overlay
- **Speaker**: Cindra (Shop)
- **Content**: Embercradle was built on strength and fire. The corruption here is flame — twisted, consuming. "We forge or we burn. There's no middle ground in the Horizons."

#### R4 — Herald's Urgent Visit (herald_visit)
- **Trigger**: After clearing R4 dungeon floor 2
- **Display**: Portrait + Text Box
- **Speaker**: Sir Cedric
- **Content**: Cedric arrives looking shaken. "The King has issued new orders. You are to search for... fragments. Crystalline fragments that predate the corruption." He pauses. "I asked for clarification. I was told to deliver the message. Nothing more." — Cedric is beginning to question.

#### R4 — Boss Kill: The Cinder Monarch (boss_first_kill)
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign (apparition — clearer now, hooded figure)
- **Content**: *"Four regions cleared. Four puppets toppled. Does your King tell you why the corruption follows his interests so precisely? No. He wouldn't."* — Pause. *"You build well, Shopkeeper. It would be a shame if everything you've built was... temporary."* — Direct challenge. Knows the Shopkeeper by role now.

#### R4 — Post-Boss (keeper_story)
- **Trigger**: Return to any town
- **Speaker**: Thalric (Training Hall)
- **Content**: "I've trained soldiers my whole life. The corruption in each region — it's not random. It's focused. Like someone is directing it toward specific places. You've noticed too, haven't you?"

---

### Region 5: Starfall Expanse (Crystalhearth)

**Theme**: Revelation — The truth about the Grail begins to surface.

#### R5 — First Arrival (region_first_arrival)
- **Display**: Full-Screen Overlay
- **Speaker**: Luxiel (Shop)
- **Content**: Crystalhearth exists outside normal time. "The crystals remember everything. Every timeline. Every choice. Some of them remember you." — First hint at the timeline/rewrite lore.

#### R5 — Dungeon Camp Story Beat (dungeon_camp_story)
- **Trigger**: R5 dungeon, floor 3 camp
- **Display**: Event Popup
- **Content**: A crystal formation hums as you approach. Images flicker inside — a grand hall, a shattered artifact, a man on a throne weeping. The vision fades. Your heroes look unsettled. — First glimpse of the Grail rupture.

#### R5 — Boss Kill: The Shattered Oracle (boss_first_kill)
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign (clear apparition, full portrait emerging)
- **Content**: *"The Oracle showed you something, didn't it? A king. A broken thing. A choice that unmade the world."* — Steps closer. *"That was not metaphor, Shopkeeper. That happened. And your Crown — your employer — is the one who broke it."* — The accusation lands. *"I intend to fix what he destroyed. Step aside... or be corrected."*

#### R5 — Herald Crisis (herald_visit)
- **Trigger**: Return to town after R5 boss
- **Display**: Portrait + Text Box
- **Speaker**: Sir Cedric
- **Content**: Cedric arrives without his formal composure. "I've been digging. The King's archives. The fragments he asked you to find — they're pieces of something called the Grail of Life. An artifact that can... rewrite history." He looks stricken. "The rupture that created the corruption. The reason the void exists. It was the King's doing. He tried to use the Grail to change the succession. It failed. And everything broke." — Long pause. "I don't know what to believe anymore. But I believe you deserve the truth."

---

### Region 6: The Necropolis (Duskhollow)

**Theme**: Consequences — Death, loss, the weight of what's been done. Both the King and Void Sovereign's pain is real.

#### R6 — First Arrival (region_first_arrival)
- **Display**: Full-Screen Overlay
- **Speaker**: Mortimer (Shop)
- **Content**: Duskhollow is where the dead gather. Not mindless — remembering. "The corruption here doesn't destroy. It preserves. Every soul trapped between was and wasn't. A kingdom of almost-people." — The corruption's nature becomes deeply sad.

#### R6 — King's Direct Letter (herald_visit — letter)
- **Trigger**: After arriving in R6
- **Display**: Portrait + Text Box (scroll)
- **Speaker**: The King (via letter, personal this time)
- **Content**: No formal address. Handwritten, not royal decree. "You know, don't you. What I did. What I am. I wanted to save my line. My father's legacy. Instead I broke the world and condemned its people to this... half-existence." — "The man in the void — the Strategist — he was my friend once. I drove him to this. If you can stop him without the Grail, perhaps that is enough. Perhaps rebuilding is enough." — First genuine vulnerability.

#### R6 — Lira's Ghost (dungeon_camp_story)
- **Trigger**: R6 dungeon, floor 2 camp
- **Display**: Event Popup
- **Speaker**: None (ghostly vision)
- **Content**: A translucent woman in scholar's robes appears at the edge of camp. She looks through the Shopkeeper, searching for someone who isn't there. Her lips move silently. She points deeper into the dungeon, then fades. — Lira's ghost. Players connect her to Valdric's story two floors later.

#### R6 — Valdric's Confession (dungeon_camp_story)
- **Trigger**: R6 dungeon, floor 4 camp
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign / Valdric (full portrait, standing before you)
- **Content**: *"Her name was Lira."* — Quiet. *"She was the finest mind in the kingdom. She warned the King the Grail was unstable. He ordered the activation anyway. She was standing next to it."* — His voice breaks, just slightly. *"I remember her. Across every rewrite, every shattered timeline. I remember her because the void burned her into me."* — Then cold again. *"The King gets to forget. I do not. That is why the Grail must be mine. Not revenge. Correction."*

#### R6 — Boss Kill: The Ossuary King (boss_first_kill)
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign (full presence)
- **Content**: *"Six regions. Six puppets. You are remarkably persistent for a merchant."* — Grudging respect. *"One region remains. The void's heart. MY domain. Come if you dare, Shopkeeper. But know this — everything you've built, every town, every hero, every supply line — exists because I ALLOW it. That courtesy ends now."*

#### R6 — Herald's Choice (herald_visit)
- **Trigger**: Return to town after R6 boss
- **Display**: Portrait + Text Box
- **Speaker**: Sir Cedric
- **Content**: Cedric arrives in civilian clothes. No tabard. "I've resigned my commission." Pause. "The King's cause is just — his guilt is real. But I cannot serve a crown that hides the truth from the people fighting for it." He looks at the Shopkeeper. "I'm not leaving. I'll fight alongside you. Not for the Crown. For the towns. For what you've built." — Cedric becomes available as a story ally for R7.

---

### Region 7: The Final Realm (Void Threshold)

**Theme**: Resolution — The end of all things. Choice. What matters is what you build.

#### R7 — First Arrival (region_first_arrival)
- **Display**: Full-Screen Overlay
- **Speaker**: The Null Merchant
- **Content**: "You perceive an ending. That is... close enough to what this is." — The town flickers between existence and void. "The Sovereign waits at the heart. The Grail waits with him. But you already know — you've always known — that artifacts don't save worlds. People do. Supply lines do. The quiet work of keeping others alive."

#### R7 — King's Final Message (herald_visit — letter, delivered by Cedric)
- **Trigger**: Before entering R7 dungeon
- **Display**: Portrait + Text Box
- **Speaker**: The King (via letter, hand-delivered by Cedric)
- **Content**: "I cannot undo what I have done. The Grail cannot undo what I have done — I know that now. Even if it could rewrite the timeline, the corruption would simply begin again from a new wound." — "You have built something I never could. Not a kingdom — a network. Connections. Trust. That is stronger than any artifact." — "Stop him. Not because I command it. Because he will break the world again trying to fix it. And this time, there may be nothing left to rebuild."

#### R7 — Dungeon Camp: Cedric (dungeon_camp_story)
- **Trigger**: R7 dungeon, floor 3 camp
- **Display**: Event Popup
- **Speaker**: Sir Cedric (if ally system exists) or ambient
- **Content**: "I keep thinking about what the Sovereign said. About remembering. About grief." Pause. "Do you think if the Grail worked perfectly — if it could truly rewrite everything — would that be mercy? Or would it just be... forgetting?"

#### R7 — Pre-Boss: Void Sovereign (dungeon_camp_story)
- **Trigger**: R7 dungeon, final floor camp (before boss room)
- **Display**: Full-Screen Overlay
- **Speaker**: Void Sovereign (full presence, calm)
- **Content**: *"This is the last threshold, Shopkeeper. Beyond that door is the Grail — or what remains of it. And me."* — Almost gentle. *"I want you to understand. I am not a monster. I am a man who lost everything because a king was afraid of dying without an heir. Every void tear, every corrupted creature, every region you've fought through — all of it traces back to one man's fear of being forgotten."* — Then resolute. *"I will use the Grail. I will rewrite the rupture. Lira will live. The corruption will never have existed. Your towns, your heroes, your supply lines — none of it will have needed to exist. Isn't that... better?"* — The fundamental question: Is erasure of suffering worth the erasure of everything built in response to it?

#### R7 — Boss Kill: The Prime Corruptor / Void Sovereign (boss_first_kill)
- **Display**: Full-Screen Overlay (extended sequence)
- **Speaker**: Multiple
- **Phase 1 — Void Sovereign defeated**:
*The Sovereign falls. The Grail pulses. Reality shudders.*
*"You... chose. To build forward. Not rewrite backward."* — He looks at the Grail. *"Perhaps... perhaps that is the answer I couldn't accept."*

- **Phase 2 — The Grail**:
The Grail of Life dims. The corruption begins to recede — not erased, but calming. The void tears seal. The regions stabilize.

- **Phase 3 — Resolution**:
*"The corruption will fade. Slowly. As the Grail's energy dissipates. The world will heal — not because it was rewritten, but because people like you kept it alive long enough to recover."*

- **Phase 4 — Epilogue tease**:
*The Anchor Stone at the center of Thornhaven pulses once. Faintly. You feel something shift — a memory of a memory. The stone has always been there. Hasn't it?*
*(NG+ hook — the cycle continues)*

---

## Campaign Flags

Story progression is tracked via flags in GameContext. These drive dialog triggers.

| Flag | Set When | Used By |
|------|----------|---------|
| `story_r1_arrived` | First enter Thornhaven | R1 arrival dialog |
| `story_r1_boss_killed` | Defeat R1 boss | Void Sovereign R1 taunt |
| `story_r2_arrived` | First enter SproutRest | R2 arrival dialog |
| `story_r2_boss_killed` | Defeat R2 boss | Void Sovereign R2 taunt |
| `story_r3_arrived` | First enter Shelldrift | R3 arrival dialog |
| `story_r3_boss_killed` | Defeat R3 boss | Void Sovereign R3 taunt |
| `story_r4_arrived` | First enter Embercradle | R4 arrival dialog |
| `story_r4_boss_killed` | Defeat R4 boss | Void Sovereign R4 taunt |
| `story_r5_arrived` | First enter Crystalhearth | R5 arrival dialog |
| `story_r5_boss_killed` | Defeat R5 boss | Void Sovereign R5 reveal |
| `story_r6_arrived` | First enter Duskhollow | R6 arrival dialog |
| `story_r6_boss_killed` | Defeat R6 boss | Void Sovereign R6 threat |
| `story_r7_arrived` | First enter Void Threshold | R7 arrival dialog |
| `story_r7_boss_killed` | Defeat R7 boss | Ending sequence |
| `story_herald_intro` | Herald first appears | Unlock herald visits |
| `story_herald_questioning` | After R4 herald visit | Cedric's doubt dialog |
| `story_herald_resigned` | After R6 herald visit | Cedric as ally |
| `story_king_revealed` | After R5 herald crisis | King's true role known |
| `story_grail_known` | After R5 crystal vision | Grail lore unlocked |
| `story_lira_seen` | After R6 Lira ghost vision | Connects to Valdric's confession |

---

## Dialog Count Summary

| Region | Full-Screen | Portrait+Text | Event Popup | Ambient | Total |
|--------|------------|--------------|-------------|---------|-------|
| R1 | 2 | 2 | 0 | 0 | 4 |
| R2 | 2 | 1 | 0 | 0 | 3 |
| R3 | 2 | 2 | 0 | 0 | 4 |
| R4 | 1 | 2 | 0 | 0 | 3 |
| R5 | 2 | 1 | 1 | 0 | 4 |
| R6 | 2 | 2 | 2 | 0 | 6 |
| R7 | 3 | 1 | 2 | 0 | 6 |
| **Total** | **14** | **11** | **5** | **0** | **30** |

---

## Key NPCs: Lira (The Lost Scholar)

- **Role**: Valdric's lover — the brilliant scholar who died in the Grail rupture
- **Appears**: As a ghostly vision in R6 dungeon (floor 2 camp), and referenced throughout Valdric's dialog
- **Portrait**: Translucent/ethereal — uses spectral overlay effect on base portrait
- **Significance**: The emotional heart of the villain's motivation. She warned the King. He didn't listen. She died.

---

## Open Questions

1. ~~**King's Name**~~: Stays as "The King" — RESOLVED
2. ~~**Void Sovereign's True Name**~~: Valdric — RESOLVED
3. ~~**Lira**~~: Appears as ghost/vision in R6 dungeon — RESOLVED
4. **Faction Leaders R2-R6**: Left unnamed for now. Can be fleshed out for NG+ where each becomes endgame boss.
5. ~~**Sir Cedric's portrait**~~: BJ#39 (MedievalPeople Icon39) — RESOLVED
6. **Memory Sigil / NG+ dialog**: Separate document for post-campaign content
7. **Ambient ticker content**: Flavor text for each region during gameplay — separate pass

---

## Implementation Priority

1. **Phase 1**: Campaign flag system in GameContext + Full-Screen Overlay UI component
2. **Phase 2**: R1-R3 dialog JSON data + trigger integration
3. **Phase 3**: Herald NPC (portrait, town appearance logic)
4. **Phase 4**: R4-R7 dialog JSON data
5. **Phase 5**: Dungeon camp story events
6. **Phase 6**: Ambient ticker system
7. **Phase 7**: NG+ story hooks
