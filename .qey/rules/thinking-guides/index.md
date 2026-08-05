# Thinking Guides(思维指南)

> **核心理念**:**大部分 bug 来自"没想到",不是"不会写**"。
> 这些 guide 不教"怎么写代码",教"**什么时候该停下来想一想**"。
> 改代码前花 30 秒过触发清单,省 3 小时 debug。

## 什么时候该想想(触发清单)

> 改代码前,扫一遍这些触发条件。命中就读对应 guide(每个 guide 是一份该问自己的问题清单)。

### 跨层问题 → [cross-layer-thinking.md](./cross-layer-thinking.md)
- [ ] 功能涉及 3+ 层(Controller / Service / Domain / Repository)
- [ ] 数据格式在层间转换(DTO ↔ DO ↔ Model)
- [ ] 多个消费者需要同一份数据
- [ ] 你不确定某逻辑该放哪层(应用服务 vs 领域服务)
- [ ] 你在加事件/RPC/队列 payload 字段

### 复用问题 → [code-reuse-thinking.md](./code-reuse-thinking.md)
- [ ] 你在写和已有代码相似的逻辑
- [ ] 同一模式重复 3+ 次
- [ ] **你在改任何常量或配置** ← 先搜所有引用!
- [ ] **你在新建工具函数** ← 先搜有没有!
- [ ] 两个文件各自解析同一个 untyped 字段

### 状态机问题 → [state-machine-thinking.md](./state-machine-thinking.md)
- [ ] 你在改订单/支付/退款/售后状态
- [ ] 你在用 `OrderStatusEnum`(⚠️ 有两个同名!)
- [ ] 你在写状态流转逻辑(`canXxx()` / `transition()`)
- [ ] 你在加新的状态值

### 边界问题 → [boundary-thinking.md](./boundary-thinking.md)
- [ ] 你在找售后/退款/库存的逻辑(⚠️ 可能不在本系统!)
- [ ] 你不确定某操作该在订单中心还是上游系统
- [ ] 你在写对外 RPC(边界在哪)
- [ ] 你在处理跨系统数据一致性

## Guide vs Code-Spec(关键区别)

| 类型 | 位置 | 目的 | 内容风格 |
|------|------|------|---------|
| **Guide**(本目录) | `rules/thinking-guides/*.md` | 帮"**该想什么**" | 清单、问题、指向 spec |
| **Code-Spec**(其他 rules) | `rules/shared/*.md` / `rules/backend/*.md` | 告诉"**怎么写**" | 签名、契约、案例 |

**决策规则**:
- "这是**写之前该考虑什么**" → 放 guide(本目录)
- "这是**怎么写**代码" → 放 code-spec(其他 rules)

> Guide 应该是**短清单指向 spec**,不复述详细规则。

## 怎么用

1. **改代码前**:扫上面的触发清单,命中就读对应 guide
2. **写代码时**:感觉某处复杂/重复,回来查 guide
3. **踩 bug 后**:把新教训加到对应 guide(通过 `/qey-distill` 触发 7)

---

**核心原则**:30 分钟思考省 3 小时 debug。
