@tool
extends VBoxContainer
class_name GDDTSettingsTab


const SORT_ASC := 0
const SORT_DESC := 1
const FILTER_ALL := 0
const FILTER_TRACKED := 1
const FILTER_UNTRACKED := 2
const FILTER_CHANGED_FROM_DEFAULT := 3


var _settings_manager
var _editor_settings: EditorSettings

var _apply_button: Button
var _preview_apply_button: Button
var _rollback_apply_button: Button
var _save_button: Button
var _build_diff_button: Button
var _run_self_checks_button: Button
var _auto_apply_toggle: CheckButton
var _status_label: Label
var _preview_label: Label
var _risky_notice_label: Label
var _risky_keywords_edit: LineEdit
var _save_risky_keywords_button: Button
var _reset_risky_keywords_button: Button

var _search_line: LineEdit
var _sort_option: OptionButton
var _filter_option: OptionButton
var _category_option: OptionButton
var _track_visible_button: Button
var _untrack_visible_button: Button
var _track_category_button: Button
var _untrack_all_button: Button
var _summary_label: Label
var _tree: Tree

var _all_paths: Array[String] = []
var _visible_paths: Array[String] = []
var _path_to_item: Dictionary = {}
var _updating_list := false
var _apply_filters_queued := false
var _updating_action_controls := false
var _updating_risky_keywords_editor := false
var _suppress_next_state_refresh := false


func initialize(settings_manager, editor_settings: EditorSettings) -> void:
    _settings_manager = settings_manager
    _editor_settings = editor_settings

    _build_ui()
    _update_status_surface()
    refresh_paths()

    if _settings_manager != null and not _settings_manager.state_changed.is_connected(_on_state_changed):
        _settings_manager.state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
    if _settings_manager != null and _settings_manager.state_changed.is_connected(_on_state_changed):
        _settings_manager.state_changed.disconnect(_on_state_changed)


func refresh_paths() -> void:
    _all_paths.clear()
    if _editor_settings == null:
        _queue_apply_filters()
        return

    var unique_paths := {}
    for property_info in _editor_settings.get_property_list():
        if typeof(property_info) != TYPE_DICTIONARY:
            continue

        var setting_path := String(property_info.get("name", ""))
        if setting_path.is_empty():
            continue
        if not setting_path.contains("/"):
            continue
        if not _editor_settings.has_setting(setting_path):
            continue

        unique_paths[setting_path] = true

    for key in unique_paths.keys():
        _all_paths.append(String(key))

    _all_paths.sort()
    _queue_apply_filters()


func _queue_apply_filters() -> void:
    if _apply_filters_queued:
        return
    _apply_filters_queued = true
    call_deferred("_apply_filters_deferred")


func _apply_filters_deferred() -> void:
    _apply_filters_queued = false
    _apply_filters()


