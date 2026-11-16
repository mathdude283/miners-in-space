extends Node2D

const G = 6.6743*(10.0**(-11.0)) # m^3/kg*s^2
const M = 5.9722*(10**24)
const MU = G*M
const R_EARTH = 6371000
const EARTH_RADIUS_PIXELS = 240
const SCALE = R_EARTH/EARTH_RADIUS_PIXELS

var dry_mass
var fuel_mass
var thrust
var isp
var target_apoapsis_altitude = 200000






func _ready():
	var background = PlayerData.background.instantiate()
	add_child(background)
	global_position = get_viewport_rect().size / 2.0

func _draw():
	# Draw the ocean using the variable
	draw_circle(Vector2.ZERO, EARTH_RADIUS_PIXELS, Color.DODGER_BLUE)
	
	# Scale the continents proportionally so they always fit inside the Earth
	draw_circle(Vector2(-0.3, -0.25) * EARTH_RADIUS_PIXELS, EARTH_RADIUS_PIXELS * 0.35, Color.FOREST_GREEN)
	draw_circle(Vector2(0.35, 0.2) * EARTH_RADIUS_PIXELS, EARTH_RADIUS_PIXELS * 0.4, Color.FOREST_GREEN)
	draw_circle(Vector2(-0.15, 0.5) * EARTH_RADIUS_PIXELS, EARTH_RADIUS_PIXELS * 0.22, Color.FOREST_GREEN)

func _process(delta: float) -> void:
	pass
