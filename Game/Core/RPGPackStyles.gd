## RPGPackStyles.gd
## Autoload singleton that provides region-tinted StyleBoxTexture factories.
## Each method returns a duplicate of a base .tres resource with modulate_color applied.
extends Node


const _PANEL_MAIN = preload("res://Themes/RPGPack/panel_main.tres")
const _PANEL_MODAL = preload("res://Themes/RPGPack/panel_modal.tres")
const _BANNER_HEADER = preload("res://Themes/RPGPack/banner_header.tres")
const _BTN_NORMAL = preload("res://Themes/RPGPack/btn_normal.tres")
const _BTN_PRESSED = preload("res://Themes/RPGPack/btn_pressed.tres")
const _BTN_HOVER = preload("res://Themes/RPGPack/btn_hover.tres")
const _SLOT_EMPTY = preload("res://Themes/RPGPack/slot_empty.tres")


static func panel_main(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s: StyleBoxTexture = _PANEL_MAIN.duplicate()
	s.modulate_color = tint
	return s


static func panel_modal(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s: StyleBoxTexture = _PANEL_MODAL.duplicate()
	s.modulate_color = tint
	return s


static func banner_header(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s: StyleBoxTexture = _BANNER_HEADER.duplicate()
	s.modulate_color = tint
	return s


static func btn_normal(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s: StyleBoxTexture = _BTN_NORMAL.duplicate()
	s.modulate_color = tint
	return s


static func btn_pressed(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s: StyleBoxTexture = _BTN_PRESSED.duplicate()
	s.modulate_color = tint
	return s


static func btn_hover(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s: StyleBoxTexture = _BTN_HOVER.duplicate()
	s.modulate_color = tint
	return s


static func slot_empty(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s: StyleBoxTexture = _SLOT_EMPTY.duplicate()
	s.modulate_color = tint
	return s
