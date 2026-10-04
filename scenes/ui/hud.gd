extends CanvasLayer

@export var shift_manager: ShiftManager

@onready var points_label: Label = $PointsLabel


func _ready() -> void:
	shift_manager.points_changed.connect(_on_points_changed)
	_on_points_changed(shift_manager.points)


func _on_points_changed(total: int) -> void:
	points_label.text = "Points: %d" % total
