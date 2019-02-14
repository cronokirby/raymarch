#version 150 core

out vec4 color;


const float PI = 3.14159;

float DE(vec3 pos) {
    pos.x = sin(PI * pos.x);
    pos.y = sin(PI * pos.y);
    vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
    float Power = 20.0;
	for (int i = 0; i < 4; i++) {
		r = length(z);
		if (r > 2.0) break;
		
		// convert to polar coordinates
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr =  pow( r, Power-1.0)*Power*dr + 1.0;
		
		// scale and rotate the point
		float zr = pow( r,Power);
		theta = theta*Power;
		phi = phi*Power;
		
		// convert back to cartesian coordinates
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=pos;
	}
	return 0.5*log(r)*r/dr;
}

vec4 trace(vec3 from, vec3 direction) {
    vec3 pos = from;
    vec3 x_dir = vec3(0.0001, 0, 0);
    vec3 y_dir = vec3(0, 0.0001, 0);
    vec3 z_dir = vec3(0, 0, 0.0001);
    vec3 h = normalize(vec3(0.3, 0.4, 1));
    for (int steps = 0; steps < 40; ++steps) {
        float d = DE(pos);
        vec3 n = normalize(vec3(
            DE(pos + x_dir) - DE(pos - x_dir),
            DE(pos + y_dir) - DE(pos - y_dir),
            DE(pos + z_dir) - DE(pos - z_dir)
        ));
        if (d < 0.001) {
            float scale = 1.0 - float(steps) / 40;
            return vec4(scale, scale, scale, 1.0);
        }
        pos += d * direction;
    }
    return vec4(0.0, 0.0, 0.0, 1.0);
}

void main() {
    vec3 camera_origin = vec3(1.0, 1.0, 1.4);
    vec3 camera_target = vec3(0.0, 0.0, 0.0);
    vec3 up_dir = vec3(0.0, 1.0, 0.0);
    vec3 w = normalize(camera_target - camera_origin);
    vec3 u = normalize(cross(up_dir, w));
    vec3 v = cross(w, u);
    vec2 screen_pos = -1.0 + 2.0 * gl_FragCoord.xy / 600;
    vec3 direction = normalize(w + screen_pos.x * u + screen_pos.y * v);
    color = trace(camera_origin, direction);
}