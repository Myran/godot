shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float amount : hint_range(0.0, 5.0) = 0.0;

void fragment() {
    COLOR = textureLod(screen_texture, SCREEN_UV, amount);
}
