extends Node
func _ready() -> void:
	var sheet: Control = preload("res://dev/font_sheet.tscn").instantiate()
	add_child(sheet)
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://font.png")
	get_tree().quit()
