@tool
extends Resource


signal state_changed


const SETTINGS_PATH := "res://addons/gddt/settings_module/settings.tres"
const LOCAL_APPLIED_VERSION_KEY := "gddt/shared_settings/applied_version"
const LOCAL_APPLIED_VERSION_SECTION := "gddt_shared_settings"
const LOCAL_APPLIED_VERSION_METADATA_KEY := "applied_version"
const DEFAULT_VERSION := 1
const PROJECT_EDITOR_LAYOUTS_PATH := "res://.godot/editor/editor_layouts.cfg"
const GLOBAL_EDITOR_LAYOUTS_FILE_NAME := "editor_layouts.cfg"
const DEFAULT_RISKY_WARNING_KEYWORDS: Array[String] = [
  "password", "passwd", "passphrase", "token", "secret", "private", "key", "apikey", "api_key",
  "auth", "oauth", "jwt", "bearer", "cookie", "credential", "credentials",
  "user", "username", "home", "profile", "local", "machine", "device", "host", "hostname",
  "path", "dir", "directory", "folder", "file", "filepath", "filename", "mount",
  "sdk", "ndk", "jdk", "toolchain", "executable", "exec", "binary", "bin", "interpreter",
  "env", "dotenv", "production", "staging", "development", "debug", "release",
  "filesystem", "editor_data", "cache", "temp", "import", "export", "addons", "plugin", "script",
]

const SettingsProfileServiceScript := preload("res://addons/gddt/settings_module/manager/settings_profile.gd")
const SettingsTrackingServiceScript := preload("res://addons/gddt/settings_module/manager/settings_tracking.gd")
const SettingsApplyServiceScript := preload("res://addons/gddt/settings_module/manager/settings_apply.gd")
const SettingsLayoutsServiceScript := preload("res://addons/gddt/settings_module/manager/settings_layouts.gd")
const SettingsValidationServiceScript := preload("res://addons/gddt/settings_module/manager/settings_validation.gd")

@export var config_version := DEFAULT_VERSION
@export var auto_apply_enabled := true
@export var setting_overrides: Dictionary = {}
@export var risky_warning_keywords: Array[String] = DEFAULT_RISKY_WARNING_KEYWORDS.duplicate()
@export var tracked_editor_layouts: Dictionary = {}

var _editor_settings: EditorSettings
var _applied_version := 0
var _last_apply_snapshot: Dictionary = {}
var _last_apply_snapshot_applied_version := 0
var _profile_service
var _tracking_service
var _apply_service
var _layouts_service
var _validation_service


func _init() -> void:
    _profile_service = SettingsProfileServiceScript.new(self)
    _tracking_service = SettingsTrackingServiceScript.new(self)
    _apply_service = SettingsApplyServiceScript.new(self)
    _layouts_service = SettingsLayoutsServiceScript.new(self)
    _validation_service = SettingsValidationServiceScript.new(self)


func load_profile(editor_settings: EditorSettings) -> void:
    _profile_service.load_profile(editor_settings)
    state_changed.emit()
    if auto_apply_enabled and config_version > _applied_version:
        apply_current_config()


func get_config_version() -> int:
    return config_version


func get_applied_version() -> int:
    return _applied_version


func is_auto_apply_enabled() -> bool:
    return auto_apply_enabled


func set_auto_apply_enabled(enabled: bool) -> void:
    _profile_service.set_auto_apply_enabled(enabled)
    state_changed.emit()


func get_tracked_setting_paths() -> Array[String]:
    return _tracking_service.get_tracked_setting_paths()


func get_tracked_editor_layout_names() -> Array[String]:
    return _layouts_service.get_tracked_editor_layout_names()


func get_available_editor_layout_names() -> Array[String]:
    return _layouts_service.get_available_editor_layout_names()


func get_tracked_editor_layout_package_roots() -> Array[String]:
    return _layouts_service.get_tracked_editor_layout_package_roots()


func get_tracked_editor_layout_package_sections(layout_root: String) -> Dictionary:
    return _layouts_service.get_tracked_editor_layout_package_sections(layout_root)


func install_tracked_editor_layout_package(layout_root: String) -> bool:
    return _layouts_service.install_tracked_editor_layout_package(layout_root)


