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
        .with_dimensions((600, 600).into());
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
        target.draw(
            &vertex_buffer,
            index::NoIndices(index::PrimitiveType::TrianglesList),
            &program,
            &uniform! {},
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
