extends Node2D

@onready var start_button: MarginContainer = $CanvasLayer/UI/StartButtonMargin
@onready var mission_select: MarginContainer = $CanvasLayer/UI/MissionSelectButtonsMargin
@onready var mission_conf: MarginContainer = $CanvasLayer/UI/MissionConfirmationMargin
@onready var mission_conf_button: Button = $CanvasLayer/UI/MissionConfirmationMargin/VBoxContainer/HBoxContainer/AcceptMissionButton
@onready var mission_summ: RichTextLabel = $CanvasLayer/UI/MissionConfirmationMargin/VBoxContainer/MissionSummary
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var background = PlayerData.background.instantiate()
	add_child(background)
	start_button.show()
	mission_select.hide()
	mission_conf.hide()


func show_mission_summary():
	mission_conf.show()
	match PlayerData.scenario:
		PlayerData.Scenario.MISSION_1:
			mission_summ.text = "Mission 1: Low-Earth Orbit Wildfire Detection"
			mission_conf_button.show()
		PlayerData.Scenario.MISSION_2:
			mission_summ.text = "Mission 2 coming soon."
			mission_conf_button.hide()
		PlayerData.Scenario.MISSION_3:
			mission_summ.text = "Mission 3 coming soon."
			mission_conf_button.hide()
		

func hide_mission_summary():
	mission_conf.hide()

func _on_start_button_pressed() -> void:
	start_button.hide()
	mission_select.show()


func _on_mission_1_pressed() -> void:
	mission_select.hide()
	PlayerData.scenario = PlayerData.Scenario.MISSION_1
	show_mission_summary()
	


func _on_mission_2_pressed() -> void:
	mission_select.hide()
	PlayerData.scenario = PlayerData.Scenario.MISSION_2
	show_mission_summary()

func _on_mission_3_pressed() -> void:
	mission_select.hide()
	PlayerData.scenario = PlayerData.Scenario.MISSION_3
	show_mission_summary()


func _on_back_button_pressed() -> void:
	hide_mission_summary()
	mission_select.show()


func _on_accept_mission_button_pressed() -> void:
	get_tree().change_scene_to_packed(PlayerData.mission_design_scene)
