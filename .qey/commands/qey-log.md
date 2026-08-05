---
description: 会话日志(机械) — bash log.sh 抓 git 信息 append 到 journal;30 秒,不提炼不判断不删旧
---

# 会话日志(机械记录)

> **本命令只做一件事:调 log.sh 抓 git → append journal。不做任何提炼/判断/分类。**
> 知识提炼请用 `/qey:distill`(那是显式的、低频的、要你确认的)。

## 执行

```bash
bash .qey/log.sh
```

带标题/备注(可选):

```bash
bash .qey/log.sh --title "支付重构第一期" --stdin <<< "完成策略模式接入"
```

**sh 引擎做**(你不做任何事):
- 抓上次 journal 记的 commit ~ HEAD 的 git log/diff/status
- append 到 `journal/journal-YYYY-MM.md`(max 2000 行自动轮转)
- **Next Session(交接)**:自动提取当前 change 的未完成 task 数 + workflow stage,**让下个 session 知道接着做什么**

---

> journal 格式:date / branch / summary / changes / commits / next(见 `journal/README.md`)。
> 何时跑:每次会话结束(机械,30 秒)。
