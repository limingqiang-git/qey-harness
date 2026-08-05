# 权限种子(Permissions Seed)

> 本文件是 `.claude/settings.local.json` 的**唯一权限种子源**。
> `/qey-init` 读取下方 JSON 种子 → merge 项目特定 deny/ask → 生成 `.claude/settings.local.json`。
> **不要**手动 `cp` 本文件成 settings.local.json(会造成 permissions.md ↔ settings.local.json 双写 split-brain)。

## 三档语义

| 档 | 含义 | 例子 |
|----|------|------|
| `allow` | AI 自动跑(低风险可逆) | `git add` / `git commit` |
| `ask` | 每次打断确认(有副作用/改状态) | `git push` / `merge` / `checkout` / `branch` / `$FORMATTER`(分级) |
| `deny` | 永远禁止(危险/不可逆) | `rm -rf` / `git push --force` / `reset --hard` |

## 种子 JSON(/qey-init 读取此代码块)

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(git push --force:*)",
      "Bash(git reset --hard:*)",
      "Bash(git clean:*)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(git merge:*)",
      "Bash(git checkout:*)",
      "Bash(git branch:*)",
      "Bash(git rebase:*)",
      "Bash(git reset:*)",
      "Bash(git tag:*)"
    ]
  }
}
```

> qey-init 按检测到的技术栈**追加 formatter 到 ask**(如 PHP→`Bash(*pint*)` ask / JS→`Bash(*prettier*)` ask)——允许 scoped/`--check`、人审拒全仓(⑩ 格式化分级)。保留本种子。模板升级 permissions.md 后,重跑 `/qey-init` 即可 merge 新种子进项目。
