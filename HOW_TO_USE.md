# qey-harness 使用指南

> 把任何新项目从"裸用 AI"拉到"L2 规则约束+记忆"。quick 全景 5-10 分钟拿骨架;数据/链路深度(deep)需再 15-30 分钟。

---

## 一句话

```
复制模板 → /qey-init 扫描 → 就绪
```

---

## 前置条件

| 要有 | 说明 |
|------|------|
| Claude Code | 在项目目录里启动 |
| project-scanner skill | 已安装(自动触发;用于扫描项目) |
| `qey-harness/` | 已在 `~/qey-harness/`(本次已建) |

---

## 三步起步

### Step 1:接入骨架(二选一)

**方式 A — 一键脚本(推荐)**:

```bash
cd /path/to/your/new-project
bash ~/qey-harness/.qey/attach.sh
```

脚本自动:cp `.qey` + commands + CLAUDE.md → 验证 → 提示跑 `/qey-init`。**幂等**(已存在的不覆盖,`.claude/CLAUDE.md` 已有不破坏)。可用 `QEY_TEMPLATE=/path` 覆盖模板源。

**方式 B — 手动 cp**:

```bash
cd /path/to/your/new-project
cp -r ~/qey-harness/.qey ./
mkdir -p .claude
cp -r ~/qey-harness/.claude/commands ./.claude/
cp ~/qey-harness/CLAUDE.md ./.claude/CLAUDE.md
# settings.local.json 不手动 cp —— 由 /qey-init 从 .qey/guardrails/permissions.md 种子生成
```

复制后结构:
```
your-project/
├── .qey/          ← 刚复制的骨架(占位符,待填充)
│   ├── rules/
│   ├── domain/        ← 空(等 qey-init 扫描填充)
│   ├── memory/
│   ├── workflow/      ← 6 阶段 loop + checklist(通用,直接用)
│   ├── guardrails/
│   ├── changes/       ← 变更工作区(specs↔changes↔archive,含 _template)
│   └── specs/         ← 当前行为真相(由 change 归档 merge 而来)
├── .claude/
│   ├── commands/      ← /qey-init + /commit + /recap
│   ├── settings.local.json  ← 基础 deny/ask/allow
│   └── CLAUDE.md      ← 骨架(红线占位,qey-init 填充)
└── ... (你的代码)
```

### Step 2:跑 /qey-init(扫描 + 填充)

在 Claude Code 里输入:

```
/qey-init              # 默认:快速全景(技术栈/目录/架构/术语)
```

AI 会:
1. 调 project-scanner 扫描项目(Phase 1 骨架扫描)
2. 把扫描结果按内容类型写入 .qey:
   - 技术栈 → `knowledge/项目级记忆.md`
   - 目录+架构 → `domain/domain-map.md`
   - 业务术语 → `domain/业务术语.md`
   - 命名陷阱 → `rules/历史遗留陷阱.md`
3. 按技术栈生成 settings(如 PHP→pint deny)
4. 生成 CLAUDE.md(红线 + 场景索引)
5. 列出写了什么,你确认

**深度选项**:
```
/qey-init deep          # 标准:全景+数据层(表/ER图/状态机)+业务流程(调用链)
/qey-init drill 支付    # 深挖特定模块
```

> 默认只跑 quick(5-10 分钟,建 domain-map + 术语)。`deep` 扫全量(15-30 分钟,多出数据字典/状态机/调用链)。**先 quick 够用,需要时再 deep 补。**

### Step 3:验证就绪

```
# 检查 CLAUDE.md 是否有红线 + 场景索引
cat .claude/CLAUDE.md

# 检查 domain-map 是否写了项目目录映射
cat .qey/domain/domain-map.md

# 检查 settings 是否配了危险操作拦截
cat .claude/settings.local.json
```

就绪后,后续 Claude Code 会话**自动读 CLAUDE.md**(红线+场景索引)→ 命中场景读 `.qey/` 对应文件。

---

