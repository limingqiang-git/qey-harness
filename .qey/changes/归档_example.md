---
type: feat
title: "支付渠道重构:策略模式 + 微信/支付宝双渠道"
date: 2026-08-05
branch: feat/pay-refactor
commit: ""
merged_to: ""
status: done
risk: high
change_id: pay-refactor
domain: 支付
mr_url: ""
issue_id: ""
depends_on: []
---

# 归档:pay-refactor — 支付渠道重构

> **这是完整填好的真实样本**——供 AI 写归档时参考质量、深度、格式。
> 结构看 `归档_template.md`,质量看本文件。

## 需求背景

旧 PaymentService 硬编码微信支付,渠道逻辑和业务逻辑耦合。支付宝渠道需新增,但原结构无法扩展。目标:引入策略模式,渠道可配置,为后续接入更多渠道铺路。

## 功能修改点

- 新增支付宝渠道(支持 App/H5/小程序)
- PaymentService 重构为策略模式,渠道走 PaymentStrategy 接口
- 后台支付配置页:新增渠道开关 + 密钥配置
- 微信支付逻辑保持不变(迁移到 WechatPayStrategy,行为一致)

## 涉及的修改

**业务层**
- `app/Service/Payment/PaymentService.php` — 重构为策略模式,渠道走 PaymentStrategy
- `app/Service/Payment/Strategy/PaymentStrategyInterface.php` — 新增(策略接口)
- `app/Service/Payment/Strategy/WechatPayStrategy.php` — 新增(微信,从旧逻辑迁移)
- `app/Service/Payment/Strategy/AlipayStrategy.php` — 新增(支付宝)
- `app/Service/Payment/PaymentStrategyFactory.php` — 新增(按 channel 配置选策略)

**数据层**
- `app/Payment/Migrations/2026_08_05_add_payment_channel_field.php` — payment 表加 channel 字段

**接口/前端**
- `app/Http/Controllers/PayController.php` — pay 接口参数加 channel
- `app/Http/Controllers/CallbackController.php` — 回调按 channel 分发到对应策略
- `resources/views/admin/payment.blade.php` — 后台配置页加渠道开关

## 表结构变更

| 表 | 变更 | 说明 |
|----|------|------|
| payment | ADD channel varchar(20) | 支付渠道(wechat/alipay) |
| payment | ADD channel_config json | 渠道配置(密钥等,加密存) |

## 配置/部署变更

- 环境变量:`PAYMENT_ALIPAY_APP_ID` / `PAYMENT_ALIPAY_PRIVATE_KEY`(支付宝凭证)
- 配置文件:`config/payment.php` 加 alipay 渠道配置块
- 依赖服务:支付宝 API(openapi.alipay.com,需白名单出网)
- 迁移脚本:`php artisan migrate`(payment 表加 channel);`php artisan payment:backfill-channel`(回填存量订单 channel=wechat)

## 影响点

- 支付回调(微信回调分发逻辑变了,确认存量微信回调不受影响) — 高
- 订单退款流程(走 PaymentService,渠道逻辑变了) — 高
- 财务报表(按渠道统计,需确认 channel 字段同步) — 中
- 后台权限(payment 配置页权限) — 低

## 测试说明

- **自动化**(AC1-3):微信下单、支付宝下单、双渠道回调全绿(见 tasks.md evidence)
- **手动验证**:支付宝沙箱实测下单 + 回调;后台配置页 UI 操作
- **已知未覆盖**:并发退款(测试数据不足,留灰度观察)
- **回归**:全量 142 passed

## 总结

按 AC1-3 完成支付重构 + 支付宝渠道接入。AC4(灰度控制)超出范围,留后续 change。顺带修了回调签名验证的 bug(见 commit abc123)。

## 踩的坑

- **锚点**:`PaymentStrategyFactory::make` (app/Service/Payment/PaymentStrategyFactory.php)
- **last_verified**: 2026-08-05
- PaymentStrategyFactory::make 第三个参数 `$config` 必须传数组不能传 null,传 null 触发类型错误(即使配置为空也要传 `[]`)
- 已同步到 `knowledge/踩坑记录/支付.md`

## 关键决策(为什么选 X 不选 Y)

- **锚点**:`PaymentStrategyInterface` (app/Service/Payment/Strategy/PaymentStrategyInterface.php)
- **last_verified**: 2026-08-05
- 选策略模式而非 if-else:渠道预计持续增加(后续接银联/虚拟币),策略模式扩展成本低(新渠道加一个 Strategy 类,不改 PaymentService)
- 满足 ADR 三门槛:难逆(重构成本高)/ 反直觉(当前只有 2 渠道看似不需要)/ 真实取舍(策略模式比 if-else 多 3 个文件)
- 已同步到 `knowledge/业务演进/支付渠道架构.md`

## 上线/回滚记录

- 2026-08-05 上线 test,观察 T+1 支付成功率(微信 >99.5% / 支付宝 >99%)
- 回滚:配置开关 `payment.refactor_enabled=false` 回退到旧逻辑

## 后续待办(衍生的)

- 灰度控制(AC4)— 独立 change `pay-grayscale`
- PaymentStrategy 超时策略统一(当前各策略超时不同,技术债)
- 银联渠道接入(依赖本次策略模式)