func _build_ui() -> void:
    if _search_line != null:
        return

    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    var workflow_row := HBoxContainer.new()
    workflow_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(workflow_row)

    _apply_button = Button.new()
    _apply_button.text = "Apply Current Config"
    _apply_button.pressed.connect(_on_apply_pressed)
    workflow_row.add_child(_apply_button)

    _preview_apply_button = Button.new()
    _preview_apply_button.text = "Preview Apply Changes"
    _preview_apply_button.pressed.connect(_on_preview_apply_pressed)
    workflow_row.add_child(_preview_apply_button)

    _rollback_apply_button = Button.new()
    _rollback_apply_button.text = "Rollback Last Apply"
    _rollback_apply_button.pressed.connect(_on_rollback_apply_pressed)
    workflow_row.add_child(_rollback_apply_button)

    _save_button = Button.new()
    _save_button.text = "Save Current Config Changes"
    _save_button.pressed.connect(_on_save_pressed)
    workflow_row.add_child(_save_button)

    _build_diff_button = Button.new()
    _build_diff_button.text = "Build Tracked from Current Diffs"
    _build_diff_button.pressed.connect(_on_build_from_diffs_pressed)
    workflow_row.add_child(_build_diff_button)

    _run_self_checks_button = Button.new()
    _run_self_checks_button.text = "Run Self Checks"
    _run_self_checks_button.pressed.connect(_on_run_self_checks_pressed)
    workflow_row.add_child(_run_self_checks_button)

    _auto_apply_toggle = CheckButton.new()
    _auto_apply_toggle.text = "Auto Apply on Startup"
    _auto_apply_toggle.toggled.connect(_on_auto_apply_toggled)
    workflow_row.add_child(_auto_apply_toggle)

    _status_label = Label.new()
    _status_label.text = "Version 0 | Applied 0 | Tracked 0 | Sync: In Sync | Auto: Off"
    add_child(_status_label)

    _preview_label = Label.new()
    _preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _preview_label.text = "Apply preview: no pending changes."
    add_child(_preview_label)

    _risky_notice_label = Label.new()
    _risky_notice_label.text = "RISKY flags are advisory only and never block tracking or saving."
    add_child(_risky_notice_label)

    var risky_keywords_row := HBoxContainer.new()
    risky_keywords_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(risky_keywords_row)

    _risky_keywords_edit = LineEdit.new()
    _risky_keywords_edit.placeholder_text = "Risk warning keywords (comma-separated)"
    _risky_keywords_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    risky_keywords_row.add_child(_risky_keywords_edit)

    _save_risky_keywords_button = Button.new()
    _save_risky_keywords_button.text = "Save Warning Keywords"
    _save_risky_keywords_button.pressed.connect(_on_save_risky_keywords_pressed)
    risky_keywords_row.add_child(_save_risky_keywords_button)

    _reset_risky_keywords_button = Button.new()
    _reset_risky_keywords_button.text = "Reset Defaults"
    _reset_risky_keywords_button.pressed.connect(_on_reset_risky_keywords_pressed)
    risky_keywords_row.add_child(_reset_risky_keywords_button)

    var header := HBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(header)

    _search_line = LineEdit.new()
    _search_line.placeholder_text = "Search settings path"
    _search_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _search_line.text_changed.connect(_on_search_changed)
    header.add_child(_search_line)

    _sort_option = OptionButton.new()
    _sort_option.add_item("Sort: A to Z", SORT_ASC)
    _sort_option.add_item("Sort: Z to A", SORT_DESC)
    _sort_option.item_selected.connect(_on_sort_changed)
    header.add_child(_sort_option)

    _filter_option = OptionButton.new()
    _filter_option.add_item("Filter: All", FILTER_ALL)
    _filter_option.add_item("Filter: Tracked", FILTER_TRACKED)
    _filter_option.add_item("Filter: Untracked", FILTER_UNTRACKED)
    _filter_option.add_item("Filter: Changed from Default", FILTER_CHANGED_FROM_DEFAULT)
    _filter_option.item_selected.connect(_on_filter_changed)
    header.add_child(_filter_option)

    var actions_row := HBoxContainer.new()
    actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(actions_row)

    _category_option = OptionButton.new()
    _category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _category_option.item_selected.connect(_on_category_changed)
    actions_row.add_child(_category_option)

    _track_visible_button = Button.new()
    _track_visible_button.text = "Track Visible"
    _track_visible_button.pressed.connect(_on_track_visible_pressed)
    actions_row.add_child(_track_visible_button)

    _untrack_visible_button = Button.new()
    _untrack_visible_button.text = "Untrack Visible"
    _untrack_visible_button.pressed.connect(_on_untrack_visible_pressed)
    actions_row.add_child(_untrack_visible_button)

    _track_category_button = Button.new()
    _track_category_button.text = "Track Category"
    _track_category_button.pressed.connect(_on_track_category_pressed)
    actions_row.add_child(_track_category_button)

    _untrack_all_button = Button.new()
    _untrack_all_button.text = "Untrack All"
    _untrack_all_button.pressed.connect(_on_untrack_all_pressed)
    actions_row.add_child(_untrack_all_button)

    _summary_label = Label.new()
    _summary_label.text = "0 settings"
    add_child(_summary_label)

    _tree = Tree.new()
    _tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tree.columns = 3
    _tree.hide_root = true
    _tree.set_column_titles_visible(true)
    _tree.set_column_title(0, "Track")
    _tree.set_column_title(1, "Setting")
    _tree.set_column_title(2, "Flags")
    _tree.set_column_expand(0, false)
    _tree.set_column_custom_minimum_width(0, 64)
    _tree.set_column_expand(1, true)
    _tree.set_column_expand(2, false)
    _tree.set_column_custom_minimum_width(2, 200)
    _tree.set_hide_folding(true)
    _tree.item_edited.connect(_on_tree_item_edited)
    add_child(_tree)


