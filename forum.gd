extends Node2D

@onready var questions:MarginContainer = $CanvasLayer/UI/Questions
@onready var evaluation:MarginContainer = $CanvasLayer/UI/Evaluation
@onready var reviewSumm:Label = $CanvasLayer/UI/Evaluation/VerticalAlign/ReviewSummary
@onready var question1Result:Label = $CanvasLayer/UI/Evaluation/VerticalAlign/Question1/Result
@onready var question2Result:Label = $CanvasLayer/UI/Evaluation/VerticalAlign/Question2/Result
@onready var question3Result:Label = $CanvasLayer/UI/Evaluation/VerticalAlign/Question3/Result
@onready var question4Result:Label = $CanvasLayer/UI/Evaluation/VerticalAlign/Question4/Result
@onready var question5Result:Label = $CanvasLayer/UI/Evaluation/VerticalAlign/Question5/Result
@onready var submit:Button = $CanvasLayer/UI/Questions/VerticalAlign/QuestionButtons/Position/Submit

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

@onready var Q1Answer = Q1Answers.get_children()[0].button_group.get_pressed_button()
@onready var Q2Answer = Q2Answers.get_children()[0].button_group.get_pressed_button()
@onready var Q3Answer = Q3Answers.get_children()[0].button_group.get_pressed_button()
@onready var Q4Answer = Q4Answers.get_children()[0].button_group.get_pressed_button()
@onready var Q5Answer = Q5Answers.get_children()[0].button_group.get_pressed_button()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var background = PlayerData.background.instantiate()
	add_child(background)
	submit.disabled = true
	# Question Generation
	question1.text = generate_question(PlayerData.MissionConfig.SHIPTYPE, PlayerData.ship_type)
	question2.text = generate_question(PlayerData.MissionConfig.ENGINETYPE, PlayerData.engine_type)
	question3.text = generate_question(PlayerData.MissionConfig.MISSION, PlayerData.scenario)
	question4.text = generate_question(PlayerData.MissionConfig.MAXFUEL, PlayerData.fuel_amount)
	question5.text = generate_question(PlayerData.MissionConfig.INSTRUMENTS, PlayerData.camera_type)

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
			1. What is the primary purpose of
			using Local Orbit ship?
			""")
		elif topic == PlayerData.ShipType.LOCALLANDING:
			# Answer Options Generation
			Q1Answers.get_children()[0].text = "10"
			Q1Answers.get_children()[1].text = "6" # Correct
			Q1Answers.get_children()[2].text = "8"
			Q1Answers.get_children()[3].text = "2"
			return (
			"""
			1. What is the max amount bays a
			local landing ship has?
			""")
		elif topic == PlayerData.ShipType.LONGORBIT:
			# Answer Options Generation
			Q1Answers.get_children()[0].text = "30,000 kg" # Correct
			Q1Answers.get_children()[1].text = "35,000 kg"
			Q1Answers.get_children()[2].text = "60,000 mg"
			Q1Answers.get_children()[3].text = "350,000 mg"
			return (
			"""
			1. What is the basic onboard propellant
			capacity of a Long Orbit ship? 
			""")
		elif topic == PlayerData.ShipType.LONGLANDING:
			# Answer Options Generation
			Q1Answers.get_children()[0].text = "6" # Correct
			Q1Answers.get_children()[1].text = "4"
			Q1Answers.get_children()[2].text = "7"
			Q1Answers.get_children()[3].text = "5"
			return (
			"""
			1. How many Instruments can a Long
			Landing Ship hold?
			""")
	# Generate Engine Type Question
	if configType == PlayerData.MissionConfig.ENGINETYPE:
		print(topic)
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
			Q3Answers.get_children()[0].text = "Light Pollution"
			Q3Answers.get_children()[1].text = "Wildfires" # Correct
			Q3Answers.get_children()[2].text = "Extreme Weather"
			Q3Answers.get_children()[3].text = "Earth's Rotation"
			return (
			"""
			3. You have selected Mission 1. 
			What will you be detecting?
			""")
	# Generate Fuel Type Question
	if configType == PlayerData.MissionConfig.MAXFUEL:
		if topic == 25:
			Q4Answers.get_children()[0].text = "500 kg" # Correct
			Q4Answers.get_children()[1].text = "200 kg"
			Q4Answers.get_children()[2].text = "100 mg"
			Q4Answers.get_children()[3].text = "200 mg"
			return (
			"""
			4. How much does a small 
			fuel tank in a Local Orbit ship hold?
			""")
		elif topic == 50:
			Q4Answers.get_children()[0].text = "15,000 kg"
			Q4Answers.get_children()[1].text = "3,500 kg"
			Q4Answers.get_children()[2].text = "30,000 kg" # Correct
			Q4Answers.get_children()[3].text = "45,000 kg"
			return (
			"""
			4. How much does a medium 
			fuel tank in Long Orbit ship hold?
			""")
		elif topic == 100:
			Q4Answers.get_children()[0].text = "2,500 kg" # Correct
			Q4Answers.get_children()[1].text = "3,000 kg"
			Q4Answers.get_children()[2].text = "6,000 L"
			Q4Answers.get_children()[3].text = "30,000 L"
			return (
			"""
			4. How much does a large
			fuel tank in Local Orbit ship hold?
			""")
	# Generate Instrument/Components Type Question
	if configType == PlayerData.MissionConfig.INSTRUMENTS:
		if topic == PlayerData.Instruments.VISUALCAMERA:
			Q5Answers.get_children()[0].text = "30 GHz"
			Q5Answers.get_children()[1].text = "30 W"
			Q5Answers.get_children()[2].text = "15 GHz"
			Q5Answers.get_children()[3].text = "15 W" # Correct
			return (
			"""
			5. How much power might the 
			visual camera cost?
			""")
		elif topic == PlayerData.Instruments.INFAREDCAMERA:
			Q5Answers.get_children()[0].text = "8 Mb" # Correct
			Q5Answers.get_children()[1].text = "80 Mb"
			Q5Answers.get_children()[2].text = "2 Mb"
			Q5Answers.get_children()[3].text = "8 Gb"
			return (
			"""
			5. What is the speed at which 
			the Infared Camera transmits data?
			""")
	return "No Question"
# Called every frame. 'delta' is the elapsed time since the previous frame.


func _process(delta: float) -> void:
	Q1Answer = Q1Answers.get_children()[0].button_group.get_pressed_button()
	Q2Answer = Q2Answers.get_children()[0].button_group.get_pressed_button()
	Q3Answer = Q3Answers.get_children()[0].button_group.get_pressed_button()
	Q4Answer = Q4Answers.get_children()[0].button_group.get_pressed_button()
	Q5Answer = Q5Answers.get_children()[0].button_group.get_pressed_button()
	if (Q1Answer != null and Q2Answer != null and Q3Answer != null and Q4Answer != null and Q5Answer != null):
		submit.disabled = false

func start_review() -> void:
	print("Starting review..")
	questions.hide()
	evaluation.show()
	var total = 0.0
	var score = 0.0
	if (Q1Answer.text == "Nearby orbital observation" or
		Q1Answer.text == "6" or
		Q1Answer.text == "30,000kg"):
		total += 1
		question1Result.text = "Passed"
	else:
		question1Result.text = "Failed"
	if (Q2Answer.text == "banana"):
		total += 1
		question2Result.text = "Passed"
	else:
		question2Result.text = "Failed"
	if (Q3Answer.text == "Wildfires"):
		total += 1
		question3Result.text = "Passed"
	else:
		question3Result.text = "Failed"
	if (Q4Answer.text == "500 kg" or 
		Q4Answer.text == "30,000 kg" or 
		Q4Answer.text == "2,500 kg"):
		total += 1
		question4Result.text = "Passed"
	else:
		question4Result.text = "Failed"
	if (Q5Answer.text == "15 W" or
		Q5Answer.text == "8 Mb"):
		total += 1
		question5Result.text = "Passed"
	else:
		question5Result.text = "Failed"
	score = round((total/6)*100)
	reviewSumm.text = str(score)

func _on_back_pressed() -> void:
	print("Back pressed!")
	get_tree().change_scene_to_packed(PlayerData.mission_design_scene)


func _on_submit_pressed() -> void:
	print("Submit pressed!")
	start_review()


func _on_retry_pressed() -> void:
	print("Retry pressed")
	evaluation.hide()
	questions.show()

func _on_continue_pressed() -> void:
	print("Continue pressed")
