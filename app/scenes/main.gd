extends Node

var transit_data = {"fare_attributes": {}, "fare_rules": {}, "routes": {}, "shapes": {}, "stops": {}, "stop_times": {}, "trips": {}}

var host = "http://149.130.216.105:5000" # feel free to use the data provided please do not abuse
var lastFeed

var geolocation_api:GeolocationWrapper
var location_watcher:LocationWatcher

@onready var MAP = $Control/panel_Center/content_Explore/Map/VBoxContainer/SubViewportContainer/SubViewport/Map
@onready var MAP_LOADER = $Control/panel_Center/content_Explore/Map/VBoxContainer/SubViewportContainer/SubViewport/Map/MapTileLoader
@onready var HTTP = $HTTPRequest
var friendly_name = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.57 Safari/537.36"#"Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/114.0 Firefox/114.0"

var latest_retrieve_token
var http_requests = {
	"example_token": "data"
}
var http_occupied = false

@onready var user_data = {"update_vehicle_positions": true, "lastKnownLocation": null, "map_provider": [0, MAP_LOADER.Provider.JAWG]}

func _ready():
	load_data()
	$HTTPManager.job(
		host+"/get_feed/"
		).on_success(
			func( _response ): lastFeed = _response.fetch()
		).on_failure(
			func( _response ): print("Failure to GET_FEED")
		).fetch()
	$HTTPManager.job(
		host+"/get_routes/"
		).on_success(
			func( _response ): transit_data["routes"] = _response.fetch();
		).on_failure(
			func( _response ): print("Failure to GET_ROUTES")
		).fetch()
	#var lastKnownLocation = user_data["lastKnownLocation"]
	#if lastKnownLocation != null:
		#MAP.latitude = lastKnownLocation["latitude"]
		#MAP.longitude = lastKnownLocation["longitude"]
		#MAP.zoom = 20
	
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
		
		if lastFeed != null:
			#$Control/panel_Center/content_Routes/VBoxContainer/ScrollContainer.visible = true
			$Control/panel_Center/content_Routes/VBoxContainer/label_Error.visible = false
			$Control/panel_Center/content_Routes/VBoxContainer/tr_Error.visible = false
			if lastFeed["VehiclePositions"].has("entity"):
				var vec = lastFeed["VehiclePositions"]["entity"]
				vec.resize(8) # limits vehicles, need to optimize pins
				lastFeed["VehiclePositions"]["entity"] = vec
				for entity in lastFeed["VehiclePositions"]["entity"]:
					if entity != null:
						var routeId = entity["vehicle"]["trip"]["routeId"]
						var infonode
						if $Control/panel_Center/content_Routes/VBoxContainer/ScrollContainer/GridContainer.has_node(entity["id"]):
							infonode = $Control/panel_Center/content_Routes/VBoxContainer/ScrollContainer/GridContainer.get_node(entity["id"])
						else:
							infonode = preload("res://scenes/vehicle.tscn").instantiate()
							infonode.name = entity["id"]
							$Control/panel_Center/content_Routes/VBoxContainer/ScrollContainer/GridContainer.add_child(infonode)
						infonode.get_node("HBoxContainer/Control2/label_Coords").text = str(entity["vehicle"]["position"]["latitude"])+", "+str(entity["vehicle"]["position"]["longitude"])
						
						if transit_data["routes"].has(routeId):
							infonode.get_node("HBoxContainer/Control/label_Route").text = transit_data["routes"][routeId]["route_short_name"]
							infonode.get_node("HBoxContainer/Control2/label_RouteB").text = transit_data["routes"][routeId]["route_long_name"]
							infonode.get_node("HBoxContainer/Control2/label_RouteA").text = "Vehicle "+entity["id"]
						#else:
						#	print(routeId)
						
						if user_data["update_vehicle_positions"]:
							if MAP.get("points").has("Vehicle "+entity["id"]):
								var step = Vector2(256, 256)
								var coords = MAP_LOADER.gps_to_tile(entity["vehicle"]["position"]["latitude"], entity["vehicle"]["position"]["longitude"], MAP.zoom) # can change zoom to max 22? then it has fine point? NO
								MAP.points["Vehicle "+entity["id"]]["coords"] = Vector2(step.x * coords.x, step.y * coords.y)
							else:
								var step = Vector2(256, 256)
								var coords = MAP_LOADER.gps_to_tile(entity["vehicle"]["position"]["latitude"], entity["vehicle"]["position"]["longitude"], MAP.zoom)
								#for zoom in MAP._zooms:
								MAP.points["Vehicle "+entity["id"]] = {"coords": Vector2(step.x * coords.x, step.y * coords.y), "sprite": "bus", "color": Color.WHITE, "label": "Bus "+transit_data["routes"][routeId]["route_short_name"]}
			else:
				$Control/panel_Center/content_Routes/VBoxContainer/label_Error.text = "No vehicles are in operation at this time."
				$Control/panel_Center/content_Routes/VBoxContainer/label_Error.visible = true
				$Control/panel_Center/content_Routes/VBoxContainer/tr_Error.visible = true
		else:
			$Control/panel_Center/content_Routes/VBoxContainer/label_Error.text = "COULD NOT RETRIEVE TRANSIT DATA\nCHECK INTERNET CONNECTION"
			$Control/panel_Center/content_Routes/VBoxContainer/label_Error.visible = true
			$Control/panel_Center/content_Routes/VBoxContainer/tr_Error.visible = true
		MAP.refresh_points()

