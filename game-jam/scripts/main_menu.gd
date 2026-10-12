extends Control

func _ready():
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://Scenes/levels/MainGame.tscn")

func _on_quit_pressed():
	get_tree().quit()
