extends Node

var transit_data = {"fare_attributes": {}, "fare_rules": {}, "routes": {}, "shapes": {}, "stops": {}, "stop_times": {}, "trips": {}}
var route_data = { # only here for testing. get data from gtfsrt.golynx.com/gtfsrt
	"14717": {"route_short_name": "42", "route_long_name": "INTL DR/ORLANDO INTL  AIRPORT", "route_type": "3"},
	"14673": {"route_short_name": "8", "route_long_name": "W. OAK RIDGE RD/INTL. DR", "route_type": "3"},
	"14711": {"route_short_name": "37", "route_long_name": "PINE HILLS/FLORIDA MALL", "route_type": "3"},
	"14691": {"route_short_name": "18", "route_long_name": "S. ORANGE AVE/KISSIMMEE", "route_type": "3"},
	"14750": {"route_short_name": "311", "route_long_name": "EAST/WEST FAST LINK", "route_type": "3"},
	"14694": {"route_short_name": "21", "route_long_name": "RALEIGH ST/KIRKMAN RD/ UNIV STUDIOS", "route_type": "3"},
	"14713": {"route_short_name": "40", "route_long_name": "AMERICANA BLVD/UNIVERSAL ORLANDO", "route_type": "3"},
	"14709": {"route_short_name": "350", "route_long_name": "ORLANDO/DEST. PKY/DISNEY SPG EXP", "route_type": "3"},
	"14731": {"route_short_name": "56", "route_long_name": "W. U.S. 192/MAGIC KINGDOM", "route_type": "3"}
	}

var host = "http://149.130.216.105:5000/" # feel free to use the data provided please do not abuse
var lastFeed = {"VehiclePositions": {"header": {"timezone": 0}, "entity": []}}

var geolocation_api:GeolocationWrapper
var location_watcher:LocationWatcher
var lastKnownLocation

func _ready():
	load_data()
	if lastKnownLocation != null:
		var map = $Control/panel_Center/content_Explore/mosaic/VBoxContainer/SubViewportContainer/SubViewport/Map
		map.latitude = lastKnownLocation["latitude"]
		map.longitude = lastKnownLocation["longitude"]
		map.zoom = 20
	
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
		await get_tree().create_timer(1).timeout # ideally every half minute plus one
		$HTTPManager.job(
		host+"/get_feed/"
		).on_success(
			func( _response ): lastFeed = _response.fetch()
		).on_failure(
			func( _response ): print("Failure to GET_FEED")
		).fetch()
		
		if lastFeed["VehiclePositions"]["entity"].size() > 0:
			var vec = lastFeed["VehiclePositions"]["entity"]
			vec.resize(8)
			lastFeed["VehiclePositions"]["entity"] = vec
			for entity in lastFeed["VehiclePositions"]["entity"]:
				var routeId = entity["vehicle"]["trip"]["routeId"]
				var infonode
				if $Control/panel_Center/content_Routes/ScrollContainer/GridContainer.has_node(entity["id"]):
					infonode = $Control/panel_Center/content_Routes/ScrollContainer/GridContainer.get_node(entity["id"])
				else:
					infonode = preload("res://scenes/vehicle.tscn").instantiate()
					infonode.name = entity["id"]
					$Control/panel_Center/content_Routes/ScrollContainer/GridContainer.add_child(infonode)
				infonode.get_node("HBoxContainer/Control2/label_Coords").text = str(entity["vehicle"]["position"]["latitude"])+", "+str(entity["vehicle"]["position"]["longitude"])
				
				if route_data.has(routeId):
					infonode.get_node("HBoxContainer/Control/label_Route").text = route_data[routeId]["route_short_name"]
					infonode.get_node("HBoxContainer/Control2/label_RouteB").text = route_data[routeId]["route_long_name"]
					infonode.get_node("HBoxContainer/Control2/label_RouteA").text = "Vehicle "+entity["id"]
				#else:
				#	print(routeId)

func deg2tile(zoom=0.0, lon=0.0, lat=0.0):
	return([floor(((lon + 180) / 360) * pow(2, zoom)), floor((1 - log(tan(deg_to_rad(lat)) + 1 / cos(deg_to_rad(lat))) / PI) /2 * pow(2, zoom))])

func load_data():
	pass

func save_data():
	pass

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
	#var tile = deg2tile(zoom, location["longitude"], location["latitude"])
	lastKnownLocation = location
	var map = $Control/panel_Center/content_Explore/mosaic/VBoxContainer/SubViewportContainer/SubViewport/Map
	map.latitude = location["latitude"]
	map.longitude = location["longitude"]
	map.zoom = 20
	$Control/panel_Center/content_Explore/Label.text = location._to_string()

func _on_vs_zoom_value_changed(value):
	var map = $Control/panel_Center/content_Explore/mosaic/VBoxContainer/SubViewportContainer/SubViewport/Map
	map.zoom = value
	if lastKnownLocation != null:
		map.latitude = lastKnownLocation["latitude"]
		map.longitude = lastKnownLocation["longitude"]
