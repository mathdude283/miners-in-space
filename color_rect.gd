extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _draw():
	seed(1)
	var viewport_dim = get_viewport().get_visible_rect().size
	var star_radius = 0.0
	var star_pos = Vector2(0, 0)
	for i in range(500):
		star_radius = randi_range(1, 5)
		star_pos = Vector2(randf_range(0, viewport_dim.x), randf_range(0, viewport_dim.y))
		draw_circle(star_pos, star_radius, Color.WHITE)
