extends SceneTree

func _init():
    var tree = AnimationNodeBlendTree.new()
    for method in tree.get_method_list():
        if method.name == "connect_node":
            print("CONNECT NODE ARGS:")
            print(method.args)
    quit()
