# opensource-gatekit

A pre-flight gate for the moment just before a repository becomes public: **scan
for leaks, sanitize what you find, verify the result with raw evidence, then
commit.** One dependency-free Python script plus the review discipline that
makes its output trustworthy.

- **Zero dependencies.** Python 3.8+, standard library only, no network access.
- **Safe to paste.** Every finding is masked, so a scan report can go into a
  ticket or a chat without leaking the value it reports.
- **Provable.** The repository ships deliberately leaky fixtures and a
  self-check that fails if the scanner ever stops catching them.

```console
$ python scripts/check_secrets.py . --exclude-path examples/fixtures

scanned 11 file(s); findings: 0
RESULT: CLEAN
```

## Why this exists

Publishing is a one-way door. A token, an internal host name or a colleague's
e-mail address that reaches a public commit stays in the history even after you
delete the line, and the copy on someone else's laptop stays forever. Reviewing
a tree by eye misses exactly the things that matter, because the dangerous lines
look like ordinary configuration.

So the check has to be mechanical, its result has to be reproducible by someone
else, and the evidence has to be safe to show. That is all this kit is.

It is **not** a history rewriter: it inspects the working tree. If a secret was
already committed, rotate the secret and rewrite history separately.

## The four admission gates

Decide *whether* something may be published before checking *whether* the copy
is clean. Full definitions, including the sanitization mapping, are in
[`docs/GATES.md`](docs/GATES.md).

| Gate | Question | Fails when |
|---|---|---|
| **G1 Copyright** | Did we write it, or is it licence-compatible? | third-party code or text, private team files, licence-restricted datasets |
| **G2 Privacy** | Is there anything that identifies a person, machine or account? | keys, tokens, passwords, real names, e-mail addresses, private IPs, MACs, host names |
| **G3 Confidentiality** | Is this internal material rather than method? | internal figures and decisions, member information, unpublished results |
| **G4 Usability** | Can a stranger run it on a clean machine? | hard-coded absolute paths, implicit dependencies, mandatory paid services |

## Quickstart (3 minutes)

```console
# 1. prove the toolchain: scanner, fixtures and this repository must agree
$ bash examples/run_selfcheck.sh

# 2. copy the tree you want to publish into a staging directory
$ cp -r /path/to/candidate ./staging-copy

# 3. scan it, fix what it reports, scan again until it says CLEAN
$ python scripts/check_secrets.py ./staging-copy
```

Nothing to install, nothing to configure, no environment variable to set. If
step 1 fails, the scanner or its allow-list is broken — fix that before you
trust anything it says about your own tree.

## The gate checks (S1-S5)

Run all five on the staging copy. Each one has to produce evidence you can
paste; "it looked fine" is not evidence.

| ID | Check | Command | Pass criterion |
|---|---|---|---|
| **S1** | secret and identity scan | `python scripts/check_secrets.py .` | `RESULT: CLEAN`, exit code 0, zero findings |
| **S2** | path and topology scan | the two greps below | no output |
| **S3** | smoke test | `python scripts/check_secrets.py --help` and the self-check | exit code 0, raw output kept |
| **S4** | structure | `git ls-files`, file count, total size | no binary blobs, no backups, no virtualenvs |
| **S5** | internal-word reverse lookup | `grep` with your internal term list | no output |

S2, using a negative lookbehind so a URL is not mistaken for a drive path, and
excluding the directory that is *supposed* to contain canaries:

```console
$ grep -rnE '(^|[^:/A-Za-z0-9])[A-Za-z]:[\\/]|/c/[A-Za-z]|/mnt/[a-z]/' \
      --exclude-dir=.git --exclude-dir=fixtures .
$ grep -rnE '\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))(\.[0-9]{1,3}){3}\b' \
      --exclude-dir=.git --exclude-dir=fixtures .
```

S5 greps for the words that should never appear — the local account name,
internal addresses and host names, the organisation, the project, private
repository names, real people. Keep that term list **outside** the repository:

```console
$ grep -rniE "$(tr '\n' '|' < /path/to/internal-terms.txt)" --exclude-dir=.git .
```

