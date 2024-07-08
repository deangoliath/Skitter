extends VBoxContainer

@onready var MAIN = get_tree().root.get_node("Main")
var is_ready = false

func _ready():
	is_ready = true


# these buttons may not work on computer/mouse after moving map for some reason, but they work perfectly fine on mobile touchscreen
func _on_btn_show_vehicles_toggled(toggled_on):
	if toggled_on:
		for child in get_children():
			if child.name != "Route":
				child.visible = true
				print(child)
	else:
		for child in get_children():
			if child.name != "Route":
				child.visible = false

func _on_btn_favorite_route_toggled(toggled_on):
	if is_ready:
		if MAIN.user_data.has("favorite_routes") == false:
			MAIN.user_data["favorite_routes"] = []
			MAIN.save_data()
		if toggled_on:
			if MAIN.user_data["favorite_routes"].has(name) == false:
				MAIN.user_data["favorite_routes"].append(name)
		else:
			MAIN.user_data["favorite_routes"].remove_at(MAIN.user_data["favorite_routes"].find(name))
		MAIN.save_data()
