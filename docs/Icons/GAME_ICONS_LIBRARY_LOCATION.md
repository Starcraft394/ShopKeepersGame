# Game-icons.net SVG Library Location

The game-icons.net SVG bundle (4170 icons) has been moved **outside** the Godot project to prevent Godot from importing thousands of unused SVGs.

## External Location

```
C:\Users\rober\OneDrive\ShopKeepers External\GameIcons\
```

### Contents

| Path | Description |
|------|-------------|
| `extracted/` | Unzipped SVG bundle |
| `extracted/icons/ffffff/000000/1x1/{author}/` | SVG icons by author |
| `game-icons.net.svg.zip` | Original download |

## Why Moved Outside Project

- Godot was importing ~4000 SVG files into `.import/`
- This bloated the import cache and slowed editor startup
- Only 8 final PNG icons are actually used in the game
- The SVG source library is only needed when adding new icons

## DevTools Scripts

The following scripts reference the external library:

- `DevTools/select_game_icons.gd` - Scans SVGs and selects best matches
- `DevTools/convert_icons.gd` - Converts selected SVGs to 32x32 PNGs

Both scripts use the `BASE_PATH` constant pointing to the external location.

### Environment Variable Override

You can override the library path by setting:

```powershell
$env:GAMEICONS_DIR = "D:\MyPath\GameIcons\extracted"
```

If the environment variable is not set, scripts fall back to the default path.

## Re-downloading the Bundle

If you need to re-download the icon bundle:

1. Visit https://game-icons.net/archives/svg/zip/game-icons.net.svg.zip
2. Extract to `C:\Users\rober\OneDrive\ShopKeepers External\GameIcons\extracted\`
3. Verify structure: `extracted/icons/ffffff/000000/1x1/{author}/{icon}.svg`

## License

All game-icons.net icons are CC BY 3.0. See `Docs/Attribution/GAME_ICONS_ATTRIBUTION.md` for per-icon attribution.
