# specs/ — 当前行为真相(Current Truth)

> 项目**当前生效**的行为规格。代码应与此一致;不一致 → 以此为准,或发新 change(`changes/<id>/`)修。
> **两个来源**:① qey-init 首扫从现有行为提炼**基线**(标置信度);② change 归档时 **merge delta**(ADDED/MODIFIED/REMOVED)。不是手写静态文档,是随扫描+change 演进的真相。
> 模板:`_template.md`(无造假范例:spec 由 init 基线 + change merge 产生)。

## 结构
- `specs/<域>/spec.md` — 一个业务域一份(支付 / 订单 / 售后 / ...)
- **改这里的行为 → 发新 change,不在 spec 直接改**

## 与其他目录分工(每个目录只回答一个问题)
| 目录 | 回答 |
|------|------|
| `specs/` | 当前行为**是什么** |
| `domain/` | 代码结构/术语/流程图(**怎么实现**) |
| `knowledge/业务演进/` | **为什么**这么设计(ADR) |
| `knowledge/踩坑记录/` | 踩过什么坑 |
| `changes/` | 正在发生什么变化(delta) |
| `rules/` | 必须**怎么写** |
