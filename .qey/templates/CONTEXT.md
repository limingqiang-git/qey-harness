# CONTEXT.md 模板

> **项目级术语统一入口(glossary)**。只放术语定义,**不含实现细节**。
> 这是 AI 每次用词前的第一参照——"用户说的'订单'到底是哪个 Order?"。
> 复制到项目根 `CONTEXT.md`,scan 填充,全程持续 sharpening。
---

## 术语表(Ubiquitous Language)

> 中↔英符号桥。每个术语一行:中文 → 英文(代码符号)| 定义 | 置信度。
> **用词和这里冲突时 → 当场 challenge**(不是默默用你的理解)。

| 中文 | 英文(代码符号) | 定义 | 置信度 |
|------|----------------|------|--------|
| [scan 填充:术语1] | `ClassName` | 一句话定义 | observed |
| [scan 填充:术语2] | `ClassName::method` | 一句话定义 | ⚠️待确认 |

## 容易混淆的术语(Disambiguation)

> 看起来像但实际不同的概念。防止 AI 把 A 当 B。

| 容易混淆 | 区别 |
|---------|------|
| [scan 填充:概念A] vs [概念B] | A 是…;B 是…;区别在… |

## 相关文件(不重复内容,只指向)

- **代码地图**(结构/入口/流程):`domain/domain-map.md` + `domain/业务流程.md`
- **行为契约**(该做什么):`specs/<域>/spec.md`
- **架构决策**(为什么选 X 不选 Y):`knowledge/业务演进/`
- **踩坑记录**:`knowledge/踩坑记录/`

> CONTEXT.md **不含**实现细节、文件路径、代码片段——那些在 domain/specs/knowledge 里。
> 这里只是"术语 → 定义"的权威字典。
