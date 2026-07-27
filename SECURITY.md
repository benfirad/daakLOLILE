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

RelayWatch is intended to:

- expose the dashboard only to localhost and explicitly allowed private/Tailscale networks;
- keep remote API access read-only;
- reject settings changes from non-loopback clients;
- avoid storing credentials in the repository;
- run the collector and dashboard without an interactive user session.

RelayWatch is not an authentication gateway and should not be exposed directly to the public internet. Use a private network or add a separately audited authenticated reverse proxy.

## Sensitive files that must never be committed

- Tor control authentication cookies
- private keys or relay identity directories
- `.env` files containing secrets
- Proton or other account recovery phrases
- Tailscale auth keys
- real public ContactInfo unless the operator knowingly wants it public
- live logs containing private network details
