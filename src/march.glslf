#version 150 core

out vec4 color;

void main() {
    vec2 pos = vec2(gl_FragCoord.x / 1024, gl_FragCoord.y / 768);
    color = vec4(pos.x, pos.y, 1.0, 1.0);
}