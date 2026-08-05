---
type: feat / fix / tweak / opt / refactor
title: ""
date: YYYY-MM-DD
branch: feat/xxx
commit: ""              # 必填,archive.sh 自动填(commit 流水线抓 hash)
merged_to: ""           # 若已 merge:dev/test/uat/master;未 merge 留空
status: in-progress     # in-progress / done / experimental / abandoned
risk: low               # low / med / high
change_id: ""           # archive.sh 自动填(= 目录名)
domain: ""              # 业务域(支付/订单/售后/...)
mr_url: ""              # MR/PR 链接(commit 流水线提 MR 后自动填)
issue_id: ""            # 任务编号(禅道/Jira/none)
depends_on: []          # 依赖的其他 change id 列表
---

# 归档:<change-id 或 title>

> 本文件是 change 的**最终落地产物**(proposal 是"想做什么",归档是"实际做成了什么 + 碰了什么")。
> **填写时机**:**change 建好就带本骨架**(事件驱动)—— 开发过程中随时填"功能修改点/涉及的修改/踩的坑",不拖到归档时。归档时 `archive.sh` 自动填 frontmatter 的 commit/date/branch,正文已填的保留。
> **对 AI 友好**:10 段固定结构 + 表格,`/qey-distill` 的 archive 提取(Step 2.2)可靠解析;影响点和修改文件表可机械回溯。
> **对人友好**:每段有明确问法,AI 起草、人校对。新成员看这一份就能理解这个 change。
> 📖 **填写参考**:看 `归档_example.md`(支付重构完整范例)——参考 12 段的质量和深度。

## 需求背景

为什么做这个 change?解决什么问题?(2-3 句,不照抄 proposal,浓缩成结论)

<!-- 例:"旧支付渠道(X 支付)2026-08 下线,必须切到新渠道(Y 支付)。
     现有 PaymentService 硬编码 X 渠道,无法扩展。目标是引入策略模式支持多渠道。" -->

## 功能修改点

这个 change 改了/加了哪些**业务功能**(用户/系统能感知的行为变化)?列出来。

<!-- 按功能点列,每点 1 句。这是"做了什么功能",不是"改了哪些文件"(那是下一段)。
     例:
     - 新增 Y 支付渠道(支持 App/小程序/H5)
     - PaymentService 重构为策略模式,渠道可配置
     - 移除 X 支付相关代码(旧渠道)
     - 后台支付配置页:新增渠道开关 -->

## 涉及的修改

改了哪些文件?每个文件一句话说明改了啥。(AI 可从 `git diff --name-only <base>..HEAD` 拉清单 + 每文件 diff 概述,人校对)

<!-- 按目录分组更清晰。例:
     **业务层**
     - `app/Payment/PaymentService.php` — 重构为策略模式,渠道走 PaymentStrategy
     - `app/Payment/Strategies/YPayStrategy.php` — 新增(YY 支付策略实现)
     - `app/Payment/Strategies/XPayStrategy.php` — 删除(旧渠道)

     **数据层**
     - `app/Payment/Migrations/2026_07_27_add_payment_channel_field.php` — payment 表加 channel 字段

     **接口/前端**
     - `app/Http/Controllers/PaymentController.php` — pay 接口参数加 channel
     - `resources/views/admin/payment.blade.php` — 后台配置页加渠道开关 -->

## 表结构变更

数据库表/字段变更。**有变更才填,无变更写"不涉及表结构"**。

<!-- 例:
     | 表 | 变更 | 说明 |
     |----|------|------|
     | payment | ADD channel varchar(20) | 支付渠道(Y/x) |
     | payment | ADD channel_config json | 渠道配置(密钥等,加密存) |
     | payment_log | INDEX (channel, created_at) | 按渠道查询日志 -->

## 配置/部署变更

部署侧变更:环境变量、配置文件、新依赖的外部服务、需手动跑的迁移脚本。**有变更才填,无变更写"不涉及配置部署"**。

