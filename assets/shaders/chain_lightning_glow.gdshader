shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 2.0) = 0.6;
uniform vec4 glow_color : source_color = vec4(1.0, 0.95, 0.4, 1.0);
uniform float flicker_speed = 8.0;
uniform float flicker_intensity = 0.2;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float flicker = 1.0 + sin(TIME * flicker_speed + UV.x * 10.0) * flicker_intensity;
    COLOR = tex * flicker;

    // 简单发光（叠加一层外发光色）
    float dist = length(UV - vec2(0.5, 0.5));
    float glow = smoothstep(0.5, 0.2, dist) * glow_strength;
    COLOR.rgb += glow * glow_color.rgb * tex.a;
}
