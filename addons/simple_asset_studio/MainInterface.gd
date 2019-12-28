tool
extends Control

enum Tool {PAINT, FILL}

var plugin : EditorPlugin

const scroll_speed = 0.3
var image : Image
var texture : ImageTexture
var prestroke_image = Image.new()
var last_paint_pixel = Vector2.ZERO

var selected_tool = Tool.PAINT
var painting = false setget set_painting
var current_path = ""
var aspect = 1
var popups = []
var flags = 0

func _ready():
	for i in $BrushSettings/ColorHistory.get_child_count():
		var child = $BrushSettings/ColorHistory.get_child(i)
		child.get_node("Button").connect("pressed", self, "_on_color_history_pressed", [i])
	for child in $Tools/Container.get_children():
		child.connect("pressed", self, "_on_tool_selected", [child.name])
	#generate popups array
	for parent in [self, $FilterDialogs]:
		for child in parent.get_children():
			if child is Popup:
				popups.append(child)
			elif child is MenuButton:
				popups.append(child.get_popup())
	$Filters.get_popup().clear()
	$Filters.get_popup().connect("id_pressed", self, "_on_filter_pressed")
	$Filters.get_popup().add_item("Convert to Grayscale", 0)
	$Filters.get_popup().add_item("Invert Colors", 2)
	$Filters.get_popup().add_item("Tint", 1)
	
func _on_New_pressed():
	$NewDialog/Options/X/Value.value = 64
	$NewDialog/Options/Y/Value.value = 64
	$NewDialog/Options/KeepAspect.pressed = true
	$NewDialog.popup_centered()

func _on_NewDialog_confirmed():
	image = Image.new()
	var size_x = $NewDialog/Options/X/Value.value
	var size_y = $NewDialog/Options/Y/Value.value
	image.create(size_x, size_y, true, Image.FORMAT_RGBA8)
	image.fill(Color.white)
	set_path_and_save($NewDialog/Options/Path.text, true)
	
func _on_Open_pressed():
	$OpenDialog.popup_centered()

func _on_OpenDialog_confirmed():
	image = Image.new()
	image.load($OpenDialog.current_path)
	setup()
	current_path = $OpenDialog.current_path

func setup():
	texture = ImageTexture.new()
	texture.create_from_image(image, flags)
	$Save.disabled = false
	$SaveAs.disabled = false
	$Filters.disabled = false
	$Workspace/Canvas.texture = texture
	$Workspace/Canvas.rect_pivot_offset = image.get_size() / 2
	$Workspace/Canvas.rect_scale = Vector2.ONE
	$Workspace/Canvas.rect_position = $Workspace.rect_size / 2 - $Workspace/Canvas.rect_pivot_offset

func _on_Save_pressed():
	if image != null:
		image.save_png(current_path)
		plugin.get_editor_interface().get_resource_filesystem().scan()
	
func _on_SaveAs_pressed():
	if image != null:
		$SaveAsDialog/Options/Path.text = current_path
		$SaveAsDialog.popup_centered()
	
func _on_SaveAs_confirmed():
	set_path_and_save($SaveAsDialog/Options/Path.text)
	
func set_path_and_save(path, queue_setup=false):
	var dir = Directory.new()
	if dir.file_exists(path):
		$OverwriteDialog/Path.text = path
		$OverwriteDialog/QueueSetup.pressed = queue_setup
		$OverwriteDialog.popup_centered()
	else:
		current_path = path
		if queue_setup:
			setup()
		image.save_png(current_path)
		plugin.get_editor_interface().get_resource_filesystem().scan()
		
func _on_OverwriteDialog_confirmed():
	current_path = $OverwriteDialog/Path.text
	if $OverwriteDialog/QueueSetup.pressed:
		setup()
	image.save_png(current_path)
	plugin.get_editor_interface().get_resource_filesystem().scan()
	
func paint(pixel=image_util.get_mouse_pixel($Workspace/Canvas)):
	if visible and image_util.has_pixel(image, pixel):
		last_paint_pixel = pixel
		image.lock()
		var brush_size = $BrushSettings/Size.value
		var opacity = $BrushSettings/Opacity.value
		for coord in image_util.get_pixels_in_radius(pixel, brush_size):
			if image_util.has_pixel(image, coord):
				var brush_color = $BrushSettings/Color.color
				var weight = opacity
				prestroke_image.lock()
				var color = lerp(prestroke_image.get_pixelv(coord), brush_color, weight)
				prestroke_image.unlock()
				image.set_pixelv(coord, color)
		image.unlock()
		texture.create_from_image(image, flags)
		update_color_history()

