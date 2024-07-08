extends Control

@onready var MAIN = get_tree().root.get_node("Main")
var coords = []

func _on_btn_map_vehicle_pressed():
	MAIN.MAP.latitude = coords[0]
	MAIN.MAP.longitude = coords[1]
	MAIN.hide_content()
	MAIN.get_node("Control/panel_Center/content_Explore").visible = true
