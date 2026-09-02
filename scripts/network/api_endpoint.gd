class_name ApiEndpoint
extends RefCounted


const PRODUCTION_ORIGIN := "https://floorball-frenzy-3d.vercel.app"


static func current_base() -> String:
	var origin := PRODUCTION_ORIGIN
	if OS.has_feature("web"):
		var browser_origin = JavaScriptBridge.eval("window.location.origin")
		if browser_origin != null and is_absolute(String(browser_origin)):
			origin = String(browser_origin)
	return base_for_origin(origin)


static func base_for_origin(origin: String) -> String:
	return origin.trim_suffix("/") + "/api"


static func is_absolute(url: String) -> bool:
	return url.begins_with("https://") or url.begins_with("http://")
