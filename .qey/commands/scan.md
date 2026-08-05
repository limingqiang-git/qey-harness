---
description: 初始化项目 harness — 调 project-scanner 扫描,按内容类型映射写入 .qey,生成 CLAUDE.md + settings
argument-hint: "[deep|drill <模块>]"
---

# 初始化项目 Harness(/qey:scan)

> 把通用骨架 `qey-harness/` 复制到项目后,跑这个命令:
> **调 project-scanner 扫描 → 按内容类型(非 Phase 编号)映射写入 .qey 文件 → 生成 CLAUDE.md + settings**。
> 松耦合:scanner 演进(加 Phase/改深度)不影响本命令——按内容类型识别,不按 Phase 编号。

## 置信度模型(⑧ observed / inferred / unknown)

scanner 产出的事实分三档置信度,写入时区别对待:

| 置信度 | 含义 | 写法 |
|--------|------|------|
| `observed` | 代码 / composer.json 等直接观测 | **自动写入**,无需确认 |
| `inferred` | 从结构推断的架构约定(如"X 是唯一入口") | 写入 + 标 `⚠️待确认`,Step 5 列给你确认 |
| `unknown` | 扫描没覆盖 / 不确定 | 写 `❓待确认` 占位,**不静默跳过** |

> **初始化通过标准 ≠ "文件生成了"**,而是:`observed` 已写 + `inferred` 你确认了 + `unknown` 都列出了。
> **Brownfield 不求全覆盖**:首次只理解"准备改的 slice";知识随真实 change 增长(改哪 → drill 哪)。

## 前置检查

1. 确认 `.qey/` 目录存在(已接入)。**不存在 → 停,提示用户从模板跑接入脚本**(本命令不自己 cp——模板路径不固定,接入是 attach.sh 的职责):
   ```
   bash /path/to/qey-harness/.qey/attach.sh
   ```
2. **确认通用 rules 齐全**(模板自带;**不靠 scanner 生成**——通用规则是语言无关原则)。检查这 7 个,缺任一 → 同上提示跑 attach.sh 补(本命令不 cp 模板):
   ```bash
   for f in git提交规范 代码注释规范 安全规范 错误处理规范 日志规范 外部调用规范 各层规范; do
     [ -f ".qey/rules/$f.md" ] || echo "✗ 缺 $f.md → 跑 attach.sh 补"
   done
   ```
   > (`rules/历史遗留陷阱.md` 由 Step 2 扫描生成,不在此列)
3. 确认 project-scanner skill 可用(会自动触发)
4. `$ARGUMENTS` 透传给 scanner 控制深度:
   - 空(默认)→ quick(Phase 1 全景:技术栈/目录/架构/术语)
   - `deep` → standard(Phase 1-3:全景+数据+流程)
   - `drill <模块>` → 深挖特定模块

## 执行流程

### Step 1:运行 project-scanner

让 AI 按 `$ARGUMENTS` 指定的深度,对当前项目跑 project-scanner 的扫描流程。
scanner 会产出:技术栈表、目录树、架构图、核心模块、业务术语、(deep 时)数据字典/ER图/状态枚举/调用链/流程图。

**重要**:不要自己重写 scanner 的逻辑——**调用 scanner**(它会自动触发),拿到它的产出。

### Step 2:按内容类型映射写入 .qey

scanner 跑完后,**从产出中按内容类型识别**,写入对应 .qey 文件:
> 📖 **填写参考**:写入 domain/specs/knowledge 时,**先读对应的 `_example.md`**——参考填好的真实样本的质量和深度,不只照空模板填栏目。