func set_tracked_editor_layout_names(layout_names: Array[String]) -> int:
    var changed_count: int = _layouts_service.set_tracked_editor_layout_names(layout_names)
    if changed_count > 0:
        state_changed.emit()
    return changed_count


func get_default_risky_warning_keywords() -> Array[String]:
    return _profile_service.get_default_risky_warning_keywords()


func get_risky_warning_keywords() -> Array[String]:
    return _profile_service.get_risky_warning_keywords()


func set_risky_warning_keywords(keywords: Array[String]) -> bool:
    var changed: bool = _profile_service.set_risky_warning_keywords(keywords)
    if changed:
        state_changed.emit()
    return changed


func reset_risky_warning_keywords_to_default() -> bool:
    var changed: bool = _profile_service.reset_risky_warning_keywords_to_default()
    if changed:
        state_changed.emit()
    return changed


func save_current_config_changes() -> bool:
    var changed: bool = _tracking_service.save_current_config_changes()
    if changed:
        state_changed.emit()
    return changed


func bootstrap_tracked_from_current_diffs() -> int:
    var count: int = _tracking_service.bootstrap_tracked_from_current_diffs()
    if count > 0:
        state_changed.emit()
    return count


func apply_current_config() -> bool:
    var applied_anything: bool = _apply_service.apply_current_config()
    if applied_anything:
        state_changed.emit()
    return applied_anything


func apply_current_config_if_needed() -> bool:
    var changed: bool = _apply_service.apply_current_config_if_needed()
    if changed:
        state_changed.emit()
    return changed


func get_status_text() -> String:
    return _apply_service.get_status_text()


func get_sync_state_text() -> String:
    return _apply_service.get_sync_state_text()


func get_tracked_count() -> int:
    return _tracking_service.get_tracked_count()


func get_tracked_value(setting_path: String) -> Variant:
    return _tracking_service.get_tracked_value(setting_path)


func get_local_divergence_paths() -> Array[String]:
    return _tracking_service.get_local_divergence_paths()


func get_local_divergence_count() -> int:
    return _tracking_service.get_local_divergence_count()


func get_apply_preview() -> Array[Dictionary]:
    return _tracking_service.get_apply_preview()


func has_apply_rollback_snapshot() -> bool:
    return _apply_service.has_apply_rollback_snapshot()


func get_apply_rollback_snapshot_count() -> int:
    return _apply_service.get_apply_rollback_snapshot_count()


func rollback_last_apply_snapshot() -> bool:
    var changed: bool = _apply_service.rollback_last_apply_snapshot()
    if changed:
        state_changed.emit()
    return changed


func run_self_checks() -> Dictionary:
    var result: Dictionary = _validation_service.run_self_checks()
    if result != null:
        state_changed.emit()
    return result


func is_setting_tracked(setting_path: String) -> bool:
    return _tracking_service.is_setting_tracked(setting_path)


func is_valid_editor_setting_path(setting_path: String) -> bool:
    return _validation_service.is_valid_editor_setting_path(setting_path)


func set_setting_tracked(setting_path: String, tracked: bool) -> bool:
    var changed: bool = _tracking_service.set_setting_tracked(setting_path, tracked)
    if changed:
        state_changed.emit()
    return changed


func set_settings_tracked(setting_paths: Array[String], tracked: bool) -> int:
    var changed_count: int = _tracking_service.set_settings_tracked(setting_paths, tracked)
    if changed_count > 0:
        state_changed.emit()
    return changed_count


func toggle_setting_tracked(setting_path: String) -> bool:
    return set_setting_tracked(setting_path, not is_setting_tracked(setting_path))


func _load_from_disk() -> Resource:
    return _profile_service._load_from_disk()


func _save_profile() -> void:
    _profile_service._save_profile()


func _load_local_applied_version() -> void:
    _profile_service._load_local_applied_version()


func _save_local_applied_version() -> void:
    _profile_service._save_local_applied_version()


func enforce_local_applied_version_lock() -> bool:
    var changed: bool = _profile_service.enforce_local_applied_version_lock()
    if changed:
        state_changed.emit()
    return changed


func _clear_apply_rollback_snapshot() -> void:
    _apply_service._clear_apply_rollback_snapshot()


func _is_reserved_setting_path(setting_path: String) -> bool:
    return _tracking_service._is_reserved_setting_path(setting_path)
