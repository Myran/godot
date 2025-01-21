extends MarginContainer

# Member variables with types
@onready var viewport: Viewport = get_viewport()
@onready var screen_size: Vector2 = viewport.get_visible_rect().size


# Functions with return type annotations
func _ready() -> void:
	viewport.connect("size_changed", Callable(self, "resize_window"))
	resize_window()


func resize_window() -> void:
	var new_size: Vector2 = viewport.get_visible_rect().size
	if new_size.x != screen_size.x or new_size.y != screen_size.y:
		screen_size = new_size
	update_safe_area()


func update_safe_area() -> void:
	var window_size: Vector2 = get_window().get_size()
	var rect: Rect2 = get_window().get_visible_rect()
	var offset: Vector2 = Vector2(
		window_size.x - rect.size.x - rect.position.x, window_size.y - rect.size.y - rect.position.y
	)

	var aspect_y: float = screen_size.y / window_size.y
	var aspect_x: float = screen_size.x / window_size.x

	var top_left: Vector2 = Vector2(rect.position.x * aspect_x, rect.position.y * aspect_y)
	var bottom_right: Vector2 = Vector2(-offset.x * aspect_x, -offset.y * aspect_y)

	offset_left = top_left.x
	offset_top = top_left.y
	offset_right = bottom_right.x
	offset_bottom = bottom_right.y
