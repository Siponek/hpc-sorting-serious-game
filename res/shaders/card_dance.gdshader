shader_type canvas_item;

// Dance animation parameters
uniform float sway_angle : hint_range(0.0, 0.5) = 0.15;        // Max rotation in radians
uniform float sway_speed : hint_range(0.0, 5.0) = 2.0;         // Speed of the sway
uniform float horizontal_sway : hint_range(0.0, 30.0) = 8.0;   // Side-to-side movement
uniform float vertical_bounce : hint_range(0.0, 20.0) = 3.0;   // Up-down bounce
uniform float phase_offset : hint_range(0.0, 6.28) = 0.0;      // Offset to desync multiple cards

void vertex() {
    // Get the pivot point (bottom center of the card)
    // We'll rotate around this point
    float pivot_y = 1.0;  // Bottom of the control (in normalized space, but we use pixels)

    // Time with phase offset for desyncing cards
    float t = TIME * sway_speed + phase_offset;

    // Rotation angle - smooth sine wave
    float angle = sin(t) * sway_angle;

    // Calculate rotation around bottom center
    // First, translate to pivot point (bottom center)
    vec2 pivot = vec2(0.0, VERTEX.y);  // We'll use the vertex's own Y as reference

    // For a proper bottom-pivot rotation, we need the control's size
    // We approximate by using the vertex position relative to a center point
    float center_x = 50.0;  // Approximate half-width of card (100/2)
    float bottom_y = 150.0; // Approximate height of card

    // Translate vertex relative to bottom-center pivot
    vec2 pos = VERTEX.xy;
    pos.x -= center_x;
    pos.y -= bottom_y;

    // Apply rotation
    float cos_a = cos(angle);
    float sin_a = sin(angle);
    vec2 rotated;
    rotated.x = pos.x * cos_a - pos.y * sin_a;
    rotated.y = pos.x * sin_a + pos.y * cos_a;

    // Translate back
    rotated.x += center_x;
    rotated.y += bottom_y;

    // Add elliptical horizontal sway (figure-8 like motion)
    float h_offset = sin(t) * horizontal_sway;

    // Add vertical bounce (double frequency for bounce feel)
    float v_offset = -abs(sin(t * 2.0)) * vertical_bounce;

    // Apply final position
    VERTEX.xy = rotated + vec2(h_offset, v_offset);
}
