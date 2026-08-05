# State Machine Thinking Guide(状态机思维)

> 改状态相关代码前,先确认用的是哪个状态枚举、状态流转走的是不是 StateMachine。
> 这是你项目的高频陷阱区(两个同名 OrderStatusEnum!)。

## 触发条件(命中就读本 guide)
- 你在改订单/支付/退款/售后状态
- 你在用 `OrderStatusEnum`(⚠️ 有两个同名!)
- 你在写状态流转逻辑(`canXxx()` / `transition()`)
- 你在加新的状态值

## 该问自己的问题(⭐ 按顺序,别跳)

### 1. 我用的是哪个 `OrderStatusEnum`?

> ⚠️ **最危险的陷阱**(来自项目 `历史遗留陷阱.md`):有两个同名 `OrderStatusEnum`!

| 位置 | 取值 | 用途 |
|------|------|------|
| `app/Domain/Order/Constants/OrderStatusEnum` | `UNPAID`/`PAID` 等 | **DDD 领域状态机**(OrderStateMachine 用) |
| `app/Constants/Order/OrderStatusEnum` | 含 `CLOSED`/`FAILED`/`UNSTOWED` + 履约态 | **展示层/履约状态**(OrderStatusProcessService 用) |

**动手前必须确认**:
```bash
# 看你当前文件的 import 用的是哪个
grep -n "OrderStatusEnum" <你的文件>
```

- 改状态机规则 → 看 `Domain/Order/Constants` 那个
- 改前台状态进程 → 看 `Constants/Order` 那个
- **import 错枚举 = 逻辑错**(排查状态问题先确认这个)

### 2. 状态流转走 StateMachine 了吗?

> 状态流转**必须**走 `OrderStateMachine`(或对应域的 StateMachine),不能直接 `$order->status = X`。

- [ ] 流转前调 `canXxx()` 判断合法性了吗?
- [ ] 流转通过 `transition()` / StateMachine 走了吗?
- [ ] 非法流转抛 `StateTransitionException` 了吗?

> ⚠️ 注意:项目的 `canPay()` / `getParentStateMachine()` 是 **TODO 空实现**,真实流转靠履约层 + `order_history` 重放。改支付状态前先认清这个边界。

### 3. 我加新状态值了吗?

加状态值是**跨层影响**:
- [ ] 枚举定义加了吗?(`*Enum` 类)
- [ ] StateMachine 的流转表加了吗?(允许的 transition)
- [ ] **所有**判断这个状态的 `if/switch` 都覆盖了吗?(grep 状态值,找全)
- [ ] 前台展示(若需要)更新了吗?

> ⚠️ Python/PHP 的 if/elseif/else **没有编译期穷尽检查**。新状态值会让旧 if 链默默 fall through 到 else,用错默认值。加新值后必须搜所有 switch 这个枚举的地方。

### 4. 退款状态有三个 SUCCESS(值不同!)

> 来自项目陷阱:三层退款状态枚举的 SUCCESS 值不同(3/3/2),极易混。

- [ ] 你用的是哪一层的退款状态?
- [ ] 对比的是同一个枚举的值吗?(别跨层比较)

## 状态机设计的通用原则

1. **状态值不可变**:枚举值定义后不改(改 = 破坏存量数据)
2. **流转单向**:大部分状态流转不可逆(UNPAID→PAID 可以,PAID→UNPAID 不行)
3. **流转集中**:所有 transition 在一个 StateMachine 类里,别散落
4. **事件驱动**:状态变化发领域事件,由 Listener 做下游(别在状态机里直接调下游)

## 指向

- 具体状态陷阱(两个 OrderStatusEnum / 三个退款 SUCCESS)→ `rules/历史遗留陷阱.md`
- 状态流程图 → `.qey/domain/状态流程.md`
- DDD 分层(Domain 层才有状态机)→ `rules/backend/ddd-conventions.md` 或 `rules/各层规范.md`