## 日常使用(4 个命令)

| 命令 | 什么时候 | 干啥 |
|------|---------|------|
| `/qey-init` | 新项目**首次**(或后续 deep 补) | 扫描项目 → 填充 harness |
| `/commit` | 每次改完代码**提交时** | 读 diff → 起草 message → 你勾选(add/add+commit/add+commit+push)→ 归档 → MR |
| `/recap` | **周期**/怀疑漂移时 | 查旧知识过期(踩坑/决策已在 loop 当场写,recap 只查漏补缺) |
| `/qey-update` | **模板升级后** | 同步新版通用文件到已落地项目(项目填充文件只 diff 不覆盖) |

---

## 文件说明(各自干啥)

| 文件 | 角色 | 来自模板还是扫描 |
|------|------|----------------|
| `.claude/CLAUDE.md` | 每轮必读的精简红线+场景索引(含未初始化自检) | 模板骨架 → qey-init 填充 |
| `.claude/settings.local.json` | 权限三档(allow/ask/deny) | qey-init 从 permissions.md 种子生成 |
| `.claude/commands/qey-init.md` | 扫描初始化命令 | 模板(通用) |
| `.claude/commands/qey-commit.md` | 引导式提交命令(项目上下文参数化) | 模板(通用) → qey-init 填项目变量 |
| `.claude/commands/qey-recap.md` | 周期审计命令(查旧+查漏) | 模板(通用) |
| `.claude/commands/qey-update.md` | 模板版本升级命令 | 模板(通用) |
| `.qey/version` | 模板版本号(/qey-update 用) | 模板(通用) |
| `.qey/README.md` | harness 入口说明 | 模板(通用) |
| `.qey/rules/git提交规范.md` | commit 规范+MR 标题+不格式化 | 模板(通用,项目特定部分 qey-init 补) |
| `.qey/rules/各层规范.md` | 各层写法约定(入口/业务/数据) | 模板骨架 → qey-init 填充 |
| `.qey/rules/代码注释规范.md` | 注释克制规范(无 AI 味,只注 why) | 模板(通用) |
| `.qey/rules/安全规范.md` | 注入/密钥/脱敏/越权 防御底线 | 模板(通用) |
| `.qey/rules/错误处理规范.md` | 不吞异常/错误码/不泄露堆栈 | 模板(通用) |
| `.qey/rules/日志规范.md` | 级别/traceId+上下文/脱敏 | 模板(通用) |
| `.qey/rules/外部调用规范.md` | 超时/重试/幂等/降级 | 模板(通用) |
| `.qey/domain/` | domain-map/术语/状态/流程 | **qey-init 扫描填充** |
| `.qey/knowledge/项目级记忆.md` | 架构/约定/高风险区 | 模板占位 → qey-init 填充 |
| `.qey/knowledge/踩坑记录/` | 坑账本 | bug-loop 第6步当场写 |
| `.qey/knowledge/业务演进/` | 流程演进(为什么 A→B→C→D) | dev-loop Stage1 决策落定当场写 |
| `.qey/guardrails/permissions.md` | 权限种子源(三档;qey-init 读它生成 settings) | 模板(通用) |
| `.qey/workflow/新需求开发-loop.md` | 6 阶段 规格↔测试融合 loop | 模板(通用,直接用) |
| `.qey/workflow/需求澄清-checklist.md` | Stage 0 澄清清单 | 模板(通用,项目维度 qey-init 补) |
| `.qey/changes/_template.md` | change 模板(proposal+design+tasks+delta) | 模板(通用) |
| `.qey/workflow/bug排查-loop.md` | bug 排查 loop(复现→根因→回归) | 模板(通用,直接用) |
| `.qey/changes/README.md` + `specs/README.md` | 变更生命周期 + 当前真相说明 | 模板(通用) |

---

## 不同项目规模的用法

