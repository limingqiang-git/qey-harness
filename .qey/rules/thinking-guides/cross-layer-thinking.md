# Cross-Layer Thinking Guide(跨层思维)

> 功能涉及多层时,先想清楚数据怎么流、逻辑该放哪层。
> 大部分跨层 bug 来自"数据格式在层间没对齐"或"逻辑放错了层"。

## 触发条件(命中就读本 guide)
- 功能涉及 3+ 层(Controller / Service / Domain / Repository)
- 数据格式在层间转换(DTO ↔ DO ↔ Model)
- 多个消费者需要同一份数据
- 你不确定某逻辑该放哪层
- 你在加事件/RPC/队列 payload 字段

## 该问自己的问题

### 1. 数据流经哪些层?每层的数据格式是什么?

画一遍数据流(心算或纸笔):
```
HTTP Request
  → Controller(收到什么?校验?)
  → Api Service(编排?调哪些服务?)
  → Domain Service(业务规则?状态机?)
  → Repository(存到哪个库?字段映射?)
  → Model(持久化结构)
```

每层的数据格式一样吗?哪里转换?转换会丢信息吗?

### 2. 这个逻辑该放哪层?

| 逻辑类型 | 该放哪层 | 不该放哪层 |
|---------|---------|-----------|
| 参数校验/格式转换 | Controller / Validator | ❌ Domain |
| 编排(调多个服务) | App Service / Api Service | ❌ Domain(不该知道别的域) |
| 业务规则/状态机/金额计算 | **Domain Service / DO** | ❌ Controller / Repository |
| 数据存取/查询 | Repository | ❌ Domain(不该知道存储) |
| 跨系统调用(RPC/队列) | Service(编排)或 Domain Event | ❌ Repository |

**判断法**:这段逻辑"知道业务规则吗"?知道 → Domain。只搬运数据 → Service。碰数据库 → Repository。

### 3. payload 字段加在哪?所有消费者都更新了吗?

加事件/RPC/队列 payload 字段时:
- [ ] 字段定义在哪?(应该有统一类型/DTO,别多处各自解析)
- [ ] 生产者加了吗?
- [ ] **所有消费者**都更新了吗?(grep payload 字段名,找全消费者)
- [ ] untyped 字段读 2+ 处?→ 提取共享 decoder/type guard

> ⚠️ "加了字段但消费者没更新"是跨层 bug 的头号来源。

## 常见陷阱

### 陷阱 1:Domain 层写了应用逻辑
- **症状**:Domain Service 里调了别的域的 Service / 发了 RPC
- **问题**:Domain 不该知道外部世界(难测、耦合)
- **修正**:Domain 只发 Event,由 Listener/Consumer 做外部调用

### 陷阱 2:Controller 直接调 Repository
- **症状**:跳过 Service 层
- **问题**:没有业务规则校验,重复逻辑
- **修正**:Controller → Service → Repository

### 陷阱 3:DTO 和 DO 字段不对齐
- **症状**:转换时丢字段或类型错
- **修正**:DTO ↔ DO 转换集中在一个地方(Transformer/Mapper),别散落

## 指向

- 具体 DDD 分层规范 → `rules/backend/ddd-conventions.md`(若已建)或 `rules/各层规范.md`
- 异常处理跨层 → `rules/shared/error-handling.md`
- 项目特定跨层陷阱 → `rules/历史遗留陷阱.md`
