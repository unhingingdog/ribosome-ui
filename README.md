# Ribosome

Build a native macOS ARM64 release archive:

```sh
./scripts/package-macos-arm64 /absolute/output/path
```

The command creates a versioned release directory, `.tar.gz` archive, and SHA-256 checksum under the output path. It requires the OCaml and Rust build dependencies only on the build host.

Extract and install the archive:

```sh
tar -xzf ribosome-<version>-macos-arm64.tar.gz
cd ribosome-<version>-macos-arm64
xattr -dr com.apple.quarantine . || true
./install
```

Open a new terminal, then run `ribosome`. To use the current terminal, run `source ~/.zprofile && hash -r` first. The installer copies the release to `~/.local/share/ribosome`, links `ribosome` into `~/.local/bin`, and adds that location to the zsh login-shell path. Run `./uninstall` from an extracted archive of that release to remove it.

`ribosome` starts a loopback-only Dream server, waits for it to become ready, runs the Ratatui client, then stops Dream when the client exits. It requires an installed and authenticated `codex` command. The current directory is the Codex working directory. Use `ribosome pr` or `ribosome pr --base origin/main` for PR mode.

The release is ad-hoc signed rather than Developer ID signed; remove the quarantine attribute before installation when macOS applies one.
