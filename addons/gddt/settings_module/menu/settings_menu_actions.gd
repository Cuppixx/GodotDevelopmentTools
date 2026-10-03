@tool
extends RefCounted
class_name GDDTSettingsMenuActions


const ACTION_APPLY := 1001
const ACTION_SAVE := 1002
const ACTION_TOGGLE_AUTO_APPLY := 1003
const ACTION_SHOW_STATUS := 1004
const ACTION_BOOTSTRAP_TRACKED := 1005
const ACTION_SUBMENU := 1010


static func handle_action(settings_manager, action_id: int) -> bool:
    if settings_manager == null:
        return false

    match action_id:
        ACTION_APPLY:
            settings_manager.apply_current_config()
            return true
        ACTION_SAVE:
            settings_manager.save_current_config_changes()
            return true
        ACTION_BOOTSTRAP_TRACKED:
            settings_manager.bootstrap_tracked_from_current_diffs()
            return true
        ACTION_TOGGLE_AUTO_APPLY:
            settings_manager.set_auto_apply_enabled(not settings_manager.is_auto_apply_enabled())
            return true

    return false
