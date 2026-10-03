@tool
extends RefCounted
class_name GDDTEditorLayoutManager


var _settings_manager


func _init(settings_manager) -> void:
    _settings_manager = settings_manager


func get_settings_manager():
    return _settings_manager


func install_tracked_layout(layout_root: String) -> bool:
    if _settings_manager == null:
        return false
    return _settings_manager.install_tracked_editor_layout_package(layout_root)
