# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-28

First public release. `scripts/check_secrets.py` is a rewrite that merges three
internal revisions of the same scanner; the most complete revision was used as
the baseline, and the rules the other two carried were folded in. Every change
below was verified by running the scanner, not by inspection.

### Added

- Rules carried over from the other revisions: `github_pat_` fine-grained
  tokens, `sk-` style API keys, account-identifier literals (`qq`, `uid`,
  `openid`, `session_id`, `account`).
- `--exclude-path PREFIX` to skip a repository-relative path prefix.
- `root` may be a single file, which is what the self-check uses.
- `--quiet`, and a documented exit-code contract (0 clean, 1 findings, 2 usage).
- `examples/fixtures/` with a deliberate-leak canary and a placeholders-only
  file, plus `examples/run_selfcheck.sh`, which asserts both behaviours and the
  repository's own cleanliness. The script resolves its own directory through
  `pwd -W` where the shell offers it, because a native Python cannot open an
  MSYS-style path (the failure mode is a confusing "can't open file" from the
  interpreter, which the self-check reports as a failed expectation).
- `docs/GATES.md`, `docs/SANITIZE_LOG.template.md`.

### Fixed

- **Findings are now masked.** The previous revision printed up to 60
  characters of the matched value, so its S1 evidence could leak the very
  secret it reported. Every finding now shows only the first four characters,
  and `absolute-path` findings print no excerpt at all, so a report pasted into
  a ticket cannot carry a drive path that a later grep would flag.
- **`--exclude` matched file names only.** `--exclude examples/fixtures`
  therefore did nothing; a directory of deliberate canaries could not be
  excluded. `--exclude` now accepts a repository-relative path, and
  `--exclude-path` does the same explicitly.
- **The path rule missed most Windows paths.** It only matched a `C:` drive
  followed by a user directory, with a backslash. A `C:` drive written with a
  forward slash, every other drive letter and the MSYS and WSL prefix forms all
  passed. It is replaced by a general absolute-path rule with a documentation
  allow-list (`<repo-root>`, `%USERPROFILE%\repo`, paths containing a generic
  segment such as `repo`, `src`, `tmp`).
- **Private addresses were silently allowed in two subnets.** The old lookahead
  skipped two whole /24 documentation subnets, so a real host in either of them
  shipped. The rule now matches any complete private address; the `x` octet
  form (`192.168.1.x`) is read as documentation and still passes.
- **MAC allow-list was case-sensitive**, so the lowercase canonical placeholder
  was reported as a leak.
- **High-entropy token heuristics** no longer report hex digests and
  GUID-carrying identifiers (git shas, device paths).

### Known limitations

- Regular expressions cannot tell a fake example from a real value; a human
  review is still required (see the README).
- Non-English identifiers, binary files and image content are not inspected.
