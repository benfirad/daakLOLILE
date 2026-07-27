# LOLILE

**A privacy-first Windows Tor relay dashboard, PC hardware monitor, safe power-mode controller, desktop widget, and macOS menu bar companion.**

[Türkçe dokümantasyon](docs/README.tr.md)

[![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?logo=windows11)](https://www.microsoft.com/windows/)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple)](https://support.apple.com/macos)
[![Tor non-exit](https://img.shields.io/badge/Tor-middle%20relay-7D4698?logo=torproject)](https://community.torproject.org/relay/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

LOLILE combines live Tor middle-relay traffic, Snowflake proxy statistics, CPU/GPU/RAM/disk/network telemetry, estimated power use, safe automatic night power modes, a small Windows desktop widget, and a macOS menu bar app. Remote access and power control are designed for a private [Tailscale](https://tailscale.com/) network.

![LOLILE dashboard preview](docs/lolile-dashboard.svg)

## Why LOLILE?

- Monitor a Windows Tor **middle/non-exit relay** without exposing an admin panel to the public internet.
- See relay bandwidth, bootstrap, reachability, consensus status, Snowflake connections, and total contributed traffic.
- Track CPU, GPU, memory, disks, network throughput, temperatures, component power sensors, and top processes.
- Keep collecting data before logon by running the Windows tasks as `SYSTEM`.
- Check the PC and switch power modes from a Mac menu bar app over Tailscale.
- Automatically use an efficient CPU/display profile at night without sleep, hibernation, network shutdown, or service interruption.
- Keep Tor settings localhost-only while allowing the narrow power-mode endpoint from localhost and Tailscale.

## Security model

LOLILE does not turn a relay into an exit node. Your Tor configuration should contain:

```text
SocksPort 0
ExitRelay 0
ExitPolicy reject *:*
```

The installer creates an inbound rule for the dashboard port that accepts only Tailscale IPv4 and IPv6 ranges. It does **not** change the Tor ORPort, router forwarding, Tailscale, Remote Desktop, file sharing, or Snowflake configuration.

The API deliberately allows Tor settings changes only from loopback (`127.0.0.1` or `::1`). The separate power endpoint accepts requests only from loopback or Tailscale addresses and can select only the predefined `auto`, `eco`, `balanced`, and `performance` profiles. It cannot execute arbitrary commands or stop services. Treat relay nickname, fingerprint, public ContactInfo, IP addresses, and logs as potentially sensitive operational information.

## Requirements

- Windows 10/11 x64
- An existing Tor relay installation whose `torrc` is under `C:\ProgramData\TorRelay` by default
- Node.js 22 or newer
- Administrator access for installation
- Optional: Tailscale on Windows and macOS
- Optional: macOS 13 or newer with Apple command-line developer tools

LOLILE downloads the pinned official [LibreHardwareMonitor 0.9.6](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/tag/v0.9.6) archive and verifies its SHA-256 checksum during Windows installation.

## Windows quick start

Download or clone the repository, open PowerShell as Administrator, then run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\install.ps1 -InstallWidget
```

If your Tor files live elsewhere:

```powershell
.\windows\install.ps1 -TorRoot 'D:\TorRelay' -DashboardPort 17657 -InstallWidget
```

Open the local dashboard:

```text
http://127.0.0.1:17657
```

From another device on the same tailnet, use the Windows PC's Tailscale IP:

```text
http://100.x.y.z:17657
```

## macOS menu bar app

1. Install and connect Tailscale on both devices.
2. Copy the `macos` folder to the Mac.
3. In Terminal, run `zsh build.command` from that folder.
4. Enter the Windows PC's Tailscale IP in LOLILE and choose **Connect**.
5. Switch between automatic, night-saving, balanced, and high-performance modes from the menu bar.
6. Optionally move `build/LOLILE.app` to Applications and add it under **System Settings → General → Login Items**.

The Mac app reads monitoring data and can call only the constrained power-mode endpoint. It does not run a relay or proxy on the Mac and cannot change Tor settings.

## Safe power modes

LOLILE creates three dedicated Windows power schemes and an automatic controller:

- **Automatic:** night-saving from `00:00` to `08:00` by default, balanced during the day.
- **Night saving:** caps CPU maximum state at 60%, disables boost where supported, and turns the display off sooner.
- **Balanced:** full CPU range with normal display timing.
- **High performance:** full CPU range and boost with a longer display timeout.

All LOLILE schemes explicitly disable sleep, hibernation, and hybrid sleep. They do not change network-adapter, USB, disk, Tor, Snowflake, Tailscale, Chrome Remote Desktop, RDP, SMB, or Syncthing settings. The controller runs as `SYSTEM` before login and checks the schedule every five minutes.

## Power readings and Corsair PSUs

The PSU wattage printed on the label—650 W, 750 W, and so on—is maximum capacity, not continuous consumption.

LOLILE uses real component sensors where LibreHardwareMonitor exposes them. It estimates missing CPU/system/PSU losses and labels the total wall-power value as an estimate. A standard PSU has no software data connection. Some digital Corsair RMi/HXi models can expose telemetry through an internal USB connection and iCUE, but LOLILE does not currently integrate iCUE.

For accurate whole-PC energy measurement, use a reputable external smart plug or power meter with local API access.

## Data and ports

| Item | Default |
| --- | --- |
| Install directory | `C:\ProgramData\LOLILE` |
| Dashboard | TCP `17657` |
| Dashboard exposure | Tailscale ranges only |
| Hardware sampling | Every 2 seconds |
| Browser refresh | Every 5 seconds |
| macOS refresh | Every 10 seconds |
| Default night schedule | `00:00–08:00` local Windows time |
| Power controller | Startup + every 5 minutes, as `SYSTEM` |
| Tor root | `C:\ProgramData\TorRelay` |

Energy history and relay traffic counters stay on the Windows PC. No analytics or third-party telemetry is included.

## Uninstall

Run as Administrator:

```powershell
.\windows\uninstall.ps1
```

The uninstaller removes LOLILE tasks, its firewall rule, widget shortcut, and installed files. It does not remove Tor, Snowflake, Tailscale, or their data. Use `-KeepData` to keep the LOLILE data directory.

## Project layout

```text
windows/
  install.ps1
  uninstall.ps1
  hardware-monitor.ps1
  power-manager.ps1
  widget.ps1
  dashboard/
macos/
  Sources/LOLILEApp.swift
  build.command
docs/
```

## Contributing

Bug reports, sensor compatibility results, translations, accessibility improvements, and safe integrations for local power meters are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md) before submitting changes.

## Disclaimer

LOLILE is an independent community project. It is not affiliated with or endorsed by The Tor Project, Tailscale, Corsair, or LibreHardwareMonitor. Run relays in accordance with your local laws, ISP terms, and the official Tor relay documentation.

## License

[MIT](LICENSE)