func _apply_filters() -> void:
    if _tree == null:
        return

    _updating_list = true
    _visible_paths.clear()
    _path_to_item.clear()
    _tree.clear()

    var root := _tree.create_item()

    var query := ""
    if _search_line != null:
        query = _search_line.text.strip_edges().to_lower()

    var selected_filter_id := FILTER_ALL
    if _filter_option != null:
        selected_filter_id = _filter_option.get_selected_id()

    _refresh_category_options()
    var selected_category := _get_selected_category_name()

    for setting_path in _all_paths:
        if not query.is_empty() and setting_path.to_lower().find(query) == -1:
            continue

        if not selected_category.is_empty() and _get_path_category(setting_path) != selected_category:
            continue

        var is_tracked_for_filter: bool = _settings_manager != null and _settings_manager.is_setting_tracked(setting_path)
        if selected_filter_id == FILTER_TRACKED and not is_tracked_for_filter:
            continue
        if selected_filter_id == FILTER_UNTRACKED and is_tracked_for_filter:
            continue
        if selected_filter_id == FILTER_CHANGED_FROM_DEFAULT and not _is_changed_from_default(setting_path):
            continue

        _visible_paths.append(setting_path)

    if _sort_option != null and _sort_option.get_selected_id() == SORT_DESC:
        _visible_paths.reverse()

    var tracked_count := 0
    for setting_path in _visible_paths:
        var is_trackable: bool = _settings_manager != null and _settings_manager.is_valid_editor_setting_path(setting_path)
        var row := _tree.create_item(root)
        row.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
        row.set_editable(0, is_trackable)
        row.set_selectable(0, false)
        row.set_metadata(0, setting_path)
        row.set_text(1, setting_path)
        row.set_selectable(1, true)
        var is_tracked: bool = is_trackable and _settings_manager.is_setting_tracked(setting_path)
        row.set_text(2, _get_row_flags_text(setting_path, is_trackable, is_tracked))
        row.set_selectable(2, true)
        row.set_tooltip_text(2, _get_row_flags_tooltip(setting_path, is_trackable, is_tracked))
        row.set_tooltip_text(0, setting_path)
        row.set_tooltip_text(1, setting_path)
        _path_to_item[setting_path] = row

        row.set_checked(0, is_tracked)
        if is_tracked:
            tracked_count += 1

    _summary_label.text = "%d settings, %d tracked" % [_visible_paths.size(), tracked_count]
    _update_status_surface()
    _update_bulk_action_state()
    _updating_list = false


func _update_summary_label() -> void:
    if _summary_label == null or _settings_manager == null:
        return

    var tracked_count := 0
    for setting_path in _visible_paths:
        if _settings_manager.is_setting_tracked(setting_path):
            tracked_count += 1
    _summary_label.text = "%d settings, %d tracked" % [_visible_paths.size(), tracked_count]


func _refresh_category_options() -> void:
    if _category_option == null:
        return

    var previous_selected := _get_selected_category_name()
    var categories: Array[String] = []
    var category_map := {}
    for setting_path in _all_paths:
        var category := _get_path_category(setting_path)
        if category.is_empty():
            continue
        category_map[category] = true

    for category_key in category_map.keys():
        categories.append(String(category_key))
    categories.sort()

    _category_option.clear()
    _category_option.add_item("Category: All", 0)
    _category_option.set_item_metadata(0, "")

    var selected_index := 0
    for idx in categories.size():
        var category_name := categories[idx]
        var option_index := idx + 1
        _category_option.add_item("Category: %s" % category_name, option_index)
        _category_option.set_item_metadata(option_index, category_name)
        if not previous_selected.is_empty() and category_name == previous_selected:
            selected_index = option_index

    _category_option.select(selected_index)


