@tool
class_name JawgMapProvider
extends MapProvider

@export var referrer := "openlynx_mobile"
@export var token := "VJHQdPffNjyivX97kVme0UQRPjMEBHG9wDTS0jCab1piq2KDAmoPu1wpi9W9qFTE" 
# later in settings will have choose map provider
# my custom styles will require small liberapay donation
# many styles should be available soon
# input liberapay userid or auth token and once verified, server will send token? else do it louis rossman way
# need to check tile files for last modified, if 4 days old then update, could make longer

func _construct_url(args: Dictionary) -> String:
	var url: String

	match self.map_style:
		MapType.DARK_OPENLYNX:
			url = "https://tile.jawg.io/511b2a44-abfc-4666-8092-55cac07a0a35/{zoom}/{x}/{y}.png?access-token="+token
			args["format"] = MapTile.Format.PNG
		MapType.STREET:
			url = "https://tile.jawg.io/jawg-streets/{zoom}/{x}/{y}.png?access-token="+token
			args["format"] = MapTile.Format.PNG
		MapType.DARK:
			url = "https://tile.jawg.io/jawg-dark/{zoom}/{x}/{y}.png?access-token="+token
			args["format"] = MapTile.Format.PNG
		MapType.LIGHT:
			url = "https://tile.jawg.io/jawg-light/{zoom}/{x}/{y}.png?access-token="+token
			args["format"] = MapTile.Format.PNG
		_:
			url = "invalid://server {server}/quad {quad}/x {x}/y {y}/zoom {zoom}/lang {lang}/api {api}"
			args["format"] = MapTile.Format.BMP

	return url.format(args)


func _url_to_cache(url: String, args: Dictionary) -> String:
	args["md5"] = url.md5_text()
	return "user://tiles/jawg/{zoom}/{md5}.tile".format(args)
