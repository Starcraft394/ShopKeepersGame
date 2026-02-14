# CraftPix UI Primitives — Slicing Reference

> Source pack: `res://Assets/UI/CraftPix/Free_Basic_Pixel_UI_RPG/PNG/`
> Created: 2026-02-12

## Region Map

All regions below are `Rect2(x, y, width, height)` in pixels.

### Panels (Main_tiles.png — 384x304)

| Resource | Region | Size | NinePatch (T,B,L,R) | Description |
|----------|--------|------|---------------------|-------------|
| `panel_wood_dark.tres` | (5, 96, 38, 37) | 38x37 | 14, 6, 6, 6 | Brown header + beige body, drop shadow |
| `panel_wood_medium.tres` | (101, 96, 38, 37) | 38x37 | 14, 6, 6, 6 | All-wood body (no beige), drop shadow |
| `icon_frame.tres` | (11, 0, 26, 37) | 26x37 | 8, 6, 5, 5 | Small panel frame for icon slots |

Panel structure (from ASCII scan):
- y+0: Shadow top (1px transparent corners, dark outline)
- y+1..12: Header area (wood or green title bar, 12px)
- y+13..14: Frame transition (2px)
- y+15..30: Interior (beige fill or wood fill)
- y+31..34: Bottom frame (4px)
- y+35..36: Shadow bottom (2px)

### Buttons (Buttons.png — 400x528)

| Resource | Region | Size | NinePatch (T,B,L,R) | Description |
|----------|--------|------|---------------------|-------------|
| `btn_primary_normal.tres` | (3, 96, 46, 16) | 46x16 | 4, 4, 6, 6 | Green button, normal state |
| `btn_primary_hover.tres` | (98, 96, 46, 16) | 46x16 | 4, 4, 6, 6 | Green button, hover state |
| `btn_primary_pressed.tres` | (3, 112, 46, 16) | 46x16 | 4, 4, 6, 6 | Green button, pressed state |

Button layout in Buttons.png:
- Row y=96-111: States 1 & 2 (columns at x~3 and x~98)
- Row y=112-127: States 3 & 4 (same column positions)
- Buttons are untexted green pill shapes, suitable for 9-slice stretching

### Inventory Slot (Inventory.png — 336x160)

| Resource | Region | Size | NinePatch (T,B,L,R) | Description |
|----------|--------|------|---------------------|-------------|
| `slot_inventory.tres` | (176, 32, 16, 16) | 16x16 | 2, 2, 2, 2 | Warm beige grid cell |

## Modulate Tint

Panel and slot resources use `modulate_color = Color(0.75, 0.72, 0.68, 1.0)` to darken
the warm CraftPix palette for our dark UI background (#262633).

Button resources are NOT tinted (green on dark already reads well).

## Tuning Guide

If regions are off by a few pixels, edit the `region` property in the .tres file:
1. Open the .tres in Godot Inspector
2. Click the AtlasTexture sub-resource
3. Adjust `region` Rect2 visually in the atlas preview
4. Adjust `texture_margin_*` if the 9-slice corners change size

## Additional Regions Available

These regions were identified but not yet extracted as resources:

| Source | Region | Description |
|--------|--------|-------------|
| Main_tiles.png | (197, 96, 38, 37) | Green/teal title bar panel (for headers) |
| Main_tiles.png | (7, 48, 34, 37) | Medium-size brown panel variant |
| Main_tiles.png | (0, 288, 128, 16) | Teal horizontal bar (for separators) |
| Buttons.png | (14, 12, 20, 22) | Small square button (normal) |
| Buttons.png | (110, 12, 20, 22) | Small square button (hover) |
| Inventory.png | (7, 0, 93, 128) | Full closed inventory panel |
| Inventory.png | (120, 0, 209, 128) | Full open inventory panel |