func start_flood_fill():
	var start_pixel = image_util.get_mouse_pixel($Workspace/Canvas)
	if image_util.has_pixel(image, start_pixel):
		image.lock()
		flood_fill(start_pixel, image.get_pixelv(start_pixel), $BrushSettings/Color.color)
		image.unlock()
		texture.create_from_image(image, flags)
		update_color_history()
		
func flood_fill(pixel, from_color, to_color):
	if not image_util.has_pixel(image, pixel):
		return
	if not image.get_pixelv(pixel) == from_color:
		return
	 
	image.set_pixelv(pixel, to_color)
	flood_fill(pixel + Vector2.UP, from_color, to_color)
	flood_fill(pixel + Vector2.DOWN, from_color, to_color)
	flood_fill(pixel + Vector2.LEFT, from_color, to_color)
	flood_fill(pixel + Vector2.RIGHT, from_color, to_color)
	
func use_eyedropper():
	var pixel = image_util.get_mouse_pixel($Workspace/Canvas)
	if image_util.has_pixel(image, pixel):
		image.lock()
		$BrushSettings/Color.color = image.get_pixelv(pixel)
		image.unlock()

func _process(delta):
	update_straight_line()
	update()

func _draw():
	if image != null and selected_tool == Tool.PAINT and is_mouse_colliding($Workspace):
		if $BrushSettings/Size.value >= 2:
			var center = get_viewport().get_mouse_position() - rect_global_position
			var radius = $BrushSettings/Size.value * $Workspace/Canvas.rect_scale.x - 1
			draw_arc(center, radius, 0, TAU, 64, Color.black)
	
func _input(event):
	if image == null: return
	for popup in popups:
		if popup.visible:
			painting = false
			return
	
	if event is InputEventMouseButton:
		if event.button_index in [BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN]:
			var increment = scroll_speed if event.button_index == BUTTON_WHEEL_UP else -scroll_speed
			if Input.is_key_pressed(KEY_SHIFT) and selected_tool == Tool.PAINT:
				#resize brush
				$BrushSettings/Size.value += increment
			else:
				#zooming
				var scale = $Workspace/Canvas.rect_scale.x + increment
				scale = max(scale, scroll_speed)
				$Workspace/Canvas.rect_scale = Vector2.ONE * scale
		if event.button_index == BUTTON_LEFT:
			if Input.is_key_pressed(KEY_CONTROL) and not Input.is_key_pressed(KEY_SHIFT):
				if event.pressed:
					use_eyedropper()
			else:
				match selected_tool:
					Tool.PAINT:
						self.painting = event.pressed
						if painting:
							if $StraightLine.visible:
								var a = image_util.get_pixel_from_global($Workspace/Canvas, $StraightLine.points[0])
								var b = image_util.get_pixel_from_global($Workspace/Canvas, $StraightLine.points[1])
								var samples = floor(a.distance_to(b) * 1.5)
								for i in samples:
									var t = i / (samples-1.0)
									paint(a.linear_interpolate(b, t))
							else:
								paint()
					Tool.FILL:
						if event.pressed:
							start_flood_fill()
							register_paint_undo("Fill")
	elif event is InputEventMouseMotion:
		#painting
		if painting and selected_tool == Tool.PAINT and not $StraightLine.visible:
			paint()
		#panning
		if Input.is_mouse_button_pressed(BUTTON_MIDDLE):
			$Workspace/Canvas.rect_position += event.relative
	elif event is InputEventKey:
		update_eyedropper_cursor(event)
		if event.scancode == KEY_S and event.pressed and not event.is_echo() and Input.is_key_pressed(KEY_CONTROL):
			print("Saved image to: " + current_path)
			_on_Save_pressed()
		
func update_eyedropper_cursor(event: InputEventKey):
	if event.scancode == KEY_CONTROL:
		if event.pressed and not Input.is_key_pressed(KEY_SHIFT):
			$Workspace/Canvas.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND
		else:
			$Workspace/Canvas.mouse_default_cursor_shape = Input.CURSOR_ARROW
		get_viewport().warp_mouse(get_viewport().get_mouse_position()) #force update

