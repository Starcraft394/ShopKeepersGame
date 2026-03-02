## IntroCutscene.gd
## Thin wrapper: loads intro cutscene JSON into CutscenePlayer,
## handles post-cutscene flag + scene transition.
extends Control

const CUTSCENE_DATA_PATH := "res://Data/Cutscenes/intro_cutscene.json"
const TOWN_HUB_PATH := "res://Game/UI/TownHub/TownHubScene.tscn"


func _ready() -> void:
	var player := CutscenePlayer.new()
	if not player.load_from_json(CUTSCENE_DATA_PATH):
		print("[Cutscene] Failed to load intro cutscene data — skipping to town")
		player.queue_free()
		_finish_cutscene()
		return
	player.set_final_button_text("Begin")
	player.cutscene_finished.connect(_finish_cutscene)
	add_child(player)
	# Start BGM
	UIAudio.play_bgm("intro_cutscene")
	print("[Cutscene] Intro cutscene started")


func _finish_cutscene() -> void:
	GameContext.set_campaign_flag("shown_intro_cutscene")
	GameContext.save_game()
	print("[Cutscene] Intro cutscene finished — transitioning to TownHub")
	SceneTransition.fade_to(TOWN_HUB_PATH)
