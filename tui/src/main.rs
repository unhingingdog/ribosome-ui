use ribosome_tui::runtime::{RuntimeConfig, run};

fn main() {
    let mut arguments = std::env::args().skip(1);
    let url = arguments.next().unwrap_or_else(|| {
        eprintln!("usage: ribosome-tui <ws-url> <initial-prompt>");
        std::process::exit(2);
    });
    let initial_prompt = arguments.next().unwrap_or_else(|| {
        eprintln!("usage: ribosome-tui <ws-url> <initial-prompt>");
        std::process::exit(2);
    });

    if let Err(error) = run(RuntimeConfig {
        url,
        initial_prompt,
    }) {
        eprintln!("{error:?}");
        std::process::exit(1);
    }
}
