fn main() {
    // Generate UniFFI scaffolding
    uniffi::generate_scaffolding("src/wawona.udl")
        .expect("Failed to generate UniFFI scaffolding");
    println!("cargo:rerun-if-changed=src/wawona.udl");

    // Rerun if wlroots protocols change
    println!("cargo:rerun-if-changed=protocols/wlroots/");
}
