@tool
extends RefCounted
class_name GDDTSettingsMenu


const ACTION_APPLY := 1001
const ACTION_SAVE := 1002
const ACTION_TOGGLE_AUTO_APPLY := 1003
const ACTION_SHOW_STATUS := 1004
const ACTION_BOOTSTRAP_TRACKED := 1005
const ACTION_TRACK_LAYOUTS := 1006
const ACTION_SUBMENU := 1010
const TOOL_SUBMENU_NAME := "GDDT Settings"
const TRACK_LAYOUTS_ITEM_TEXT := "Track Layouts..."

var _settings_manager
var _plugin: EditorPlugin
var _popup_menu: PopupMenu
var _editor_layout_popup_menu: PopupMenu
var _layout_tracking_dialog: AcceptDialog
var _layout_load_dialog: AcceptDialog
var _layout_checkbox_by_name: Dictionary = {}
var _layout_load_option: OptionButton


func initialize(plugin: EditorPlugin, settings_manager) -> void:
    _plugin = plugin
    _settings_manager = settings_manager
    _popup_menu = PopupMenu.new()
    _popup_menu.name = "GDDTSettingsMenu"
    _popup_menu.id_pressed.connect(_on_menu_id_pressed)
    _popup_menu.add_item("Apply Current Config", ACTION_APPLY)
    _popup_menu.add_item("Save Current Config Changes", ACTION_SAVE)
    _popup_menu.add_item("Build Tracked Settings from Current Diffs", ACTION_BOOTSTRAP_TRACKED)
    _popup_menu.add_check_item("Auto Apply on Startup", ACTION_TOGGLE_AUTO_APPLY)
    _popup_menu.add_item(_settings_manager.get_status_text(), ACTION_SHOW_STATUS)
    _popup_menu.set_item_disabled(_popup_menu.get_item_index(ACTION_SHOW_STATUS), true)

    _attach_submenu()
    _attach_editor_layout_action()
    _update_state()


func shutdown() -> void:
    _detach_editor_layout_action()

    if _layout_tracking_dialog != null and is_instance_valid(_layout_tracking_dialog):
        _layout_tracking_dialog.queue_free()
    _layout_tracking_dialog = null

    if _layout_load_dialog != null and is_instance_valid(_layout_load_dialog):
        _layout_load_dialog.queue_free()
    _layout_load_dialog = null

    _layout_checkbox_by_name.clear()
    _layout_load_option = null

    if _popup_menu != null and is_instance_valid(_popup_menu):
        _popup_menu.queue_free()
    _popup_menu = null
    _settings_manager = null
    _plugin = null


func _attach_submenu() -> void:
    if _plugin == null or _popup_menu == null:
        return

    var editor_menu_popup := _find_editor_popup_menu()
    if editor_menu_popup != null:
        editor_menu_popup.add_submenu_node_item(TOOL_SUBMENU_NAME, _popup_menu, ACTION_SUBMENU)
        _reposition_editor_submenu_item(editor_menu_popup)
        return

    _plugin.add_tool_submenu_item(TOOL_SUBMENU_NAME, _popup_menu)
    push_warning("GDDT: Could not find the Editor popup menu; added submenu to Tools menu instead.")


func _detach_submenu() -> void:
    if _plugin == null or _popup_menu == null:
        return

    var editor_menu_popup := _find_editor_popup_menu()
    if editor_menu_popup != null:
        var item_index := editor_menu_popup.get_item_index(ACTION_SUBMENU)
        if item_index >= 0:
            editor_menu_popup.remove_item(item_index)
    else:
        _plugin.remove_tool_menu_item(TOOL_SUBMENU_NAME)


func _attach_editor_layout_action() -> void:
    _detach_editor_layout_action()

    var editor_layout_popup := _find_editor_layout_popup_menu()
    if editor_layout_popup == null:
        return

    _editor_layout_popup_menu = editor_layout_popup
    if not _editor_layout_popup_menu.id_pressed.is_connected(_on_editor_layout_menu_id_pressed):
        _editor_layout_popup_menu.id_pressed.connect(_on_editor_layout_menu_id_pressed)

    if _editor_layout_popup_menu.get_item_index(ACTION_TRACK_LAYOUTS) < 0:
        _editor_layout_popup_menu.add_separator("GDDT")
        _editor_layout_popup_menu.add_item(TRACK_LAYOUTS_ITEM_TEXT, ACTION_TRACK_LAYOUTS)


