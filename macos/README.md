# daakLOLILE for macOS

This menu bar app reads the daakLOLILE API and switches among its constrained power profiles over a private Tailscale connection. It does not run Tor, Snowflake, or a hardware collector on the Mac.

## Build

On macOS 13 or newer:

```zsh
xcode-select --install
zsh build.command
```

The script creates and opens `build/daakLOLILE.app`. Enter the Windows PC's Tailscale IP in the app.

The app stores only the selected host in macOS user defaults. It can read status and request one of four predefined power modes; it cannot edit Tor settings or execute commands.
