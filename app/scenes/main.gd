extends Node

var transit_data = {"fare_attributes": {}, "fare_rules": {}, "routes": {}, "shapes": {}, "stops": {}, "stop_times": {}, "trips": {}}

var host = "http://149.130.216.105:5000" # feel free to use the data provided please do not abuse
var lastFeed

var geolocation_api:GeolocationWrapper
var location_watcher:LocationWatcher

@onready var MAP = $Control/panel_Center/content_Explore/Map/VBoxContainer/SubViewportContainer/SubViewport/Map
@onready var MAP_LOADER = $Control/panel_Center/content_Explore/Map/VBoxContainer/SubViewportContainer/SubViewport/Map/MapTileLoader
@onready var HTTP = $HTTPRequest
#var friendly_name = "Mozilla/5.0 (Windows NT 10.0; rv:127.0) Gecko/20100101 Firefox/127.0"
var friendly_name = "OpenLynx/"+str(ProjectSettings.get_setting("application/config/version"))+" OS/0 (Linux; Android "+str(OS.get_version())+"; 0 Build/0)"
var latest_retrieve_token
var http_requests = {
	"example_token": "data"
}
var http_occupied = false

@onready var user_data = {"update_vehicle_positions": true, "lastKnownLocation": null, "map_provider": [0, MAP_LOADER.Provider.JAWG], "location_provider": [0, "FUSED"]}

func _ready():
	print(friendly_name)
	load_data()
	# check if internet connectivity here before issuing http requests
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
	#if Engine.has_singleton("Geolocation"):
		#var singleton = Engine.get_singleton("Geolocation")
		#singleton.helloWorld()
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
	$Control/panel_Center/content_Settings/VBoxContainer/ob_LocationProvider.select(user_data["location_provider"][0])
	#if Engine.has_singleton("Geolocation"):
		#geolocation_api.set_location_provider(user_data["location_provider"][1])
	if user_data.has("transit_account"):
		$HTTPManager.job(
		"https://www.lynxpawpass.com/members/"
		).add_header(
		"Cookie", user_data["transit_account"]["Cookie"]
		).add_header(
			"Host", "www.lynxpawpass.com"
		).add_header(
			"User-Agent", friendly_name
		).on_success(
			func( _response ):
				print("barbie")
				print(_response.fetch().split('Email Address:').size())
				if _response.fetch().split('Email Address:').size() > 1:
					var emailaddress = _response.fetch().split('Email Address:')[1].split('<div class="formContent">')[1].split('</div>')[0]
					var collegestatus
					$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountHome/label_Email.text = emailaddress
					$Control/panel_Center/content_Wallet/content_Login.visible = false
					$Control/panel_Center/content_Wallet/content_Account.visible = true
				else:
					user_data.erase("transit_account")
					save_data()
		).on_failure(
			func( _response ): print("Failure to www.lynxpawpass.com/members/")
		).fetch()

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
	
	if Engine.has_singleton("Geolocation"):
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
		#MAP.zoom = 20
		#$Control/panel_Center/content_Explore/MapNav/VBoxContainer/vs_Zoom.value = 20
		$Control/panel_Center/content_Explore/Label.text = location._to_string()

func _on_vs_zoom_value_changed(value):
	MAP.zoom = value
	#if lastKnownLocation != null:
		#MAP.latitude = lastKnownLocation["latitude"]
		#MAP.longitude = lastKnownLocation["longitude"]

func _on_btn_login_pressed():
	$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Email.editable = false
	$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Password.editable = false
	$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/btn_Login.disabled = true
	var username = $Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Email.text
	var password = $Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Password.text
	var body
	$HTTPManager.job(
		"https://www.lynxpawpass.com/members/login/"
	).on_success( 
		func(response): 
			body = response.fetch()
			# xml parser godot has might use later
			var data = { #requesttoken has two versions, one in body other in cookie
					"__RequestVerificationToken": body.split('<input name="__RequestVerificationToken" type="hidden" value="')[1].split('" />')[0],
					"__EVENTVALIDATION": body.split('<input type="hidden" name="__EVENTVALIDATION" id="__EVENTVALIDATION" value="')[1].split('" />')[0],
					"__VIEWSTATE": body.split('<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="')[1].split('" /></div></form>')[0],
					"CT_Main_0$txtUsername": username,
					"CT_Main_0$txtPassword": password,
					"CT_Main_0$btnLogin": "Login",
				}
			$HTTPManager.job(
				"https://www.lynxpawpass.com/members/login/"
			).add_header( # set_cookie not working
				"Cookie", "ASP.NET_SessionId="+$HTTPManager._cookies["www.lynxpawpass.com"]["ASP.NET_SessionId"].get("value")+"; __RequestVerificationToken="+$HTTPManager._cookies["www.lynxpawpass.com"]["__RequestVerificationToken"].get("value")+";"
			).add_header(
				"Host", "www.lynxpawpass.com"
			).add_header(
				"User-Agent", friendly_name
			).add_header(
				"Content-Type", "application/x-www-form-urlencoded"
			).add_post(
				data
			).on_success(
				func( _response ):
					print("this one means failure")
					#print("this should not happen, should return 500 internal.. if you read this PLEASE open an issue for investigation!!!!")
					$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Email.editable = true
					$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Password.editable = true
					$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/btn_Login.disabled = false
			).on_failure(
				func( _response ):
					data.erase("CT_Main_0$txtUsername")
					data.erase("CT_Main_0$txtPassword")
					data.erase("CT_Main_0$btnLogin")
					data["Cookie"] = "ASP.NET_SessionId="+$HTTPManager._cookies["www.lynxpawpass.com"]["ASP.NET_SessionId"].get("value")+"; __RequestVerificationToken="+$HTTPManager._cookies["www.lynxpawpass.com"]["__RequestVerificationToken"].get("value")+";"
					user_data["transit_account"] = data
					save_data()
					$HTTPManager.job(
						"https://www.lynxpawpass.com/members/"
					).on_success(
						func( _response ): 
							body = _response.fetch()
							var collegestatus
							$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountHome/label_Email.text = username
							$Control/panel_Center/content_Wallet/content_Login.visible = false
							$Control/panel_Center/content_Wallet/content_Account.visible = true
					).fetch()
			).fetch()
	).fetch()

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

