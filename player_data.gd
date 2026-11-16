extends Node


enum ShipType { LOCALORBIT, LOCALLANDING, LONGORBIT, LONGLANDING }
enum EngineType { SOLIDSMALL, SOLIDMEDIUM, SOLIDLARGE, LIQUIDSMALL, LIQUIDMEDIUM, LIQUIDLARGE }
enum Scenario { MISSION_1, MISSION_2, MISSION_3 }
enum MaxFuel { SMALL, MEDIUM, LARGE}
enum PowerType {SMALLSOLAR, LARGESOLAR, RTG}
enum Instruments { VISUALCAMERA, INFAREDCAMERA, RADARSAR, SPECTROMETER, MAGNETOMETER, PROBE, ALTIMETER }
enum ThermalType {PASSIVE, HEATERS_RADIATORS, ADVANCED_LOOP}
enum StorageType { SMALL, MEDIUM, LARGE }


enum MissionConfig { SHIPTYPE, ENGINETYPE, MAXFUEL, POWERTYPE, THERMALTYPE, MISSION, INSTRUMENTS}
var power_type = null
var thermal_type = null
var storage_type = null
var camera_type = null
var fuel_amount = 0
var ship_type = null
var engine_type = null
var scenario = null
var mission_summaries = ["This is the mission 1 summary.", "This is the mission 2 summary.", "This is the mission 3 summary."]
var main_menu_scene = "res://main_menu.tscn"
var mission_design_scene = "res://mission_design.tscn"
var forum_scene = "res://forum.tscn"
var flight_scene = "res://flight.tscn"
var end_scene = "res://end.tscn"
var background = preload("res://background.tscn")
var ship_type_dict = {str(ShipType.LOCALORBIT): "Local Orbit", str(ShipType.LOCALLANDING): "Local Landing", str(ShipType.LONGORBIT): "Long Orbit", str(ShipType.LONGLANDING): "Long Landing"}
var engine_type_dict = {str(EngineType.SOLIDSMALL): "Solid Small", str(EngineType.SOLIDMEDIUM): "Solid Medium", str(EngineType.SOLIDLARGE): "Solid LARGE", str(EngineType.LIQUIDSMALL): "Liquid Small", str(EngineType.LIQUIDMEDIUM): "Liquid Medium", str(EngineType.LIQUIDLARGE): "Liquid Large",}

const G = 6.6743*(10.0**(-11.0)) # m^3/kg*s^2
const M = 5.9722*(10**24)
const MU = G*M
const R_EARTH = 6371000
const EARTH_RADIUS_PIXELS = 240
const SCALE = R_EARTH/EARTH_RADIUS_PIXELS
const CROSS_AREA = 10.5


var dry_mass
var fuel_mass
var thrust
var isp
var target_apoapsis_altitude = 200000


var flight_path := Line2D.new()
var center_pos = null
var path_start = null

var power_data = {
	PowerType.SMALLSOLAR: {
		"name": "Small Solar Arrays",
		"output": "300 W at 1 AU",
		"output_w": 300,
		"mass_kg": 400,
		"cost_m": 60,
		"notes": "Weak far from the Sun",
	},
	PowerType.LARGESOLAR: {
		"name": "Large Solar Arrays",
		"output": "1,000 W at 1 AU",
		"output_w": 1000,
		"mass_kg": 3500,
		"cost_m": 650,
		"notes": "Fragile, and degrade with radiation",
	},
	PowerType.RTG: {
		"name": "GPHS-type RTG",
		"output": "~0.25 kW",
		"output_w": 250,
		"mass_kg": 58,
		"cost_m": 200,
		"notes": "Works anywhere, no eclipse, but low output and slowly decays",
	},
}

var thermal_data = {
	ThermalType.PASSIVE: {
		"name": "Passive (coatings, insulation)",
		"mass_kg": 350,
		"power_kw": 0.5,
		"cost_m": 30,
		"notes": "Insulation and heat rejection without powered devices",
	},
	ThermalType.HEATERS_RADIATORS: {
		"name": "Heaters and radiators",
		"mass_kg": 900,
		"power_kw": 3.0,
		"cost_m": 110,
		"notes": "Heaters activate when temperature drops",
	},
	ThermalType.ADVANCED_LOOP: {
		"name": "Advanced loop",
		"mass_kg": 3500,
		"power_kw": 9.0,
		"cost_m": 600,
		"notes": "Active circulation for more demanding thermal designs",
	},
}

var storage_data = {
	StorageType.SMALL: {
		"name": "Small Data Storage",
		"capacity_tb": 2,
		"mass_kg": 60,
		"power_kw": 0.2,
		"cost_m": 20,
		"notes": "Limited storage for observation data",
	},
	StorageType.MEDIUM: {
		"name": "Medium Data Storage",
		"capacity_tb": 10,
		"mass_kg": 180,
		"power_kw": 0.5,
		"cost_m": 65,
		"notes": "Balanced storage",
	},
	StorageType.LARGE: {
		"name": "Large Data Storage",
		"capacity_tb": 50,
		"mass_kg": 500,
		"power_kw": 1.0,
		"cost_m": 180,
		"notes": "High capacity for image-heavy missions",
	},
}

var camera_data = {
	Instruments.VISUALCAMERA: {
		"name": "Visible camera",
		"mass_kg": 12,
		"power_kw": 0.015,
		"data_mb": 25,
		"data_unit": "image",
		"cost_m": 30,
		"notes": "Visible-light pictures of clouds, terrain, and targets",
		"missions": "All",
	},
	Instruments.INFAREDCAMERA: {
		"name": "Thermal infrared imager",
		"mass_kg": 30,
		"power_kw": 0.06,
		"data_mb": 8,
		"data_unit": "scan",
		"cost_m": 50,
		"notes": "Thermal infrared radiance and estimated brightness temperature (K)",
		"missions": "Wildfire, lunar",
	},
}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func gen_path():
	pass

func get_data_coll_time():
	pass
