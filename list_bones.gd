extends SceneTree

func _init():
    var scene = load("res://Flavio/Warrior Idle.fbx").instantiate()
    var skeleton = scene.get_node("Armature/Skeleton3D")
    if skeleton:
        for i in range(skeleton.get_bone_count()):
            print(skeleton.get_bone_name(i))
    else:
        print("Skeleton not found at Armature/Skeleton3D. Children:")
        for child in scene.get_children():
            print(child.name)
            for c in child.get_children():
                print(" - ", c.name)
    quit()
