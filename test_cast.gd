extends SceneTree

func _init():
    var player = Player.new()
    if player is Player:
        print(player._character_skin)
    quit()