<!-- 和表结构变更对齐:表结构是 DB schema,本段是部署侧。运维上线必看。
     例:
     - 环境变量:`PAYMENT_Y_APP_ID` / `PAYMENT_Y_APP_SECRET`(Y 支付凭证)
     - 配置文件:`config/payment.php` 加 Y 渠道配置块
     - 依赖服务:Y 支付 API(api.pay-y.com,需白名单出网)
     - 迁移脚本:`php artisan migrate`(payment 表加 channel 字段);`php artisan payment:sync-channel`(回填存量订单 channel) -->

## 影响点

这个 change 可能影响哪些**已有功能/系统**?回归测试重点看这些。

<!-- 列出受影响的功能/模块,标注风险等级。例:
     - 支付回调(X 渠道的回调处理被移除,确认无在途 X 订单) — 高
     - 订单退款流程(走 PaymentService,渠道逻辑变了) — 高
     - 财务报表(按渠道统计,需确认 channel 字段同步) — 中
     - 后台权限(payment 配置页权限) — 低 -->

## 测试说明

测了哪些场景 + 手动验证了啥 + 已知未覆盖。**补 tasks.md 的机器 evidence(RED/GREEN/exit code),这段是人能读懂的测试覆盖说明**。

<!-- 例:
     - **自动化**(对应 AC1-3):支付下单、回调、退款三场景全绿(见 tasks.md evidence)
     - **手动验证**:Y 支付沙箱环境实测下单 + 回调;后台配置页 UI 操作
     - **已知未覆盖**:并发退款(测试数据不足,留灰度观察);旧 X 渠道迁移(迁移脚本测了 dry-run,生产跑前再验)
     - **回归**:全量 128 passed(php artisan test) -->

## 总结

对比 proposal 的 AC 清单,哪些达成、哪些没达成、哪些超出范围?(2-5 句)

<!-- 例:"按 AC1-3 完成支付重构 + Y 渠道接入;AC4(灰度)未做,留后续 change。
     超出范围:顺带修了回调重试 bug(见 commit abc123)。" -->

## 踩的坑

遇到的、**可复用**的坑(不复述 change 过程,只记别人/下次会踩的)。

<!-- 若有 → 同步一份到 knowledge/踩坑记录/<域>.md(事件驱动,当场写,不拖 recap)。
     若无 → 写"无显著坑"。
     例:"PaymentStrategy::refund 第三个参数必须传 null 不能省略,省略触发类型错误。" -->

## 关键决策(为什么选 X 不选 Y)

满足 ADR 三门槛(难逆 / 反直觉 / 真实取舍)的决策。

<!-- 若有 → 同步到 knowledge/业务演进/<流程>.md(事件驱动,当场写)。
     若无 → 写"常规实现,无重大取舍"。
     例:"选策略模式而非 if-else:渠道预计持续增加,策略模式扩展成本低。" -->

## 上线/回滚记录

若已上线:环境 + 时间 + 观察指标 + 回滚预案。

<!-- 若已上线:"2026-07-27 上线 test,观察 T+1 回调成功率 >99%;回滚:配置开关 PaymentV2.enabled=false"。
     若未上线:"未上线"或"待灰度"。 -->

## 后续待办(衍生的)

本次 change 衍生的新 change / 技术债 / 遗留问题。

<!-- 若有:列出来(每个可能成为新 change)。
     若无:"无"。
     例:"① 灰度控制(AC4)独立 change;② PaymentStrategy 超时策略统一(技术债)。" -->

---

> **归档自动填的 frontmatter**(archive.sh / commit 流水线填,人不写):
> - `commit`:归档时关联的 git commit hash(commit 流水线自动抓)
> - `date`:归档日期 / `branch`:归档时所在分支
> - `change_id`:change 目录名 / `status`:归档时改 done(或 experimental)
> - `mr_url`:commit 流水线提 MR 后自动填 MR 链接
>
> **人/AI 填的**:type / title / risk / domain / issue_id / depends_on(创建时)+ 正文 10 段(开发过程中持续填)
