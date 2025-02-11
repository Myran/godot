shader_type canvas_item;

uniform float vignette_intensity = 0.40;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_rgb : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D mask;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D tex : hint_default_white;

float vignette(vec2 uv){
    uv *= 1.0 - uv.xy;
    float vignette = uv.x * uv.y * 15.0;
    return pow(vignette, vignette_intensity * vignette_opacity);
}

void fragment(){
    vec4 color = texture(screen_tex, SCREEN_UV);
    vec4 text = texture(tex, UV);

    text.rgba *= (vignette_rgb.rgba);
    text.rgba *= (1.0 - vignette(UV));

    vec4 mask_color = texture(mask, UV).rgba;
    if (mask_color.a == 0.0)
    {
        text.a = 0.0;
    }
    COLOR = vec4((text.rgb)*color.rgb,text.a);
}
