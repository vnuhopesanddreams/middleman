class_name WalkGrid
extends Node2D

## The grid people walk on, RPG Maker style: one tile at a time, 4 directions, around
## anything solid (tables, walls with collision). Built once when the level starts.

## Area covered, in cells. Include off-screen cells the exit sits in.
@export var region := Rect2i(0, 0, 24, 16)
@export var cell_size := 16
@export_flags_2d_physics var obstacle_mask := 1
## Draws blocked cells in red, to check the grid lines up with the level.
@export var show_debug := false

var _astar := AStarGrid2D.new()
var _built := false


func _ready() -> void:
	# Tile collision (walls) only exists a couple of physics frames after the level
	# loads, so wait before checking which cells are blocked.
	for i in 3:
		await get_tree().physics_frame
	_build()


## Path from one feet position to another, as a list of points to walk through.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	if _built:
		var start := _nearest_open_cell(_to_cell(from))
		var end := _nearest_open_cell(_to_cell(to))
		for cell in _astar.get_id_path(start, end, true):
			points.append(_astar.get_point_position(cell))
	points.append(to)
	return points


func _build() -> void:
	_astar.region = region
	_astar.cell_size = Vector2(cell_size, cell_size)
	_astar.offset = global_position + Vector2(cell_size, cell_size) / 2.0
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	# Almost the whole cell, so a table covering only part of a cell still blocks it.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size - 4, cell_size - 4)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = obstacle_mask
	var space := get_world_2d().direct_space_state

	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(0.0, _astar.get_point_position(cell))
			for hit in space.intersect_shape(query, 4):
				# Characters move around, so only static things block the grid.
				if not hit.collider is CharacterBody2D:
					_astar.set_point_solid(cell)
					break

	_built = true
	queue_redraw()


func _to_cell(point: Vector2) -> Vector2i:
	var cell := Vector2i(((point - global_position) / cell_size).floor())
	return cell.clamp(region.position, region.end - Vector2i.ONE)


## The cell itself if walkable, otherwise the closest walkable one (e.g. a seat tucked
## against a table edge).
func _nearest_open_cell(cell: Vector2i) -> Vector2i:
	for radius in range(0, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var candidate := cell + Vector2i(dx, dy)
				if _astar.is_in_boundsv(candidate) and not _astar.is_point_solid(candidate):
					return candidate
	return cell


func _draw() -> void:
	if not show_debug or not _built:
		return
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			if _astar.is_point_solid(Vector2i(x, y)):
				var top_left := Vector2(x, y) * cell_size
				draw_rect(Rect2(top_left, Vector2(cell_size, cell_size)), Color(1, 0, 0, 0.35))
