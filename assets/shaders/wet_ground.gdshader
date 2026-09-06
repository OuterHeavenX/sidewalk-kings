shader_type canvas_item;

// Wet ground.
//
// Two things happen to a street when it is wet: it goes darker and slightly more saturated,
// and long soft bands of reflected light slide across it. This does both, cheaply, with no
// screen reads -- the game runs on the Compatibility renderer for WebGL2 and mobile, where
// reading the screen in 2D is a trap, so nothing here samples anything but its own texture.
//
// The pattern is computed in WORLD space, not UV space. Ground is drawn as hundreds of 16px
// tiles, so a UV-driven pattern restarts inside every tile and paints a grid on top of the
// one the tile variants were added to break up. The varying below is the whole reason this
// reads as one wet street rather than as wet squares.

uniform float wetness : hint_range(0.0, 1.0) = 0.5;
uniform float sheen_scale = 0.010;
uniform float sheen_speed = 0.10;
uniform vec3 sheen_tint : source_color = vec3(0.60, 0.72, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Wet darkens and deepens. Subtle: the lighting pass is what carries this picture, and
	// a ground that fights it just looks muddy.
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 wet = mix(tex.rgb, mix(vec3(lum), tex.rgb, 1.25) * 0.88, wetness);

	// Broad bands of reflected light, two frequencies so it never reads as one sine wave.
	float a = sin(world_pos.x * sheen_scale + TIME * sheen_speed);
	float b = sin((world_pos.x * 0.6 + world_pos.y * 1.7) * sheen_scale - TIME * sheen_speed * 0.6);
	float band = (a + b) * 0.25 + 0.5;
	float streak = smoothstep(0.62, 0.98, band);

	// Held below 1.0 on purpose. Glow threshold is exactly 1.0, so anything brighter than
	// this would bloom -- and a blooming pavement is not a highlight, it is a bug.
	vec3 lit = wet + sheen_tint * streak * 0.075 * wetness;

	COLOR = vec4(clamp(lit, vec3(0.0), vec3(0.98)), tex.a);
}
