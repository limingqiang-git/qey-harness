---
description: 引导式提交 — sh 引擎拉 diff 执行 git,LLM 只起草 message;纯 git 提交动作
argument-hint: "[可选: type(scope) 提示, 如 fix(wms)]"
---

# 引导式 git 提交(sh 引擎驱动)

> **2.0 轻量定位**:commit **只管 git 提交的机械动作**——拉 diff、起草 message、add/commit/push。
> 知识提炼(过期检测/踩坑同步/决策沉淀)归 `/qey:distill`,**不在 commit 里做**。

## Step 1:sh 引擎拉 context

```bash
bash .qey/commit.sh stage1-context
```

sh 做:拉 status / diff --stat / 近 10 条 commit(看历史风格)/ dirty 文件 / 探测 MR 工具。输出 **JSON context**。

LLM 读 JSON(不用再调 git):看 diff_stat + dirty_files 理解改了啥;看 recent_commits 学 commit 风格。

## Step 2:LLM 起草 commit message

从 diff 起草:
- `<type>(<scope>): <概述>`(10~50 字)
- body 用 bullet `- `,动词开头
- **❌ 不加 Co-Authored-By / 邮箱 / 任何 AI 署名**
- **格式化**:对本次改动文件跑 `$FORMATTER`(若非 none);❌ 禁全仓;✅ 允许 `--check`

展示:改动文件清单 + 完整 message。

## Step 3:用户勾选提交范围

AskUserQuestion 单选:
- `只 git add(暂存)`
- `git add + commit`
- `git add + commit + push`
- `git add + commit + push + 归档`(若在 change 里;自动衔接 archive.sh)
- `git add + commit + push + 归档 + 提 MR`
- `重新起草 message`

## Step 4:sh 引擎执行(按勾选)

```bash
bash .qey/commit.sh stage3-execute "<message转义>" "<scope:add,commit,push>" "[<change_id>]"
```

sh 做:git add / commit / push(按 scope)→ 抓 commit hash → 输出 JSON。

**归档**(若勾选 + 在 change 里):自动跑 `archive.sh run <change_id>`(验 evidence + merge delta + 移 archive)。归档时的知识提炼(踩坑/决策同步)留给 `/qey:distill`,commit 不做。

**提 MR**(若勾选):sh 执行 glab/gh。

## 硬约束

- ❌ 不加 AI 署名 | ❌ 不自动 push master | ✅ push/merge/MR 触发 ask
- ✅ 格式化分级:只格式化本次改动 + `--check`;禁全仓
