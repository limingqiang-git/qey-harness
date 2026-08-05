# 业务演进(ADR)范例

> **这是完整填好的真实样本**——供 AI 写业务演进/ADR 时参考质量、深度、格式。
> 结构看 `_template.md`,质量看本文件。
> 只记满足**三门槛**的决策:难逆 / 反直觉 / 真实取舍。常规实现不记。

---

## 决策:支付渠道用策略模式而非 if-else 分支

- **锚点**:`PaymentStrategyInterface` (app/Service/Payment/Strategy/PaymentStrategyInterface.php)
- **last_verified**: 2026-08-05
- **日期**:2026-08-01(pay-refactor change)
- **背景**:原 PaymentService 硬编码微信支付,需新增支付宝。团队讨论两种方案。
- **选项**:
  1. if-else 分支:在 PaymentService 里按 `$channel` if-else 调用不同渠道逻辑
  2. 策略模式:定义 PaymentStrategyInterface,每个渠道一个 Strategy 实现,PaymentService 只依赖接口
- **决策**:选策略模式(选项 2)
- **理由**:
  - 渠道预计持续增加(后续接银联/虚拟币/Apple Pay),每加一个渠道 if-else 会让 PaymentService 膨胀
  - 策略模式扩展成本低:新渠道加一个 Strategy 类 + Factory 注册,不改 PaymentService 核心逻辑
  - 单元测试更清晰:每个 Strategy 独立测,PaymentService 测 mock Strategy
- **代价**:比 if-else 多 3 个文件(Interface + Factory + 首个 Strategy),当前只有 2 渠道时"过度设计"感
- **扩展性**:未来加渠道 = 加 Strategy 类 + 配置注册,不碰 PaymentService

```php
// 决策的实现
interface PaymentStrategyInterface {
    public function pay(array $order): array;
    public function callback(array $params): bool;
}

class WechatPayStrategy implements PaymentStrategyInterface { ... }
class AlipayStrategy implements PaymentStrategyInterface { ... }

class PaymentService {
    public function __construct(private PaymentStrategyFactory $factory) {}
    public function processPayment(array $order): array {
        $strategy = $this->factory->make($order['channel'], $order['id'], $order['config']);
        return $strategy->pay($order);
    }
}
```

---

## 决策:售后拦截窗口期按物流商配置,不硬编码

- **锚点**:`AfterSaleLogisticService::checkInterceptWindow` (app/Service/AfterSale/AfterSaleLogisticService.php)
- **last_verified**: 2026-08-01
- **日期**:2026-07-28(after-sale-refactor change)
- **背景**:拦截窗口期硬编码 2 小时(顺丰规则),接入京东后踩坑(京东是 1 小时)。
- **决策**:窗口期从 `config/logistic.php` 按物流商读取,不硬编码。
- **理由**:不同物流商规则不同,硬编码必然踩坑。配置化后接新物流商只需加配置项。
- **代价**:代码多一行读配置,略微增加理解成本。

---

## 决策:订单状态变更必须经过 OrderStateMachine,禁止直接改 status 字段

- **锚点**:`OrderStateMachine::transition` (app/Order/OrderStateMachine.php)
- **last_verified**: 2026-08-05
- **日期**:2026-06-15(订单状态机统一,初始重构)
- **背景**:多处代码直接 `$order->status = 'paid'` 改状态,导致非法转换(如已退款→待支付)和状态不一致。
- **决策**:所有状态变更必须经 `OrderStateMachine::transition()`,该方法校验转换合法性,非法转换抛异常。直接改 status 字段的代码 review 时打回。
- **理由**:状态机一致性是订单系统生命线;分散改状态必然出 bug。
- **代价**:开发者多写一行 `StateMachine::transition($orderId, 'paid')` 而非直接赋值。
