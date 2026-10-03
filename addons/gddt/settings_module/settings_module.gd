@tool
class_name GDDTSettingsModule extends RefCounted


const SettingsManagerScript := preload("res://addons/gddt/settings_module/manager/settings_manager.gd")
const SettingsContextMenuScript := preload("res://addons/gddt/settings_module/settings_context_menu.gd")
const SettingsMenuScript := preload("res://addons/gddt/settings_module/menu/settings_menu.gd")
const SettingsTabControllerScript := preload("res://addons/gddt/settings_module/settings_tab_controller.gd")

var _plugin: EditorPlugin
var _settings_manager
var _editor_settings: EditorSettings
var _settings_context_menu_plugin
var _settings_menu
var _settings_tab_controller
var _ui_refresh_accumulator := 0.0


func initialize(plugin: EditorPlugin, settings_manager, editor_settings: EditorSettings) -> void:
    _plugin = plugin
    _settings_manager = settings_manager
    _editor_settings = editor_settings

    _settings_manager.state_changed.connect(_on_settings_manager_state_changed)
    _editor_settings.settings_changed.connect(_on_editor_settings_changed)

    _settings_context_menu_plugin = SettingsContextMenuScript.new(_settings_manager)
    if _settings_context_menu_plugin is EditorContextMenuPlugin and _plugin != null:
        if _plugin.has_method("add_context_menu_plugin"):
            _plugin.add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_INSPECTOR_PROPERTY, _settings_context_menu_plugin)

    _settings_menu = SettingsMenuScript.new()
    _settings_menu.initialize(_plugin, _settings_manager)

    _settings_tab_controller = SettingsTabControllerScript.new(_settings_manager, _editor_settings)


func shutdown() -> void:
    if _editor_settings != null and _editor_settings.settings_changed.is_connected(_on_editor_settings_changed):
        _editor_settings.settings_changed.disconnect(_on_editor_settings_changed)

    if _settings_manager != null and _settings_manager.state_changed.is_connected(_on_settings_manager_state_changed):
        _settings_manager.state_changed.disconnect(_on_settings_manager_state_changed)

    if _settings_context_menu_plugin != null and _plugin != null and _plugin.has_method("remove_context_menu_plugin"):
        _plugin.remove_context_menu_plugin(_settings_context_menu_plugin)
        _settings_context_menu_plugin = null

    if _settings_menu != null:
        _settings_menu.shutdown()
        _settings_menu = null

    if _settings_tab_controller != null:
        _settings_tab_controller.shutdown()
        _settings_tab_controller = null

    _settings_manager = null
    _editor_settings = null
    _plugin = null


func process(delta: float) -> void:
    _ui_refresh_accumulator += delta
    if _ui_refresh_accumulator < 0.5:
        return
    _ui_refresh_accumulator = 0.0

    if _settings_tab_controller != null:
        _settings_tab_controller.refresh_if_needed()


func _on_settings_manager_state_changed() -> void:
    if _settings_menu != null:
        _settings_menu.on_settings_state_changed()
    if _settings_tab_controller != null:
        _settings_tab_controller.request_refresh()


func _on_editor_settings_changed() -> void:
    if _settings_manager == null or _settings_manager.has_method("enforce_local_applied_version_lock") == false:
        return
    _settings_manager.enforce_local_applied_version_lock()
    if _settings_tab_controller != null:
        _settings_tab_controller.request_refresh()
