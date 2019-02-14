use std::fs::File;
use std::io::prelude::*;

#[macro_use]
extern crate glium;
use glium::{Display, glutin, index, Surface, VertexBuffer};
use glium::glutin::{Event, VirtualKeyCode, WindowEvent};


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

    loop {
        let mut target = display.draw();
        let uniforms = uniform! {
            g_theta: 0.0f32,
            g_phi: 0.0f32,
            g_camUp: [0.0, 1.0, 0.0f32],
            g_camRight: [1.0, 0.0, 0.0f32],
            g_camForward: [0.0, 0.0, 1.0f32],
            g_eye: [0.0, 0.0, -2.0f32],
            g_focalLength: 1.67f32,
            g_zNear: 0.0f32,
            g_zFar: 15.0f32,
            g_moveSpeed: 0.1f32,
            g_rmSteps: 64,
            g_rmEpsilon: 0.001f32,
            g_skyColor: [0.31, 0.47, 0.67, 1.0f32],
            g_ambient: [0.15, 0.2, 0.32, 1.0f32],
            g_light0Position: [0.25, 2.0, 0.0f32],
            g_light0Color: [0.67, 0.87, 0.93, 1.0f32],
            g_windowWidth: 1024f32,
            g_windowHeight: 768f32,
            g_aspectRatio: 1024.0 / 768.0f32
        };
        target.draw(
            &vertex_buffer,
            index::NoIndices(index::PrimitiveType::TrianglesList),
            &program,
            &uniforms,
            &Default::default()
        ).unwrap();

        target.finish().unwrap();

        let mut should_return = false;
        events_loop.poll_events(|e| match e {
            Event::WindowEvent { event, .. } => {
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
