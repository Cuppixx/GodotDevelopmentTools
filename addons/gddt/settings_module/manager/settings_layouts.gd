@tool
class_name GDDTSettingsLayoutsService extends RefCounted


var _manager


func _init(manager) -> void:
    _manager = manager


func get_tracked_editor_layout_names() -> Array[String]:
    var layout_names: Array[String] = []
    for layout_name_variant in _manager.tracked_editor_layouts.keys():
        layout_names.append(String(layout_name_variant))
    layout_names.sort()
    return layout_names


func get_available_editor_layout_names() -> Array[String]:
    var names_map := {}
    var file_paths := _get_editor_layout_candidate_paths()
    for file_path in file_paths:
        var sections := _load_layout_sections_from_file(file_path)
        for section_name_variant in sections.keys():
            names_map[String(section_name_variant)] = true

    for tracked_name_variant in _manager.tracked_editor_layouts.keys():
        names_map[String(tracked_name_variant)] = true

    var result: Array[String] = []
    for name_variant in names_map.keys():
        result.append(String(name_variant))
    result.sort()
    return result


func get_tracked_editor_layout_package_roots() -> Array[String]:
    var roots := {}
    for section_name_variant in _manager.tracked_editor_layouts.keys():
        var section_name := String(section_name_variant)
        var slash_index := section_name.find("/")
        var root_name := section_name if slash_index < 0 else section_name.substr(0, slash_index)
        if root_name.is_empty():
            continue
        roots[root_name] = true

    var result: Array[String] = []
    for root_variant in roots.keys():
        result.append(String(root_variant))
    result.sort()
    return result


func get_tracked_editor_layout_package_sections(layout_root: String) -> Dictionary:
    var package_sections: Dictionary = {}
    var prefix := layout_root + "/"
    for section_name_variant in _manager.tracked_editor_layouts.keys():
        var section_name := String(section_name_variant)
        if section_name == layout_root or section_name.begins_with(prefix):
            package_sections[section_name] = _manager.tracked_editor_layouts[section_name]
    return package_sections


func install_tracked_editor_layout_package(layout_root: String) -> bool:
    var root_name := layout_root.strip_edges()
    if root_name.is_empty():
        return false

    var package_sections := get_tracked_editor_layout_package_sections(root_name)
    if package_sections.is_empty():
        return false

    return _save_layout_sections_to_project(package_sections)


func set_tracked_editor_layout_names(layout_names: Array[String]) -> int:
    var normalized_names: Array[String] = []
    var seen := {}
    for name_variant in layout_names:
        var layout_name := String(name_variant).strip_edges()
        if layout_name.is_empty() or seen.has(layout_name):
            continue
        normalized_names.append(layout_name)
        seen[layout_name] = true

    var changed_count := 0
    var next_tracked: Dictionary = {}
    for layout_name in normalized_names:
        var captured_data := _capture_editor_layout_section(layout_name)
        if captured_data.is_empty() and _manager.tracked_editor_layouts.has(layout_name):
            captured_data = _manager.tracked_editor_layouts[layout_name]
        if not captured_data.is_empty():
            next_tracked[layout_name] = captured_data

    for prev_name_variant in _manager.tracked_editor_layouts.keys():
        var prev_name := String(prev_name_variant)
        if not next_tracked.has(prev_name):
            changed_count += 1

    for next_name_variant in next_tracked.keys():
        var next_name := String(next_name_variant)
        if not _manager.tracked_editor_layouts.has(next_name) or _manager.tracked_editor_layouts[next_name] != next_tracked[next_name]:
            changed_count += 1

    if changed_count > 0:
        _manager.tracked_editor_layouts = next_tracked
        _manager._profile_service._save_profile()

    return changed_count


func _capture_editor_layout_section(layout_name: String) -> Dictionary:
    var file_paths := _get_editor_layout_candidate_paths()
    for file_path in file_paths:
        var sections := _load_layout_sections_from_file(file_path)
        if sections.has(layout_name):
            return sections[layout_name]
    return {}


func _apply_tracked_editor_layouts() -> bool:
    if _manager.tracked_editor_layouts.is_empty():
        return false

    return _save_layout_sections_to_project(_manager.tracked_editor_layouts)


func _save_layout_sections_to_project(layout_sections: Dictionary) -> bool:
    if layout_sections.is_empty():
        return false

    var target_path := ProjectSettings.globalize_path(_manager.PROJECT_EDITOR_LAYOUTS_PATH)
    var config := ConfigFile.new()
    if FileAccess.file_exists(target_path):
        var load_error := config.load(target_path)
        if load_error != OK:
            push_warning("GDDT: Could not load editor layouts file for apply: %s" % target_path)

    var changed := false
    for layout_name_variant in layout_sections.keys():
        var layout_name := String(layout_name_variant)
        var layout_data = layout_sections[layout_name]
        if typeof(layout_data) != TYPE_DICTIONARY:
            continue

        for key_variant in layout_data.keys():
            var key := String(key_variant)
            var target_value: Variant = layout_data[key]
            var has_key := config.has_section_key(layout_name, key)
            var current_value: Variant = config.get_value(layout_name, key, null)
            if not has_key or current_value != target_value:
                config.set_value(layout_name, key, target_value)
                changed = true

    if not changed:
        return false

    var save_error := config.save(target_path)
    if save_error != OK:
        push_warning("GDDT: Could not save tracked editor layouts to %s" % target_path)
        return false

    return true


func _get_editor_layout_candidate_paths() -> Array[String]:
    var paths: Array[String] = []
    var seen := {}

    var project_path := ProjectSettings.globalize_path(_manager.PROJECT_EDITOR_LAYOUTS_PATH)
    paths.append(project_path)
    seen[project_path] = true

    var editor_paths := EditorInterface.get_editor_paths()
    if editor_paths != null:
        var global_path := editor_paths.get_config_dir().path_join(_manager.GLOBAL_EDITOR_LAYOUTS_FILE_NAME)
        if not seen.has(global_path):
            paths.append(global_path)
            seen[global_path] = true

    return paths


func _load_layout_sections_from_file(file_path: String) -> Dictionary:
    var result: Dictionary = {}
    if not FileAccess.file_exists(file_path):
        return result

    var config := ConfigFile.new()
    var load_error := config.load(file_path)
    if load_error != OK:
        return result

    var sections := config.get_sections()
    for section_name in sections:
        var section_dict: Dictionary = {}
        for key in config.get_section_keys(section_name):
            section_dict[String(key)] = config.get_value(section_name, key)
        result[String(section_name)] = section_dict

    return result
