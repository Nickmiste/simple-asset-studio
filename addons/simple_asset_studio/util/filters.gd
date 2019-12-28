class_name filters

static func brightness_contrast(image:Image):
	pass
	
static func to_grayscale(image:Image):
	image.lock()
	for x in image.get_size().x:
		for y in image.get_size().y:
			var color = image.get_pixel(x, y)
			var value = (color.r + color.g + color.b) / 3
			image.set_pixel(x, y, Color(value, value, value))
	image.unlock()

static func invert_colors(image:Image):
	image.lock()
	for x in image.get_size().x:
		for y in image.get_size().y:
			var color = image.get_pixel(x, y)
			color.r = 1 - color.r
			color.g = 1 - color.g
			color.b = 1 - color.b
			image.set_pixel(x, y, color)
	image.unlock()

static func tint(image:Image, tint_color, strength):
	image.lock()
	for x in image.get_size().x:
		for y in image.get_size().y:
			var color = image.get_pixel(x, y)
			color += tint_color * strength
			image.set_pixel(x, y, color)
	image.unlock()
