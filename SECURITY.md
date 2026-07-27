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

LOLILE is intended to:

- expose the dashboard only to localhost and explicitly allowed private/Tailscale networks;
- keep Tor configuration writes restricted to localhost;
- allow remote power changes only from Tailscale addresses and only among predefined profiles;
- reject settings changes from non-loopback clients;
- avoid storing credentials in the repository;
- run the collector and dashboard without an interactive user session.

LOLILE is not an authentication gateway and should not be exposed directly to the public internet. Use a private network or add a separately audited authenticated reverse proxy.

The power endpoint does not accept command strings, executable paths, service names, or arbitrary `powercfg` settings. It maps four fixed mode names to locally installed LOLILE schemes. Every scheme disables sleep and preserves network-dependent services.

## Sensitive files that must never be committed

- Tor control authentication cookies
- private keys or relay identity directories
- `.env` files containing secrets
- Proton or other account recovery phrases
- Tailscale auth keys
- real public ContactInfo unless the operator knowingly wants it public
- live logs containing private network details
