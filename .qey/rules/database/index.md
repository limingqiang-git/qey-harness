# Database Development(数据库开发)

> 数据库相关:迁移、索引、表结构、查询规范。
> 本文件是数据库规范的**入口**(Pre-Development Checklist + Quality Check)。

---

## Pre-Development Checklist(改数据库前)

| 你要干的事 | 先读 |
|-----------|------|
| 加/改字段 | 本文件"表结构变更"段 + 确认影响点 |
| 加索引 | 本文件"索引规范"段 |
| 写迁移脚本 | 本文件"迁移规范"段 |
| 查询性能(慢查询/N+1) | 本文件"查询规范"段 |
| 多租户(切 connection) | `../../knowledge/项目级记忆.md` 的多租户段(若适用) |
| 边界(库存/售后在别的系统?) | `../thinking-guides/boundary-thinking.md` |

---

## 表结构变更

- [qey-init 填充:表结构维护方式(DBA/迁移脚本/外部维护)]
- [qey-init 填充:命名约定(表名/字段名/前缀)]

> ⚠️ 改表结构前,确认影响点(grep 表名/字段名,找全引用)。

## 索引规范

- [qey-init 填充:高频查询字段建索引]
- [qey-init 填充:联合索引顺序约定]

## 迁移规范

- [qey-init 填充:迁移工具(Phinx/Laravel migrate/手动 DBA)]
- [qey-init 填充:回滚约定]

## 查询规范

- **防 N+1**:批量查询替代循环单条
- **走索引**:WHERE 字段必须有索引
- **软删除**:deleted_at 约定(若有)
- **多存储**:MySQL 走小查询,大查询/统计走 ClickHouse(若适用)

---

## Quality Check(改完后验证)

1. 确认表结构变更不影响存量数据
2. 确认索引建了(慢查询日志/EXPLAIN)
3. 确认迁移脚本可回滚
4. 确认多租户不会串数据(若适用)

```bash
# [qey-init 填充:数据库相关验证命令]
```
