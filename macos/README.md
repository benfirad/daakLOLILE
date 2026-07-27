# RelayWatch for macOS

This menu bar app reads the RelayWatch API over a private Tailscale connection. It does not run Tor, Snowflake, or a hardware collector on the Mac.

## Build

On macOS 13 or newer:

```zsh
xcode-select --install
zsh build.command
```

The script creates and opens `build/RelayWatch.app`. Enter the Windows PC's Tailscale IP in the app.

The app stores only the selected host in macOS user defaults. Remote API access is read-only.
