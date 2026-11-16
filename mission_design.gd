extends Node2D

const CARD_SCENE = preload("res://ship_options.tscn")
@onready var ui: Control = $CanvasLayer/UI
@onready var title: RichTextLabel = $CanvasLayer/UI/MissionDesignHeader/Title
@onready var option_menu: ShipOptions = CARD_SCENE.instantiate()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	option_menu.hide()
	ui.add_child(option_menu)
	# Dictionary is of form {id, image, descr, button_txt}
	setup_spaceship_cards()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup_spaceship_cards():
	option_menu.hide()
	option_menu.clear_cards()
	var ids = [PlayerData.ShipType.LOCALORBIT, PlayerData.ShipType.LOCALLANDING, PlayerData.ShipType.LONGORBIT, PlayerData.ShipType.LONGLANDING]
	var imgs = [preload("res://assets/imgs/MissionDesign/LocalOrbit.png"), preload("res://assets/imgs/MissionDesign/LocalLanding.png"), preload("res://assets/imgs/MissionDesign/LongOrbit.png"), preload("res://assets/imgs/MissionDesign/LongLanding.png")]
	var descr = ["A ship made for entering orbit around the earth or moon.", "A ship made for landing on the moon.", "A ship made for long space travel and entering orbit around other planets.", "A ship made for long space travel and landing on other planets."]
	var button_txt = ["Select", "Select", "Select", "Select"]
	var card_dicts = []
	for card in range(len(ids)):
		card_dicts.append({"id": ids[card], "image": imgs[card], "descr": descr[card], "button_txt": button_txt[card]})
	option_menu.setup(card_dicts)
	option_menu.back_button_pressed.connect(_spaceship_type_back)
	option_menu.selection_confirmed.connect(_spaceship_type_confirmed)
	option_menu.show()

func setup_engine_cards():
	option_menu.hide()
	option_menu.clear_cards()
	var ids = [PlayerData.EngineType.SOLIDSMALL, PlayerData.EngineType.SOLIDMEDIUM, PlayerData.EngineType.SOLIDLARGE, PlayerData.EngineType.LIQUIDSMALL, PlayerData.EngineType.LIQUIDMEDIUM, PlayerData.EngineType.LIQUIDLARGE]
	var imgs = [preload("res://assets/imgs/Placeholder.png"), preload("res://assets/imgs/Placeholder.png"), preload("res://assets/imgs/Placeholder.png"), preload("res://assets/imgs/Placeholder.png"), preload("res://assets/imgs/Placeholder.png"), preload("res://assets/imgs/Placeholder.png")]
	var descr = ["A small solid rocket engine", "A medium solid rocket engine", "A large solid rocket engine", "A small liquid rocket engine", "A medium liquid rocket engine", "A large liquid rocket engine"]
	var button_txt = ["Select", "Select", "Select", "Select", "Select", "Select"]
	var card_dicts = []
	for card in range(len(ids)):
		card_dicts.append({"id": ids[card], "image": imgs[card], "descr": descr[card], "button_txt": button_txt[card]})
	option_menu.setup(card_dicts)
	option_menu.back_button_pressed.connect(_engine_type_back)
	option_menu.selection_confirmed.connect(_engine_type_confirmed)
	option_menu.show()

func setup_fuel_cards():
	option_menu.hide()
	option_menu.clear_cards()
	var ids = [PlayerData.MaxFuel.SMALL, PlayerData.MaxFuel.MEDIUM, PlayerData.MaxFuel.LARGE]
	var imgs = [preload("res://assets/imgs/Placeholder.png"), preload("res://assets/imgs/Placeholder.png"), preload("res://assets/imgs/Placeholder.png")]
	var descr = ["A small fuel tank", "A medium fuel tank", "A large fuel tank"]
	var button_txt = ["Select", "Select", "Select"]
	var card_dicts = []
	for card in range(len(ids)):
		card_dicts.append({"id": ids[card], "image": imgs[card], "descr": descr[card], "button_txt": button_txt[card]})
	option_menu.setup(card_dicts)
	option_menu.back_button_pressed.connect(_fuel_amount_back)
	option_menu.selection_confirmed.connect(_fuel_amount_confirmed)
	option_menu.show()

func _spaceship_type_confirmed(selection_id):
	PlayerData.ship_type = selection_id
	if option_menu.back_button_pressed.is_connected(_spaceship_type_back):
		option_menu.back_button_pressed.disconnect(_spaceship_type_back)
	if option_menu.selection_confirmed.is_connected(_spaceship_type_confirmed):
		option_menu.selection_confirmed.disconnect(_spaceship_type_confirmed)
	setup_engine_cards()

func _spaceship_type_back():
	if option_menu.back_button_pressed.is_connected(_spaceship_type_back):
		option_menu.back_button_pressed.disconnect(_spaceship_type_back)
	if option_menu.selection_confirmed.is_connected(_spaceship_type_confirmed):
		option_menu.selection_confirmed.disconnect(_spaceship_type_confirmed)
	get_tree().change_scene_to_packed(PlayerData.main_menu_scene)

func _engine_type_confirmed(selection_id):
	PlayerData.engine_type = selection_id
	if option_menu.back_button_pressed.is_connected(_engine_type_back):
		option_menu.back_button_pressed.disconnect(_engine_type_back)
	if option_menu.selection_confirmed.is_connected(_engine_type_confirmed):
		option_menu.selection_confirmed.disconnect(_engine_type_confirmed)
	setup_fuel_cards()
	

func _engine_type_back():
	if option_menu.back_button_pressed.is_connected(_engine_type_back):
		option_menu.back_button_pressed.disconnect(_engine_type_back)
	if option_menu.selection_confirmed.is_connected(_engine_type_confirmed):
		option_menu.selection_confirmed.disconnect(_engine_type_confirmed)
	setup_spaceship_cards()

func _fuel_amount_confirmed(selection_id):
	if option_menu.back_button_pressed.is_connected(_fuel_amount_back):
		option_menu.back_button_pressed.disconnect(_fuel_amount_back)
	if option_menu.selection_confirmed.is_connected(_fuel_amount_confirmed):
		option_menu.selection_confirmed.disconnect(_fuel_amount_confirmed)
		option_menu.hide()
		option_menu.clear_cards()
		match selection_id:
			PlayerData.MaxFuel.SMALL:
				PlayerData.fuel_amount = 25
			PlayerData.MaxFuel.MEDIUM:
				PlayerData.fuel_amount = 50
			PlayerData.MaxFuel.LARGE:
				PlayerData.fuel_amount = 100
		title.text = "You chose a " + PlayerData.ship_type_dict[str(PlayerData.ship_type)] + " ship, a " + PlayerData.engine_type_dict[str(PlayerData.engine_type)] + ", with " + str(PlayerData.fuel_amount) + " fuel."
		
func _fuel_amount_back():
	if option_menu.back_button_pressed.is_connected(_fuel_amount_back):
		option_menu.back_button_pressed.disconnect(_fuel_amount_back)
	if option_menu.selection_confirmed.is_connected(_fuel_amount_confirmed):
		option_menu.selection_confirmed.disconnect(_fuel_amount_confirmed)
	setup_engine_cards()
