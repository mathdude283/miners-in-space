extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CanvasLayer/UI/StartButtonMargin.show()
	hide_mission_buttons()
	hide_mission_summary()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func hide_mission_buttons():
	$CanvasLayer/UI/MissionSelectButtonsMargin.hide()

func show_mission_buttons():
	$CanvasLayer/UI/MissionSelectButtonsMargin.show()

func show_mission_summary():
	$CanvasLayer/UI/MissionConfirmationMargin.show()
	match PlayerData.scenario:
		PlayerData.Scenario.MISSION_1:
			$CanvasLayer/UI/MissionConfirmationMargin/VBoxContainer/MissionSummary.text = "This is the Mission 1 Summary"
		PlayerData.Scenario.MISSION_2:
			$CanvasLayer/UI/MissionConfirmationMargin/VBoxContainer/MissionSummary.text = "This is the Mission 2 Summary"
		PlayerData.Scenario.MISSION_3:
			$CanvasLayer/UI/MissionConfirmationMargin/VBoxContainer/MissionSummary.text = "This is the Mission 3 Summary"
		

func hide_mission_summary():
	$CanvasLayer/UI/MissionConfirmationMargin.hide()

func _on_start_button_pressed() -> void:
	$CanvasLayer/UI/StartButtonMargin.hide()
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


func _on_mission_select_button_pressed() -> void:
	$CanvasLayer/MissionSelectButton.hide()
	show_mission_buttons()
