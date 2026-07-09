shader_type canvas_item;
// Pulsing rim/outline for "glowing" mini-boss variants (the Mad Forest glow bat).
// Samples the sprite's alpha in eight directions; any transparent texel that borders an
// opaque one becomes the outline, so the effect traces the art's silhouette without needing
// a hand-drawn border. A gentle sine pulse makes the rim breathe so it reads as a magical
// glow, not a flat stroke. Works under the project's GL Compatibility renderer.
//
// IMPORTANT: the sprite this material is applied to must carry a transparent margin around the
// art (see VSEnemy._make_glow_texture) — the outline is drawn OUTWARD into that margin, and any
// silhouette edge that touches the texture border (a bat's wingtips do) would otherwise clip.

uniform vec4 outline_color : source_color = vec4(0.30, 0.60, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 6.0) = 1.6;   // in texels
uniform float pulse_speed = 4.0;
uniform float pulse_amount = 0.35;   // brightness swing around 1.0

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2( ps.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0,  ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a);
	// Rim lives where a neighbour is opaque but this texel is (mostly) not.
	float rim = a * (1.0 - col.a);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	vec4 outline = outline_color;
	outline.rgb *= pulse;
	outline.a = outline_color.a * rim;
	// Composite the sprite ON TOP of the glowing rim (modulate is applied automatically after).
	COLOR = mix(outline, col, col.a);
}
