@tool
extends EditorPlugin


const SettingsManagerScript := preload("res://addons/gddt/settings_module/settings_manager.gd")
const SettingsModuleScript := preload("res://addons/gddt/settings_module/settings_module.gd")

var _settings_manager
var _settings_module

var _editor_settings: EditorSettings


func _enter_tree() -> void:
    _editor_settings = EditorInterface.get_editor_settings()

    _settings_manager = SettingsManagerScript.new()
    _settings_manager.load_profile(_editor_settings)

    _settings_module = SettingsModuleScript.new()
    _settings_module.initialize(self, _settings_manager, _editor_settings)

    set_process(true)


func _exit_tree() -> void:
    printraw("\nGDDT is about to leave the SceneTree\n")

    if _settings_module != null:
        _settings_module.shutdown()
        _settings_module = null

    _settings_manager = null
    _editor_settings = null

    set_process(false)


func _process(delta: float) -> void:
    if _settings_module != null:
        _settings_module.process(delta)
