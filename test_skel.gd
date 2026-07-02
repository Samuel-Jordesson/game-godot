extends SceneTree
func _init():
	var skel = Skeleton3D.new()
	for m in skel.get_method_list():
		if "bone" in m["name"].to_lower() and "pose" in m["name"].to_lower():
			print(m["name"])
	quit()
