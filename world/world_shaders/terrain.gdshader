shader_type spatial;

// Texture Samplers
uniform sampler2D grass_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D rock_texture  : source_color, filter_nearest, repeat_enable;
uniform sampler2D sand_texture  : source_color, filter_nearest, repeat_enable;
uniform sampler2D snow_texture  : source_color, filter_nearest, repeat_enable;

// UV Scaling to control texture tiling size
uniform float uv_scale = 0.1;

// Height & Slope Parameters
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
    // Generate tiling UV coordinates from world position XZ
    vec2 uv = world_pos.xz * uv_scale;

    // Sample RGB colors from textures
    vec3 grass_color = texture(grass_texture, uv).rgb;
    vec3 rock_color  = texture(rock_texture, uv).rgb;
    vec3 sand_color  = texture(sand_texture, uv).rgb;
    vec3 snow_color  = texture(snow_texture, uv).rgb;

    // Blend sampled colors using height and normal slope
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