# Backend Development(后端开发)

> 后端代码的写法约定。qey-init 扫描后填充具体框架(Hyperf/Laravel/ThinkPHP...)的规范。
> 本文件是后端规范的**入口**(Pre-Development Checklist + Quality Check)。

---

## Pre-Development Checklist(改后端代码前)

> 改后端代码前,按场景读对应规范(不全读,精准加载)。

| 你要干的事 | 先读 |
|-----------|------|
| 确认分层(逻辑该放哪层) | `../各层规范.md`(入口/业务/数据层约定) |
| 跨层数据流(涉及 3+ 层) | `../thinking-guides/cross-layer-thinking.md` |
| 改状态机/状态枚举 | `../thinking-guides/state-machine-thinking.md` |
| 改常量/配置/枚举值 | `../thinking-guides/code-reuse-thinking.md`(先搜引用!) |
| 处理异常 | `../错误处理规范.md` |
| 打日志 | `../日志规范.md` |
| 调外部服务 | `../外部调用规范.md` |
| 安全(SQL/密钥) | `../安全规范.md` |
| 写注释 | `../代码注释规范.md` |

---

## 框架特定(项目填充)

> qey-init 检测到框架后填充。当前在 `../各层规范.md`(扁平),规划迁移到这里。

- [qey-init 填充:框架特定约定(如 Hyperf 的 DDD 结构 / Laravel 的 Eloquent 约定)]

---

## Quality Check(改完后验证)

1. `git diff --name-only` 看改了啥
2. 对照上面的 Pre-Development Checklist,读相关规范
3. 确认分层正确(业务规则在 Domain,编排在 Service)
4. 确认异常/日志/安全符合规范
5. 跑测试 + lint + typecheck

```bash
# [qey-init 填充:项目 test/lint/typecheck 命令]
```

---

> **渐进迁移**:当前后端规范在 `../各层规范.md`(扁平)。规划迁移到本目录(backend/),拆成:
> - `ddd-conventions.md`(DDD 分层约定)
> - `<框架>-specific.md`(框架特定)
> 迁移时 index.md 路由同步更新。
