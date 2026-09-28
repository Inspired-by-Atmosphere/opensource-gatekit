# Sanitization log - <repo-name>

> Copy this file to `docs/SANITIZE_LOG.md` and fill it in before the gate run.
> **Record categories and counts only.** Never paste the original value, a
> masked prefix of it, or a hash of it - the log itself ships with the
> repository.

| Field | Value |
|---|---|
| Repository | `<repo-name>` |
| Staging path | `<staging-dir>` |
| Gate run date | `<YYYY-MM-DD>` |
| Scanner | `scripts/check_secrets.py` (commit `<sha>`) |
| S1 result | `RESULT: CLEAN` / `FINDINGS PRESENT` |
| Reviewed by | `<your-name>` (a human, not a tool) |

## 1. Replaced

| # | Category | Count | Action taken |
|---|---|---|---|
| 1 | user home path | 0 | rewritten to `$HOME/...` or `./` |
| 2 | absolute project path | 0 | rewritten to repository-relative paths |
| 3 | internal address | 0 | replaced with the `x.` form or an RFC 5737 range |
| 4 | host / service name | 0 | replaced with `your-server` |
| 5 | organisation name | 0 | replaced with `your-org` |
| 6 | person name / handle | 0 | replaced with `your-name` |
| 7 | credential or token | 0 | removed; the README names the environment variable only |
| 8 | real e-mail address | 0 | replaced with the noreply address |
| 9 | device identifier (MAC / serial) | 0 | replaced with the placeholder |
| 10 | customer or third-party data | 0 | removed (see section 2) |

Total replacements: **0**

## 2. Removed

Files, sections, screenshots or dataset samples that were dropped entirely
instead of being rewritten.

| # | What was removed | Category | Reason |
|---|---|---|---|
| 1 | | | |

## 3. Kept deliberately

Anything that looks like a leak in a scan report but is intentional. The gate
ships the same idea: `examples/fixtures/` contains deliberate canaries and is
excluded from the scan with `--exclude-path`.

| # | Path | Why it stays | Excluded from the gate? |
|---|---|---|---|
| 1 | `examples/fixtures/` | deliberate canaries that `run_selfcheck.sh` verifies | yes, `--exclude-path examples/fixtures` |
| 2 | `<path>` | `<reason>` | `<yes/no>` |

## 4. Licence and provenance

| Item | Answer |
|---|---|
| Files not written by us | `<none / list>` |
| Their licence | `<MIT / Apache-2.0 / ...>` |
| Declared licence of this repository | `<MIT>` |
| Reason, if not MIT | `<...>` |

## 5. Residual risk and sign-off

- Known false negatives of the scanner (see *Limitations* in the README):
  `<...>`
- Parts of the tree a human reviewed line by line: `<...>`
- Parts that were **not** reviewed: `<...>`
- Sign-off: `<name>`, `<YYYY-MM-DD>`
