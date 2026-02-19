# ShopKeepers Game — Agent Definitions

This directory contains agent prompts for structured Claude Code workflows.

## Agent Orchestration Pattern

The recommended workflow order is:

```
Repo Auditor → Implementer → UI Refiner (optional) → Data Curator (optional)
                                                    → Item Curator (optional)
                                                    → Art Director (optional)
                                                    → Story Architect (optional)
                                                    → Balancer (optional)
                                                    → Gameplay Guide (optional)
```

1. **Repo Auditor** decides WHAT to build next
2. **Implementer** builds it with tests
3. **UI Refiner** polishes the visual layer (if needed)
4. **Data Curator** extends content (if needed)
5. **Item Curator** updates item manifest and HTML reference (if items changed)
6. **Art Director** tracks visual assets, adds icon_hint descriptions, updates HTML (if needed)
7. **Story Architect** writes narrative content, lore, and campaign arcs (if needed)
8. **Balancer** audits abilities, passives, equipment, and updates balance reference (if needed)
9. **Gameplay Guide** maintains game guide, assists with tutorials (if needed)

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
- "Use the Gameplay Guide agent to update the game guide"

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
| `audit`, `status`, `tech debt`, `milestone`, `architecture` | Repo Auditor |
| `implement`, `build`, `fix bug`, `add feature`, `test` | Implementer |
| `tier`, `economy`, `stat curve` | Balancer |
| `guide`, `tutorial`, `how to play`, `help text`, `tooltip`, `onboarding` | Gameplay Guide |
| `new player`, `walkthrough`, `game flow`, `first time` | Gameplay Guide + Story Architect |

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
