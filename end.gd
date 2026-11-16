extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var background = PlayerData.background.instantiate()
	add_child(background)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
