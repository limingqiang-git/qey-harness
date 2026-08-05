# 踩坑记录模板(Pitfall Ledger)

> **append-only 坑账本**。踩了坑 → 追加到对应域文件。
> **写入时机**:bug-loop **第 6 步当场写**(信息最全),不拖到 distill。
> **2.0 增强**:每条必须有**验证锚点**(符号/路径),`qey verify` 自动检测过期。
> 📖 **填写参考**:看 `_example.md`(回调签名/拦截窗口完整范例)——参考踩坑的写法。

## 条目格式

````markdown
### [YYYY-MM-DD] 标题 [observed|⚠️待确认]
- **锚点**:`ClassName::method` 或 `app/path/file.php`  ← verify 检测过期用
- **last_verified**: YYYY-MM-DD
- **坑现象**:<一句话;复杂场景给复现步骤>
- **根因**:<说明 + 错误代码段>
  ```php
  // ❌ 问题代码
  ```
- **怎么避**:<正确代码段>
  ```php
  // ✅ 正确写法
  ```
````

> **锚点规范**(优先级):① 符号 `Class::method`(最稳,verify 能 grep)② 路径 `app/xxx.php`(次稳,verify 能测存在)③ 行号 `:56 (YYYY-MM codegraph)`(最弱,必带日期)
> **置信度**:observed = 代码直接验证过;⚠️待确认 = 推断的,verify 优先查

## 索引(新增条目补一行)

| 域 | 文件 |
|----|------|
| [qey:scan 填充:域1] | |
