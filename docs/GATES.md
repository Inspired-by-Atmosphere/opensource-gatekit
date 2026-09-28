# Gates

Two layers, applied in order:

1. **Admission gates (G1-G4)** decide whether something may be published at all.
2. **Gate checks (S1-S5)** produce the evidence that a staging copy is fit to
   leave the machine.

A tree passes only when all four admission gates pass and S1-S5 all report the
pass criteria below.

---

## 1. Admission gates

| Gate | Meaning | Not allowed |
|---|---|---|
| **G1 Copyright** | Ship only code and text you wrote, or material under a licence compatible with the one you publish (MIT / Apache-2.0) | third-party clones, code copied from other authors, files from private team repositories, competition submissions, licence-restricted datasets |
| **G2 Privacy** | Zero credentials, zero real identities, zero internal topology | API keys, tokens, passwords, private keys, account or student numbers, e-mail addresses, real names, school or employer names, private IP addresses, MAC addresses, host names |
| **G3 Confidentiality** | Publish the method, never the internal material | internal decisions and figures, internal conduct rules, member information, unpublished results, customer information |
| **G4 Usability** | A stranger on a clean machine can follow the README and run it | hard-coded absolute paths, implicit dependencies, a mandatory paid service (mark it optional instead) |

Practical rules for each gate:

- **G1**: for every file you did not write yourself, record where it came from.
  "It was in my working tree" is not provenance.
- **G2**: assume every published byte is permanent. History survives a revert.
- **G3**: if a number, a name or a rule is only meaningful inside the team,
  it is internal.
- **G4**: state the Python/OS version the code was tested on, and list every
  environment variable the user has to set.

---

## 2. Sanitization mapping

Replace the left column with the right column, and log the *category and count*
in `docs/SANITIZE_LOG.md` (see `SANITIZE_LOG.template.md`). Never record the
original value, not even a hash or a masked prefix.

| Category | Real shape | Replace with |
|---|---|---|
| User home | a Windows profile path or an MSYS `/c/`-style path | `$HOME/...`, `%USERPROFILE%\...` or `./` |
| Project drive | a drive-letter path to a working directory | a repository-relative path |
| Internal address | RFC 1918 or CGNAT address | `x.` form (`192.168.1.x`) or an RFC 5737 range (`198.51.100.10`) |
| Host or service name | a concrete server, router model or internal domain | `your-server`, `your-router` |
| Organisation | school, team or company name | `your-org` |
| Person | real name, nickname, account handle | `your-name` |
| Credential | any key, password, token or session | `$ENV_VAR`; the README names the variable only |
| Device identifiers | serial numbers, MAC addresses, IMEI | `AA:BB:CC:DD:EE:FF` (the canonical placeholder) |
| Contact | any working e-mail address | the repository's `users.noreply.github.com` address or `you@example.com` |

---

## 3. Gate checks

| ID | Check | Command | Pass criterion |
|---|---|---|---|
| **S1** | Secret and identity scan | `python scripts/check_secrets.py .` (add `--exclude-path <dir>` for directories that hold deliberate canaries) | `RESULT: CLEAN`, exit code 0, **zero findings** |
| **S2** | Path and topology scan | grep for drive-letter paths, MSYS user paths and private addresses (see below) | zero hits; any path kept as an example must be marked as an example |
| **S3** | Smoke test | the documented entry point with `--help`, or the test suite | exit code 0, raw output attached |
| **S4** | Structure | file list, file count, total size | no binary blobs, no backup files, no virtual environments |
| **S5** | Reverse lookup of internal words | grep the local account name, internal addresses, organisation and project names, private repository names, person names | zero hits |

### S2 in practice

Use a negative lookbehind so that a URL (`https://…`) does not look like a
drive path, exclude any fixture directory that is supposed to contain canaries,
and write the MSYS part of the pattern as a character class so this page does
not match its own example:

```console
$ grep -rnE '(^|[^:/A-Za-z0-9])[A-Za-z]:[\\/]|/c/[A-Za-z]|/mnt/[a-z]/' \
      --exclude-dir=.git --exclude-dir=fixtures .
$ grep -rnE '\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))(\.[0-9]{1,3}){3}\b' \
      --exclude-dir=.git --exclude-dir=fixtures .
```

Both must print nothing. Write Windows paths in documentation as
`%USERPROFILE%\repo` and Unix paths as `$HOME/repo` or `./`, so the first grep
has nothing to find. The scanner checks the same two categories (`absolute-path`
and `private-ip`), so S1 already covers them — S2 is the independent, raw grep
view of the same question.

### S5 in practice

Keep the term list **outside** the repository (a scratch file, a password
manager entry) and grep with it:

```console
$ grep -rniE "$(tr '\n' '|' < /path/to/internal-terms.txt)" \
      --exclude-dir=.git .
```

The list covers: the local account name, internal addresses and host names,
the school / company / team name, the project name, private repository names
and the names of real people. A hit on any of them fails S5.

---

## 4. Evidence rules

- **Raw output or it did not happen.** Every conclusion in a report has to be
  backed by a command whose output is pasted verbatim. Reformatting, summarising
  or "cleaning up" an output is not evidence.
- **Write files before reporting.** Anything the report claims to deliver must
  already exist on disk; a report with an empty directory is void.
- **A receipt is not evidence.** Accept a report only after inspecting the tree
  yourself (`ls`, `git ls-files`).
- **Never claim a pass you did not run.** If a check was skipped, write
  "not run" and why.
- **Read exit codes from the command, not from a pipeline.** `cmd | head`
  followed by `$?` reports the exit code of `head`.
- **Do not publish a finding verbatim.** A scan report should carry the file,
  the line and the rule name with a masked excerpt — never the full value.

---

## 5. 中文速览

| 关 | 含义 | 禁止 |
|---|---|---|
| G1 版权 | 只放自己写的代码/文档，或 MIT / Apache-2.0 兼容素材 | 第三方 clone、他人代码、私有仓文件、竞赛提交物、受限数据集 |
| G2 隐私 | 零凭据、零真实身份、零内网拓扑 | key/token/密码/私钥/账号/邮箱/真实姓名/学校单位/内网 IP/MAC/主机名 |
| G3 保密 | 只放方法，不放内部材料 | 内部口径与数字、内部纪律、成员信息、未公开结果、客户信息 |
| G4 可用 | 陌生机器照 README 能跑 | 写死的绝对路径、隐式依赖、强依赖付费服务 |

门禁：S1 扫描器零命中；S2 盘符路径与内网地址零命中；S3 入口 `--help` 退出码 0；
S4 结构核对（清单/文件数/体积、无大文件与备份）；S5 内部词反查零命中（词表放在仓库外）。

纪律：原始输出才算证据；做不到写「未测」，禁编造；回报前先落盘；收到回报必须自己 `ls` 核对。