func _get_selected_category_name() -> String:
    if _category_option == null or _category_option.item_count == 0:
        return ""
    var selected_index := _category_option.selected
    if selected_index < 0:
        return ""
    return String(_category_option.get_item_metadata(selected_index))


func _get_path_category(setting_path: String) -> String:
    var split := setting_path.split("/", false, 1)
    if split.is_empty():
        return ""
    return String(split[0])


func _is_changed_from_default(setting_path: String) -> bool:
    if _editor_settings == null:
        return false
    if not _editor_settings.has_setting(setting_path):
        return false
    if not _editor_settings.property_can_revert(setting_path):
        return false
    var current_value := _editor_settings.get_setting(setting_path)
    var default_value := _editor_settings.property_get_revert(setting_path)
    return current_value != default_value


func _update_status_surface() -> void:
    if _status_label == null or _settings_manager == null:
        return

    var status_text := "Version %d | Applied %d | Tracked %d | Drift %d | Sync: %s | Auto: %s" % [
        _settings_manager.get_config_version(),
        _settings_manager.get_applied_version(),
        _settings_manager.get_tracked_count(),
        _settings_manager.get_local_divergence_count(),
        _settings_manager.get_sync_state_text(),
        "On" if _settings_manager.is_auto_apply_enabled() else "Off",
    ]
    _status_label.text = status_text

    if _auto_apply_toggle != null:
        _updating_action_controls = true
        _auto_apply_toggle.button_pressed = _settings_manager.is_auto_apply_enabled()
        _updating_action_controls = false

    if _rollback_apply_button != null:
        _rollback_apply_button.disabled = not _settings_manager.has_apply_rollback_snapshot()

    _refresh_risky_keywords_editor()
    _refresh_apply_preview_label()


func _refresh_risky_keywords_editor() -> void:
    if _risky_keywords_edit == null or _settings_manager == null:
        return
    if _risky_keywords_edit.has_focus():
        return

    var keywords: Array[String] = _settings_manager.get_risky_warning_keywords()
    var keywords_text := ", ".join(keywords)
    if _risky_keywords_edit.text == keywords_text:
        return

    _updating_risky_keywords_editor = true
    _risky_keywords_edit.text = keywords_text
    _updating_risky_keywords_editor = false


func _refresh_apply_preview_label() -> void:
    if _preview_label == null or _settings_manager == null:
        return

    var preview_rows: Array[Dictionary] = _settings_manager.get_apply_preview()
    if preview_rows.is_empty():
        _preview_label.text = "Apply preview: no pending changes."
        return

    var lines: Array[String] = []
    lines.append("Apply preview (%d pending changes):" % preview_rows.size())

    var max_preview_lines := 12
    var shown := 0
    for row in preview_rows:
        if shown >= max_preview_lines:
            break
        var path := String(row.get("path", ""))
        var current_text := _variant_to_display(row.get("current_value"))
        var target_text := _variant_to_display(row.get("target_value"))
        lines.append("- %s: %s -> %s" % [path, current_text, target_text])
        shown += 1

    if preview_rows.size() > shown:
        lines.append("...and %d more." % (preview_rows.size() - shown))

    _preview_label.text = "\n".join(lines)


func _variant_to_display(value: Variant) -> String:
    var text := str(value)
    if text.length() > 64:
        return "%s..." % text.substr(0, 64)
    return text


func _set_self_check_result_text(result: Dictionary) -> void:
    if _preview_label == null:
        return

    var passed := bool(result.get("passed", false))
    var lines: Array[String] = []
    lines.append("Self checks: %s" % ("PASS" if passed else "FAIL"))

    var details: Array[String] = result.get("details", [])
    for detail in details:
        lines.append("- %s" % detail)

    _preview_label.text = "\n".join(lines)


