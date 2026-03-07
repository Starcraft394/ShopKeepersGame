## RegionTheme.gd
## Static utility class that derives a UI color palette from region theme/accent hex colors.
## Used by TownScene, CombatScene, and TownHubScene to tint UI per-region.
class_name RegionTheme
extends RefCounted


## Get a derived palette dict from a RegionData object.
## Returns { bg_dark, bg_medium, title_bar, accent, border, theme } — all Color values.
static func get_palette(region_data: RegionData) -> Dictionary:
	if region_data == null:
		return _derive_palette(
			Color.from_string("#4a7a5a", Color.WHITE),
			Color.from_string("#6aaa7a", Color.WHITE)
		)
	var theme_col: Color = Color.from_string(region_data.theme_color, Color.WHITE)
	var accent_col: Color = Color.from_string(region_data.accent_color, Color.WHITE)
	return _derive_palette(theme_col, accent_col)


## Convenience: get palette for the current region from GameContext.
static func get_palette_for_current_region() -> Dictionary:
	var region_id: String = GameContext.get_current_region_id()
	var region_data: RegionData = DataRegistry.get_region(region_id)
	return get_palette(region_data)


## Derive a full palette from two base colors.
## Higher multipliers + lower offsets preserve color distinction between regions.
## Green (#4a7a5a) → cool teal tones. Amber (#7a6040) → warm brown tones.
static func _derive_palette(theme: Color, accent: Color) -> Dictionary:
	return {
		"bg_dark": Color(theme.r * 0.45 + 0.02, theme.g * 0.45 + 0.02, theme.b * 0.45 + 0.03, 1.0),
		"bg_medium": Color(theme.r * 0.6 + 0.03, theme.g * 0.6 + 0.03, theme.b * 0.6 + 0.04, 0.9),
		"title_bar": Color(theme.r * 0.75 + 0.05, theme.g * 0.75 + 0.05, theme.b * 0.75 + 0.06, 0.9),
		"accent": Color(accent.r, accent.g, accent.b, 0.5),
		"border": Color(minf(accent.r * 1.2, 1.0), minf(accent.g * 1.1, 1.0), accent.b * 0.5, 0.9),
		"theme": theme,
		"ui_tint": Color(
			clampf(theme.r * 0.8 + 0.2, 0.0, 1.0),
			clampf(theme.g * 0.8 + 0.2, 0.0, 1.0),
			clampf(theme.b * 0.8 + 0.2, 0.0, 1.0),
			1.0
		),
	}
