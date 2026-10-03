@tool
class_name GDDTSettingsValidationService extends RefCounted


var _manager


func _init(manager) -> void:
    _manager = manager


func run_self_checks() -> Dictionary:
    var details: Array[String] = []
    var passed := true

    if _manager._editor_settings == null:
        details.append("FAIL: EditorSettings is null.")
        return {"passed": false, "details": details}

    var backup_overrides: Dictionary = _manager.setting_overrides.duplicate(true)
    var backup_config_version: int = _manager.config_version
    var backup_applied_version: int = _manager._applied_version
    var backup_snapshot: Dictionary = _manager._last_apply_snapshot.duplicate(true)
    var backup_snapshot_applied_version: int = _manager._last_apply_snapshot_applied_version

    var temp_key := "gddt/self_check/temp"
    var had_temp: bool = _manager._editor_settings.has_setting(temp_key)
    var temp_backup_value: Variant = null
    if had_temp:
        temp_backup_value = _manager._editor_settings.get_setting(temp_key)

    _manager._editor_settings.set_setting(temp_key, 1)

    if is_valid_editor_setting_path(_manager.LOCAL_APPLIED_VERSION_KEY):
        passed = false
        details.append("FAIL: Reserved applied-version key is trackable.")
    else:
        details.append("PASS: Reserved applied-version key remains non-trackable.")

    if not _manager._tracking_service.set_setting_tracked(temp_key, true):
        passed = false
        details.append("FAIL: Could not track a valid temporary setting path.")
    elif not _manager._tracking_service.is_setting_tracked(temp_key):
        passed = false
        details.append("FAIL: Temporary setting path was not marked tracked.")
    else:
        details.append("PASS: Track flow works for a temporary setting path.")

    if not _manager._tracking_service.set_setting_tracked(temp_key, false):
        passed = false
        details.append("FAIL: Could not untrack a temporary setting path.")
    else:
        details.append("PASS: Untrack flow works for a temporary setting path.")

    _manager._editor_settings.set_setting(temp_key, 5)
    _manager._tracking_service.set_setting_tracked(temp_key, true)
    _manager._editor_settings.set_setting(temp_key, 9)

    var preview_rows: Array[Dictionary] = _manager._tracking_service.get_apply_preview()
    if preview_rows.is_empty():
        passed = false
        details.append("FAIL: Apply preview produced no rows for a diverged tracked setting.")
    else:
        details.append("PASS: Apply preview detects pending changes.")

    if not _manager._apply_service.apply_current_config():
        passed = false
        details.append("FAIL: Apply flow reported no changes for a diverged tracked setting.")
    elif int(_manager._editor_settings.get_setting(temp_key)) != 5:
        passed = false
        details.append("FAIL: Apply flow did not restore tracked value.")
    else:
        details.append("PASS: Apply flow updates local setting to tracked value.")

    if not _manager._apply_service.rollback_last_apply_snapshot():
        passed = false
        details.append("FAIL: Rollback flow did not restore pre-apply snapshot.")
    elif int(_manager._editor_settings.get_setting(temp_key)) != 9:
        passed = false
        details.append("FAIL: Rollback restored an unexpected value.")
    else:
        details.append("PASS: Rollback flow restores the pre-apply local value.")

    var lock_changed: bool = _manager._profile_service.enforce_local_applied_version_lock()
    details.append("PASS: Reserved lock enforcement executed%s." % (" (changed state)" if lock_changed else ""))

    _manager.setting_overrides = backup_overrides
    _manager.config_version = backup_config_version
    _manager._applied_version = backup_applied_version
    _manager._last_apply_snapshot = backup_snapshot
    _manager._last_apply_snapshot_applied_version = backup_snapshot_applied_version

    if had_temp:
        _manager._editor_settings.set_setting(temp_key, temp_backup_value)
    elif _manager._editor_settings.has_method("erase") and _manager._editor_settings.has_setting(temp_key):
        _manager._editor_settings.call("erase", temp_key)

    _manager._profile_service._save_local_applied_version()
    _manager._profile_service._save_profile()

    return {"passed": passed, "details": details}


func is_valid_editor_setting_path(setting_path: String) -> bool:
    if _manager._editor_settings == null:
        return false
    if setting_path.is_empty():
        return false
    if _manager._tracking_service._is_reserved_setting_path(setting_path):
        return false
    return _manager._editor_settings.has_setting(setting_path)
