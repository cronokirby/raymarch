// Credits to https://github.com/lightbits/ray-march for initial shader
#version 140

out vec4 outColor;

// Camera
uniform vec2 g_resolution;
uniform vec3 g_cam_up;
uniform vec3 g_cam_right;
uniform vec3 g_cam_forward;
uniform vec3 g_eye;
uniform float g_focal_length;
uniform float g_z_near;
uniform float g_z_far;
uniform float g_aspect;

// Raymarch parameters
uniform int g_rm_steps; // Max steps
uniform float g_rm_epsilon; // Distance threshold

// Scene
uniform vec4 g_sky_color;
uniform vec4 g_ambient;
uniform vec3 g_light_pos;
uniform vec4 g_light_color;
// Window
uniform float g_window_width;
uniform float g_window_height;

// Rotates a point t radians around the y-axis
vec3 rotate_y(vec3 v, float t) {
    float cost = cos(t); float sint = sin(t);
    return vec3(v.x * cost + v.z * sint, v.y, -v.x * sint + v.z * cost);
}

// Rotates a point t radians around the x-axis
vec3 rotate_x(vec3 v, float t) {
    float cost = cos(t); float sint = sin(t);
    return vec3(v.x, v.y * cost - v.z * sint, v.y * sint + v.z * cost);
}

// Maps x from the range [minX, maxX] to the range [minY, maxY]
// The function does not clamp the result, as it may be useful
float map_to(float x, float minX, float maxX, float minY, float maxY) {
    float a = (maxY - minY) / (maxX - minX);
    float b = minY - a * minX;
    return a * x + b;
}

// Returns the signed distance to a sphere at the origin
float sd_sphere(vec3 p, float radius) {
    return length(p) - radius;
}

// Returns the unsigned distance estimate to a box at the origin of the given size
float ud_box(vec3 p, vec3 size) {
    return length(max(abs(p) - size, vec3(0.0)));
}

// Returns the signed distance estimate to a box at the origin of the given size
float sd_box(vec3 p, vec3 size) {
    vec3 d = abs(p) - size;
    return min(max(d.x, max(d.y, d.z)), 0.0) + ud_box(p, size);
}

// Subtracts d1 from d0, assuming d1 is a signed distance
float op_subtract(float d0, float d1) {
    return max(d0, -d1);
}

// Defines the distance field for the scene
float dist_scene(vec3 p) {
    vec3 q = p;
    q.xz = mod(q.xz, 1.0) - vec2(0.5);
    float box = sd_box(q - vec3(0.0, 1.0, 0.0), vec3(0.2));
    p.x = mod(p.x, 2.0);
    float sphere = sd_sphere(p - vec3(1.0, 1.0, 2.0), 0.5);
    return min(box, sphere);
}

// Finds the closest intersecting object along the ray at origin ro, and direction rd.
// i: step count
// t: distance traveled by the ray
void raymarch(vec3 ro, vec3 rd, out int i, out float t) {
    t = 0.0;
    for (i = 0; i < g_rm_steps; ++i) {
        float dist = dist_scene(ro + rd * t);
        // We make epsilon proportional to t so that we drop accuracy the further into the scene we get
        // We also drop the ray as soon as it leaves the clipping volume as defined by g_z_far
        if (dist < g_rm_epsilon * t * 2.0 || t > g_z_far) break;
        t += dist;
    }
}

// Returns a value between [0, 1] depending on how visible p0 is from p1
// k: denotes the soft-shadow strength
// See http://www.iquilezles.org/www/articles/rmshadows/rmshadows.htm
float get_visibility(vec3 p0, vec3 p1, float k) {
    vec3 rd = normalize(p1 - p0);
    float t = 10.0 * g_rm_epsilon;
    float maxt = length(p1 - p0);
    float f = 1.0;
    while (t < maxt) {
        float d = dist_scene(p0 + rd * t);
        // A surface was hit before we reached p1
        if (d < g_rm_epsilon) {
            return 0.0;
        }
        // Penumbra factor
        f = min(f, k * d / t);
        t += d;
    }
    return f;
}

