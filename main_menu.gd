extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide_mission_buttons()
	hide_mission_summary()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func hide_mission_buttons():
	$Mission1.hide()
	$Mission2.hide()
	$Mission3.hide()

func show_mission_buttons():
	$Mission1.show()
	$Mission2.show()
	$Mission3.show()

func show_mission_summary():
	$MissionSummary.show()
	match PlayerData.scenario:
		PlayerData.Scenario.MISSION_1:
			$MissionSummary.text = "This is the Mission 1 Summary"
		PlayerData.Scenario.MISSION_2:
			$MissionSummary.text = "This is the Mission 2 Summary"
		PlayerData.Scenario.MISSION_3:
			$MissionSummary.text = "This is the Mission 3 Summary"
		

func hide_mission_summary():
	$MissionSummary.hide()

func _on_new_game_button_pressed() -> void:
	$NewGameButton.hide()
	show_mission_buttons()


func _on_mission_1_pressed() -> void:
	hide_mission_buttons()
	PlayerData.scenario = PlayerData.Scenario.MISSION_1
	show_mission_summary()
	


func _on_mission_2_pressed() -> void:
	hide_mission_buttons()
	PlayerData.scenario = PlayerData.Scenario.MISSION_2
	show_mission_summary()

func _on_mission_3_pressed() -> void:
	hide_mission_buttons()
	PlayerData.scenario = PlayerData.Scenario.MISSION_3
	show_mission_summary()


func _on_back_button_pressed() -> void:
	hide_mission_summary()
	show_mission_buttons()


func _on_accept_mission_button_pressed() -> void:
	get_tree().change_scene_to_packed(PlayerData.mission_design_scene)
