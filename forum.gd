extends Node2D

@export var questions:MarginContainer

@onready var submit:Button = $CanvasLayer/UI/Buttons/HBoxContainer/Submit
@onready var back:Button = $CanvasLayer/UI/Buttons/HBoxContainer/Back
@onready var question1:Label = $"CanvasLayer/UI/Questions/VerticalAlign"/Q1Container/Question1
@onready var Q1Answers:VBoxContainer = $CanvasLayer/UI/Questions/VerticalAlign/Q1Container/AnswerContainer
@onready var question2:Label = $CanvasLayer/UI/Questions/VerticalAlign/Q2Container/Question2
@onready var Q2Answers:VBoxContainer = $CanvasLayer/UI/Questions/VerticalAlign/Q2Container/AnswerContainer
@onready var question3:Label = $CanvasLayer/UI/Questions/VerticalAlign/Q3Container/Question3
@onready var Q3Answers:VBoxContainer = $CanvasLayer/UI/Questions/VerticalAlign/Q3Container/AnswerContainer
@onready var question4:Label = $CanvasLayer/UI/Questions/VerticalAlign/Q4Container/Question4
@onready var Q4Answers:VBoxContainer = $CanvasLayer/UI/Questions/VerticalAlign/Q4Container/AnswerContainer
@onready var question5:Label = $CanvasLayer/UI/Questions/VerticalAlign/Q5Container/Question5
@onready var Q5Answers:VBoxContainer = $CanvasLayer/UI/Questions/VerticalAlign/Q5Container/AnswerContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	submit.disabled = true
	# Question Generation
	question1.text = generate_question(PlayerData.MissionConfig.SHIPTYPE, PlayerData.ShipType.LOCALORBIT)
	question2.text = generate_question(PlayerData.MissionConfig.ENGINETYPE, PlayerData.EngineType.SOLIDSMALL)
	question3.text = generate_question(PlayerData.MissionConfig.MISSION, PlayerData.Scenario.MISSION_1)
	question4.text = generate_question(PlayerData.MissionConfig.MAXFUEL, PlayerData.MaxFuel.SMALL)
	question5.text = generate_question(PlayerData.MissionConfig.INSTRUMENTS, PlayerData.Instruments.VISUALCAMERA)
	