func update_straight_line():
	if image == null or not Input.is_key_pressed(KEY_SHIFT) or selected_tool != Tool.PAINT or not is_mouse_colliding($Workspace):
		$StraightLine.hide()
		return
		
	$StraightLine.show()
	$StraightLine.position = -rect_global_position
	var start = image_util.get_pixel_global_pos($Workspace/Canvas, last_paint_pixel, true)
	var end = get_viewport().get_mouse_position()
	if Input.is_key_pressed(KEY_CONTROL):
		var delta = end - start
		var radius = delta.length()
		var theta = atan2(delta.y, delta.x)
		var snap_interval = TAU / 16
		theta = round(theta / snap_interval) * snap_interval
		end = start + Vector2(radius * cos(theta), radius * sin(theta))
	$StraightLine.points[0] = start
	$StraightLine.points[1] = end

func _on_tool_selected(tool_name):
	for child in $Tools/Container.get_children():
		child.pressed = false
	$Tools/Container.get_node(tool_name).pressed = true
	match tool_name:
		"Paint": selected_tool = Tool.PAINT
		"Fill": selected_tool = Tool.FILL
	
func update_color_history():
	var history_size = $BrushSettings/ColorHistory.get_child_count()
	for child in $BrushSettings/ColorHistory.get_children():
		if child.color == $BrushSettings/Color.color:
			return
	for i in history_size:
		var child = $BrushSettings/ColorHistory.get_child(i)
		if i < history_size - 1:
			var next = $BrushSettings/ColorHistory.get_child(i + 1)
			child.color = next.color
		else:
			child.color = $BrushSettings/Color.color

func _on_color_history_pressed(index):
	$BrushSettings/Color.color = $BrushSettings/ColorHistory.get_child(index).color

func set_painting(value):
	painting = value
	if painting:
		prestroke_image.copy_from(image)
	else:
		register_paint_undo("Paint")
		
func register_paint_undo(action_name):
	if not image_util.are_images_identical(image, prestroke_image):
		plugin.get_undo_redo().create_action(action_name)
		var before = Image.new()
		var after = Image.new()
		before.copy_from(prestroke_image)
		after.copy_from(image)
		plugin.get_undo_redo().add_do_method(self, "update_image", after)
		plugin.get_undo_redo().add_undo_method(self, "update_image", before)
		plugin.get_undo_redo().commit_action()

func update_image(new_image):
	image.copy_from(new_image)
	texture.create_from_image(image, flags)

func _on_size_text_changed(value, x_changed):
	if $NewDialog/Options/KeepAspect.pressed:
		if x_changed:
			$NewDialog/Options/Y/Value.value = value / aspect
		else:
			$NewDialog/Options/X/Value.value = value * aspect
	else:
		aspect = $NewDialog/Options/X/Value.value / $NewDialog/Options/Y/Value.values
		
func _on_filter_pressed(id):
	if image != null:
		match id:
			0: filters.to_grayscale(image)
			1: $FilterDialogs/TintDialog.popup_centered()
			2: filters.invert_colors(image)
		if id % 2 == 0: #even id indicates immediate effect (no dialog)
			texture.create_from_image(image, flags)
			register_paint_undo("Apply Filter")

func _on_TintDialog_confirmed():
	filters.tint(image, $FilterDialogs/TintDialog/Options/Color.color, $FilterDialogs/TintDialog/Options/Strength.value)
	texture.create_from_image(image, flags)
	register_paint_undo("Apply Filter")

func _on_Filter_toggled(pressed):
	if pressed: flags |= ImageTexture.FLAG_FILTER
	else: flags &= ~ImageTexture.FLAG_FILTER
	if image != null:
		texture.create_from_image(image, flags)

func is_mouse_colliding(control:Control):
	var mouse_pos = get_viewport().get_mouse_position()
	var minx = control.rect_global_position.x
	var miny = control.rect_global_position.y
	var maxx = minx + control.rect_size.x * control.rect_scale.x
	var maxy = miny + control.rect_size.y * control.rect_scale.y
	return mouse_pos.x >= minx and mouse_pos.y >= miny and mouse_pos.x <= maxx and mouse_pos.y <= maxy
