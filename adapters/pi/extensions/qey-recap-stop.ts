// qey-recap-stop.ts
// 替代 .claude/hooks/recap-stop-hook.sh(Claude Stop hook,可 decision:block 强制拦截)
//
// 能力差距(诚实标注):
// - Claude:Stop hook 能 `decision:block` 把会话拦住强制沉淀
// - omp:session_shutdown 事件不能 block(返回值列为 "—"),只能 notify 提醒
// 替代策略:用 turn_end 做"改了代码就提醒核实 freshness" + session_shutdown 轻量提醒
// 协同:omp 内置 autolearn(memory.backend + autolearn.enabled)会在 stop 后 nudge 写 memory/skill,
//       与本 hook 不冲突(本 hook 提醒写 .qey/,autolearn 提醒写 omp memory)

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { execSync } from "child_process";

interface HookContext {
  hasUI?: boolean;
  ui?: {
    notify?: (message: string, type?: string) => void;
  };
}

// 统计 git 改动文件数(非 git 返回 -1)
function gitChangedCount(): number {
  try {
    const out = execSync("git status --porcelain 2>/dev/null | wc -l", {
      encoding: "utf8",
      stdio: ["pipe", "pipe", "ignore"],
    });
    const n = parseInt(out.trim(), 10);
    return Number.isFinite(n) ? n : -1;
  } catch {
    return -1;
  }
}

export default function (pi: ExtensionAPI): void {
  let turnNudged = false;

  // turn_end:改了代码就提醒核实 freshness(每个 turn 一次,防 nag)
  pi.on("turn_end", async (_event: unknown, ctx: unknown) => {
    if (turnNudged) return;
    const c = ctx as HookContext;
    if (!c?.hasUI || !c.ui?.notify) return;

    const changed = gitChangedCount();
    if (changed <= 0) return; // 0 改动或非 git

    turnNudged = true;
    c.ui.notify(
      `本次有 ${changed} 处改动:产出可沉淀知识吗?业务理解→domain/、纠正/坑→knowledge/踩坑记录/、决策→knowledge/业务演进/、行为真相→specs/。改了代码→核实 .qey 引用 freshness(过期比没知识更危险)。`,
      "info"
    );
  });

  // session_shutdown:给一次沉淀提醒(非阻断,omp 无法强制拦截)
  pi.on("session_shutdown", async (_event: unknown, ctx: unknown) => {
    const c = ctx as HookContext;
    if (!c?.hasUI || !c.ui?.notify) return;
    c.ui.notify(
      "会话结束:本次的可沉淀知识写进 .qey/ 了吗?(domain/memory/specs)。已写或不涉及→忽略。可用 /recap 系统过一遍。",
      "info"
    );
  });

  // 每个 turn 重置 nudged 标记(下个 turn 又能提醒)
  pi.on("turn_start", async () => {
    turnNudged = false;
  });
}
