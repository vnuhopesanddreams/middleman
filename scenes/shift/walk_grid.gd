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

## For a level that repeats sideways: the columns it repeats (first column, width).
## Only those are checked for obstacles; every other column is a copy of the one it
## repeats. Zero width for a level that doesn't repeat.
var wrap_columns := Vector2i.ZERO

## How much room either side a straightened path keeps from anything solid.
const STRAIGHT_CLEARANCE = 4.0

var _astar := AStarGrid2D.new()
var _built := false


func _ready() -> void:
	# Tile collision (walls) only exists a couple of physics frames after the level
	# loads, so wait before checking which cells are blocked.
	for i in 3:
		await get_tree().physics_frame
	_build()


## Path from one feet position to another, as a list of points to walk through.
## Tile by tile, unless `straight`: then it cuts across wherever nothing is in the way.
func find_path(from: Vector2, to: Vector2, straight := false) -> PackedVector2Array:
	var points := PackedVector2Array()
	if _built:
		var start := _nearest_open_cell(_to_cell(from))
		var end := _nearest_open_cell(_to_cell(to))
		for cell in _astar.get_id_path(start, end, true):
			points.append(_astar.get_point_position(cell))
	points.append(to)
	return _straighten(from, points) if straight and _built else points


## Whether the point is on walkable floor.
func is_open(point: Vector2) -> bool:
	return _built and not _astar.is_point_solid(_to_cell(point))


## Skips every point that can be reached in a straight line from an earlier one.
func _straighten(from: Vector2, points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var current := from
	var i := 0
	while i < points.size():
		var furthest := i
		for j in range(points.size() - 1, i, -1):
			if _is_clear(current, points[j]):
				furthest = j
				break
		result.append(points[furthest])
		current = points[furthest]
		i = furthest + 1
	return result


## Whether a straight walk between two points stays clear of anything solid.
func _is_clear(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(ceili(from.distance_to(to) / 4.0), 1)
	var side := from.direction_to(to).orthogonal() * STRAIGHT_CLEARANCE
	for step in steps + 1:
		var point := from.lerp(to, float(step) / steps)
		for check in [point, point + side, point - side]:
			if _astar.is_point_solid(_to_cell(check)):
				return false
	return true


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

	var scanned := region
	if wrap_columns.y > 0:
		scanned = Rect2i(wrap_columns.x, region.position.y, wrap_columns.y, region.size.y)
	for x in range(scanned.position.x, scanned.end.x):
		for y in range(scanned.position.y, scanned.end.y):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(0.0, _astar.get_point_position(cell))
			for hit in space.intersect_shape(query, 4):
				# Characters move around, so only static things block the grid.
				if not hit.collider is CharacterBody2D:
					_astar.set_point_solid(cell)
					break

	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			if not scanned.has_point(Vector2i(x, y)):
				var original := Vector2i(scanned.position.x + posmod(x - scanned.position.x, scanned.size.x), y)
				_astar.set_point_solid(Vector2i(x, y), _astar.is_point_solid(original))

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
