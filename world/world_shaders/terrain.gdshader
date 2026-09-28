shader_type spatial;

uniform vec3 grass_color : source_color = vec3(0.28, 0.45, 0.18);
uniform vec3 rock_color : source_color = vec3(0.40, 0.37, 0.34);
uniform vec3 sand_color : source_color = vec3(0.76, 0.70, 0.50);
uniform vec3 snow_color : source_color = vec3(0.95, 0.95, 0.97);
uniform float sand_height = -8.0;
uniform float snow_height = 22.0;
uniform float rock_slope = 0.75;      // normal.y below this blends toward rock
uniform bool show_chunk_checker = false;
uniform float chunk_size = 32.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = grass_color;
	col = mix(sand_color, col, smoothstep(sand_height, sand_height + 3.0, world_pos.y));
	col = mix(col, snow_color, smoothstep(snow_height, snow_height + 4.0, world_pos.y));
	col = mix(rock_color, col, smoothstep(rock_slope - 0.1, rock_slope + 0.1, world_normal.y));

	if (show_chunk_checker) {
		vec2 cell = floor(world_pos.xz / chunk_size);
		col *= mix(1.0, 0.8, mod(cell.x + cell.y, 2.0));
	}

	ALBEDO = col;
	ROUGHNESS = 1.0;
}