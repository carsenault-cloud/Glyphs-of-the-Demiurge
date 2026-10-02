class_name TerrainConfig

const CHUNK_SIZE := 32					# Meters per side
const VERTS_PER_SIDE := CHUNK_SIZE + 1	# Edge verts are shared with neighboring chunks
const LOAD_RADIUS := 6					# In chunks
const UNLOAD_RADIUS := 8				# In chunks. Larger than load radius to prevent thrashing
const DETAIL_LOAD_RADIUS := 4      # large veg/clutter/destructibles
const DETAIL_UNLOAD_RADIUS := 5
const CLUTTER_LOAD_RADIUS := 2     # small veg/clutter/destructibles
const CLUTTER_UNLOAD_RADIUS := 3
const MAX_LOADS_PER_FRAME := 2			
const MAX_REBUILDS_PER_FRAME := 2		
const MAX_LARGE_LOADS_PER_FRAME := 1
const MAX_SMALL_LOADS_PER_FRAME := 1
