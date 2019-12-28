tool
extends EditorPlugin

var main_interface

func _enter_tree():
	main_interface = preload("res://addons/simple_asset_studio/MainInterface.tscn").instance()
	main_interface.plugin = self
	get_editor_interface().get_editor_viewport().add_child(main_interface)
	make_visible(false)

func _exit_tree():
	main_interface.queue_free()

func has_main_screen():
	return true

func make_visible(visible):
	main_interface.visible = visible
	
func get_plugin_name():
	return "Studio"

func get_plugin_icon():
	return preload("res://addons/simple_asset_studio/icon.png")