Details, rationale and the evidence rules are in [`docs/GATES.md`](docs/GATES.md).

## Walk-through: gating one repository

```console
# 1. staging copy - the original tree stays read-only
$ cp -r /path/to/candidate ./staging-copy

# 2. S1 - first pass; expect findings, that is the point
$ python scripts/check_secrets.py ./staging-copy
staging-copy/config.py:12: [credential-assignment] api_************
staging-copy/deploy.sh:4: [absolute-path] ************
staging-copy/hosts.md:22: [private-ip] 10.2******

scanned 41 file(s); findings: 3
RESULT: FINDINGS PRESENT

# 3. fix each finding, and record the CATEGORY in the sanitize log
#    (config.py: read the value from $API_KEY instead of hard-coding it)

# 4. S1 again - the gate only passes on a clean pass
$ python scripts/check_secrets.py ./staging-copy

scanned 41 file(s); findings: 0
RESULT: CLEAN

# 5. S2 - raw greps must print nothing
# 6. S3 - the documented entry point must run
$ python scripts/check_secrets.py --help
$ bash examples/run_selfcheck.sh

# 7. S4 - structure and size
$ git ls-files | wc -l && du -sh .

# 8. S5 - internal-word reverse lookup

# 9. commit in the staging repository, then hand it over for approval
```

*The scan excerpts in that block are illustrative — a made-up repository with 41
files and three findings. Every other transcript in this README is pasted
verbatim from a real run.*

Two habits make the difference between a gate and a ritual:

- **Fix the class, not the instance.** A hard-coded path in one script usually
  means hard-coded paths in its siblings. Grep for the shape, not just the line.
- **Never restate a scan.** If you edit a file after scanning, the scan is
  void. Re-run it and paste the new output.

## How to write a sanitization log

The log ships with the repository, so it must not contain what you removed.

- Record **category, count and action** — for example
  `user home path | 7 | rewritten to $HOME/...`.
- Never record the original value, a masked prefix of it, or a hash of it.
- Distinguish *replaced* (rewritten in place), *removed* (dropped entirely) and
  *kept deliberately* (a canary, a published test vector) — the last one needs a
  reason and an exclusion if it is scanned.
- End with residual risk: what a human reviewed, what was not reviewed, who
  signed off.

Start from [`docs/SANITIZE_LOG.template.md`](docs/SANITIZE_LOG.template.md) and
copy it to `docs/SANITIZE_LOG.md` in the repository you are publishing.

## Proving the scanner still works

`examples/fixtures/leaky_sample.env` contains a deliberate leak of every
category the scanner claims to detect. It must be reported. `examples/fixtures/`
is therefore **excluded from the repository's own gate** — the same way you
would exclude a published test vector — and `examples/run_selfcheck.sh` asserts
that the exclusion did not also disable the detection:

```console
$ bash examples/run_selfcheck.sh
scanner     : ./scripts/check_secrets.py
interpreter : python

== self-check 1/3: the deliberate-leak fixture must be reported ==
leaky_sample.env:9: [cloud-access-key] AKIA************
leaky_sample.env:10: [credential-assignment] api_************
leaky_sample.env:11: [github-token] ghp_************
leaky_sample.env:11: [high-entropy-token] GITH************
leaky_sample.env:13: [email-address] ops.************
leaky_sample.env:14: [internal-hostname] lab-************
leaky_sample.env:15: [private-ip] 10.2******
leaky_sample.env:16: [mac-address] DE:A************
leaky_sample.env:17: [absolute-path] ************
leaky_sample.env:20: [jwt] eyJh************
leaky_sample.env:20: [bearer-literal] Auth************
leaky_sample.env:20: [high-entropy-token] dozj************
leaky_sample.env:22: [private-key-block] ----************

scanned 1 file(s); findings: 13
RESULT: FINDINGS PRESENT
exit code: 1
PASS: the leaky fixture was reported
  caught: cloud-access-key
  caught: credential-assignment
  caught: github-token
  caught: email-address
  caught: private-ip
  caught: mac-address
  caught: absolute-path
  caught: private-key-block
  caught: jwt

== self-check 2/3: documented placeholders must stay clean ==

scanned 1 file(s); findings: 0
RESULT: CLEAN
exit code: 0
PASS: documented placeholders are ignored

== self-check 3/3: the repository must pass its own gate ==
   (examples/fixtures is excluded: it is a deliberate canary)

scanned 11 file(s); findings: 0
RESULT: CLEAN
exit code: 0
PASS: the repository is clean

SELF-CHECK: PASS
```

