# Security policy

## Reporting a vulnerability

Please do not publish exploit details, personal IP addresses, relay ContactInfo, fingerprints tied to an undisclosed operator, authentication cookies, recovery phrases, or access tokens in a public issue.

Use GitHub's private vulnerability reporting feature for this repository. Include:

- the affected version or commit;
- the attack prerequisites;
- a minimal reproduction with secrets removed;
- the expected security boundary;
- a suggested mitigation, if known.

## Supported security boundary

daakLOLILE is intended to:

- expose the dashboard only to localhost and explicitly allowed private/Tailscale networks;
- keep Tor configuration writes restricted to localhost;
- allow remote power changes only from Tailscale addresses and only among predefined profiles;
- allow BOINC management only through fixed action identifiers from localhost or Tailscale;
- reject settings changes from non-loopback clients;
- avoid storing credentials in the repository;
- run the collector and dashboard without an interactive user session.

daakLOLILE is not an authentication gateway and should not be exposed directly to the public internet. Use a private network or add a separately audited authenticated reverse proxy.

The power endpoint does not accept command strings, executable paths, service names, or arbitrary `powercfg` settings. It maps four fixed mode names to locally installed daakLOLILE schemes. Every scheme disables sleep and preserves network-dependent services.

The memory-maintenance endpoint accepts no process names, paths, thresholds, or command strings. It can only run the bundled maintenance policy, which targets daakLOLILE helper processes. Tor, Snowflake, Tailscale, remote-desktop, file-sharing, and unrelated application processes are outside its allowlist.

The BOINC console is not a shell. It accepts only fixed action identifiers defined in the server source. The browser cannot supply command text, executable paths, arguments, PowerShell, service names, or file paths. Console requests require a localhost/Tailscale source, an allowed host header, a matching origin, and a short-lived in-memory token. Actions run under the dashboard's `SYSTEM` task and are written to a local metadata-only audit log. Do not add a free-form terminal to this service.

The Windows installer restricts the installation directory to full control for `SYSTEM` and Administrators, with read-and-execute access for standard users. This is required because scheduled tasks execute the installed scripts as `SYSTEM`.

## Sensitive files that must never be committed

- Tor control authentication cookies
- private keys or relay identity directories
- `.env` files containing secrets
- Proton or other account recovery phrases
- Tailscale auth keys
- real public ContactInfo unless the operator knowingly wants it public
- live logs containing private network details
