@tool
class_name OSMMapProvider
extends MapProvider

func _construct_url(args: Dictionary) -> String:
	var url: String

	match self.map_style:
		MapType.SATELLITE:
			url = "https://a.tile.openstreetmap.org/{zoom}/{x}/{y}.png"
			args["format"] = MapTile.Format.PNG
		_:
			url = "invalid://server {server}/quad {quad}/x {x}/y {y}/zoom {zoom}/lang {lang}/api {api}"
			args["format"] = MapTile.Format.BMP

	return url.format(args)

func _url_to_cache(url: String, args: Dictionary) -> String:
	args["md5"] = url.md5_text()
	return "user://tiles/osm/{zoom}/{md5}.tile".format(args)
