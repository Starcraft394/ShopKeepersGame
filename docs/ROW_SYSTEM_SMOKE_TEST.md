# Row System Smoke Test (Phase 1)

Manual verification checklist for the 3-Row Formation System.

---

## Default Behavior

- [ ] New hero defaults to Middle (row 1)
- [ ] Hero with no saved row defaults to Middle
- [ ] Row indicator shows `[M]` in combat for default heroes

---

## Assignment Persistence

- [ ] Change hero to Front → Save → Reload → remains Front
- [ ] Change hero to Back → Save → Reload → remains Back
- [ ] Old save file (no `hero_row_assignments` key) loads all heroes into Middle

---

## Targeting Priority (Melee)

- [ ] If Front row has alive unit → melee targets Front first
- [ ] If Front empty → melee targets Middle
- [ ] If Front + Middle empty → melee targets Back
- [ ] Ranged targeting ignores row (targets lowest HP)

---

## UI Consistency

- [ ] Inn dropdown reflects stored row on panel open
- [ ] Inn dropdown updates GameContext immediately on change
- [ ] Combat row indicator `[F]`/`[M]`/`[B]` matches actual unit row
- [ ] Row indicator matches targeting behavior

---

## Edge Cases

- [ ] Hero removed from party retains row assignment
- [ ] Hero re-added to party uses previously saved row
- [ ] Multiple heroes can share the same row

---

*Last updated: Phase 1 implementation*
