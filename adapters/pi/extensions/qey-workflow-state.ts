// qey-workflow-state.ts
// 1.7 新增:每 turn(before_agent_start)读 .workflow-state → 注入对应 workflow breadcrumb
// 让 AI 永远知道自己在哪个阶段,防跳步(吸收自 Trellis 的 workflow-state 机制)
//
// 状态来源:.qey/.workflow-state(由 change.sh create/start/archive 写)
//   change_id=<id>
//   stage=planning|in_progress|finishing
// 无文件 = no_change(无 active change)
//
// breadcrumb 内容:对应 workflow.md 的 [workflow-state:X] 块(精简版,每 turn 注入)

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { readFileSync, existsSync } from "fs";

// workflow-state 文件路径(相对 cwd)
const STATE_FILE = ".qey/.workflow-state";

// 各阶段的 breadcrumb 提示(精简,每 turn 注入;对应 workflow.md 的 [workflow-state:X] 块)
const BREADCRUMBS: Record<string, { label: string; hint: string }> = {
  no_change: {
    label: "no_change",
    hint:
      "无 active change。先分类:新需求(过需求澄清 → Stage 1 建 change)/ 复杂 bug(Stage 0 复现+根因 → 建 change)/ 简单 bug·tweak(不建 change,直接改,踩坑当场写 memory)。",
  },
  planning: {
    label: "planning (Stage 0-1)",
    hint:
      "在 Stage 0-1(规划设计)。过需求澄清-checklist → 填 proposal(为什么+AC)+ design + tasks(AC→Scenario→Seam)+ specs delta。\n" +
      "⚠️ 3 硬闸:① 无批准 Scenario → 不实现;② 无 evidence → 不归档;③ Intent 变 → 新建 change。\n" +
      "填完 review gate → `bash .qey/change.sh start <id>` 切 in_progress。",
  },
  in_progress: {
    label: "in_progress (Stage 2-4)",
    hint:
      "在 Stage 2-4(实现+验证+提交)。按 Scenario TDD:一个 Scenario 一个 vertical slice(red→green→填 evidence)。\n" +
      "每 Scenario 必填 evidence:RED(因正确原因失败)+ GREEN + 回归 + verified@commit hash。\n" +
      "全 AC evidence 齐 → `/qey-commit`(sh 引擎 + AI 起草 message)。",
  },
  finishing: {
    label: "finishing (Stage 4-5)",
    hint:
      "在 Stage 4-5(归档)。commit 后自动衔接 `archive.sh run <id>`:验 evidence + merge delta + 移 archive + 填归档.md。归档后回 no_change。",
  },
};

// 读 .workflow-state,返回 {changeId, stage}
function readState(): { changeId: string; stage: string } {
  if (!existsSync(STATE_FILE)) {
    return { changeId: "", stage: "no_change" };
  }
  const content = readFileSync(STATE_FILE, "utf8");
  const changeId = content.match(/change_id=(.+)/)?.[1]?.trim() ?? "";
  const stage = content.match(/stage=(.+)/)?.[1]?.trim() ?? "no_change";
  return { changeId, stage };
}

export default function (pi: ExtensionAPI): void {
  pi.on("before_agent_start", async () => {
    const { changeId, stage } = readState();
    const crumb = BREADCRUMBS[stage] ?? BREADCRUMBS.no_change;

    // 组装注入文本
    const changePart = changeId ? ` (change: ${changeId})` : "";
    const text = `📍 Workflow: ${crumb.label}${changePart}\n${crumb.hint}`;

    return {
      message: {
        customType: "qey-workflow-state",
        content: [{ type: "text", text }],
      },
    };
  });
}
