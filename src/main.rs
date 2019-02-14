use std::fs::File;
use std::io::prelude::*;
use std::time::{Duration, Instant};

#[macro_use]
extern crate glium;
use glium::{Display, glutin, index, Surface, VertexBuffer};
use glium::glutin::{ElementState, Event, VirtualKeyCode, WindowEvent};

mod math;
use math::Vec3;


#[derive(Debug)]
struct Controls {
    left: bool,
    right: bool,
    up: bool,
    down: bool    
}

impl Controls {
    fn new() -> Self {
        Controls { left: false, right: false, up: false, down: false }
    }

    fn update(&mut self, event: &WindowEvent) {
        if let WindowEvent::KeyboardInput { input, .. } = event {
            let toggle = input.state == ElementState::Pressed;
            match input.virtual_keycode {
                Some(VirtualKeyCode::A) => self.left = toggle,
                Some(VirtualKeyCode::D) => self.right = toggle,
                Some(VirtualKeyCode::W) => self.up = toggle,
                Some(VirtualKeyCode::S) => self.down = toggle,
                _ => {}
            }
        }
    }
}

/// A struct for the first person Camera
struct Camera {
    /// Horizontal angle
    theta: f32,
    /// Vertical angle
    phi: f32,
    up: Vec3,
    right: Vec3,
    forward: Vec3,
    /// The position of the Camera in the global space
    position: Vec3,
    /// The controls for the Camera
    controls: Controls
}

impl Camera {
    fn from_angles(theta: f32, phi: f32, position: Vec3) -> Self {
        let sin_theta = theta.sin();
        let cos_theta = theta.cos();
        let sin_phi = phi.sin();
        let cos_phi = phi.cos();

        let forward = Vec3::new(
            cos_phi * sin_theta,
            -sin_phi,
            cos_phi * cos_theta
        );
        let right = Vec3::new(
            cos_theta,
            0.0f32,
            -sin_theta
        );
        let up = forward.cross(right).norm();

        Camera { 
            theta, phi, up, right, forward, position,
            controls: Controls::new()
        }
    }

    fn update(&mut self, dt: f32, event: &WindowEvent) {
        let move_speed = 2.0 * dt;
        self.controls.update(event);
        if self.controls.left {
            self.position -= self.right * move_speed;
        }
        if self.controls.right {
            self.position += self.right * move_speed;
        }
        if self.controls.up {
            self.position += self.forward * move_speed;
        }
        if self.controls.down {
            self.position -= self.forward * move_speed;
        }
    }

    fn get_up(&self) -> [f32; 3] {
        self.up.uniform()
    }

    fn get_right(&self) -> [f32; 3] {
        self.right.uniform()
    }

    fn get_forward(&self) -> [f32; 3] {
        self.forward.uniform()
    }

    fn get_position(&self) -> [f32; 3] {
        self.position.uniform()
    }
}

impl Default for Camera {
    fn default() -> Self {
        Camera::from_angles(0.0, 0.0, Vec3::new(0.0, 0.0, 0.0))
    }
}


#[derive(Copy, Clone)]
struct Vertex {
    position: [f32; 2]
}
implement_vertex!(Vertex, position);


fn main() {
    let mut events_loop = glutin::EventsLoop::new();
    let window = glutin::WindowBuilder::new()
        .with_title("Ray March".to_string())
        .with_dimensions((1024, 768).into());
    let context = glutin::ContextBuilder::new();
    let display = Display::new(window, context, &events_loop).unwrap();

    let mut file = File::open("src/march.glslf").expect("No shader file");
    let mut shader = String::new();
    file.read_to_string(&mut shader).expect("Failed to read shader");
    let program = glium::Program::from_source(
        &display,
        include_str!("march.glslv"),
        &shader,
        None
    ).unwrap();

    let vertices = [
        Vertex{ position: [-1.0,  1.0]},
        Vertex{ position: [ 1.0,  1.0]},
        Vertex{ position: [-1.0, -1.0]},

        Vertex{ position: [-1.0, -1.0]},
        Vertex{ position: [ 1.0,  1.0]},
        Vertex{ position: [ 1.0, -1.0]}
    ];
    let vertex_buffer = VertexBuffer::new(&display, &vertices).unwrap();

    let mut camera = Camera::default();
    let mut then = Instant::now();

    loop {
        let mut target = display.draw();
        let uniforms = uniform! {
            g_cam_up: camera.get_up(),
            g_cam_right: camera.get_right(),
            g_cam_forward: camera.get_forward(),
            g_eye: camera.get_position(),
            g_focal_length: 1.67f32,
            g_z_near: 0.0f32,
            g_z_far: 15.0f32,
            g_moveSpeed: 0.1f32,
            g_rm_steps: 64,
            g_rm_epsilon: 0.001f32,
            g_sky_color: [0.31, 0.47, 0.67, 1.0f32],
            g_ambient: [0.15, 0.2, 0.32, 1.0f32],
            g_light_pos: [0.25, 2.0, 0.0f32],
            g_light_color: [0.67, 0.87, 0.93, 1.0f32],
            g_window_width: 1024f32,
            g_window_height: 768f32,
            g_aspect: 1024.0 / 768.0f32
        };
        target.draw(
            &vertex_buffer,
            index::NoIndices(index::PrimitiveType::TrianglesList),
            &program,
            &uniforms,
            &Default::default()
        ).unwrap();

        target.finish().unwrap();

        let now = Instant::now();
        let dt = (now.duration_since(then).subsec_micros() as f32) / 1000000.0;
        then = now;

        let mut should_return = false;
        events_loop.poll_events(|e| match e {
            Event::WindowEvent { event, .. } => {
                camera.update(dt, &event);
                match event {
                    WindowEvent::CloseRequested => should_return = true,
                    WindowEvent::KeyboardInput { input, .. } => {
                        if let Some(VirtualKeyCode::Escape) = input.virtual_keycode {
                            should_return = true;
                        }
                    }
                    _ => {}
                }
            }
            _ => {}
        });
        if should_return {
            return;
        }
    }
}
