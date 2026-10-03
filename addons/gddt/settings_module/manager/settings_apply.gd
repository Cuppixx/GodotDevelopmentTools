@tool
class_name GDDTSettingsApplyService extends RefCounted


var _manager


func _init(manager) -> void:
    _manager = manager


func apply_current_config() -> bool:
    if _manager._editor_settings == null:
        return false

    var applied_anything := false
    var snapshot: Dictionary = {}
    for setting_key_variant in _manager.setting_overrides.keys():
        var setting_key := String(setting_key_variant)
        if _manager._tracking_service._is_reserved_setting_path(setting_key):
            continue
        if not _manager._editor_settings.has_setting(setting_key):
            continue

        var target_value: Variant = _manager.setting_overrides[setting_key]
        if _manager._editor_settings.get_setting(setting_key) != target_value:
            snapshot[setting_key] = _manager._editor_settings.get_setting(setting_key)
            _manager._editor_settings.set_setting(setting_key, target_value)
            applied_anything = true

    if applied_anything:
        _manager._last_apply_snapshot = snapshot
        _manager._last_apply_snapshot_applied_version = _manager._applied_version

    _manager._applied_version = _manager.config_version
    var applied_layouts: bool = _manager._layouts_service._apply_tracked_editor_layouts()
    _manager._profile_service._save_local_applied_version()
    _manager._profile_service._save_profile()
    return applied_anything or applied_layouts


func apply_current_config_if_needed() -> bool:
    if not _manager.auto_apply_enabled:
        return false
    if _manager.config_version <= _manager._applied_version:
        return false
    return apply_current_config()


func get_status_text() -> String:
    return "Version %d | Applied %d | Tracked %d | Drift %d | Sync: %s | Auto: %s" % [
        _manager.config_version,
        _manager._applied_version,
        _manager.setting_overrides.size(),
        _manager.get_local_divergence_count(),
        _manager.get_sync_state_text(),
        "On" if _manager.auto_apply_enabled else "Off",
    ]


func get_sync_state_text() -> String:
    var is_version_outdated: bool = _manager.config_version > _manager._applied_version
    var divergence_count: int = _manager.get_local_divergence_count()
    if not is_version_outdated and divergence_count == 0:
        return "In Sync"

    if is_version_outdated and divergence_count > 0:
        return "Out of Sync (Version + Drift)"
    if is_version_outdated:
        return "Out of Sync (Version)"
    return "Out of Sync (Drift)"


func has_apply_rollback_snapshot() -> bool:
    return _manager._last_apply_snapshot.size() > 0


func get_apply_rollback_snapshot_count() -> int:
    return _manager._last_apply_snapshot.size()


func rollback_last_apply_snapshot() -> bool:
    if _manager._editor_settings == null:
        return false
    if _manager._last_apply_snapshot.is_empty():
        return false

    var rolled_back_anything := false
    for setting_path_variant in _manager._last_apply_snapshot.keys():
        var setting_path := String(setting_path_variant)
        if not _manager._editor_settings.has_setting(setting_path):
            continue

        var rollback_value: Variant = _manager._last_apply_snapshot[setting_path]
        if _manager._editor_settings.get_setting(setting_path) != rollback_value:
            _manager._editor_settings.set_setting(setting_path, rollback_value)
            rolled_back_anything = true

    _manager._applied_version = _manager._last_apply_snapshot_applied_version
    _manager._profile_service._save_local_applied_version()
    _manager._clear_apply_rollback_snapshot()
    return rolled_back_anything


func _clear_apply_rollback_snapshot() -> void:
    _manager._last_apply_snapshot.clear()
    _manager._last_apply_snapshot_applied_version = _manager._applied_version
