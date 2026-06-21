shader_type canvas_item;

// Infinite scrolling tiled field. The background ColorRect fills the viewport;
// RunController feeds the camera/player world position into camera_pos each frame,
// and the tile repeats via fract() so the field looks boundless.

uniform vec2 camera_pos = vec2(0.0);
uniform float tile_size = 64.0;
uniform vec2 field_size = vec2(480.0, 270.0);  // viewport size in pixels
uniform sampler2D tile_texture : repeat_enable;

void fragment() {
	vec2 world_uv = (UV * field_size + camera_pos) / tile_size;
	COLOR = texture(tile_texture, fract(world_uv));
}
