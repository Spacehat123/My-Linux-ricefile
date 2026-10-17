precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 pixColor = texture2D(tex, v_texcoord);
    // Warm night light color filter (4200K equivalent blue-light reduction)
    pixColor.r = min(1.0, pixColor.r * 1.05);
    pixColor.g = pixColor.g * 0.88;
    pixColor.b = pixColor.b * 0.65;
    gl_FragColor = pixColor;
}
