extends Node


enum ShipType { LOCALORBIT, LOCALLANDING, LONGORBIT, LONGLANDING }
enum EngineType { SOLIDSMALL, SOLIDMEDIUM, SOLIDLARGE, LIQUIDSMALL, LIQUIDMEDIUM, LIQUIDLARGE }
enum Scenario { MISSION_1, MISSION_2, MISSION_3 }
var fuel_amount = 0
var scenario = null
var mission_summaries = ["This is the mission 1 summary.", "This is the mission 2 summary.", "This is the mission 3 summary."]
var mission_design_scene = preload("uid://b1boi15b3h4ip")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
