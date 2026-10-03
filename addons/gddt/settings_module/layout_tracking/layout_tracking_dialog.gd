@tool
extends RefCounted
class_name GDDTLayoutTrackingDialog


func build_dialog() -> AcceptDialog:
    var dialog := AcceptDialog.new()
    dialog.title = "Track Editor Layouts"
    dialog.dialog_autowrap = true
    return dialog
