#version 150 core

out vec4 color;


vec4 trace(vec3 from, vec3 direction) {
    vec3 pos = from;
    for (int steps = 0; steps < 20; ++steps) {
        float d = length(pos - vec3(0.0, 0.0, -2.0)) - 0.5;
        if (d < 0.001) {
            float scale = 1.0 - float(steps) / 20;
            return vec4(vec3(1.0, 1.0, 1.0) * scale, 1.0);
        }
        pos += d * direction;
    }
    return vec4(1, 1, 1, 1.0);
}

void main() {
    float aspect = 600 / 600;
    float half_height = 1;
    float half_width = aspect * half_height;
    vec3 lower_left = vec3(-half_width, -half_height, -1);
    vec3 horizontal = vec3(2 * half_width, 0, 0);
    vec3 vertical = vec3(0, 2 * half_height, 0);
    vec3 origin = vec3(0, 0, 0);
    vec3 direction = lower_left + gl_FragCoord.x / 600 * horizontal + gl_FragCoord.y / 600 * vertical;
    color = trace(origin, direction);
}