func load_data():
	if FileAccess.file_exists("user://user_data.json"):
		var file = FileAccess.open("user://user_data.json", FileAccess.READ)
		user_data = JSON.parse_string(file.get_as_text())
	else:
		save_data()
	$Control/panel_Center/content_Settings/VBoxContainer/ob_MapProvider.select(user_data["map_provider"][0])
	MAP_LOADER.tile_provider = user_data["map_provider"][1]

func save_data():
	var file = FileAccess.open("user://user_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(user_data))

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
	$Control/panel_Top/label_Title.text = "OpenLynx"
	$Control/panel_Center/content_Explore.visible = false
	$Control/panel_Center/content_Routes.visible = false
	$Control/panel_Center/content_Settings.visible = false
	$Control/panel_Center/content_Wallet.visible = false

func _on_btn_explore_pressed():
	hide_content()
	$Control/panel_Center/content_Explore.visible = true

func _on_btn_routes_pressed():
	hide_content()
	$Control/panel_Top/label_Title.text = "Transit Routes"
	$Control/panel_Center/content_Routes.visible = true

func _on_btn_settings_pressed():
	hide_content()
	$Control/panel_Top/label_Title.text = "App Settings"
	$Control/panel_Center/content_Settings.visible = true

func _on_btn_wallet_pressed():
	hide_content()
	$Control/panel_Top/label_Title.text = "Mobile Wallet"
	$Control/panel_Center/content_Wallet.visible = true

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
	user_data["lastKnownLocation"] = location
	save_data()
	MAP.latitude = location["latitude"]
	MAP.longitude = location["longitude"]
	MAP.zoom = 20
	$Control/panel_Center/content_Explore/MapNav/VBoxContainer/vs_Zoom.value = 20
	$Control/panel_Center/content_Explore/Label.text = location._to_string()

func _on_vs_zoom_value_changed(value):
	MAP.zoom = value
	#if lastKnownLocation != null:
		#MAP.latitude = lastKnownLocation["latitude"]
		#MAP.longitude = lastKnownLocation["longitude"]

func _on_btn_login_pressed():
	var username = $Control/panel_Center/content_Wallet/le_Email.text
	var password = $Control/panel_Center/content_Wallet/le_Password.text
	var data = {}
	var custom_headers = []
	var request_type = HTTPClient.METHOD_GET
	var retrieve_token = generate_string(100)
	make_http_request("http://www.lynxpawpass.com/members/login/", data, true, retrieve_token, custom_headers, request_type)
	while http_requests.has(retrieve_token) == false:
		await get_tree().create_timer(0.01).timeout
	var rdata = http_requests[retrieve_token]
	http_requests.erase(retrieve_token)
	if typeof(rdata) == 2:
		print('http failed')
		return # show that login failed
	if rdata != null:
		$HTTPRequest.set_http_proxy("127.0.0.1", 8080)
		var headers = rdata[1]
		var headers_data = {}
		#print(headers[4].split("; ")[0].split("Set-Cookie: ASP.NET_SessionId="))
		# EACH PAGE CAN HAVE DIFFERENT VALUES AND LENGTHS!!
		print(headers)
		headers = ["Cache-Control: no-cache, no-store", "Pragma: no-cache", "Content-Type: text/html; charset=utf-8", "Content-Encoding: gzip", "Expires: -1", "Vary: Accept-Encoding", "Set-Cookie: ASP.NET_SessionId=wh0nmzazfdsizuibjhi2fzpv; path=/; secure; HttpOnly; SameSite=Lax", "Set-Cookie: ASP.NET_SessionId=wh0nmzazfdsizuibjhi2fzpv; path=/; secure; HttpOnly; SameSite=Lax", "Set-Cookie: __RequestVerificationToken=3nJbZOZusvkmfC5wb5mYt0OatE4aPDk3uo1-6eAYGtWVz7WfZOsot604MoKhop5iojvwFeTG-dE9oWKDCXxO0EBvQaw1; path=/; secure; HttpOnly", "Set-Cookie: lmH9dWHtPW1DBGaNE6nS0BT37EuCmpBZL%2F3djpMWHNHRNF3qiKh4RvqWFlkL2xMr=; path=/; secure; HttpOnly", "Set-Cookie: 3xIIBfqDBxxGDEV33zAzaSq8zWYGn1iVKlvYnI7zIJ0%3D=; path=/; secure; HttpOnly", "X-Frame-Options: SAMEORIGIN", "X-UA-Compatible: IE=edge,chrome=1", "Date: Mon, 01 Jul 2024 21:48:17 GMT", "Content-Length: 11884"]
		headers_data["ASP.NET_SessionId"] = headers[6].split("; ")[0].split("Set-Cookie: ASP.NET_SessionId=")[1]
		headers_data["__RequestVerificationToken"] = headers[8].split(";")[0].split("Set-Cookie: __RequestVerificationToken=")[1]
		headers_data["__EVENTVALIDATION"] = rdata[2].split('<input type="hidden" name="__EVENTVALIDATION" id="__EVENTVALIDATION" value="')[1].split('" />')[0]
		#print(rdata[2].split('<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="')[1].split('" /></div></form>')[0])
		headers_data["__VIEWSTATE"] = rdata[2].split('<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="')[1].split('" /></div></form>')[0] #extract_string(rdata[2], '<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="(?:[^\\"]|\\\\|\\")*">')
		var cookie = "ASP.NET_SessionId="+headers_data["ASP.NET_SessionId"]+"; __RequestVerificationToken="+headers_data["__RequestVerificationToken"]+";"
		var file4 = FileAccess.open("user://cookie", FileAccess.WRITE)
		file4.store_string(cookie)
		data = {
			"__RequestVerificationToken": headers_data["__RequestVerificationToken"],
			"CT_Main_0$txtUsername": username,
			"CT_Main_0$txtPassword": password,
			"CT_Main_0$btnLogin": "Login",
			"__EVENTVALIDATION": headers_data["__EVENTVALIDATION"],
			"__VIEWSTATE": headers_data["__VIEWSTATE"]
		}
		data = {
			"__RequestVerificationToken": "7LRGZJGmaeuCz21y8iTO8-zhn1Twj7OPHTGnFmNq2TwgJo0HX1M5ai1yqwI0aQ52vOlL6lrlYSU65UipckzcR1rXSu81",
			"CT_Main_0$txtUsername": username,
			"CT_Main_0$txtPassword": password,
			"CT_Main_0$btnLogin": "Login",
			"__EVENTVALIDATION": "uISvjb1xMTXEzNK0ITAiCaxzVoo1sQMSyf1hnCLwGXboazvdmSMwHaaYMGVRMWqQ5wdRocI54tzsp70PDkA2rFGTcoAdsMTYxplTHISDUkEcEZWZWOQGDMWFCcFo8nBYdMqdpyWGcsQafZ8gj8WNXxDgolhnsit4zUj7VsNuYIN2V+TzeW+oWLytJEEspaK6NqJ5aVmxXFSbjD/IwTp/Fyk6kLw=",
			"__VIEWSTATE": "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"
		}
		#cookie = "ASP.NET_SessionId=wh0nmzazfdsizuibjhi2fzpv; __RequestVerificationToken=3nJbZOZusvkmfC5wb5mYt0OatE4aPDk3uo1-6eAYGtWVz7WfZOsot604MoKhop5iojvwFeTG-dE9oWKDCXxO0EBvQaw1;"
		var file = FileAccess.open("user://almost.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		var file2 = FileAccess.open("user://cookie2", FileAccess.WRITE)
		file2.store_string(cookie)
		var file3 = FileAccess.open("user://body.html", FileAccess.WRITE)
		file3.store_string(rdata[2])
		print(cookie)
		custom_headers = ["Cookie: "+cookie]
		#custom_headers = ["Cookie: "+"ASP.NET_SessionId="+headers_data["ASP.NET_SessionId"]+";"+"__RequestVerificationToken="+headers_data["__RequestVerificationToken"]]
		request_type = HTTPClient.METHOD_POST
		retrieve_token = generate_string(100)
		make_http_request("http://www.lynxpawpass.com/members/login/", data, true, retrieve_token, custom_headers, request_type, true)
		while http_requests.has(retrieve_token) == false:
			await get_tree().create_timer(0.01).timeout
		rdata = http_requests[retrieve_token]
		http_requests.erase(retrieve_token)
		if typeof(rdata) == 2:
			print('http failed')
			return # show that login failed
		if rdata != null:
			"Successful Login"
			headers = rdata[1]
			#print(rdata[2])
			#print(headers)
			print(rdata[0])

func generate_string(length, chars='abcdefghijklmnopqrstuvwxyz'):
	var word: String
	var n_char = len(chars)
	for i in range(length):
		word += chars[randi()% n_char]
	return word

func extract_string(full_content: String, regex_string):
	var regex = RegEx.new()
	regex.compile(regex_string)
	
	var result = regex.search(full_content)
	if result:
		return result.get_string(1)
	else:
		return ""

func make_http_request(url, data_to_send, use_ssl, retrieve_token, custom_headers, request_type, alt_send=false):
	while http_occupied:
		await get_tree().create_timer(0.01).timeout
	http_occupied = true
	var query = JSON.stringify(data_to_send)
	var headers = ["User-Agent: "+"HTTPie"]
	headers.append_array(custom_headers)
	if alt_send:
		var httpClient = HTTPClient.new()
		var queryString = httpClient.query_string_from_dict(data_to_send)
		headers.append_array(["Content-Type: application/x-www-form-urlencoded", "Content-Length: " + str(queryString.length())])
		HTTP.request(url, headers, request_type, queryString)
	else:
		HTTP.request(url, headers, request_type, query)
	latest_retrieve_token = retrieve_token

func _on_http_request_request_completed(result, response_code, headers, body):
	http_requests[latest_retrieve_token] = [response_code, headers, body.get_string_from_utf8()]
	http_occupied = false

#func _on_request_completed(result, response_code, headers, body, callback=null, data=null):
	#if callback == "golynx_login":
		#data = {}
		#data["ASP.NET_SessionId"] = headers[4].split("; ")[0].split("Set-Cookie: ASP.NET_SessionId=")[1]
		#data["__RequestVerificationToken"] = headers[6].split("; ")[0].split("Set-Cookie: __RequestVerificationToken=")[1]
		#$HTTPRequest.request_completed.connect(_on_request_completed.bind("golynx_auth"))
		#$HTTPRequest.request("https://www.lynxpawpass.com/")
	#elif callback == "golynx_auth":
		#print("auth5")
		#var cookie = "ASP.NET_SessionId="+data["ASP.NET_SessionId"]+"; __RequestVerificationToken="+data["__RequestVerificationToken"]+";"
		#print(cookie)
		#$HTTPRequest.request_completed.connect(_on_request_completed.bind("golynx_auth_finish"))
		#$HTTPRequest.request("https://www.lynxpawpass.com/members/login", ["Cookie: "+cookie])
		#var token = data[""]
	#elif callback == "golynx_auth_finish":
		#print(response_code)
		#print(headers)
		#print(body)

func _on_ob_map_provider_item_selected(index):
	if index == 0:
		user_data["map_provider"][0] = 0
		user_data["map_provider"][1] = MAP_LOADER.Provider.JAWG
	elif index == 1:
		user_data["map_provider"][0] = 1
		user_data["map_provider"][1] = MAP_LOADER.Provider.BING
	save_data()
	MAP_LOADER.tile_provider = user_data["map_provider"][1]
