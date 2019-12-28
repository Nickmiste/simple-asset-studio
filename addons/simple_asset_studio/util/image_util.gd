class_name image_util

static func get_pixels_in_radius(center, radius):
	var pixels = []
	radius -= 1
	var radius_squared = radius * radius
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pixel = center + Vector2(x, y)
			if center.distance_squared_to(pixel) <= radius_squared:
				pixels.append(pixel)
	return pixels

static func has_pixel(image, pixel):
	return pixel.x >= 0 and pixel.y >= 0 and pixel.x < image.get_size().x and pixel.y < image.get_size().y

static func get_mouse_pixel(canvas):
	return get_pixel_from_global(canvas, canvas.get_viewport().get_mouse_position())
	
static func get_pixel_from_global(canvas, pos):
	var pixel = pos - canvas.rect_global_position
	pixel /= canvas.rect_scale
	pixel = pixel.floor()
	return pixel

static func get_pixel_global_pos(canvas, pixel, center=false):
	if center:
		pixel += Vector2.ONE * 0.5
	return canvas.rect_global_position + pixel * canvas.rect_scale

static func are_images_identical(a:Image, b:Image):
	if a.get_size() != b.get_size():
		return false
	a.lock()
	b.lock()
	for x in a.get_size().x:
		for y in a.get_size().y:
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				return false
	a.unlock()
	b.unlock()
	return true
