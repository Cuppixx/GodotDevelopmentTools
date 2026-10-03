@tool
extends RefCounted
class_name GDDTLayoutLoadDialog


func build_dialog() -> AcceptDialog:
    var dialog := AcceptDialog.new()
    dialog.title = "Load Tracked Layout"
    dialog.dialog_autowrap = true
    return dialog
