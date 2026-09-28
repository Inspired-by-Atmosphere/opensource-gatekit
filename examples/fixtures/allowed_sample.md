# Allowed patterns - this file looks risky but must stay clean

Every line below is a documentation placeholder that the scanner is designed to
ignore. If the scanner reports a finding here, the allow-list regressed:
`examples/run_selfcheck.sh` fails when this file produces any finding.

| Pattern | Example | Why it is allowed |
|---|---|---|
| environment reference | `api_key = $MY_API_KEY` | the value is an environment variable name |
| angle placeholder | `api_key = <YOUR_API_KEY>` | explicit placeholder, no literal value |
| percent placeholder | `api_key = %API_KEY%` | Windows-style environment reference |
| example e-mail | `you@example.com` | reserved documentation domain (RFC 2606) |
| GitHub noreply | `Inspired-by-Atmosphere@users.noreply.github.com` | noreply address, no mailbox |
| documentation address | `192.168.1.x` and `10.0.0.x` | the `x` octet form marks documentation |
| RFC 5737 address | `198.51.100.10` | TEST-NET-2, reserved for examples |
| placeholder MAC | `AA:BB:CC:DD:EE:FF` | canonical placeholder hardware address |
| home placeholder | `%USERPROFILE%\repo` and `<repo-root>` | no real account name in the path |
| OpenWrt section name | `dhcp.lan` | stock UCI section, not local topology |
| generic path segment | `/srv/repo/src/app.py` | `repo` / `src` are documentation segments |

Placeholders that are never filled in are reported separately as INFO
(`--show-info`), not as failures: `<YOUR_API_KEY>`, `TODO`, `XXX`.
