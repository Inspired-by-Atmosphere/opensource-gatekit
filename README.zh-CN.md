# opensource-gatekit（开源前门禁工具包）

在仓库公开前的**最后一道门禁**：扫描泄漏 → 脱敏 → 用原始证据核验 → 再提交。
一个零依赖的 Python 脚本，加上让它结论可信的那套审阅纪律。

- **零依赖**：Python 3.8+，只用标准库，不联网。
- **报告可直接贴**：所有命中项都做了遮罩，扫描报告贴进工单或聊天不会反泄原值。
- **可自证**：仓库自带“故意泄漏”的夹具和一键自检，扫描器一旦漏检，自检就失败。

```console
$ python scripts/check_secrets.py . --exclude-path examples/fixtures

scanned 11 file(s); findings: 0
RESULT: CLEAN
```

## 为什么需要它

公开是单向门。一个 token、一个内网主机名、一位同事的邮箱，一旦进入公开提交，
即使你删掉那一行，它也留在历史里，而且留在别人机器上的那份副本永远收不回来。
用眼睛审一棵树，恰恰会漏掉最关键的东西——危险的行看起来就像普通的配置。

所以这道检查必须是机械的、结论必须能被别人复现、证据必须能公开贴出来。
这套工具包只做这三件事。

它**不是**历史重写工具：它只看工作区。如果密钥已经被提交过，请先轮换密钥，
再单独处理历史。

## 准入四关

先判断“能不能公开”，再检查“这份副本干不干净”。完整定义（含脱敏映射表）见
[`docs/GATES.md`](docs/GATES.md)。

| 关 | 问的是什么 | 不通过的情形 |
|---|---|---|
| **G1 版权** | 东西是自己写的，还是许可证兼容的？ | 第三方代码或文字、团队私有文件、受限数据集 |
| **G2 隐私** | 有没有指向人、机器、账号的信息？ | 密钥、令牌、密码、真实姓名、邮箱、内网 IP、MAC、主机名 |
| **G3 保密** | 这是方法，还是内部材料？ | 内部口径与数字、成员信息、未公开结果 |
| **G4 可用** | 陌生机器照 README 能跑吗？ | 写死的绝对路径、隐式依赖、强依赖付费服务 |

## 3 分钟上手

```console
# 1. 先证明工具链本身是好的：扫描器、夹具、本仓库三者必须自洽
$ bash examples/run_selfcheck.sh

# 2. 把准备公开的目录复制成 staging 副本
$ cp -r /path/to/candidate ./staging-copy

# 3. 扫描它，改掉命中项，再扫，直到 CLEAN
$ python scripts/check_secrets.py ./staging-copy
```

不用安装、不用配置、不需要设任何环境变量。如果第 1 步就失败，
说明扫描器或它的白名单坏了——先修它，再去相信它对你仓库的判断。

## 门禁检查 S1–S5

五项都要在 staging 副本上跑，而且每项都要留下能直接贴出来的证据；
“我看过了没问题”不是证据。

| 编号 | 检查 | 命令 | 通过标准 |
|---|---|---|---|
| **S1** | 密钥与身份扫描 | `python scripts/check_secrets.py .` | `RESULT: CLEAN`，退出码 0，零命中 |
| **S2** | 路径与拓扑扫描 | 下面两条 grep | 无任何输出 |
| **S3** | 空跑 | `python scripts/check_secrets.py --help` 与自检脚本 | 退出码 0，保留原始输出 |
| **S4** | 结构核对 | `git ls-files`、文件数、总体积 | 无大二进制、无备份文件、无虚拟环境 |
| **S5** | 内部词反查 | 用内部词表 grep | 无任何输出 |

S2 用负向后顾，避免把 URL 当成盘符路径；并排除那个**本来就该**含泄漏的目录：

```console
$ grep -rnE '(^|[^:/A-Za-z0-9])[A-Za-z]:[\\/]|/c/[A-Za-z]|/mnt/[a-z]/' \
      --exclude-dir=.git --exclude-dir=fixtures .
$ grep -rnE '\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))(\.[0-9]{1,3}){3}\b' \
      --exclude-dir=.git --exclude-dir=fixtures .
```

S5 反查的是“绝不该出现”的词：本机账号名、内网地址与主机名、单位名、项目名、
私有仓名、真实人名。词表本身**不能放进仓库**：

```console
$ grep -rniE "$(tr '\n' '|' < /path/to/internal-terms.txt)" --exclude-dir=.git .
```

理由、取舍和证据纪律见 [`docs/GATES.md`](docs/GATES.md)。

## 完整走一遍：给一个仓库过门禁

```console
# 1. 建 staging 副本——原目录保持只读
$ cp -r /path/to/candidate ./staging-copy

# 2. S1 第一遍：就应该有命中，这正是它的用途
$ python scripts/check_secrets.py ./staging-copy
staging-copy/config.py:12: [credential-assignment] api_************
staging-copy/deploy.sh:4: [absolute-path] ************
staging-copy/hosts.md:22: [private-ip] 10.2******

scanned 41 file(s); findings: 3
RESULT: FINDINGS PRESENT

# 3. 逐条修掉，并把“类别”记进脱敏日志
#    （config.py：改成从 $API_KEY 读取，不要写死）

# 4. 再跑 S1——只有干净通过才算过关
$ python scripts/check_secrets.py ./staging-copy

scanned 41 file(s); findings: 0
RESULT: CLEAN

# 5. S2——两条原始 grep 必须无输出
# 6. S3——文档里写的入口必须能跑
$ python scripts/check_secrets.py --help
$ bash examples/run_selfcheck.sh

# 7. S4——结构与体积
$ git ls-files | wc -l && du -sh .

# 8. S5——内部词反查

# 9. 在 staging 仓里提交，然后交给上级/用户批准
```

