class_name TerrainBiome
extends Resource

@export var biome_name := "Biome"
@export var chunk_mat: Material
@export var ground_clutter: Array[ClutterMesh]
@export var ground_veg: Array[ClutterMesh]
@export var large_veg: Array[ClutterMesh]
@export var large_clutter: Array[ClutterMesh]
@export var structures: Array[StructureBiomeEntry]
@export var large_destructibles: Array[DestructibleClutterDef]
@export var large_destructible_density := 0.01
@export var small_destructibles: Array[DestructibleClutterDef]
@export var small_destructible_density := 0.05
@export var ground_clutter_density := 0.15
@export var ground_veg_density := 0.08
@export var large_veg_density := 0.02
@export var large_clutter_density := 0.01
@export var min_scale := 0.8
@export var max_scale := 1.3
