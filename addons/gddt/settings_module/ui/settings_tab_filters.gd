@tool
extends RefCounted
class_name GDDTSettingsTabFilters


const SORT_ASC := 0
const SORT_DESC := 1
const FILTER_ALL := 0
const FILTER_TRACKED := 1
const FILTER_UNTRACKED := 2
const FILTER_CHANGED_FROM_DEFAULT := 3


static func get_path_category(setting_path: String) -> String:
    var split := setting_path.split("/", false, 1)
    if split.is_empty():
        return ""
    return String(split[0])


static func is_changed_from_default(editor_settings: EditorSettings, setting_path: String) -> bool:
    if editor_settings == null:
        return false
    if not editor_settings.has_setting(setting_path):
        return false
    if not editor_settings.property_can_revert(setting_path):
        return false

    var current_value: Variant = editor_settings.get_setting(setting_path)
    var default_value: Variant = editor_settings.property_get_revert(setting_path)
    return current_value != default_value