| 项目规模 | 推荐深度 | 说明 |
|---------|---------|------|
| **新项目/小项目** | `/qey-init`(quick) | 全景扫描够用;后续踩坑再 /recap 补 |
| **中型项目** | `/qey-init deep` | 全景+数据+流程,一次性扫透 |
| **大型老项目** | `/qey-init` → 逐模块 `drill` | 先全景,再逐个核心模块深挖 |
| **已有 CLAUDE.md** | `/qey-init` 仍可跑 | qey-init **追加不覆盖**;把现有 CLAUDE.md 的规则保留,补场景索引 |

---

## 模板版本升级(已落地项目同步新版)

模板升级后(改了 workflow/rules/guardrails/commands),已初始化的项目跑 `/qey-update` 同步:

- **可覆盖**:模板自带的通用文件(`workflow/*`、`rules/git提交规范.md`、`guardrails/permissions.md`、`commands/*`、`changes/_template.md`)——覆盖前 diff 给你看
- **只 diff 不覆盖**:项目填充文件(`domain/*`、`memory/*`、`rules/各层规范.md`、`rules/历史遗留陷阱.md`、`CLAUDE.md`、`settings.local.json`)——绝不静默覆盖你的内容
- 升级后 `.qey/version` 更新;若 permissions 种子/映射表变了,再跑 `/qey-init` merge 进 settings

> 原则:**项目实例内容(domain/memory)永远不丢**;只同步通用流程文件。

---

## 常见问题

**Q: scanner 扫描结果不准怎么办?**
A: qey-init 跑完后让你确认,你可以改。scanner 是辅助不是最终答案——harness 靠 /recap 持续修正。

**Q: 项目没有 codegraph 索引能用吗?**
A: 能。scanner 用 Read/grep 也行,只是没 codegraph 精准。建议对大项目先建 codegraph 索引。

**Q: 模板里的 workflow loop 适合非 PHP 项目吗?**
A: 适合。6 阶段 loop + 规格↔测试融合 + HITL 是**语言无关**的通用流程。PHP/Java/Go/JS/Python 都一样。

**Q: 模板里的 settings 适合非 PHP 项目吗?**
A: settings 基础(rm -rf deny / git push ask)是通用的。PHP 特定的(pint deny)由 qey-init 按检测到的技术栈自动追加/跳过。

**Q: 多人团队怎么共享?**
A: `.qey/` + `.claude/` 随 git 进仓库,团队所有人 clone 下来就有了。每个人踩的坑 /recap 写进去,全团队受益。

**Q: scanner 未来演进(加 Phase/改深度)会断吗?**
A: 不会。qey-init **按内容类型映射**(找"技术栈表""目录树""状态枚举"等),不按 Phase 编号。scanner 加 Phase 4 安全分析?qey-init 按内容类型识别后映射;不识别就跳过,不断。

---

## 版本

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-07-01 | 初始模板(从 westmonth 项目实践抽出) |
| 1.1 | 2026-07-09 | 目录收拢 `.qey/`;`/commit` 参数化;permissions 种子化;补 `bug排查-loop`/`各层规范`;加 `/qey-update` 版本机制 |
| 1.2 | 2026-07-19 | **① 统一 Change 生命周期**:`plans/`+`archive/`+`spec-模板` 三套 → `specs/`(当前真相)+ `changes/<id>/`+`changes/archive/`(delta=ADDED/MODIFIED/REMOVED);记忆事件驱动(`/recap`→周期审计)+ freshness;`README.md`→`_template.md`;⑤ AC→Scenario |

> 设计原理:三层信息架构(常驻红线 / 惯性详情 / 运行时工具)+ 内容类型映射解耦 + 更新优先于追加(详见各 `.qey/` 文件)。

## 迁移指南(1.1 → 1.2)

> 结构性迁移(`/qey-update` 只 diff 不自动迁)。完整步骤见 **[`.qey/migrations/1.1-to-1.2.md`](.qey/migrations/1.1-to-1.2.md)**:plans/→changes/、archive 扁平→目录化、delta 合并、删旧、改引用、升版本。
