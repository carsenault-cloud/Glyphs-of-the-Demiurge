class_name TerrainConfig

const CHUNK_SIZE := 32					# Meters per side
const VERTS_PER_SIDE := CHUNK_SIZE + 1	# Edge verts are shared with neighboring chunks
const LOAD_RADIUS := 6					# In chunks
const UNLOAD_RADIUS := 8				# In chunks. Larger than load radius to prevent thrashing
const MAX_LOADS_PER_FRAME := 2			
const MAX_REBUILDS_PER_FRAME := 2		
