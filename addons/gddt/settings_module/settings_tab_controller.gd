@tool
class_name GDDTSettingsTabController extends RefCounted


const SettingsTabScript := preload("res://addons/gddt/settings_module/ui/settings_tab.gd")


var _settings_manager
var _editor_settings: EditorSettings
var _settings_tab
var _settings_tab_container: TabContainer
var _refresh_requested := true


func _init(settings_manager, editor_settings: EditorSettings) -> void:
    _settings_manager = settings_manager
    _editor_settings = editor_settings


func shutdown() -> void:
    _remove_tracking_tab()
    _settings_manager = null
    _editor_settings = null


func request_refresh() -> void:
    _refresh_requested = true


func refresh_if_needed() -> void:
    if _settings_manager == null or _editor_settings == null:
        return

    var tab_container := _find_editor_settings_tab_container()
    if tab_container == null:
        _remove_tracking_tab()
        return

    if tab_container != _settings_tab_container:
        _remove_tracking_tab()
        _settings_tab_container = tab_container

    if _settings_tab == null or not is_instance_valid(_settings_tab):
        _settings_tab = SettingsTabScript.new()
        _settings_tab.name = "GDDTSettingsTab"
        _settings_tab.initialize(_settings_manager, _editor_settings)
        _settings_tab_container.add_child(_settings_tab)
        _settings_tab_container.set_tab_title(_settings_tab.get_index(), "Godot Development Tools")
        _refresh_requested = false
        return

    if _refresh_requested and _settings_tab.get_parent() == _settings_tab_container and _settings_tab.has_method("refresh_paths"):
        _settings_tab.refresh_paths()
        _refresh_requested = false


func _remove_tracking_tab() -> void:
    if _settings_tab != null and is_instance_valid(_settings_tab):
        _settings_tab.queue_free()
    _settings_tab = null
    _settings_tab_container = null
    _refresh_requested = true


func _find_editor_settings_tab_container() -> TabContainer:
    var base_control := EditorInterface.get_base_control()
    if base_control == null:
        return null

    var tab_containers := base_control.find_children("*", "TabContainer", true, false)
    for node in tab_containers:
        var tab_container := node as TabContainer
        if _is_editor_settings_tab_container(tab_container):
            return tab_container

    return null


func _is_editor_settings_tab_container(tab_container: TabContainer) -> bool:
    if tab_container == null:
        return false
    if tab_container.get_tab_count() < 2:
        return false

    return _contains_tab_title(tab_container, "general") and _contains_tab_title(tab_container, "shortcut")


func _contains_tab_title(tab_container: TabContainer, title_fragment: String) -> bool:
    if tab_container == null:
        return false

    for tab_idx in tab_container.get_tab_count():
        var tab_title := tab_container.get_tab_title(tab_idx).to_lower()
        if tab_title.contains(title_fragment):
            return true

    return false