// Approximates the (normalized) gradient of the distance function at the given point.
// If p is near a surface, the function will approximate the surface normal.
vec3 get_normal(vec3 p) {
    float h = 0.0001;

    return normalize(vec3(
        dist_scene(p + vec3(h, 0, 0)) - dist_scene(p - vec3(h, 0, 0)),
        dist_scene(p + vec3(0, h, 0)) - dist_scene(p - vec3(0, h, 0)),
        dist_scene(p + vec3(0, 0, h)) - dist_scene(p - vec3(0, 0, h))));
}

// Calculate the light intensity with soft shadows
// p: point on surface
// lightPos: position of the light source
// lightColor: the radiance of the light source
// returns: the color of the point
vec4 get_shading(vec3 p, vec3 normal, vec3 lightPos, vec4 lightColor) {
    float intensity = 0.0;
    float vis = get_visibility(p, lightPos, 16);
    if (vis > 0.0) {
        vec3 lightDirection = normalize(lightPos - p);
        intensity = clamp(dot(normal, lightDirection), 0, 1) * vis;
    }
    return lightColor * intensity + g_ambient * (1.0 - intensity);
}

// Compute an ambient occlusion factor
// p: point on surface
// n: normal of the surface at p
// returns: a value clamped to [0, 1], where 0 means there were no other surfaces around the point,
// and 1 means that the point is occluded by other surfaces.
float ambient_occlusion(vec3 p, vec3 n) {
    float stepSize = 0.01;
    float t = stepSize;
    float oc = 0.0;
    for(int i = 0; i < 10; ++i) {
        float d = dist_scene(p + n * t);
        oc += t - d; // Actual distance to surface - distance field value
        t += stepSize;
    }
    return clamp(oc, 0, 1);
}

// Create a checkboard texture
vec4 get_floor_texture(vec3 p) {
    vec2 m = mod(p.xz, 2.0) - vec2(1.0);
    return m.x * m.y > 0.0 ? vec4(0.1) : vec4(1.0);
}

// To improve performance we raytrace the floor
// n: floor normal
// o: floor position
float raytrace_floor(vec3 ro, vec3 rd, vec3 n, vec3 o) {
    return dot(o - ro, n) / dot(rd, n);
}

vec4 compute_color(vec3 ro, vec3 rd) {
    float t0;
    int i;
    raymarch(ro, rd, i, t0);

    vec3 floorNormal = vec3(0, 1, 0);
    float t1 = raytrace_floor(ro, rd, floorNormal, vec3(0, -0.5, 0));

    vec3 p; // Surface point
    vec3 normal; // Surface normal
    float t; // Distance traveled by ray from eye
    vec4 texture = vec4(1.0); // Surface texture

    // The floor was closest
    if (t1 < t0 && t1 >= g_z_near && t1 <= g_z_far) {
        t = t1;
        p = ro + rd * t1;
        normal = floorNormal;
        texture = get_floor_texture(p);
    } // Raymarching hit a surface
    else if (i < g_rm_steps && t0 >= g_z_near && t0 <= g_z_far) {
        t = t0;
        p = ro + rd * t0;
        normal = get_normal(p);
    } else {
        return g_sky_color;
    }

    vec4 color;
    float z = map_to(t, g_z_near, g_z_far, 1, 0); // Map depth to [0, 1]

    // Color based on depth
    //color = vec4(1.0f) * z;

    // Diffuse lighting
    color = texture * (
        get_shading(p, normal, g_light_pos, g_light_color) +
        get_shading(p, normal, vec3(2.0, 1.0, 0.0), vec4(1.0, 0.5, 0.5, 1.0))
        ) / 2.0;

    // Color based on surface normal
    //color = vec4(abs(normal), 1.0);

    // Blend in ambient occlusion factor
    float ao = ambient_occlusion(p, normal);
    color = color * (1.0 - ao);

    // Blend the background color based on the distance from the camera
    float zSqrd = z * z;
    color = mix(g_sky_color, color, zSqrd * (3.0 - 2.0 * z)); // Fog

    return color;
}

void main() {
    vec2 uv = vec2(gl_FragCoord.x / g_window_width, gl_FragCoord.y / g_window_height);
    vec2 hps = vec2(1.0) / (g_resolution * 2.0);
    vec3 ro = g_eye;
    vec3 rd = normalize(g_cam_forward * g_focal_length + g_cam_right * uv.x * g_aspect + g_cam_up * uv.y);
    vec4 color = compute_color(ro, rd);
    outColor = vec4(color.xyz, 1.0);
}
