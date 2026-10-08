class_name ChunkManifest
extends RefCounted

const VERSION := 1

var biome := 0
var instances: Array[Dictionary] = []
var built: Array[Dictionary] = []

func to_dict() -> Dictionary:
	return {"version": VERSION, "biome": biome, "instances": instances, "built": built}

static func from_dict(d: Dictionary) -> ChunkManifest:
	var m := ChunkManifest.new()
	m.biome = int(d.get("biome", 0))
	var raw: Array = d.get("instances", [])
	var out: Array[Dictionary] = []
	for entry in raw:
		if entry is Dictionary:
			out.append(entry)
	m.instances = out
	var built_out: Array[Dictionary] = []
	for entry in d.get("built", []):
		if entry is Dictionary:
			built_out.append(entry)
	m.built = built_out
	return m
