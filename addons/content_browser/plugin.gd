@tool
extends EditorPlugin
## Adds the "Content" tab at the top of the editor (next to 2D / 3D / Script / AssetLib).
## All the work happens in content_browser.gd.

const Browser := preload("res://addons/content_browser/content_browser.gd")

var _panel


func _enter_tree() -> void:
	_panel = Browser.new()
	_panel.setup(EditorInterface)
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)


func _exit_tree() -> void:
	if _panel:
		_panel.flush()
		_panel.queue_free()
		_panel = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _panel:
		_panel.visible = visible
		if visible:
			_panel.on_shown()


func _get_plugin_name() -> String:
	return "Content"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("ResourcePreloader", "EditorIcons")


## Called when the editor saves (Ctrl+S, running the game...): write any edit still waiting.
func _save_external_data() -> void:
	if _panel:
		_panel.flush()
