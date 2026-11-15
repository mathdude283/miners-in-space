extends MarginContainer

const OPTION_CARD_SCENE = preload("res://config_option.tscn")

signal selection_confirmed(selected_id: int)
signal back_button_pressed()

@onready var card_container: HBoxContainer = $VBoxContainer/OptionCards
@onready var back_button: Button = $VBoxContainer/NavigationButtons/BackButton
@onready var confirm_button: Button = $VBoxContainer/NavigationButtons/ConfirmButton

var current_selection_id = -1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	for child in card_container.get_children():
		if child is ConfigOption:
			child.option_selected.connect(_on_card_selected.bind(child))

# Dictionary is of form {id, image, descr, button_txt}
func setup(cards: Array[Dictionary]):
	confirm_button.disabled = true
	for choice in cards:
		var card: ConfigOption = OPTION_CARD_SCENE.instantiate()
		card_container.add_child(card)
		card.setup(choice)
		card.option_selected.connect(_on_card_selected.bind(card))

func clear_cards():
	for child in card_container.get_children():
		if child is ConfigOption:
			if child.option_selected.is_connected(_on_card_selected):
				child.option_selected.disconnect(_on_card_selected)
			child.queue_free()
	confirm_button.disabled = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_card_selected(selection_id, source_card: ConfigOption):
	confirm_button.disabled = false
	for child in card_container.get_children():
		if child is ConfigOption:
			child.enable_button()
	source_card.disable_button()

func _on_confirm_pressed():
	selection_confirmed.emit(current_selection_id)

func _spaceship_type_confirmed():
	pass

func _spaceship_type_back():
	pass

func _engine_type_confirmed():
	pass

func _engine_type_back():
	pass

func _fuel_amount_confirmed():
	pass

func _fuel_amount_back():
	pass

func _on_back_pressed():
	back_button_pressed.emit()
