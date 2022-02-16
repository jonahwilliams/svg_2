extern crate lyon;

use lyon::math::point;
use lyon::path::Path;
use lyon::path::path::Builder;
use lyon::tessellation::*;


#[derive(Copy, Clone, Debug)]
struct Vertex { position: [f32; 2] }


#[no_mangle]
pub extern "C" fn create_path() -> *mut Builder {
    let builder = Box::new(Path::builder());
    Box::into_raw(builder)
}

#[no_mangle]
pub extern "C" fn begin(builder: *mut Builder, x: f32, y: f32) {
   unsafe {
       let builder = builder.as_mut().unwrap();
       builder.begin(point(x, y));
   }
}

#[no_mangle]
pub extern "C" fn line_to(builder: *mut Builder, x: f32, y: f32) {
   unsafe {
       let builder = builder.as_mut().unwrap();
       builder.line_to(point(x, y));
   }
}

#[no_mangle]
pub extern "C" fn cubic_to(builder: *mut Builder, x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32) {
   unsafe {
       let builder = builder.as_mut().unwrap();
       builder.cubic_bezier_to(point(x1, y1), point(x2, y2), point(x3, y3));
   }
}


#[no_mangle]
pub extern "C" fn close(builder: *mut Builder, close: bool) {
   unsafe {
       let builder = builder.as_mut().unwrap();
       builder.end(close);
   }
}

#[no_mangle]
pub extern "C" fn tessellate(builder: *mut Builder) {
    unsafe {
        let builder = builder.as_mut().unwrap().clone();
        let path = builder.build();
        let mut geometry: VertexBuffers<Vertex, u16> = VertexBuffers::new();
        let mut tessellator = FillTessellator::new();
        {
            tessellator.tessellate_path(
                &path,
                &FillOptions::default(),
                &mut BuffersBuilder::new(&mut geometry, |vertex: FillVertex| {
                    Vertex {
                        position: vertex.position().to_array(),
                    }
                }),
            ).unwrap();
        }
        println!(" -- {} vertices {} indices",
            geometry.vertices.len(),
            geometry.indices.len()
        );
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