func _get_row_flags_text(setting_path: String, is_trackable: bool, is_tracked: bool) -> String:
    var flags := _get_row_flags(setting_path, is_trackable, is_tracked)
    if flags.is_empty():
        return "-"
    return " | ".join(flags)


func _get_row_flags_tooltip(setting_path: String, is_trackable: bool, is_tracked: bool) -> String:
    var flags := _get_row_flags(setting_path, is_trackable, is_tracked)
    if flags.is_empty():
        return "No flags"

    var notes: Array[String] = []
    for flag in flags:
        match flag:
            "NON-TRACKABLE":
                notes.append("NON-TRACKABLE: This setting path cannot be tracked by GDDT.")
            "RISKY":
                notes.append("RISKY: This setting looks machine- or user-specific.")
            "CHANGED":
                notes.append("CHANGED: Local value differs from tracked shared value.")
    return "\n".join(notes)


func _get_row_flags(setting_path: String, is_trackable: bool, is_tracked: bool) -> Array[String]:
    var flags: Array[String] = []
    if not is_trackable:
        flags.append("NON-TRACKABLE")
    if _is_risky_setting_path(setting_path):
        flags.append("RISKY")
    if is_tracked and _is_changed_locally_from_tracked(setting_path):
        flags.append("CHANGED")
    return flags


func _is_risky_setting_path(setting_path: String) -> bool:
    var lower := setting_path.to_lower()
    var risky_keywords: Array[String] = []
    if _settings_manager != null and _settings_manager.has_method("get_risky_warning_keywords"):
        risky_keywords = _settings_manager.get_risky_warning_keywords()
    for keyword in risky_keywords:
        if lower.contains(keyword):
            return true

    if lower.contains(":/") or lower.begins_with("/"):
        return true
    if lower.contains("\\"):
        return true
    return false


func _is_changed_locally_from_tracked(setting_path: String) -> bool:
    if _settings_manager == null or _editor_settings == null:
        return false
    if not _settings_manager.is_setting_tracked(setting_path):
        return false
    if not _editor_settings.has_setting(setting_path):
        return false

    var tracked_value: Variant = _settings_manager.get_tracked_value(setting_path)
    var local_value: Variant = _editor_settings.get_setting(setting_path)
    return tracked_value != local_value


func _update_bulk_action_state() -> void:
    var has_visible := _visible_paths.size() > 0
    var has_any_tracked: bool = _settings_manager != null and _settings_manager.get_tracked_count() > 0
    var has_category_selection := not _get_selected_category_name().is_empty()

    if _track_visible_button != null:
        _track_visible_button.disabled = not has_visible
    if _untrack_visible_button != null:
        _untrack_visible_button.disabled = not has_visible
    if _track_category_button != null:
        _track_category_button.disabled = not has_visible and not has_category_selection
    if _untrack_all_button != null:
        _untrack_all_button.disabled = not has_any_tracked


func _on_search_changed(_new_text: String) -> void:
    _queue_apply_filters()


func _on_sort_changed(_index: int) -> void:
    _queue_apply_filters()


func _on_filter_changed(_index: int) -> void:
    _queue_apply_filters()


func _on_category_changed(_index: int) -> void:
    _queue_apply_filters()


func _on_state_changed() -> void:
    _update_status_surface()
    if _suppress_next_state_refresh:
        _suppress_next_state_refresh = false
        _update_summary_label()
        _update_bulk_action_state()
        return
    _queue_apply_filters()


func _on_apply_pressed() -> void:
    if _settings_manager == null:
        return
    _settings_manager.apply_current_config()


func _on_preview_apply_pressed() -> void:
    _refresh_apply_preview_label()


func _on_rollback_apply_pressed() -> void:
    if _settings_manager == null:
        return
    _settings_manager.rollback_last_apply_snapshot()


func _on_save_pressed() -> void:
    if _settings_manager == null:
        return
    _settings_manager.save_current_config_changes()


