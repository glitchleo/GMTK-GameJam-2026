extends CanvasLayer

@onready var pause_menu = $PauseMenu
@onready var game_over_menu = $GameOverMenu
@onready var final_score_label = $GameOverMenu/VBoxContainer/FinalScore

@export var player: CharacterBody2D 

func _ready():
	pause_menu.hide()
	game_over_menu.hide()

	$PauseMenu/VBoxContainer/ResumeButton.pressed.connect(unpause_game)
	$PauseMenu/VBoxContainer/MenuButton.pressed.connect(go_to_menu)

	$GameOverMenu/VBoxContainer/RestartButton.pressed.connect(restart_game)
	$GameOverMenu/VBoxContainer/MenuButton.pressed.connect(go_to_menu)

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel") and !game_over_menu.visible:
		if get_tree().paused:
			unpause_game()
		else:
			pause_game()

func pause_game():
	get_tree().paused = true
	pause_menu.show()

func unpause_game():
	get_tree().paused = false
	pause_menu.hide()

func trigger_game_over():
	get_tree().paused = true
	game_over_menu.show()
	if player:
		final_score_label.text = "FINAL SCORE: " + str(player.current_score)

func restart_game():
	get_tree().paused = false
	get_tree().reload_current_scene()

func go_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/actors/MainMenu.tscn")
