# CraftPix Free Basic Pixel Art UI for RPG — Asset Index

> Pack source: https://craftpix.net/freebies/free-basic-pixel-art-ui-for-rpg/
> Integration date: 2026-02-12

## PNG Sprite Sheets

All assets are sprite sheets (not individual slices). They must be sliced into
AtlasTexture regions or NinePatchRect sources before use in Godot UI.

| File | Contents | Key Elements |
|------|----------|--------------|
| `Main_tiles.png` | Panel frames, window borders, 9-slice sources | Wood panels (3 color variants), title bars, corner pieces, dividers, scrollbar parts |
| `Buttons.png` | Button states + text labels | Normal/hover/pressed/disabled for multiple button sizes, menu buttons (Resume, Settings, Levels, Inventory, Equipment, Shop, Craft, Quit), arrows, checkboxes, radio buttons |
| `Icons.png` | RPG item/action icons | Stars, gems, arrows, swords, shields, potions, hearts, keys, scrolls, helmets, tools (~70 icons) |
| `Inventory.png` | Inventory panel composites | Open/closed states, grid slots, item icons, close button |
| `Equipment.png` | Equipment panel composites | Paper doll silhouette, gear slots, grid view, character preview |
| `Shop.png` | Shop panel composites | Buy buttons, price displays, item grid, shop window frames |
| `Craft.png` | Crafting panel composites | 3 color variants, recipe slots, result slot, create button, mortar/pestle icons |
| `character_panel.png` | Character HP/MP bars | Portrait frame, health bar (multi-color states), mana bar, mini portraits |
| `Action_panel.png` | Ability/action bar | Horizontal slot bar, action slot frames, elemental icons |
| `Settings.png` | Settings panel | Toggle switches, sliders, dropdown frames, save/decline buttons |
| `Circle_menu.png` | Radial menu | Circular menu segments for quick-access |
| `Main_menu.png` | Main menu layout | Title screen frame, menu button arrangement |
| `Levels.png` | Level select UI | Level nodes, progress paths, star ratings |
| `Win_loose.png` | Victory/defeat screens | Win/lose panel frames, reward displays |
| `Numbers.png` | Numeric font sprites | Pixel number glyphs for damage/score display |
| `Numbers_levels.png` | Level number sprites | Styled number glyphs for level indicators |
| `Text1.png` | Text label sprites | Pre-rendered text labels (set 1) |
| `Text2.png` | Text label sprites | Pre-rendered text labels (set 2) |
| `Decorative_cracks.png` | Decorative overlays | Crack/damage overlays for worn panel effects |

## PSD Source Files

13 PSD files with separated layers for: Main_tiles, Buttons, Icons, Inventory,
Equipment, Shop, Craft, character_panel, Settings, Circle_menu, Main_menu,
Levels, Win_loose.

PSD folder has `.gdignore` — Godot will not import these.

## 9-Slice Notes

`Main_tiles.png` contains the primary 9-slice panel sources. The wood panels
appear in 3 color variants (light, medium, dark brown) at multiple sizes.

Recommended extraction for Godot NinePatchRect:
- Identify a single panel frame (e.g., medium brown, ~48x48 or 64x64)
- Create AtlasTexture with the region rect
- Apply as NinePatchRect texture with ~4-8px patch margins

## Color Palette Summary

The pack uses a warm earth-tone palette:
- **Panel wood:** Light tan (#D4B87A), Medium brown (#A67C52), Dark brown (#6B4226)
- **Accent green:** Muted teal-green (#5B8C5A) for buttons and highlights
- **Title bar:** Green-teal header strips
- **Text:** Dark brown on light panels
- **Grid slots:** Warm beige (#C4A96A) for inventory/equipment cells
