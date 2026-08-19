# Ribosome TUI smoke test

Start a Dream server that exposes `ws://127.0.0.1:8080/v1/tui`, then run:

```sh
cargo run -p ribosome-tui -- ws://127.0.0.1:8080/v1/tui 'Explain this change.'
```

The final argument is the consumer-supplied initial prompt. `Ctrl-C` restores the terminal and exits.