func _detach_editor_layout_action() -> void:
    if _editor_layout_popup_menu != null and is_instance_valid(_editor_layout_popup_menu):
        var item_index := _editor_layout_popup_menu.get_item_index(ACTION_TRACK_LAYOUTS)
        if item_index >= 0:
            _editor_layout_popup_menu.remove_item(item_index)
        if _editor_layout_popup_menu.id_pressed.is_connected(_on_editor_layout_menu_id_pressed):
            _editor_layout_popup_menu.id_pressed.disconnect(_on_editor_layout_menu_id_pressed)

    _editor_layout_popup_menu = null


func _find_editor_popup_menu() -> PopupMenu:
    var base_control := EditorInterface.get_base_control()
    if base_control == null:
        return null

    var popup_menus := base_control.find_children("*", "PopupMenu", true, false)
    for node in popup_menus:
        var popup := node as PopupMenu
        if popup == null:
            continue

        var has_editor_layout := false
        var has_editor_docks := false
        for item_idx in popup.item_count:
            var item_text := popup.get_item_text(item_idx)
            if item_text == "Editor Layout":
                has_editor_layout = true
            elif item_text == "Editor Docks":
                has_editor_docks = true

        if has_editor_layout and has_editor_docks:
            return popup

    return null


func _find_editor_layout_popup_menu() -> PopupMenu:
    var editor_menu_popup := _find_editor_popup_menu()
    if editor_menu_popup == null:
        return null

    for item_idx in editor_menu_popup.item_count:
        if editor_menu_popup.get_item_text(item_idx) != "Editor Layout":
            continue

        var submenu_path := String(editor_menu_popup.get_item_submenu(item_idx))
        if submenu_path.is_empty():
            break

        var submenu_node := editor_menu_popup.get_node_or_null(submenu_path)
        if submenu_node is PopupMenu:
            return submenu_node
        break

    # Fallback scan for versions where submenu lookup cannot be resolved by node path.
    var base_control := EditorInterface.get_base_control()
    if base_control == null:
        return null

    var popup_menus := base_control.find_children("*", "PopupMenu", true, false)
    for node in popup_menus:
        var popup := node as PopupMenu
        if popup == null:
            continue

        var has_layout_entry := false
        for item_idx in popup.item_count:
            var item_text := popup.get_item_text(item_idx)
            if item_text.contains("Layout"):
                has_layout_entry = true
                break

        if has_layout_entry:
            return popup

    return null


func _reposition_editor_submenu_item(editor_menu_popup: PopupMenu) -> void:
    if editor_menu_popup == null:
        return

    var gddt_index := editor_menu_popup.get_item_index(ACTION_SUBMENU)
    if gddt_index < 0:
        return

    var command_palette_index := -1
    var editor_docks_index := -1
    for item_idx in editor_menu_popup.item_count:
        var item_text := editor_menu_popup.get_item_text(item_idx)
        if item_text == "Command Palette...":
            command_palette_index = item_idx
        elif item_text == "Editor Docks":
            editor_docks_index = item_idx

    if editor_docks_index >= 0:
        editor_menu_popup.set_item_index(gddt_index, editor_docks_index)
        return

    if command_palette_index >= 0:
        editor_menu_popup.set_item_index(gddt_index, command_palette_index + 1)


func _on_menu_id_pressed(id: int) -> void:
    match id:
        ACTION_APPLY:
            _settings_manager.apply_current_config()
        ACTION_SAVE:
            _settings_manager.save_current_config_changes()
        ACTION_BOOTSTRAP_TRACKED:
            _settings_manager.bootstrap_tracked_from_current_diffs()
        ACTION_TOGGLE_AUTO_APPLY:
            _settings_manager.set_auto_apply_enabled(not _settings_manager.is_auto_apply_enabled())


func _on_editor_layout_menu_id_pressed(id: int) -> void:
    if id != ACTION_TRACK_LAYOUTS:
        return
    _open_layout_tracking_dialog()


