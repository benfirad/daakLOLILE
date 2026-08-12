# daakLOLILE for macOS

This menu bar app is the DAAK NODE device center. It reads the daakLOLILE API over a private Tailscale connection, monitors the MYA-L11 Intel Mac server over a cable-first route with automatic Tailscale fallback, and integrates the Galaxy S9+ project phone. It shows Windows hardware, Tor/Snowflake traffic, Folding@home, BOINC, RIPE Atlas, MYA-L11 UPS/health telemetry, and the phone's connection state.

## Build

On macOS 13 or newer:

```zsh
xcode-select --install
zsh build.command
```

The script creates and opens `build/daakLOLILE.app`. Enter the Windows PC's Tailscale IP in the app.

Wake-on-LAN hardware addresses stay local and are never committed. Configure MYA-L11 on the Mac with `defaults write app.daaklolile.menu myaL11WakeMac "001122aabbcc"`, replacing the example with the server's MAC address.

The app stores only the selected host in macOS user defaults. MYA-L11 connectivity is derived from successful status synchronization and fresh SSH telemetry so macOS Local Network Privacy cannot produce a false offline state after a successful cable transfer. It can read status and request predefined, constrained actions; it cannot edit Tor settings, attach external volunteer-computing accounts, or execute arbitrary commands.
