use ribosome_tui::runtime::{RuntimeConfig, run};

fn main() {
    let mut arguments = std::env::args().skip(1);
    let url = arguments
        .next()
        .unwrap_or_else(|| String::from("ws://127.0.0.1:8080/v1/tui"));
    let initial_prompt = arguments
        .next()
        .unwrap_or_else(|| String::from("Describe the UI."));

    if let Err(error) = run(RuntimeConfig {
        url,
        initial_prompt,
    }) {
        eprintln!("{error:?}");
        std::process::exit(1);
    }
}
