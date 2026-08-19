use ribosome_tui::runtime::{RuntimeConfig, UiProfile, run};

fn usage() -> ! {
    eprintln!("usage: ribosome-tui <ws-url> <initial-prompt> <conversation|pr>");
    std::process::exit(2);
}

fn main() {
    let mut arguments = std::env::args().skip(1);
    let url = arguments.next().unwrap_or_else(|| usage());
    let initial_prompt = arguments.next().unwrap_or_else(|| usage());
    let profile = arguments
        .next()
        .and_then(|value| UiProfile::parse(&value))
        .unwrap_or_else(|| usage());
    if arguments.next().is_some() {
        usage();
    }

    if let Err(error) = run(RuntimeConfig {
        url,
        initial_prompt,
        profile,
    }) {
        eprintln!("{error:?}");
        std::process::exit(1);
    }
}