`examples/fixtures/allowed_sample.md` is the opposite canary: environment
references, `<PLACEHOLDER>` values, `@example.com` addresses, the `x.` octet
form, the canonical placeholder MAC, `%USERPROFILE%` paths and stock OpenWrt
section names. If the scanner reports anything there, the allow-list regressed
and the self-check fails.

When you add a rule, add a line to one of the two fixtures. A rule with no
fixture is a rule nobody will notice breaking.

## Scanner reference

| Option | Meaning |
|---|---|
| `root` | file or directory to scan, default `.` |
| `--exclude NAME` | skip a file name or a repository-relative path (repeatable) |
| `--exclude-path PREFIX` | skip a repository-relative path prefix, e.g. `examples/fixtures` (repeatable) |
| `--max-bytes N` | skip files larger than N bytes, default 2000000 |
| `--json` | machine-readable report instead of text |
| `--show-info` | also print INFO lines: unfilled placeholders, `TODO`, `XXX` |
| `--quiet` | print the summary only |

Exit codes: `0` clean, `1` findings, `2` usage error. `.git`, virtualenvs, caches
and known binary extensions are skipped; files with a NUL byte in the first
4 KiB are treated as binary.

The scanner reads **no** environment variables and makes no network calls. The
only variable the kit uses is `PYTHON`, which the self-check honours so you can
pick the interpreter (`PYTHON=python3 bash examples/run_selfcheck.sh`).

What it deliberately allows is listed at the top of
[`scripts/check_secrets.py`](scripts/check_secrets.py) — documentation forms
such as `$VAR`, `<PLACEHOLDER>`, `192.168.1.x`, `AA:BB:CC:DD:EE:FF`,
`you@example.com` and paths containing a generic segment (`repo`, `src`, `tmp`).

## Layout

```
.
├── README.md
├── README.zh-CN.md
├── CHANGELOG.md
├── LICENSE
├── requirements.txt          # documents that there are no dependencies
├── docs/
│   ├── GATES.md              # the four gates, S1-S5, evidence rules
│   └── SANITIZE_LOG.template.md
├── examples/
│   ├── run_selfcheck.sh
│   └── fixtures/
│       ├── leaky_sample.env      # must be caught
│       └── allowed_sample.md     # must stay clean
└── scripts/
    └── check_secrets.py
```

## Limitations

Read this before you rely on a clean result.

- **A regex is not a reviewer.** The scanner cannot tell a fake example from a
  real value, cannot judge whether prose identifies somebody, and cannot see a
  licence problem. G1 and G3 are human work; the scanner only covers the
  mechanical part of G2.
- **Binary files are skipped by extension and by a NUL-byte probe.** A
  screenshot of a dashboard can carry a customer name, a host name and a key.
  Review images and PDFs yourself.
- **`--max-bytes` skips large files** (2 MB by default). Check what was skipped
  and why.
- **Working tree only.** `.git` is never scanned, so an already-committed secret
  is invisible here. Rotate the credential and rewrite history separately.
- **Encoding.** Files are decoded as UTF-8 with replacement characters; text in
  another encoding can lose content before it is matched.
- **The entropy rule is a heuristic.** It is tuned against prose and
  identifiers, so it will miss a short secret and will occasionally flag a long
  random-looking identifier.
- **The `x.` documentation forms are trusted** (`192.168.1.x`): a real leak
  written that way passes. Use explicit examples only where no real address
  exists.
- **A clean scan is necessary, not sufficient.** G1, G3 and the human part of
  G4 are not automated here, and no scanner replaces reading the diff.

## License

MIT — see [LICENSE](LICENSE).
