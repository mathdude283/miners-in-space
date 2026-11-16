@tool
class_name ConfigOption
extends VBoxContainer

signal option_selected(option_id: int)

@export var card_image: Texture2D = preload("res://assets/imgs/Placeholder.png"):
	set(value):
		card_image = value
		if is_node_ready():
			text_rect.texture = value
	get:
		return text_rect.texture if is_node_ready() else card_image

@export_multiline var card_description: String = "Placeholder":
	set(value):
		card_description = value
		if is_node_ready():
			description.text = value
	get:
		return description.text if is_node_ready() else card_description

@export var button_text: String = "Select":
	set(value):
		button_text = value
		if is_node_ready():
			button.text = value
	get:
		return button.text if is_node_ready() else button_text

@export var option_id: int

@onready var text_rect: TextureRect = $PanelContainer/TextureRect
@onready var description: RichTextLabel = $RichTextLabel
@onready var button: Button = $Button



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text_rect.texture = card_image
	description.text = card_description
	button.text = button_text
	if Engine.is_editor_hint():
		return
	
	button.pressed.connect(_on_button_pressed)

# Dictionary is of form {id, image, descr, button_txt}
func setup(dict: Dictionary):
	option_id = dict["id"]
	card_image = dict["image"]
	card_description = dict["descr"]
	button_text = dict["button_txt"]

func _on_button_pressed():
	option_selected.emit(option_id)

func disable_button():
	button.disabled = true

func enable_button():
	button.disabled = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