| scanner 产出内容 | 内容类型关键词 | 写入 .qey 文件 | 写法 |
|----------------|-------------|-------------------|------|
| 技术栈表(框架/版本/语言) | `tech_stack` | `knowledge/项目级记忆.md` | 替换 `[qey:scan 填充:...]` 占位(正则 `\[qey:scan 填充[^\]]*\]`) |
| 目录树 + 架构图 | `directory_architecture` | `domain/domain-map.md`(新建) | 写目录权威映射 + 分层 |
| 业务术语表(glossary) | `business_glossary` | **`CONTEXT.md`**(项目根,新建)+ `domain/业务术语.md` | CONTEXT.md = 统一术语入口(只放定义,指向各处);业务术语.md = 详细中↔英符号桥 |
| 数据字典(表/字段) | `data_dictionary` | `domain/数据字典.md`(新建,deep 时) | 6 列格式 |
| 状态枚举 + 流转图 | `state_enum_flow` | `domain/状态流程.md`(新建,deep 时) | 状态值 + mermaid |
| 调用链 + 流程图 + 时序 | `call_chain_flow` | `domain/业务流程.md`(新建,deep 时) | 每域一行(干啥+入口+表,地图层);末尾加注释:大功能升级独立 md 见 `业务领域/_template.md` |
| 业务行为/不变量(从流程+状态提炼) | `behavior_truth` | `specs/<域>/spec.md`(新建) | 当前行为基线;observed/inferred 标置信度(见置信度模型) |
| "改X→碰这些文件" | `change_impact` | `rules/历史遗留陷阱.md`(新建) | 陷阱 + 权威路径 |
| 命名陷阱/历史遗留 | `naming_trap` | 同上 | 合并进去 |
| 各层规范(从架构图/模块提炼) | `layer_convention` | `rules/各层规范.md`(新建) | 按层填 checklist |
| 核心模块清单 | `core_modules` | `domain/domain-map.md` 的模块节 | |

> **scanner 未来加了新内容类型?** 按产出内容判断属于 domain/rules/memory 哪类,写入对应文件。不认识的 → 标 `unknown`(❓待确认),不静默跳过。
> **⑧ 置信度标记**:写入时给每条事实打 observed/inferred/unknown(见「置信度模型」)。`inferred` 标 `⚠️待确认` 收集到 Step 5;`unknown` 标 `❓待确认`。
> **specs/ 基线**(brownfield):从核心域的流程+状态提炼**行为不变量** → `specs/<域>/spec.md`(当前真相基线,标置信度)。后续 change 在此之上 delta;这样存量项目也有"当前真相",不只靠首个 change 归档。
> **⭐ 验证锚点(2.0 必填)**:写入 domain/specs/knowledge 的每条知识**必须带锚点**(`Class::method` 符号 或 `app/path.php` 路径)+ `last_verified` 日期。`qey verify` 用这些锚点自动检测过期——没锚点的知识无法被验证,等于盲区。

### Step 3:按检测到的技术栈生成 settings

**读权限种子**:先读 `.qey/guardrails/permissions.md` 的 JSON 种子块,作为 `settings.local.json` 的基础三档。再读 scanner 技术栈,推断项目特定危险操作,merge 进去:

读 scanner 产出的技术栈,推断危险操作,merge 进 `.claude/settings.local.json`(本步生成,不要手动 cp):

| 检测到 | 加 deny | 加 ask |
|--------|---------|--------|
| PHP + pint | — | `Bash(*pint*)`(⑩ 分级:scoped/`--check` ✅、全仓人审拒) |
| JS + eslint/prettier | — | `Bash(*prettier*)`(同上) |
| 任何项目 | `rm -rf`、`git push --force` | `git push/merge` |
| 数据库迁移 | — | `*migrate*` |
| Docker | `*docker*rm*` | — |

> 保留模板自带的 deny/ask,项目特定的**追加**不覆盖。
> **hooks**:`.claude/settings.json`(团队共享,进 git)的 `hooks.Stop` 由 harness-attach 复制(指向 `.claude/hooks/recap-stop-hook.sh`,**每次会话结束触发沉淀提醒**:覆盖 熟悉业务/看代码(→domain)、改代码(→freshness)、查阅纠正(→memory/踩坑)、决策(→业务演进);marker 防 nag,二次停止跳过)。若项目缺 settings.json/hooks → 提示用户从模板补。

### Step 3.5:探测并填充 commit 项目上下文

读 `.claude/commands/qey-commit.md` 顶部「项目上下文」表,探测/问后填「实际值」列:

| 变量 | 怎么定 |
|------|--------|
| `$GIT_HOST` | `git remote -v` 的 host → gitlab / github / gitea |
| `$REPO_PATH` | `git remote get-url origin` 解析出 host/group/project |
| `$MR_TOOL` | gitlab 且 `glab` 已装 → glab;github 且 `gh` 已装 → gh;否则 → 无(提示装) |
| `$FORMATTER` | 复用 Step 3 技术栈检测:PHP→pint / JS→eslint 或 prettier / 其他→无 |
| `$ISSUE_TRACKER` | **问你**(无法自动探测):禅道 / jira / none |