*上面那段扫描输出是示意：一个假想的示例仓库、41 个文件、3 处命中。
本文档中其他输出块都是从真实运行中原样粘贴的。*

两个习惯决定这是“门禁”还是“仪式”：

- **修模式，不是修个例**：一个脚本里写死了路径，兄弟脚本里大概率也有。
  照形状去 grep，而不是只改那一行。
- **改完必须重扫**：扫描之后又编辑了文件，那次扫描就作废。重跑，并贴新输出。

## 脱敏日志怎么写

日志会跟着仓库一起公开，所以它本身不能包含你删掉的东西。

- 只记**类别、条数、处理动作**，例如 `用户目录 | 7 | 改写为 $HOME/...`。
- 禁止记录原值本身，遮罩前缀和哈希也不行。
- 分清三类：*已替换*（原地改写）、*已删除*（整段拿掉）、*有意保留*
  （夹具、公开的测试向量）——第三类必须写理由，并说明是否被排除在扫描之外。
- 最后写残余风险：人工逐行看过哪些、哪些**没看**、谁签的字。

模板见 [`docs/SANITIZE_LOG.template.md`](docs/SANITIZE_LOG.template.md)，
拷成待发布仓库里的 `docs/SANITIZE_LOG.md` 再填。

## 怎么证明扫描器还灵

`examples/fixtures/leaky_sample.env` 里故意埋了它声称能检出的**每一类**泄漏，
它必须被报出来。因此 `examples/fixtures/` **被排除在仓库自身的门禁之外**——
和自己发布的测试向量一样处理——再由 `examples/run_selfcheck.sh` 断言：
排除目录并没有把检出能力一起排除掉。

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

`examples/fixtures/allowed_sample.md` 是反向夹具：环境变量引用、`<PLACEHOLDER>` 占位、
`@example.com` 邮箱、`x.` 形式的网段、规范占位 MAC、`%USERPROFILE%` 路径、
OpenWrt 出厂段名。扫描器一旦在这里报出命中，说明白名单退化了，自检就会失败。

新增规则时，请同时在两个夹具之一加一行。没有夹具的规则，坏了没人会发现。

## 扫描器参数

| 参数 | 含义 |
|---|---|
| `root` | 要扫描的文件或目录，默认 `.` |
| `--exclude NAME` | 跳过某文件名或仓库内相对路径（可重复） |
| `--exclude-path PREFIX` | 跳过某个相对路径前缀，如 `examples/fixtures`（可重复） |
| `--max-bytes N` | 跳过大于 N 字节的文件，默认 2000000 |
| `--json` | 输出机器可读报告，替代文本报告 |
| `--show-info` | 附带 INFO 行：未填的占位、`TODO`、`XXX` |
| `--quiet` | 只输出汇总 |

退出码：`0` 干净、`1` 有命中、`2` 用法错误。`.git`、虚拟环境、缓存目录和已知二进制
扩展名会被跳过；前 4 KiB 出现 NUL 字节的文件按二进制处理。

扫描器**不读**任何环境变量、不发起网络请求。整套工具只用到一个环境变量 `PYTHON`，
供自检脚本选择解释器（`PYTHON=python3 bash examples/run_selfcheck.sh`）。

它有意放行的形态列在
[`scripts/check_secrets.py`](scripts/check_secrets.py) 文件头：`$VAR`、
`<PLACEHOLDER>`、`192.168.1.x`、`AA:BB:CC:DD:EE:FF`、`you@example.com`，
以及含通用路径段（`repo`、`src`、`tmp`）的路径。

## 目录结构

```
.
├── README.md
├── README.zh-CN.md
├── CHANGELOG.md
├── LICENSE
├── requirements.txt          # 说明本项目没有依赖
├── docs/
│   ├── GATES.md              # 四关、S1-S5、证据纪律
│   └── SANITIZE_LOG.template.md
├── examples/
│   ├── run_selfcheck.sh
│   └── fixtures/
│       ├── leaky_sample.env      # 必须被检出
│       └── allowed_sample.md     # 必须保持干净
└── scripts/
    └── check_secrets.py
```

## 局限

依赖“扫描结果干净”之前，先读这一节。

- **正则不是审阅者**。它分不清真假示例，判断不了某段文字是否指向真人，
  也看不出许可证问题。G1、G3 和 G4 的人工部分要靠人；扫描器只覆盖 G2 里
  机械可判的那部分。
- **二进制文件会被跳过**（按扩展名与 NUL 字节探测）。一张截图里可能带着客户名、
  主机名和密钥，图片与 PDF 必须人工看。
- **`--max-bytes` 会跳过较大文件**（默认 2 MB）。被跳过了哪些、为什么跳过，
  要自己核。
- **只看工作区**。`.git` 从不扫描，所以已提交进历史的密钥在这里是看不见的；
  请轮换凭据并另行重写历史。
- **编码**。文件按 UTF-8 解码（无法解码的字节替换），其他编码的文本可能在匹配前
  就已经丢内容。
- **高熵规则是启发式**。它按“散文与标识符”调过参，因此会漏掉短密钥，
  偶尔也会把长随机标识符误报。
- **`x.` 形式的示例网段是被信任的**（`192.168.1.x`）：真泄漏若写成这个形式就能过门禁。
  只有在确实不存在真实地址的地方才用示例地址。
- **扫描干净是必要条件，不是充分条件**。G1、G3 与 G4 的人工部分没有自动化，
  任何扫描器都替代不了自己读一遍 diff。

## 许可证

MIT，见 [LICENSE](LICENSE)。
