@tool
extends Object
class_name ClosestPointOnCurveMeta
var before_segment : int
var point_position : Vector2
var local_point_position : Vector2

func _init(bs : int = 0, pp := Vector2.ZERO , lpp := Vector2.ZERO):
	before_segment = bs
	point_position = pp
	local_point_position = lpp