func _on_ob_map_provider_item_selected(index):
	if index == 0:
		user_data["map_provider"][1] = MAP_LOADER.Provider.JAWG
	elif index == 1:
		user_data["map_provider"][1] = MAP_LOADER.Provider.BING
	user_data["map_provider"][0] = index
	save_data()
	MAP_LOADER.tile_provider = user_data["map_provider"][1]

func _on_ob_location_provider_item_selected(index):
	if index == 0:
		user_data["location_provider"][1] = "FUSED"
	elif index == 1:
		user_data["location_provider"][1] = "GPS"
	elif index == 2:
		user_data["location_provider"][1] = "NETWORK"
	elif index == 3:
		user_data["location_provider"][1] = "API"
	user_data["location_provider"][0] = index
	save_data()
	geolocation_api.set_location_provider(user_data["location_provider"][1])

func _on_btn_other_settings_next_pressed():
	var tabs = $Control/panel_Center/content_Settings/VBoxContainer/TabContainer
	tabs.current_tab += 1
	if tabs.current_tab+1 >= tabs.get_tab_count():
		$Control/panel_Center/content_Settings/VBoxContainer/hb_OtherSettingsNav/btn_OtherSettingsNext.disabled = true
	if tabs.current_tab > 0:
		$Control/panel_Center/content_Settings/VBoxContainer/hb_OtherSettingsNav/btn_OtherSettingsBack.disabled = false

func _on_btn_other_settings_back_pressed():
	var tabs = $Control/panel_Center/content_Settings/VBoxContainer/TabContainer
	tabs.current_tab -= 1
	if tabs.current_tab <= 0:
		$Control/panel_Center/content_Settings/VBoxContainer/hb_OtherSettingsNav/btn_OtherSettingsBack.disabled = true
	if tabs.current_tab+1 <= tabs.get_tab_count():
		$Control/panel_Center/content_Settings/VBoxContainer/hb_OtherSettingsNav/btn_OtherSettingsNext.disabled = false

# this will all be organized into sections in this script
func hide_all_account_pages():
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountHome.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_ManagePayments.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_BuyTickets.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_MyTickets.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_MyDevices.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_ExpiredTickets.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_OrderHistory.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_ChangePassword.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountLogout.visible = false

func _on_btn_account_home_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountHome.visible = true

func _on_btn_manage_payments_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_ManagePayments.visible = true

func _on_btn_buy_tickets_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_BuyTickets.visible = true

func _on_btn_my_tickets_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_MyTickets.visible = true

func _on_btn_my_devices_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_MyDevices.visible = true

func _on_btn_expired_tickets_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_ExpiredTickets.visible = true

func _on_btn_order_history_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_OrderHistory.visible = true

func _on_btn_change_password_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_ChangePassword.visible = true

func _on_btn_account_logout_pressed():
	hide_all_account_pages()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountLogout.visible = true
	$HTTPManager.job(
		"https://www.lynxpawpass.com/members/logout/"
	).add_header(
		"Cookie", user_data["transit_account"]["Cookie"]
	).add_header(
		"Host", "www.lynxpawpass.com"
	).add_header(
		"User-Agent", friendly_name
	).on_failure(
		func( _response ):
			print("logout error")
	).fetch()
	user_data.erase("transit_account")
	save_data()
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountLogout.visible = false
	$Control/panel_Center/content_Wallet/content_Account/HBoxContainer/vb_AccountHome.visible = true
	$Control/panel_Center/content_Wallet/content_Account.visible = false
	$Control/panel_Center/content_Wallet/content_Login.visible = true
	$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Email.editable = true
	$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/le_Password.editable = true
	$Control/panel_Center/content_Wallet/content_Login/VBoxContainer/btn_Login.disabled = false