func _on_build_from_diffs_pressed() -> void:
    if _settings_manager == null:
        return
    _settings_manager.bootstrap_tracked_from_current_diffs()


func _on_run_self_checks_pressed() -> void:
    if _settings_manager == null:
        return
    var result: Dictionary = _settings_manager.run_self_checks()
    _set_self_check_result_text(result)


func _on_auto_apply_toggled(enabled: bool) -> void:
    if _updating_action_controls:
        return
    if _settings_manager == null:
        return
    _settings_manager.set_auto_apply_enabled(enabled)


func _on_save_risky_keywords_pressed() -> void:
    if _settings_manager == null or _risky_keywords_edit == null:
        return

    var parsed_keywords := _parse_keyword_list(_risky_keywords_edit.text)
    _settings_manager.set_risky_warning_keywords(parsed_keywords)


func _on_reset_risky_keywords_pressed() -> void:
    if _settings_manager == null:
        return
    _settings_manager.reset_risky_warning_keywords_to_default()


func _parse_keyword_list(keywords_text: String) -> Array[String]:
    var parsed: Array[String] = []
    var seen := {}
    for raw_part in keywords_text.split(","):
        var keyword := raw_part.strip_edges().to_lower()
        if keyword.is_empty() or seen.has(keyword):
            continue
        parsed.append(keyword)
        seen[keyword] = true
    return parsed


func _on_tree_item_edited() -> void:
    if _updating_list:
        return
    if _settings_manager == null:
        return

    var edited := _tree.get_edited()
    if edited == null:
        return
    if _tree.get_edited_column() != 0:
        return

    var edited_path := String(edited.get_metadata(0))
    if edited_path.is_empty():
        return
    if not _settings_manager.is_valid_editor_setting_path(edited_path):
        edited.set_checked(0, false)
        return

    var target_checked := edited.is_checked(0)
    var currently_tracked: bool = _settings_manager.is_setting_tracked(edited_path)
    if target_checked == currently_tracked:
        return

    _suppress_next_state_refresh = true
    _settings_manager.set_setting_tracked(edited_path, target_checked)
    _refresh_row_item(edited, edited_path)
    _update_summary_label()


func _refresh_row_item(row: TreeItem, setting_path: String) -> void:
    if row == null or _settings_manager == null:
        return

    var is_trackable: bool = _settings_manager.is_valid_editor_setting_path(setting_path)
    var is_tracked: bool = is_trackable and _settings_manager.is_setting_tracked(setting_path)

    row.set_editable(0, is_trackable)
    row.set_checked(0, is_tracked)
    row.set_text(2, _get_row_flags_text(setting_path, is_trackable, is_tracked))
    row.set_tooltip_text(2, _get_row_flags_tooltip(setting_path, is_trackable, is_tracked))


func _on_track_visible_pressed() -> void:
    _set_tracked_for_paths(_visible_paths, true)


func _on_untrack_visible_pressed() -> void:
    _set_tracked_for_paths(_visible_paths, false)


func _on_track_category_pressed() -> void:
    var category := _get_selected_category_name()
    if category.is_empty():
        _set_tracked_for_paths(_visible_paths, true)
        return

    var category_paths: Array[String] = []
    for setting_path in _all_paths:
        if _get_path_category(setting_path) == category:
            category_paths.append(setting_path)

    _set_tracked_for_paths(category_paths, true)


func _on_untrack_all_pressed() -> void:
    if _settings_manager == null:
        return
    _set_tracked_for_paths(_settings_manager.get_tracked_setting_paths(), false)


func _set_tracked_for_paths(paths: Array[String], tracked: bool) -> void:
    if _settings_manager == null:
        return

    if _settings_manager.has_method("set_settings_tracked"):
        _settings_manager.set_settings_tracked(paths, tracked)
    else:
        for setting_path in paths:
            if not _settings_manager.is_valid_editor_setting_path(setting_path):
                continue
            _settings_manager.set_setting_tracked(setting_path, tracked)

    _queue_apply_filters()