> 替换 qey-commit.md 表里 5 个 `[qey:scan 填充]`。未装的 CLI 标 `无` 并提示 `brew install glab` / `gh`。

### Step 4:生成 CLAUDE.md

从 scanner 产出 + 写入的 .qey 文件,生成精简 CLAUDE.md:
1. 读项目内 `.claude/CLAUDE.md`(Step 1 复制的骨架)
2. 填红线(分层/异常/响应/事务——从 scanner 产出提炼)
3. 填场景索引(根据扫描到的业务域写"改X→读Y"行)
4. 填核心命令(build/test/lint——从 composer.json/package.json 等检测)

### Step 5:AskUserQuestion 确认 + 自检

列出:
- 写了哪些 .qey 文件(新增/更新)
- 生成的 CLAUDE.md 红线 + 场景索引
- settings 加了哪些 deny/ask
- qey-commit.md 项目上下文填了哪些变量
- 有什么不确定的(让用户确认/补充)

**自检**:
- `grep -rn "\[qey:scan 填充" .qey/ .claude/` 残留占位符 > 0 → ⚠️ 警告「以下占位未填」,列出来让你补
- **通用 rules 齐全**:`ls .qey/rules/` 应含 git提交规范 / 代码注释规范 / 安全规范 / 错误处理规范 / 日志规范 / 外部调用规范 / 各层规范 共 7 个。缺了 → 提示跑 attach.sh 补(前置检查 step 2)
- **skills frontmatter 自检**:扫 `.claude/skills/*/SKILL.md`,每个需有 `name:` + `description:` frontmatter(触发前提,缺了 skill 不触发)。缺的 → ⚠️ 列出提示补
- 列 scanner 产出映射统计:「识别 N 块内容 / 映射 M 块 / 跳过 N-M 块」,让你核对未映射项是否该手动补
- **⑧ 置信度核对**:列 `inferred`(⚠️待确认)让你逐条确认;列 `unknown`(❓待确认)让你定(补扫/标已知/留待)。**未确认的 inferred 不算通过**。
- **机制自检**(v2):若 `.qey/parity-check.sh` + `hash-check.sh` 在 → 跑一下 sanity(`bash .qey/parity-check.sh` + `bash .qey/hash-check.sh $TEMPLATE`)。刚接入应全绿;不绿说明接入/模板有问题,先修。

用户确认 → 完成。

### Step 6:提示后续

```
✓ harness 初始化完成
- domain-map / 业务术语 / 状态流程 / 业务流程 + specs 基线 已写入(标置信度)
- CLAUDE.md 红线 + 场景索引 已生成
- settings deny/ask 已配置

→ 后续日常:
  - 改代码前查 CLAUDE.md 场景索引(domain-first:先 domain/ 拿符号→codegraph 验证)
  - 接新需求:bash .qey/change.sh create <id> <域>(建 change 骨架)→ 填 proposal/design/tasks/evidence → change.sh archive <id>(归档:验 evidence+merge delta+移 archive)
  - change.sh list 看所有 change 状态;hash-check.sh 查项目漂移;parity-check.sh 查 adapter
  - /commit 提交、/recap 周期审计(踩坑/决策已在 loop 当场写)
  - scanner 只跑 Phase 1 → 后续 /qey:scan deep 补数据层+业务流程
```

## 重要约束

- **松耦合**:不写死 scanner 的 Phase 编号/产出物结构;按**内容类型**识别
- **不覆盖用户手写**:settings/CLAUDE.md 只**追加/填占位**,不覆盖已有内容
- **⑧ 置信度**:observed 自动写;inferred 标 `⚠️待确认`、Step5 人确认;unknown 不跳过。通过标准 = inferred 已确认 + unknown 已列
- **⑧ Brownfield**:首次扫描不求全覆盖,聚焦"准备改的 slice";知识随 change 增长
- **scanner 不可用**:提示用户"project-scanner skill 未找到,请先安装";或手动按 Phase 1 5 产出物逐个产出后手动映射
