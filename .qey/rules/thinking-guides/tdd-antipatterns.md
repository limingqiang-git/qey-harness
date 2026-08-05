# TDD 反模式与 Seam 纪律

> 写测试前花 30 秒过一遍。大部分测试问题来自"没想到",不是"不会写"。

## 写测试前(Seam 先确认)

**Seam = 你测的公开接口(观察行为的边界)**。写任何测试前:

1. **写下要测的 Seam**(`Class::method` / API 路由 / CLI 命令)
2. **和用户确认这些 Seam**——没确认的 Seam 不写测试
3. **用最高的 Seam**——优先测外层公开接口(如 Controller),不测内部 Service(除非逻辑复杂)
4. **理想 Seam 数 = 1**——Seam 越少,测试越稳

> ❌ 在未确认的 Seam 写测试。✅ 先列 Seam → 确认 → 再写。

## 三个反模式(出现就改)

### ① 实现耦合(Implementation-coupled)

**症状**:重构后行为没变,但测试挂了。

```typescript
// ❌ BAD:测内部调用(mock 了内部 collaborator)
test("checkout calls paymentService.process", () => {
  const mock = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mock.process).toHaveBeenCalledWith(cart.total);  // 重构 payment 调用方式 → 测试挂
});

// ✅ GOOD:测公开行为
test("user can checkout with valid cart", async () => {
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");  // 重构不影响
});
```

**红旗**:mock 内部 collaborator / 测 private 方法 / 断言调用次数或顺序 / 通过查数据库而非接口验证。

### ② 同义反复(Tautological)

**症状**:测试永远过——因为期望值是用同样的逻辑算出来的。

```typescript
// ❌ BAD:期望值用同样的算法重算(永远过)
test("calculateTotal sums items", () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((s, i) => s + i.price, 0);  // 和实现一样的逻辑!
  expect(calculateTotal(items)).toBe(expected);
});

// ✅ GOOD:期望值是独立的已知常量
test("calculateTotal sums items", () => {
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);  // 独立来源
});
```

**红旗**:期望值用 reduce/map/同算法重算 / 快照是手算的且和实现一样 / 常量断言等于自身。

### ③ 水平切片(Horizontal slicing)

**症状**:测试覆盖了"想象的"行为,对真实变化不敏感。

```
❌ 先写完全部测试 → 再批量实现(测的是"形状",不是行为)
✅ 一个测试 → 一个最小实现 → 再下一个(每个测试是 tracer bullet,响应该轮学到的东西)
```

**红旗**:设计期写死了所有测试名和断言 / 提交了测试结构但还不理解实现 / 一批测试一起绿(没逐个 red→green)。

## Red → Green 循环规则

- **先 Red 后 Green**:先写失败的测试,再写让它过的最小代码。不预判未来测试。
- **一次一个切片**:一个 Seam,一个测试,一个最小实现,一轮。
- **Refactor 不在循环里**:重构属于 review 阶段,不是 red→green 周期内的事。
