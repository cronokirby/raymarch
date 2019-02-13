#version 150 core

out vec4 color;

float good_mod(float f, float m) {
    if (f > m) {
        return -m;
    } else if (-f > m) {
        return m;
    } else {
        return f;
    }
}

float DE(vec3 pos) {
    vec3 c = vec3(0.5, 0.5, -2.0);
    //float x2 = length(pos + vec3(1.2, 0.0, 0.0) - c) - 0.05;
    //float x3 = length(pos - vec3(1.2, 0.0, 0.0) - c) - 0.05;
    pos.x = mod(pos.x, 1.0);
    pos.y = mod(pos.y, 1.0);
    pos.z = -mod(-pos.z, 2.0);
    float x1 = length(pos - c) - 0.2;
    return x1;
}

vec4 trace(vec3 from, vec3 direction) {
    vec3 pos = from;
    vec3 x_dir = vec3(0.0001, 0, 0);
    vec3 y_dir = vec3(0, 0.0001, 0);
    vec3 z_dir = vec3(0, 0, 0.0001);
    vec3 h = normalize(vec3(0.3, 0.4, 1));
    for (int steps = 0; steps < 20; ++steps) {
        float d = DE(pos);
        vec3 n = normalize(vec3(
            DE(pos + x_dir) - DE(pos - x_dir),
            DE(pos + y_dir) - DE(pos - y_dir),
            DE(pos + z_dir) - DE(pos - z_dir)
        ));
        if (d < 0.001) {
            float scale = 1.0 - float(steps) / 20;
            vec3 ambient = vec3(0.1, 0.0, 0.2);
            float specular = 0.0;
            float lambertian = max(dot(n, h), 0.0);
            if (lambertian > 0.0) {
                specular = pow(lambertian, 4.0);
            }
            vec3 color = ambient
                + vec3(0.2, 0.0, 0.6) * max(dot(n, h), 0.0) * scale
                + vec3(1.0, 1.0, 1.0) * specular * scale;
            return vec4(color, 1.0);
        }
        pos += d * direction;
    }
    return vec4(0.0, 0.0, 0.04, 1.0);
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