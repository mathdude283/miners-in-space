extends Node2D

const CARD_SCENE = preload("res://ship_options.tscn")
@onready var ui: Control = $CanvasLayer/UI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var option_menu = CARD_SCENE.instantiate()
	option_menu.hide()
	ui.add_child(option_menu)
	imgs = [preload("res://assets/imgs/MissionDesign/LocalLanding.png")]
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
