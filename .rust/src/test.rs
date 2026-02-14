use godot::classes::{ISprite2D, Sprite2D};
use godot::prelude::*;
use std::f32::consts::PI;

#[derive(GodotClass)]
#[class(base=Sprite2D)]
struct Player {
    speed: f32,
    angular_speed: f32,
    base: Base<Sprite2D>,
}

#[godot_api]
impl ISprite2D for Player {
    fn init(base: Base<Sprite2D>) -> Self {
        godot_print!("Hello, world!"); // Prints to the Godot console

        Self {
            speed: 400.,
            angular_speed: PI,
            base,
        }
    }

    fn physics_process(&mut self, delta: f32) {
        // GDScript code:
        //
        // rotation += angular_speed * delta
        // var velocity = Vector2.UP.rotated(rotation) * speed
        // position += velocity * delta

        let radians = self.angular_speed * delta;
        self.base_mut().rotate(radians);

        let rotation = self.base().get_rotation();
        let velocity = Vector2::UP.rotated(rotation) * self.speed;
        self.base_mut().translate(velocity * delta);

        // or verbose:
        // let this = self.base_mut();
        // this.set_position(
        //     this.position() + velocity * delta as f32
        // );
    }
}
