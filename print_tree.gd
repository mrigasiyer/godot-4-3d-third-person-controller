extends SceneTree

func _init():
    var scene = preload("res://environment/mushroom/mushroom.glb").instantiate()
    print_nodes(scene, "")
    quit()

func print_nodes(node, indent):
    print(indent + node.name)
    for child in node.get_children():
        print_nodes(child, indent + "  ")
