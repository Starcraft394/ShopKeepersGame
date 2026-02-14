# ShopKeepers Game — Agent Definitions

This directory contains agent prompts for structured Claude Code workflows.

## Agent Orchestration Pattern

The recommended workflow order is:

```
Repo Auditor → Implementer → UI Refiner (optional) → Data Curator (optional)
                                                    → Art Director (optional)
```

1. **Repo Auditor** decides WHAT to build next
2. **Implementer** builds it with tests
3. **UI Refiner** polishes the visual layer (if needed)
4. **Data Curator** extends content (if needed)
5. **Art Director** tracks and integrates visual assets (if needed)

## Available Agents

| Agent | File | Purpose |
|-------|------|---------|
| Repo Auditor | `repo-auditor.md` | Scan repo, assess state, propose next milestone |
| Implementer | `implementer.md` | Test-driven implementation, minimal diffs |
| UI Refiner | `ui-refiner.md` | Visual cleanup, theme consistency |
| Data Curator | `data-curator.md` | JSON validation, content extension |
| Art Director | `art-director.md` | Art asset tracking, integration, consistency |

## Usage

Copy the System Prompt from the relevant agent file when starting a new task.

Or reference the agent by saying:
- "Use the Repo Auditor agent to assess current state"
- "Use the Implementer agent to build [feature]"
- "Use the UI Refiner agent to clean up [panel]"
- "Use the Data Curator agent to add [item/monster]"
- "Use the Art Director agent to integrate art for [feature]"

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
