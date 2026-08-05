# 踩坑记录范例

> **这是完整填好的真实样本**——供 AI 写踩坑时参考质量、深度、格式。
> 结构看 `_template.md`,质量看本文件。

---

### [2026-08-03] 支付回调签名验证顺序错误 [observed]

- **锚点**:`CallbackController::notify` (app/Http/Controllers/CallbackController.php)
- **last_verified**: 2026-08-05
- **坑现象**:微信支付回调偶发验签失败(约 0.3%),但重试时成功。日志显示签名不匹配,但参数值一致。
- **根因**:验签前先做了参数排序(`ksort`),但微信回调的签名字段是 `sign`(不在业务参数里),排序后参与签名的字段集变了,导致算出的签名和微信发的不一致。
  ```php
  // ❌ 问题:sign 参与了排序
  $params = $request->all();
  ksort($params);
  $sign = generateSign($params);  // sign 字段被算进去了
  ```
- **怎么避**:验签时**先剔除 sign 字段,再排序**:
  ```php
  // ✅ 正确:sign 不参与签名计算
  $params = $request->except('sign');
  ksort($params);
  $sign = generateSign($params);
  ```

---

### [2026-07-28] 京东物流拦截窗口期是 1 小时不是 2 小时 [observed]

- **锚点**:`AfterSaleLogisticService::checkInterceptWindow` (app/Service/AfterSale/AfterSaleLogisticService.php)
- **last_verified**: 2026-08-01
- **坑现象**:售后单发货 1.5 小时后调京东拦截 API,返回"超时不可拦截",但系统显示"在窗口内"。
- **根因**:拦截窗口判断硬编码为 2 小时(顺丰的规则),京东实际是 1 小时。
- **怎么避**:窗口期按物流商配置,不硬编码:
  ```php
  // ✅ 按物流商读配置
  $window = config("logistic.{$courier}.intercept_window", 7200);
  ```
- **证据**:`app/Service/AfterSale/AfterSaleLogisticService.php:47`

---

### [2026-07-15] PaymentStrategyFactory 第三参数不能传 null [⚠️待确认]

- **锚点**:`PaymentStrategyFactory::make` (app/Service/Payment/PaymentStrategyFactory.php)
- **last_verified**: 2026-08-05
- **坑现象**:渠道配置为空时调 `PaymentStrategyFactory::make($channel, $orderId, null)` 触发 TypeError。
- **根因**:make 方法第三参数 `$config` 类型声明为 `array`,传 null 不兼容。即使配置为空也要传 `[]`。
- **怎么避**:配置为空时传空数组:`make($channel, $orderId, $config ?? [])`。
