shader_type canvas_item;

// Split position (0.0 = top, 1.0 = bottom)
uniform float split_point : hint_range(0.0, 1.0) = 0.5;
// Color for the text/background
uniform vec4 main_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);  // Black

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float text_alpha = tex.a;

    if (UV.y < split_point) {
        // TOP: text color on transparent background
        COLOR = vec4(main_color.rgb, text_alpha);
    } else {
        // BOTTOM: transparent text (cutout) on colored background
        float inverted_alpha = 1.0 - text_alpha;
        COLOR = vec4(main_color.rgb, inverted_alpha);
    }
}
