## BossCutsceneManager.gd
## Static helper for showing boss cutscenes with flag gating.
## Usage: var player = BossCutsceneManager.try_show(self, "boss_entry")
##        if player != null: await player.cutscene_finished
class_name BossCutsceneManager
extends RefCounted


## Try to show a boss cutscene for the current region.
## Returns the CutscenePlayer node or null if no cutscene / already shown.
static func try_show(caller: Node, trigger_type: String, region_id: String = "") -> CutscenePlayer:
	if region_id == "":
		region_id = GameContext.get_current_region_id()

	var cutscene: BossCutsceneData = DataRegistry.get_boss_cutscene(region_id, trigger_type)
	if cutscene == null:
		return null

	# Flag gating: if once_only and already shown, skip
	if cutscene.once_only and cutscene.flag_set != "":
		if GameContext.has_campaign_flag(cutscene.flag_set):
			return null

	# Create CutscenePlayer and load panels
	var player := CutscenePlayer.new()
	if not player.load_panels(cutscene.panels, cutscene.bgm):
		player.queue_free()
		return null

	# Boss cutscenes are short — always show skip
	player.set_always_show_skip(true)
	player.set_final_button_text("Close")

	# Connect flag setting on finish
	if cutscene.flag_set != "":
		player.cutscene_finished.connect(func():
			GameContext.set_campaign_flag(cutscene.flag_set)
			GameContext.save_game()
			print("[BossCutscene] Flag set: %s" % cutscene.flag_set)
		)

	caller.add_child(player)
	print("[BossCutscene] Showing %s for %s (boss=%s)" % [trigger_type, region_id, cutscene.boss_id])
	return player
