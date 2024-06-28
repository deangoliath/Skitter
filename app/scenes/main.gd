extends Node

var lastFeed = {"VehiclePositions": {"header": {"timezone": 0}, "entity": []}}

func _ready():
	while true:
		await get_tree().create_timer(1).timeout
		$HTTPManager.job(
		"http://127.0.0.1:5000/get_feed/"
		).on_success(
			func( _response ): lastFeed = _response.fetch()
		).on_failure(
			func( _response ): print("Failure to GET_FEED")
		).fetch()
		if lastFeed["VehiclePositions"]["entity"].size() > 0:
			for child in $Control/ScrollContainer/GridContainer.get_children():
				child.queue_free()
			for entity in lastFeed["VehiclePositions"]["entity"]:
				var newinfo = preload("res://scenes/vehicle.tscn").instantiate()
				newinfo.get_node("label_Coords").text = str(entity["vehicle"]["position"]["latitude"])+", "+str(entity["vehicle"]["position"]["longitude"])
				$Control/ScrollContainer/GridContainer.add_child(newinfo)

func _process(delta):
	pass
