class_name RoomRepeater
extends Node

## Makes the restaurant feel big from a single screen built in the editor.
##
## Sideways it is endless, but only in looks: there is one room, drawn again and again
## either side of itself, and when the waiter walks off one edge they are moved to the
## other.
## Upwards, the floor band (the part with the tables) is copied for real a few times,
## and the back wall above it is moved up to sit on top of the stack. The original
## screen stays at the bottom, with the entrance.

## How many room-widths either side the room is drawn again, and the walk grid covers.
## Enough for the widest screens, plus the camera trailing behind.
const WRAP_REACH = 3

## The cells of one screen. Its width is what repeats sideways, so the spacing between
## its tables and its edges should match the spacing between the tables themselves.
## Tiles outside its columns are removed.
@export var screen := Rect2i(6, 0, 13, 14)
## Rows of the screen that repeat upwards: first row, and the row after the last one.
## Same as sideways, its height should match the spacing between rows of tables.
## Everything above it (back wall, counter) ends up at the very top.
@export var floor_rows := Vector2i(6, 12)
## Floors stacked up, counting the original.
@export var screen_rows := 3
## Tile layers to copy upwards.
@export var layers: Array[TileMapLayer] = []
@export var walk_grid: WalkGrid
@export var camera: FollowCamera
## Everything drawn again either side: tiles, tables and guests. The waiter and whoever
## they lead are kept outside it, so they only show up once.
@export var room: Node2D
## Who gets moved across when walking off a side.
@export var waiter: CharacterBody2D

## The room's sideways extent in world space: left edge and width.
var _left := 0.0
var _width := 0.0


func _ready() -> void:
	for layer in layers:
		_clear_outside_columns(layer)
		_repeat_upwards(layer)
	var cell_size := Vector2(layers[0].tile_set.tile_size)
	var cells := _room()
	var top_left := layers[0].to_global(layers[0].map_to_local(cells.position) - cell_size / 2.0)
	_left = top_left.x
	_width = cells.size.x * cell_size.x

	camera.limit_top = floori(top_left.y)
	camera.limit_bottom = ceili(top_left.y + cells.size.y * cell_size.y)
	# Drawn in the same pass as everything else, so the copies can never lag behind.
	# Repeat times counts the copies besides the original, half on each side.
	RenderingServer.canvas_set_item_repeat(room.get_canvas_item(), Vector2(_width, 0), WRAP_REACH * 2)
	waiter.wrap_width = _width
	# Paths may lead into the copies either side (e.g. toward a table seen there), as far
	# as a wide screen shows.
	walk_grid.wrap_columns = Vector2i(cells.position.x, cells.size.x)
	var reach := cells.size.x * WRAP_REACH
	walk_grid.region = walk_grid.region.merge(cells.grow_individual(reach, 0, reach, 0))
	# Siblings can't be added while the level is still being set up. This still runs
	# before the shift manager collects the tables and the walk grid scans for them.
	_repeat_tables.call_deferred()


func _physics_process(_delta: float) -> void:
	var x := waiter.global_position.x
	if x < _left:
		_wrap(Vector2(_width, 0))
	elif x >= _left + _width:
		_wrap(Vector2(-_width, 0))


## Moves the waiter and camera across; the room looks the same from both sides.
func _wrap(offset: Vector2) -> void:
	waiter.shift(offset)
	camera.shift(offset)


## All cells the finished room covers.
func _room() -> Rect2i:
	var top := screen.position.y - _floor_height() * (screen_rows - 1)
	return Rect2i(screen.position.x, top, screen.size.x, screen.end.y - top)


func _floor_height() -> int:
	return floor_rows.y - floor_rows.x


func _clear_outside_columns(layer: TileMapLayer) -> void:
	for cell in layer.get_used_cells():
		if cell.x < screen.position.x or cell.x >= screen.end.x:
			layer.erase_cell(cell)


## Lifts the back wall to the top, then stacks floor copies in the gap it leaves.
func _repeat_upwards(layer: TileMapLayer) -> void:
	var lift := Vector2i(0, -_floor_height() * (screen_rows - 1))
	var back_wall: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = []
	for cell in layer.get_used_cells():
		if cell.y >= screen.position.y and cell.y < floor_rows.x:
			back_wall.append(cell)
		elif cell.y >= floor_rows.x and cell.y < floor_rows.y:
			floor_cells.append(cell)

	# Top rows first: they move up, so no cell is overwritten before it has been moved.
	back_wall.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for cell in back_wall:
		_copy_cell(layer, cell, cell + lift)
		layer.erase_cell(cell)
	for cell in floor_cells:
		for i in range(1, screen_rows):
			_copy_cell(layer, cell, cell - Vector2i(0, _floor_height() * i))


func _copy_cell(layer: TileMapLayer, from: Vector2i, to: Vector2i) -> void:
	layer.set_cell(to, layer.get_cell_source_id(from), layer.get_cell_atlas_coords(from), layer.get_cell_alternative_tile(from))


func _repeat_tables() -> void:
	var step := Vector2(0, -_floor_height() * layers[0].tile_set.tile_size.y)
	for table in get_tree().get_nodes_in_group("tables"):
		for row in range(1, screen_rows):
			var copy: Node2D = table.duplicate()
			copy.position += step * row
			table.add_sibling(copy)