# Generate question based on a topic using PlayerData
func generate_question(configType, topic) -> String:
	# Generate Ship Type Question
	if configType == PlayerData.MissionConfig.SHIPTYPE:
		if topic == PlayerData.ShipType.LOCALORBIT:
			# Answer Options Generation
			Q1Answers.get_children()[0].text = "Probe/Lander delivery"
			Q1Answers.get_children()[1].text = "Nearby surface exploration"
			Q1Answers.get_children()[2].text = "Nearby orbital observation" # Correct
			Q1Answers.get_children()[3].text = "Long distance exploration"
			return (
			"""
			What is the primary purpose of
			using local orbit ship?
			""")
		elif topic == PlayerData.ShipType.LOCALLANDING:
			# Answer Options Generation
			Q1Answers.get_children()[0].text = "10"
			Q1Answers.get_children()[1].text = "6" # Correct
			Q1Answers.get_children()[2].text = "8"
			Q1Answers.get_children()[3].text = "2"
			return (
			"""
			How many bays does a local landing ship contain?
			""")
		elif topic == PlayerData.ShipType.LONGORBIT:
			# Answer Options Generation
			Q1Answers.get_children()[0].text = "bananana"
			Q1Answers.get_children()[1].text = "banana"
			Q1Answers.get_children()[2].text = "nanana"
			Q1Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hello
			""")
		elif topic == PlayerData.ShipType.LONGLANDING:
			# Answer Options Generation
			Q1Answers.get_children()[0].text = "bananana"
			Q1Answers.get_children()[1].text = "banana"
			Q1Answers.get_children()[2].text = "nanana"
			Q1Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hello
			""")
	# Generate Engine Type Question
	if configType == PlayerData.MissionConfig.ENGINETYPE:
		if topic == PlayerData.EngineType.SOLIDSMALL:
			# Answer Options Generation
			Q2Answers.get_children()[0].text = "bananana"
			Q2Answers.get_children()[1].text = "banana"
			Q2Answers.get_children()[2].text = "nanana"
			Q2Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Good Day
			""")
		elif topic == PlayerData.EngineType.SOLIDMEDIUM:
			Q2Answers.get_children()[0].text = "bananana"
			Q2Answers.get_children()[1].text = "banana"
			Q2Answers.get_children()[2].text = "nanana"
			Q2Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Good Day
			""")
		elif topic == PlayerData.EngineType.SOLIDLARGE:
			Q2Answers.get_children()[0].text = "bananana"
			Q2Answers.get_children()[1].text = "banana"
			Q2Answers.get_children()[2].text = "nanana"
			Q2Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Good Day
			""")
		elif topic == PlayerData.EngineType.LIQUIDSMALL:
			Q2Answers.get_children()[0].text = "bananana"
			Q2Answers.get_children()[1].text = "banana"
			Q2Answers.get_children()[2].text = "nanana"
			Q2Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Good Day
			""")
		elif topic == PlayerData.EngineType.LIQUIDMEDIUM:
			Q2Answers.get_children()[0].text = "bananana"
			Q2Answers.get_children()[1].text = "banana"
			Q2Answers.get_children()[2].text = "nanana"
			Q2Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Good Day
			""")
		elif topic == PlayerData.EngineType.LIQUIDLARGE:
			Q2Answers.get_children()[0].text = "bananana"
			Q2Answers.get_children()[1].text = "banana"
			Q2Answers.get_children()[2].text = "nanana"
			Q2Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Good Day
			""")
	# Generate Scenario Type Question
	if configType == PlayerData.MissionConfig.MISSION:
		if topic == PlayerData.Scenario.MISSION_1:
			Q3Answers.get_children()[0].text = "bananana"
			Q3Answers.get_children()[1].text = "banana"
			Q3Answers.get_children()[2].text = "nanana"
			Q3Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hi
			""")
		elif topic == PlayerData.Scenario.MISSION_2:
			Q3Answers.get_children()[0].text = "bananana"
			Q3Answers.get_children()[1].text = "banana"
			Q3Answers.get_children()[2].text = "nanana"
			Q3Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hi
			""")
		elif topic == PlayerData.Scenario.MISSION_3:
			Q3Answers.get_children()[0].text = "bananana"
			Q3Answers.get_children()[1].text = "banana"
			Q3Answers.get_children()[2].text = "nanana"
			Q3Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hi
			""")
	# Generate Fuel Type Question
	if configType == PlayerData.MissionConfig.MAXFUEL:
		if topic == PlayerData.MaxFuel.SMALL:
			Q4Answers.get_children()[0].text = "bananana"
			Q4Answers.get_children()[1].text = "banana"
			Q4Answers.get_children()[2].text = "nanana"
			Q4Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hey
			""")
		elif topic == PlayerData.MaxFuel.MEDIUM:
			Q4Answers.get_children()[0].text = "bananana"
			Q4Answers.get_children()[1].text = "banana"
			Q4Answers.get_children()[2].text = "nanana"
			Q4Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hey
			""")
		elif topic == PlayerData.MaxFuel.LARGE:
			Q4Answers.get_children()[0].text = "bananana"
			Q4Answers.get_children()[1].text = "banana"
			Q4Answers.get_children()[2].text = "nanana"
			Q4Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Hey
			""")
	# Generate Instrument/Components Type Question
	if configType == PlayerData.MissionConfig.INSTRUMENTS:
		if topic == PlayerData.Instruments.VISUALCAMERA:
			Q5Answers.get_children()[0].text = "bananana"
			Q5Answers.get_children()[1].text = "banana"
			Q5Answers.get_children()[2].text = "nanana"
			Q5Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Ello
			""")
		elif topic == PlayerData.Instruments.INFAREDCAMERA:
			Q5Answers.get_children()[0].text = "bananana"
			Q5Answers.get_children()[1].text = "banana"
			Q5Answers.get_children()[2].text = "nanana"
			Q5Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Ello
			""")
		elif topic == PlayerData.Instruments.RADARSAR:
			Q5Answers.get_children()[0].text = "bananana"
			Q5Answers.get_children()[1].text = "banana"
			Q5Answers.get_children()[2].text = "nanana"
			Q5Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Ello
			""")
		elif topic == PlayerData.Instruments.SPECTROMETER:
			Q5Answers.get_children()[0].text = "bananana"
			Q5Answers.get_children()[1].text = "banana"
			Q5Answers.get_children()[2].text = "nanana"
			Q5Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Ello
			""")
		elif topic == PlayerData.Instruments.MAGNETOMETER:
			Q5Answers.get_children()[0].text = "bananana"
			Q5Answers.get_children()[1].text = "banana"
			Q5Answers.get_children()[2].text = "nanana"
			Q5Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Ello
			""")
		elif topic == PlayerData.Instruments.PROBE:
			Q5Answers.get_children()[0].text = "bananana"
			Q5Answers.get_children()[1].text = "banana"
			Q5Answers.get_children()[2].text = "nanana"
			Q5Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Ello
			""")
		elif topic == PlayerData.Instruments.ALTIMETER:
			Q5Answers.get_children()[0].text = "bananana"
			Q5Answers.get_children()[1].text = "banana"
			Q5Answers.get_children()[2].text = "nanana"
			Q5Answers.get_children()[3].text = "naaaa"
			return (
			"""
			Ello
			""")
	return "No Question"
# Called every frame. 'delta' is the elapsed time since the previous frame.


func _process(delta: float) -> void:
	var Q1Answer = Q1Answers.get_children()[0].button_group.get_pressed_button()
	var Q2Answer = Q2Answers.get_children()[0].button_group.get_pressed_button()
	var Q3Answer = Q3Answers.get_children()[0].button_group.get_pressed_button()
	var Q4Answer = Q4Answers.get_children()[0].button_group.get_pressed_button()
	var Q5Answer = Q5Answers.get_children()[0].button_group.get_pressed_button()
	if (Q1Answer != null and Q2Answer != null and Q3Answer != null and Q4Answer != null and Q5Answer != null):
		submit.disabled = false


func _on_back_pressed() -> void:
	print("Back pressed!")
	get_tree().change_scene_to_packed(PlayerData.mission_design_scene)


func _on_submit_pressed() -> void:
	print("Submit pressed!")
