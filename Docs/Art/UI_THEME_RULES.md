# UI Theme Rules — Single Source of Truth

> CraftPix-based UI theme standards for all new screens.
> Existing production scenes (`game_theme.tres`) are not affected.

---

## 1. Theme Selection

| Theme File | Usage |
|---|---|
| `craftpix_ui_tinted.tres` | **Default for all new UI screens** |
| `craftpix_ui.tres` | Raw/untinted variant — debug, A/B comparison only |
| `game_theme.tres` | Legacy production scenes — do NOT modify |

## 2. Theme Propagation

- Assign theme **only on the root Control** of each screen scene.
- All children inherit automatically — no per-node `theme_override_styles` needed for:
  - `PanelContainer` panels (inherits `panel_wood_dark`)
  - `Button` styles (inherits primary normal/hover/pressed/disabled)
  - `Label` / `RichTextLabel` colors (inherits warm cream)
- **Per-node overrides allowed** for these alternates only:

| Resource | Use Case |
|---|---|
| `panel_wood_medium.tres` | All-wood panels (no beige interior) — nav rails, grid backgrounds |
| `slot_inventory.tres` | Inventory grid cells |
| `icon_frame.tres` | Item/ability icon display frames |
| `header_bar_teal_tinted.tres` | Section header strips |
| `header_bar_teal.tres` | Untinted header strip (rare) |

## 3. Pixel Import Rules

All CraftPix sprite sheets (`Assets/UI/CraftPix/`):
- **Texture Filter**: OFF (nearest-neighbor, no bilinear)
- **Mipmaps**: OFF
- **Compression**: Lossless or uncompressed

Do NOT modify source PNGs. All slicing uses `AtlasTexture` regions in `.tres` files.

## 4. Layout Doctrine

**Principle**: Tactical readability first, minimal clutter.

### Standard Spacing Values

| Name | Value | Usage |
|---|---|---|
| Screen edge padding | `16px` | Offset from viewport edges to main layout |
| Section gap | `12px` | Between major layout panels (HBox/VBox separation) |
| Element gap | `8px` | Within sections (buttons, labels, sub-panels) |
| Grid cell gap | `2px` | Between inventory/slot grid cells |

### Standard Sizes

| Element | Size |
|---|---|
| Inventory slot | `36x36` (compact) or `40x40` (standard) |
| Header bar height | `28px` minimum |
| Button height | `36px` standard, `28px` compact |
| Nav rail width | `160px` minimum |

### Structure Pattern
```
Root Control (theme assigned here)
  ColorRect (background: Color(0.15, 0.15, 0.2, 1))
  HBoxContainer (screen edge padding via offsets, separation=12)
    [Nav Rail / Left Panel]
    [Content Panel / Right Panel]
```

Use `header_bar_teal_tinted` at the top of each major panel as a section title bar.

## 5. Inventory Grid Rules

- Wrap grid in `PanelContainer` with `panel_wood_medium` override (warm wood background)
- Inside: `MarginContainer` (8px all sides) > `GridContainer`
- Each slot: `PanelContainer` with `slot_inventory` override
- Grid columns: 4 (compact), 6 (medium), 8 (wide)
- Cell gap: 2px (`h_separation` and `v_separation`)

## 6. Color Doctrine

| Color Role | Meaning |
|---|---|
| Teal header bars | Navigation / section boundaries |
| Green buttons (theme default) | Confirm / primary action |
| Warm cream text `(0.96, 0.91, 0.82)` | Default readable text |
| Gold text `(0.96, 0.87, 0.7)` | Section titles, emphasis |
| Gray text `(0.7, 0.7, 0.75)` | Subtitle, secondary info |
| Dark background `(0.15, 0.15, 0.2)` | Screen fill behind panels |

Do NOT add new decorative colors without a defined semantic role.

## 7. File Placement Rules

| What | Where |
|---|---|
| New UI scenes | `Game/UI/<Feature>/<Feature>Scene.tscn` |
| Scene scripts | Same folder, same name: `<Feature>Scene.gd` |
| Theme resources | `Themes/CraftPix/*.tres` |
| CraftPix source PNGs | `Assets/UI/CraftPix/` (read-only, never duplicate) |
| Demo/showcase scenes | `Game/UI/Demos/` |
| Kenney assets | `Assets/UI/Kenney/` (unchanged, not referenced by new screens) |

### Naming Conventions
- Scenes: `PascalCase` + `Scene` suffix (e.g., `ShopScene.tscn`)
- Scripts: Match scene name exactly (e.g., `ShopScene.gd`)
- Theme resources: `snake_case` (e.g., `panel_wood_dark.tres`)

---

## References

- Slicing details: `Themes/CraftPix/SLICING_REFERENCE.md`
- Art direction: `Docs/Art/ART_DIRECTION_MASTER.md`
- CraftPix attribution: `Docs/Attribution/ATTRIBUTION.md`
