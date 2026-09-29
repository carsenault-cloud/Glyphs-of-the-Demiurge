class_name ShapedRecipe
extends CraftingRecipe

## Rows of symbol strings, e.g. ["AB", " A"]. Space = empty cell.
@export var pattern: Array[String] = []
## Symbol -> Item
@export var key: Dictionary = {}

func _pattern_size() -> Vector2i:
	var h := pattern.size()
	var w := 0 if h == 0 else pattern[0].length()
	return Vector2i(w, h)

func matches(grid_items: Array[Item], width: int, height: int) -> bool:
	var psize := _pattern_size()
	if psize.x > width or psize.y > height:
		return false

	for oy in range(0, height - psize.y + 1):
		for ox in range(0, width - psize.x + 1):
			if _matches_at(grid_items, width, height, ox, oy, psize):
				return true
	return false

func _matches_at(grid_items: Array[Item], width: int, height: int, ox: int, oy: int, psize: Vector2i) -> bool:
	for gy in height:
		for gx in width:
			var idx := gy * width + gx
			var in_pattern := gx >= ox and gx < ox + psize.x and gy >= oy and gy < oy + psize.y
			if not in_pattern:
				if grid_items[idx] != null:
					return false
				continue
			var symbol := pattern[gy - oy][gx - ox]
			var expected: Item = key.get(symbol, null) if symbol != " " else null
			var actual := grid_items[idx]
			if expected == null and actual == null:
				continue
			if expected == null or actual == null or expected.id != actual.id:
				return false
	return true
