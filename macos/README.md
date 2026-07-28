# daakLOLILE for macOS

This menu bar app reads the daakLOLILE API over a private Tailscale connection. It shows Windows hardware, Tor/Snowflake traffic, Folding@home, BOINC, and RIPE Atlas state, and it can switch among the constrained Windows power profiles.

## Build

On macOS 13 or newer:

```zsh
xcode-select --install
zsh build.command
```

The script creates and opens `build/daakLOLILE.app`. Enter the Windows PC's Tailscale IP in the app.

The app stores only the selected host in macOS user defaults. It can read status and request one of four predefined power modes; it cannot edit Tor settings, attach external volunteer-computing accounts, or execute arbitrary commands. Tor, Snowflake, Folding@home, BOINC, RIPE Atlas, and the hardware collector continue to run on the Windows PC, not on the Mac.
