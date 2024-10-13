extends MarginContainer

@onready var viewport = get_viewport()
@onready var screen_size = viewport.get_visible_rect().size

func _ready():
	viewport.connect("size_changed", Callable(self, "resize_window"))
	resize_window()

func resize_window():
	#print("Resizing safe area")
	var new_size = viewport.get_visible_rect().size
	if new_size.x != screen_size.x or new_size.y != screen_size.y:
		screen_size = new_size

	update_safe_area()

func update_safe_area():
	# Turn off debugging godot 3->4 
	# var rect = DisplayServer.get_display_safe_area()
	var window_size = get_window().get_size()
	var rect = get_window().get_visible_rect()
	var offset = Vector2(
		window_size.x - rect.size.x - rect.position.x,
		window_size.y - rect.size.y - rect.position.y
	)

	var aspect_y = screen_size.y / window_size.y
	var aspect_x = screen_size.x / window_size.x

	var topLeft = Vector2(rect.position.x * aspect_x, rect.position.y * aspect_y)
	var bottomRight = Vector2(-offset.x * aspect_x, -offset.y * aspect_y)

	offset_left = topLeft.x
	offset_top = topLeft.y
	offset_right = bottomRight.x
	offset_bottom = bottomRight.y
	#print("Screen size: ",screen_size)
	#print("Window size: ",window_size)
	#print("Safe Area:", rect )
	#printt("Margins: ",margin_top,margin_bottom,margin_left,margin_right)
	#print("Rect size: ",rect_size)
