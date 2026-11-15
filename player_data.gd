extends Node


enum ShipType { LOCALORBIT, LOCALLANDING, LONGORBIT, LONGLANDING }
enum EngineType { SOLIDSMALL, SOLIDMEDIUM, SOLIDLARGE, LIQUIDSMALL, LIQUIDMEDIUM, LIQUIDLARGE }
enum Scenario { MISSION_1, MISSION_2, MISSION_3 }
enum MaxFuel { SMALL, MEDIUM, LARGE}
enum Instruments { VISUALCAMERA, INFAREDCAMERA, RADARSAR, SPECTROMETER, MAGNETOMETER, PROBE, ALTIMETER }
enum MissionConfig { SHIPTYPE, ENGINETYPE, MAXFUEL, MISSION, INSTRUMENTS}
var fuel_amount = 0
var ship_type = null
var engine_type = null
var scenario = null
var mission_summaries = ["This is the mission 1 summary.", "This is the mission 2 summary.", "This is the mission 3 summary."]
var main_menu_scene = preload("res://main_menu.tscn")
var mission_design_scene = preload("res://mission_design.tscn")
var forum_scene = preload("res://forum.tscn")
var flight_scene = preload("res://flight.tscn")
var end_scene = preload("res://end.tscn")
var ship_type_dict = {str(ShipType.LOCALORBIT): "Local Orbit", str(ShipType.LOCALLANDING): "Local Landing", str(ShipType.LONGORBIT): "Long Orbit", str(ShipType.LONGLANDING): "Long Landing"}
var engine_type_dict = {str(EngineType.SOLIDSMALL): "Solid Small", str(EngineType.SOLIDMEDIUM): "Solid Medium", str(EngineType.SOLIDLARGE): "Solid LARGE", str(EngineType.LIQUIDSMALL): "Liquid Small", str(EngineType.LIQUIDMEDIUM): "Liquid Medium", str(EngineType.LIQUIDLARGE): "Liquid Large",}



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
