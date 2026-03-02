# ShopKeepers Game — Agent Definitions

This directory contains agent prompts for structured Claude Code workflows.

## Agent Orchestration Pattern

The recommended workflow order is:

```
Repo Auditor → Implementer → UI Refiner (optional) → Data Curator (optional)
                                                    → Item Curator (optional)
                                                    → Art Director (optional)
                                                    → Sound Director (optional)
                                                    → Story Architect (optional)
                                                    → Balancer (optional)
                                                    → Heroes Agent (optional)
                                                    → Gameplay Guide (optional)
                                                    → Playtest Agent (optional)
```

1. **Repo Auditor** decides WHAT to build next
2. **Implementer** builds it with tests
3. **UI Refiner** polishes the visual layer (if needed)
4. **Data Curator** extends content (if needed)
5. **Item Curator** updates item manifest and HTML reference (if items changed)
6. **Art Director** tracks visual assets, adds icon_hint descriptions, updates HTML (if needed)
7. **Sound Director** tracks audio assets, manages BGM replacement and SFX integration (if needed)
8. **Story Architect** writes narrative content, lore, and campaign arcs (if needed)
9. **Balancer** audits abilities, passives, equipment, and updates balance reference (if needed)
10. **Gameplay Guide** maintains game guide, assists with tutorials (if needed)

## Available Agents

| Agent | File | Purpose |
|-------|------|---------|
| Repo Auditor | `repo-auditor.md` | Scan repo, assess state, propose next milestone |
| Implementer | `implementer.md` | Test-driven implementation, minimal diffs |
| UI Refiner | `ui-refiner.md` | Visual cleanup, theme consistency |
| Data Curator | `data-curator.md` | JSON validation, content extension |
| Item Curator | `item-curator.md` | Item manifest tracking, HTML reference sync |
| Art Director | `art-director.md` | Art asset tracking, icon_hint descriptions, HTML updates |
| Story Architect | `story-architect.md` | Narrative content, lore, campaign arcs, event text |
| Balancer | `balancer.md` | Abilities, passives, equipment balance, reference file |
| Gameplay Guide | `gameplay-guide.md` | Game guide, tutorials, onboarding, help text |
| Sound Director | `sound-director.md` | Audio asset tracking, BGM replacement, SFX integration |
| Icon Mapper | `icon-mapper.md` | Icon assignment, ledger generation, recolour pipeline |
| Monster Curator | `monster-curator.md` | Monster manifest, roles, abilities, AI tiers, stat distributions |
| Heroes Agent | `heroes-agent.md` | Hero reference, class kits, race balance, build paths, stat synergies |
| Controls Agent | `controls-agent.md` | Input controls, keyboard/mouse/gamepad mapping, focus navigation, conventions |
| Playtest Agent | `playtest-agent.md` | Steam Playtest prep, analytics, telemetry, feedback, GDPR compliance |

## Usage

Copy the System Prompt from the relevant agent file when starting a new task.

Or reference the agent by saying:
- "Use the Repo Auditor agent to assess current state"
- "Use the Implementer agent to build [feature]"
- "Use the UI Refiner agent to clean up [panel]"
- "Use the Data Curator agent to add [item/monster]"
- "Use the Item Curator agent to update the item manifest"
- "Use the Art Director agent to integrate art for [feature]"
- "Use the Story Architect agent to write lore for [region/event]"
- "Use the Balancer agent to review balance for [region/tier/category]"
- "Use the Sound Director agent to replace BGM tracks"
- "Use the Sound Director agent to map SFX to combat actions"
- "Use the Gameplay Guide agent to update the game guide"
- "Use the Heroes Agent to audit class balance and build paths"
- "Use the Controls Agent to audit gamepad support for [scene]"
- "Use the Controls Agent to check button mappings"
- "Use the Playtest Agent to prepare for Steam Playtest"
- "Use the Playtest Agent to design analytics tracking"

## Keyword → Agent Lookup

When you mention a topic, these keywords auto-map to the relevant agent(s):

| Keyword | Agent(s) |
|---------|----------|
| `icon`, `art`, `sprite`, `portrait`, `png`, `uploaded`, `art pack` | Art Director + Item Curator |
| `item`, `equipment`, `weapon`, `armor`, `consumable`, `material` | Item Curator + Data Curator |
| `balance`, `stats`, `scaling`, `power spike`, `bloat` | Balancer |
| `ability`, `passive`, `cooldown`, `damage` | Balancer + Data Curator |
| `lore`, `story`, `narrative`, `quest`, `dialogue`, `flavor text` | Story Architect |
| `event text`, `npc`, `boss name`, `region name`, `town name` | Story Architect + Data Curator |
| `ui`, `layout`, `panel`, `button`, `theme`, `display` | UI Refiner |
| `json`, `schema`, `validate`, `gating`, `unlock` | Data Curator |
| `manifest`, `html reference`, `item count`, `slot coverage` | Item Curator |
| `monster`, `creature`, `enemy`, `encounter`, `ai tier`, `combat role` | Monster Curator + Balancer |
| `hero`, `class`, `race`, `build path`, `archetype`, `kit`, `class balance` | Heroes Agent + Balancer |
| `icon`, `ledger`, `recolour`, `icon_path`, `icon_hint` | Icon Mapper + Art Director |
| `audit`, `status`, `tech debt`, `milestone`, `architecture` | Repo Auditor |
| `implement`, `build`, `fix bug`, `add feature`, `test` | Implementer |
| `tier`, `economy`, `stat curve` | Balancer |
| `guide`, `tutorial`, `how to play`, `help text`, `tooltip`, `onboarding` | Gameplay Guide |
| `new player`, `walkthrough`, `game flow`, `first time` | Gameplay Guide + Story Architect |
| `controls`, `controller`, `gamepad`, `keyboard`, `input`, `keybind`, `mapping` | Controls Agent |
| `focus`, `navigation`, `d-pad`, `joystick`, `xbox`, `playstation` | Controls Agent |
| `sound`, `audio`, `music`, `bgm`, `sfx`, `volume`, `track`, `ambience` | Sound Director |
| `combat sounds`, `music pack`, `jukebox`, `sound effect` | Sound Director |
| `playtest`, `steam`, `release`, `analytics`, `telemetry`, `feedback` | Playtest Agent |
| `gdpr`, `privacy`, `consent`, `survey`, `store page`, `godotsteam` | Playtest Agent |

Multiple agents may trigger for a single request — they work in parallel on their respective duties.

## Project Map (Reduce Scanning)

All agents should consult `Docs/PROJECT_MAP.md` (maintained by Repo Auditor) before scanning directories. This file contains a complete directory index so agents can jump straight to the right files instead of globbing/grepping blindly.

## Invariants (All Agents Must Respect)

These rules apply across ALL agents:

1. **Combat Semantics** — Do NOT modify CombatUnit, TurnQueue, StatusRuntime, SeededRNG, or damage/status math unless explicitly requested
2. **Stash Banking** — Stash is locked during dungeon; items bank only on extract/town
3. **Loot Recipient** — Manual routing only (no auto-sort/prefs)
4. **Dungeon Bags** — No stacking; stash is the only place that stacks
5. **Determinism** — All RNG through SeededRNG for reproducibility

## Test Requirements

Every implementation change MUST:
- Add or update tests in `DevTools/test_ability_execution_v1.gd`
- Pass headless validation: `DevTools\run_headless.bat`
- Report test counts: "X passed, Y failed"
