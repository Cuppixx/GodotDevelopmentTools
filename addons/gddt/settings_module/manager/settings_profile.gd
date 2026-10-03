@tool
class_name GDDTSettingsProfileService extends RefCounted


var _manager


func _init(manager) -> void:
    _manager = manager


func load_profile(editor_settings: EditorSettings) -> void:
    _manager._editor_settings = editor_settings
    var loaded_profile := _load_from_disk()
    if loaded_profile != null:
        _manager.config_version = loaded_profile.config_version
        _manager.auto_apply_enabled = loaded_profile.auto_apply_enabled
        _manager.setting_overrides = loaded_profile.setting_overrides.duplicate(true)
        _manager.risky_warning_keywords = loaded_profile.get_risky_warning_keywords()
        _manager.tracked_editor_layouts = loaded_profile.tracked_editor_layouts.duplicate(true)
    else:
        _save_profile()

    _load_local_applied_version()


func set_auto_apply_enabled(enabled: bool) -> void:
    _manager.auto_apply_enabled = enabled
    _save_profile()


func get_default_risky_warning_keywords() -> Array[String]:
    return _manager.DEFAULT_RISKY_WARNING_KEYWORDS.duplicate()


func get_risky_warning_keywords() -> Array[String]:
    var result: Array[String] = []
    for keyword_variant in _manager.risky_warning_keywords:
        result.append(String(keyword_variant))
    return result


func set_risky_warning_keywords(keywords: Array[String]) -> bool:
    var sanitized: Array[String] = []
    var seen := {}
    for keyword_variant in keywords:
        var keyword := String(keyword_variant).strip_edges().to_lower()
        if keyword.is_empty() or seen.has(keyword):
            continue
        sanitized.append(keyword)
        seen[keyword] = true

    var changed: bool = _manager.risky_warning_keywords.size() != sanitized.size()
    if not changed:
        for idx in sanitized.size():
            if _manager.risky_warning_keywords[idx] != sanitized[idx]:
                changed = true
                break

    if not changed:
        return false

    _manager.risky_warning_keywords = sanitized
    _save_profile()
    return true


func reset_risky_warning_keywords_to_default() -> bool:
    return set_risky_warning_keywords(get_default_risky_warning_keywords())


func _load_from_disk() -> Resource:
    if not FileAccess.file_exists(_manager.SETTINGS_PATH):
        return null

    return ResourceLoader.load(_manager.SETTINGS_PATH)


func _save_profile() -> void:
    ResourceSaver.save(_manager, _manager.SETTINGS_PATH)


func _load_local_applied_version() -> void:
    if _manager._editor_settings == null:
        _manager._applied_version = 0
        return

    var metadata_applied_version := int(_manager._editor_settings.get_project_metadata(
        _manager.LOCAL_APPLIED_VERSION_SECTION,
        _manager.LOCAL_APPLIED_VERSION_METADATA_KEY,
        0
    ))

    var resolved_applied_version := metadata_applied_version
    if _manager._editor_settings.has_setting(_manager.LOCAL_APPLIED_VERSION_KEY):
        resolved_applied_version = int(_manager._editor_settings.get_setting(_manager.LOCAL_APPLIED_VERSION_KEY))

    _manager._applied_version = resolved_applied_version
    _save_local_applied_version()


func _save_local_applied_version() -> void:
    if _manager._editor_settings == null:
        return

    _manager._editor_settings.set_project_metadata(
        _manager.LOCAL_APPLIED_VERSION_SECTION,
        _manager.LOCAL_APPLIED_VERSION_METADATA_KEY,
        _manager._applied_version
    )
    _erase_legacy_local_applied_version_setting()


func enforce_local_applied_version_lock() -> bool:
    if _manager._editor_settings == null:
        return false

    var changed := false
    var metadata_value := int(_manager._editor_settings.get_project_metadata(
        _manager.LOCAL_APPLIED_VERSION_SECTION,
        _manager.LOCAL_APPLIED_VERSION_METADATA_KEY,
        _manager._applied_version
    ))
    if metadata_value != _manager._applied_version:
        _manager._editor_settings.set_project_metadata(
            _manager.LOCAL_APPLIED_VERSION_SECTION,
            _manager.LOCAL_APPLIED_VERSION_METADATA_KEY,
            _manager._applied_version
        )
        changed = true

    if _erase_legacy_local_applied_version_setting():
        changed = true

    return changed


func _erase_legacy_local_applied_version_setting() -> bool:
    if _manager._editor_settings == null:
        return false
    if not _manager._editor_settings.has_setting(_manager.LOCAL_APPLIED_VERSION_KEY):
        return false
    if _manager._editor_settings.has_method("erase"):
        _manager._editor_settings.call("erase", _manager.LOCAL_APPLIED_VERSION_KEY)
        return true
    return false
