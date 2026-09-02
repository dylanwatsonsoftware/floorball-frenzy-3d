extends SceneTree


const ApiEndpointScript = preload("res://scripts/network/api_endpoint.gd")


func _init() -> void:
	if ApiEndpointScript.base_for_origin("https://floorball-frenzy-3d.vercel.app") != "https://floorball-frenzy-3d.vercel.app/api":
		fail("Production matchmaking URLs must be absolute and same-origin")
		return
	if ApiEndpointScript.base_for_origin("https://preview-name.vercel.app/") != "https://preview-name.vercel.app/api":
		fail("Preview deployments must resolve matchmaking against their own origin")
		return
	if not ApiEndpointScript.is_absolute("https://preview-name.vercel.app/api/lobby") or ApiEndpointScript.is_absolute("/api/lobby"):
		fail("Godot HTTPRequest must never receive a relative matchmaking URL")
		return
	print("Matchmaking endpoints expand to absolute same-origin URLs.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
