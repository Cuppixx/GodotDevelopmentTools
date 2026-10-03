@tool
class_name GDDTSettingsTrackingService extends RefCounted


var _manager


func _init(manager) -> void:
    _manager = manager


func get_tracked_setting_paths() -> Array[String]:
    var setting_paths: Array[String] = []
    for path in _manager.setting_overrides.keys():
        setting_paths.append(String(path))
    setting_paths.sort()
    return setting_paths


func get_tracked_value(setting_path: String) -> Variant:
    if not _manager.setting_overrides.has(setting_path):
        return null
    return _manager.setting_overrides[setting_path]


func get_local_divergence_paths() -> Array[String]:
    var diverged_paths: Array[String] = []
    if _manager._editor_settings == null:
        return diverged_paths

    for setting_path_variant in _manager.setting_overrides.keys():
        var setting_path := String(setting_path_variant)
        if _is_reserved_setting_path(setting_path):
            continue
        if not _manager._editor_settings.has_setting(setting_path):
            continue

        var tracked_value: Variant = _manager.setting_overrides[setting_path]
        var local_value: Variant = _manager._editor_settings.get_setting(setting_path)
        if local_value != tracked_value:
            diverged_paths.append(setting_path)

    diverged_paths.sort()
    return diverged_paths


func get_local_divergence_count() -> int:
    return get_local_divergence_paths().size()


func save_current_config_changes() -> bool:
    if _manager._editor_settings == null:
        return false

    var new_overrides := _collect_tracked_overrides()
    var saved_anything: bool = _manager.setting_overrides.size() != new_overrides.size()
    if not saved_anything:
        for setting_path in new_overrides.keys():
            if not _manager.setting_overrides.has(setting_path) or _manager.setting_overrides[setting_path] != new_overrides[setting_path]:
                saved_anything = true
                break

    if not saved_anything:
        return false

    _manager.setting_overrides = new_overrides
    _manager.config_version += 1
    _manager._profile_service._save_profile()
    return true


func bootstrap_tracked_from_current_diffs() -> int:
    if _manager._editor_settings == null:
        return 0

    var discovered_overrides := _collect_all_non_default_overrides()

    var changed := false
    if _manager.setting_overrides.size() != discovered_overrides.size():
        changed = true
    else:
        for setting_path in discovered_overrides.keys():
            if not _manager.setting_overrides.has(setting_path) or _manager.setting_overrides[setting_path] != discovered_overrides[setting_path]:
                changed = true
                break

    if not changed:
        return discovered_overrides.size()

    _manager.setting_overrides = discovered_overrides
    _manager.config_version += 1
    _manager._profile_service._save_profile()
    return discovered_overrides.size()


func get_tracked_count() -> int:
    return _manager.setting_overrides.size()


func get_apply_preview() -> Array[Dictionary]:
    var preview: Array[Dictionary] = []
    if _manager._editor_settings == null:
        return preview

    var tracked_paths := get_tracked_setting_paths()
    for setting_path in tracked_paths:
        if _is_reserved_setting_path(setting_path):
            continue
        if not _manager._editor_settings.has_setting(setting_path):
            continue

        var target_value: Variant = _manager.setting_overrides[setting_path]
        var current_value: Variant = _manager._editor_settings.get_setting(setting_path)
        if current_value == target_value:
            continue

        preview.append({
            "path": setting_path,
            "current_value": current_value,
            "target_value": target_value,
        })

    return preview


func is_setting_tracked(setting_path: String) -> bool:
    return _manager.setting_overrides.has(setting_path)


func set_setting_tracked(setting_path: String, tracked: bool) -> bool:
    if setting_path.is_empty() or _manager._editor_settings == null:
        return false
    if _is_reserved_setting_path(setting_path):
        return false
    if tracked and not _manager._editor_settings.has_setting(setting_path):
        return false

    var changed := false
    if tracked:
        var current_value: Variant = _manager._editor_settings.get_setting(setting_path)
        if not _manager.setting_overrides.has(setting_path) or _manager.setting_overrides[setting_path] != current_value:
            _manager.setting_overrides[setting_path] = current_value
            changed = true
    else:
        if _manager.setting_overrides.erase(setting_path):
            changed = true

    if changed:
        _manager.config_version += 1
        _manager._profile_service._save_profile()

    return changed


func set_settings_tracked(setting_paths: Array[String], tracked: bool) -> int:
    if _manager._editor_settings == null:
        return 0

    var changed_count := 0
    for setting_path in setting_paths:
        if setting_path.is_empty() or _is_reserved_setting_path(setting_path):
            continue
        if not _manager._editor_settings.has_setting(setting_path):
            continue

        if tracked:
            var current_value: Variant = _manager._editor_settings.get_setting(setting_path)
            if not _manager.setting_overrides.has(setting_path) or _manager.setting_overrides[setting_path] != current_value:
                _manager.setting_overrides[setting_path] = current_value
                changed_count += 1
        else:
            if _manager.setting_overrides.erase(setting_path):
                changed_count += 1

    if changed_count > 0:
        _manager.config_version += 1
        _manager._profile_service._save_profile()

    return changed_count


func toggle_setting_tracked(setting_path: String) -> bool:
    var tracked := not is_setting_tracked(setting_path)
    return set_setting_tracked(setting_path, tracked)


func _collect_tracked_overrides() -> Dictionary:
    var overrides: Dictionary = {}
    for setting_path_variant in _manager.setting_overrides.keys():
        var setting_path := String(setting_path_variant)
        if _is_reserved_setting_path(setting_path):
            continue
        if not _manager._editor_settings.has_setting(setting_path):
            continue

        overrides[setting_path] = _manager._editor_settings.get_setting(setting_path)
    return overrides


func _collect_all_non_default_overrides() -> Dictionary:
    var overrides: Dictionary = {}
    for property_info in _manager._editor_settings.get_property_list():
        if typeof(property_info) != TYPE_DICTIONARY:
            continue

        var property_name := String(property_info.get("name", ""))
        if property_name.is_empty():
            continue
        if _is_reserved_setting_path(property_name):
            continue
        if not property_name.contains("/"):
            continue
        if not _manager._editor_settings.has_setting(property_name):
            continue
        if not _manager._editor_settings.property_can_revert(property_name):
            continue

        var current_value: Variant = _manager._editor_settings.get_setting(property_name)
        var default_value: Variant = _manager._editor_settings.property_get_revert(property_name)
        if current_value != default_value:
            overrides[property_name] = current_value

    return overrides


func _is_reserved_setting_path(setting_path: String) -> bool:
    return setting_path == _manager.LOCAL_APPLIED_VERSION_KEY
