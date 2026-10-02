class_name ChunkManifest
extends RefCounted

const VERSION := 1

var biome := 0
var instances: Array[Dictionary] = []

func to_dict() -> Dictionary:
	return {"version": VERSION, "biome": biome, "instances": instances}

static func from_dict(d: Dictionary) -> ChunkManifest:
	var m := ChunkManifest.new()
	m.biome = int(d.get("biome", 0))
	var raw: Array = d.get("instances", [])
	var out: Array[Dictionary] = []
	for entry in raw:
		if entry is Dictionary:
			out.append(entry)
	m.instances = out
	return m
