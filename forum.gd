extends Node2D

@export var questions:MarginContainer
@export var buttons:MarginContainer

@onready var question1 = $CanvasLayer/UI/Questions/VBoxContainer/Q1Container/Question1
@onready var Q1Answers = $CanvasLayer/UI/Questions/VBoxContainer/Q1Container/VBoxContainer
@onready var question2 = $CanvasLayer/UI/Questions/VBoxContainer/Q2Container/Question2
@onready var Q2Answers = $CanvasLayer/UI/Questions/VBoxContainer/Q2Container/VBoxContainer
@onready var question3 = $CanvasLayer/UI/Questions/VBoxContainer/Q3Container/Question1
@onready var Q3Answers = $CanvasLayer/UI/Questions/VBoxContainer/Q3Container/VBoxContainer
@onready var question4 = $CanvasLayer/UI/Questions/VBoxContainer/Q4Container/Question2
@onready var Q4Answers = $CanvasLayer/UI/Questions/VBoxContainer/Q4Container/VBoxContainer
@onready var question5 = $CanvasLayer/UI/Questions/VBoxContainer/Q5Container/Question2
@onready var Q5Answers = $CanvasLayer/UI/Questions/VBoxContainer/Q5Container/VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func generate_question(shipType, engineType, scenario) -> String:
	if PlayerData.ship_type == PlayerData.ShipType.LOCALORBIT:
		pass
	if PlayerData.ship_type == PlayerData.ShipType.LOCALLANDING:
		pass
	return ""

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
