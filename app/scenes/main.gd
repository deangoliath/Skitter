extends Node

var transit_data = {"fare_attributes": {}, "fare_rules": {}, "routes": {}, "shapes": {}, "stops": {}, "stop_times": {}, "trips": {}}

var host = "http://127.0.0.1:5000"
var lastFeed = {"VehiclePositions": {"header": {"timezone": 0}, "entity": []}}

var geolocation_api:GeolocationWrapper
var location_watcher:LocationWatcher

func _ready():
	geolocation_api= get_node("/root/GeolocationWrapper")

	if geolocation_api.supported:
		geolocation_api.authorization_changed.connect(_on_authorization_changed, 0)
		geolocation_api.error.connect(_on_error, 0)
		geolocation_api.debug.connect(_on_debug, 0)
		geolocation_api.location_update.connect(_on_location_update, 0)
		geolocation_api.heading_update.connect(_on_heading_update, 0)
		geolocation_api.set_failure_timeout(5) #optional
		geolocation_api.set_debug_log_signal(true) #optional
	if Engine.has_singleton("Geolocation"):
		var singleton = Engine.get_singleton("Geolocation")
		singleton.helloWorld()
	while true:
		await get_tree().create_timer(5).timeout
		$HTTPManager.job(
		host+"/get_feed/"
		).on_success(
			func( _response ): lastFeed = _response.fetch()
		).on_failure(
			func( _response ): print("Failure to GET_FEED")
		).fetch()
		if lastFeed["VehiclePositions"]["entity"].size() > 0:
			for child in $Control/panel_Center/ScrollContainer/GridContainer.get_children():
				child.queue_free()
			for entity in lastFeed["VehiclePositions"]["entity"]:
				var newinfo = preload("res://scenes/vehicle.tscn").instantiate()
				newinfo.get_node("label_Coords").text = str(entity["vehicle"]["position"]["latitude"])+", "+str(entity["vehicle"]["position"]["longitude"])
				$Control/panel_Center/ScrollContainer/GridContainer.add_child(newinfo)


func _on_authorization_changed(status:int):
	glog("+signal authorization changed: " + str(status))

func _on_error(code:int):
	glog("Error: " + str(code))
	#glog("+signal ERROR: " + geolocation_api.geolocation_error_codes.keys()[code-1] + "(" + str(code) + ")")
	
func _on_debug(message :String, number:float = 0):
	glog("log: " + message + "(" + str(number) + ")")
	
func _on_location_update(location:Location):
	glog("+signal location update!")
	#set_location_output(location.to_string())

func _on_heading_update(heading_data:Dictionary):
	glog("+signal heading update!")

func glog(message:String):
	$Control/panel_Center/content_Explore/Label2.text = message + "\n" + $Control/panel_Center/content_Explore/Label2.text
	
func set_location_output(content:String):
	$Control/panel_Center/content_Explore/Label.text = content
	#location_data_output.text = content

func hide_content():
	$Control/panel_Center/content_Explore.visible = false
	$Control/panel_Center/content_Routes.visible = false
	$Control/panel_Center/content_Map.visible = false

func _on_btn_explore_pressed():
	hide_content()
	$Control/panel_Center/content_Explore.visible = true

func _on_btn_routes_pressed():
	hide_content()
	$Control/panel_Center/content_Routes.visible = true

func _on_btn_settings_pressed():
	pass # Replace with function body.

func _on_btn_location_pressed():
	## stop old watcher
	#if location_watcher != null && location_watcher.is_updating:
		#location_watcher.stop()
	#
	## create watcher and wait for ready
	#location_watcher = geolocation_api.start_updating_location_autopermission()
	#var success:bool = await location_watcher.ready
	#
	## report error
	#if !success:
		## log error if an error was reported
		#if location_watcher.error > 0:
			#set_location_output("Error: " + str(location_watcher.error))
		#return
	#
	## wait for new location in loop until stopped
	#while(location_watcher.is_updating):
		#var location:Location = await location_watcher.location_update
		#if location == null:
			#set_location_output("Error: location null where it should never be null")
			#continue
		#$Control/panel_Center/content_Explore/Label.text = location.to_string()
		#
	#glog("after watching while loop. should be end here after stop or error")
	
	var request = geolocation_api.request_location_autopermission()
	var location:Location = await request.location_update
	glog("after yield")
	# location is null when no location could be found (no permission, no connection, no capabilty)
	if location == null:
		glog("location was null")
		# log error if an error was reported
		if request.error > 0:
			set_location_output("Error: " + str(request.error))
		else:
			set_location_output("Error: " + geolocation_api.geolocation_error_codes.keys()[request.error-1])
		return
	# show location 
	$Control/panel_Center/content_Explore/Label.text = location.to_string()

