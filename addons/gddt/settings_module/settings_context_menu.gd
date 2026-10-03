@tool
class_name GDDTSettingsContextMenu extends EditorContextMenuPlugin


var _settings_manager


func _init(settings_manager) -> void:
    _settings_manager = settings_manager


func attach_to(plugin: EditorPlugin) -> void:
    if plugin == null:
        return
    if not plugin.has_method("add_context_menu_plugin"):
        return

    plugin.call("add_context_menu_plugin", EditorContextMenuPlugin.CONTEXT_SLOT_INSPECTOR_PROPERTY, self)


func detach_from(plugin: EditorPlugin) -> void:
    if plugin == null:
        return
    if not plugin.has_method("remove_context_menu_plugin"):
        return

    plugin.call("remove_context_menu_plugin", self)


func get_settings_manager():
    return _settings_manager