func _open_layout_tracking_dialog() -> void:
    if _plugin == null or _settings_manager == null:
        return

    if _layout_tracking_dialog != null and is_instance_valid(_layout_tracking_dialog):
        _layout_tracking_dialog.queue_free()

    _layout_checkbox_by_name.clear()

    _layout_tracking_dialog = AcceptDialog.new()
    _layout_tracking_dialog.title = "Track Editor Layouts"
    _layout_tracking_dialog.dialog_hide_on_ok = true
    _layout_tracking_dialog.confirmed.connect(_on_layout_tracking_confirmed)
    _layout_tracking_dialog.custom_action.connect(_on_layout_tracking_custom_action)

    var root := VBoxContainer.new()
    _layout_tracking_dialog.add_child(root)

    var info_label := Label.new()
    info_label.text = "Select layout entries to track and share."
    root.add_child(info_label)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(520, 260)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)

    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)

    var tracked_names_map := {}
    for tracked_name in _settings_manager.get_tracked_editor_layout_names():
        tracked_names_map[String(tracked_name)] = true

    var available_names: Array[String] = _settings_manager.get_available_editor_layout_names()
    for layout_name in available_names:
        var checkbox := CheckBox.new()
        checkbox.text = layout_name
        checkbox.button_pressed = tracked_names_map.has(layout_name)
        list.add_child(checkbox)
        _layout_checkbox_by_name[layout_name] = checkbox

    if available_names.is_empty():
        var empty_label := Label.new()
        empty_label.text = "No editor layouts were found in project/global layout files."
        list.add_child(empty_label)

    _layout_tracking_dialog.add_button("Load Layout...", false, "load_layout")

    _plugin.add_child(_layout_tracking_dialog)
    _layout_tracking_dialog.popup_centered()


func _on_layout_tracking_custom_action(action: StringName) -> void:
    if action != "load_layout":
        return
    _open_layout_load_dialog()


func _on_layout_tracking_confirmed() -> void:
    if _settings_manager == null:
        return

    var selected_names: Array[String] = []
    for layout_name_variant in _layout_checkbox_by_name.keys():
        var layout_name := String(layout_name_variant)
        var checkbox := _layout_checkbox_by_name[layout_name] as CheckBox
        if checkbox != null and checkbox.button_pressed:
            selected_names.append(layout_name)

    selected_names.sort()
    _settings_manager.set_tracked_editor_layout_names(selected_names)


func _open_layout_load_dialog() -> void:
    if _plugin == null or _settings_manager == null:
        return

    if _layout_load_dialog != null and is_instance_valid(_layout_load_dialog):
        _layout_load_dialog.queue_free()

    _layout_load_dialog = AcceptDialog.new()
    _layout_load_dialog.title = "Load Tracked Layout"
    _layout_load_dialog.dialog_hide_on_ok = true
    _layout_load_dialog.confirmed.connect(_on_layout_load_confirmed)

    var root := VBoxContainer.new()
    _layout_load_dialog.add_child(root)

    var info_label := Label.new()
    info_label.text = "Choose a tracked layout package root to install into the project layout file."
    root.add_child(info_label)

    _layout_load_option = OptionButton.new()
    _layout_load_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_child(_layout_load_option)

    var roots: Array[String] = _settings_manager.get_tracked_editor_layout_package_roots()
    for root_name in roots:
        _layout_load_option.add_item(root_name)

    if roots.is_empty():
        _layout_load_option.disabled = true
        var empty_label := Label.new()
        empty_label.text = "No tracked layout packages are available yet."
        root.add_child(empty_label)

    _plugin.add_child(_layout_load_dialog)
    _layout_load_dialog.popup_centered()


func _on_layout_load_confirmed() -> void:
    if _settings_manager == null or _layout_load_option == null:
        return
    if _layout_load_option.item_count == 0:
        return

    var selected_index := _layout_load_option.selected
    if selected_index < 0:
        return

    var layout_root := _layout_load_option.get_item_text(selected_index)
    _settings_manager.install_tracked_editor_layout_package(layout_root)


func _update_state() -> void:
    if _popup_menu == null or _settings_manager == null:
        return

    _popup_menu.set_item_checked(_popup_menu.get_item_index(ACTION_TOGGLE_AUTO_APPLY), _settings_manager.is_auto_apply_enabled())
    _popup_menu.set_item_text(_popup_menu.get_item_index(ACTION_SHOW_STATUS), _settings_manager.get_status_text())


func get_popup_menu() -> PopupMenu:
    return _popup_menu


func on_settings_state_changed() -> void:
    _update_state()
