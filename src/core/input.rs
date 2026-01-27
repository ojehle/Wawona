


/// Button/Key state
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KeyState {
    Released = 0,
    Pressed = 1,
}

pub type ButtonState = KeyState;

/// Input event type for internal core usage
#[derive(Debug, Clone)]
pub enum InputEvent {
    PointerMotion {
        x: f64, 
        y: f64, 
        time_ms: u32
    },
    PointerButton {
        button: u32, 
        state: ButtonState, 
        time_ms: u32
    },
    PointerAxis {
        horizontal: f64,
        vertical: f64,
        time_ms: u32
    },
    KeyboardKey {
        keycode: u32,
        state: KeyState,
        time_ms: u32
    },
    KeyboardModifiers {
        depressed: u32,
        latched: u32,
        locked: u32,
        group: u32
    },
}
