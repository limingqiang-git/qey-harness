# Git 提交规范(AI 起草 + 人工引导)

## 提交格式

```
<type>(<scope>): <概述>      ← 10~50 字

- 改动点1(动词开头)
- 改动点2
```

type: feat / fix / refactor / opt / docs / chore。允许中文。

## 规则
1. 先读 diff(`git diff`)再起草
2. 概述 **10~50 字**
3. body 用 **bullet 列表**,动词开头
4. **❌ 不加 Co-Authored-By / 邮箱 / 任何 AI 署名**
5. **格式化分级**(对应 qey-commit.md `$FORMATTER`):
   - ❌ 禁**全仓**格式化(`pint`/`prettier` 无参)——大量无关 diff
   - ✅ 允许**只格式化本次改动的文件**(让改动行合规、过 CI `--check`)
   - ✅ 允许 `formatter --check`(只读验证)
   - ⚠️ 格式化产生**大量无关 diff** → 停 + 报告(可能误触全仓)
   - style-only 清理单独 `style:` commit

## 格式化分级(防 CI 挂 + 防 diff 污染)

> [!note] AI 可格式化**本次改动的文件**(让改动行合规过 CI),但**禁全仓**格式化(无关 diff 噪声)。存量格式债清理是单独人工 `style:` 工程。
> permissions:`$FORMATTER` 走 **ask**(非 deny)——人审批准 scoped/`--check`、拒绝全仓。

## MR 标题格式(项目特定,qey-init 填)

```
[qey-init 填充:MR标题模板,如 【环境】【编号】 type(scope): 内容]
```
