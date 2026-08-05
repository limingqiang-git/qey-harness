// qey-find-code.ts
// 替代 .claude/hooks/find-code-reminder.sh(Claude UserPromptSubmit hook)
// omp 无 UserPromptSubmit 事件,用 before_agent_start 检测最新 user message
//
// 时机差异(诚实标注):
// - Claude:prompt 提交时注入(prompt 还没进 agent)
// - omp:before_agent_start 注入(turn 已开始,但 LLM call 未发出)
// 效果接近,时机略晚。TS 实现不依赖 grep 粗提取 JSON,关键词匹配更准。

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// 找代码关键词(精确到代码定位,不是找 bug/找问题)
const FIND_CODE_PATTERN =
  /在哪|定位|代码在哪|找.*代码|找.*功能|调用链|链路|代码段|入口在哪|看.*代码|查.*代码|.*在哪.*代码/;

// omp hook event 结构(@oh-my-pi/pi-coding-agent 未导出公开 d.ts,用结构化类型 + 类型守卫)
interface TextChunk {
  type?: string;
  text?: string;
}

interface AgentMessage {
  role?: string;
  content?: string | TextChunk[];
}

interface BeforeAgentStartEvent {
  messages?: AgentMessage[];
}

// 从 message 提取纯文本
function extractText(msg: AgentMessage): string {
  const content = msg.content;
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter((c): c is TextChunk & { text: string } =>
        c?.type === "text" && typeof c.text === "string")
      .map((c) => c.text)
      .join(" ");
  }
  return "";
}

// 找最新 user message 的文本
function lastUserText(messages: AgentMessage[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m?.role === "user") return extractText(m);
  }
  return "";
}

export default function (pi: ExtensionAPI): void {
  pi.on("before_agent_start", async (event: unknown) => {
    // 类型守卫:event 需有 messages 数组
    if (!event || typeof event !== "object") return;
    const evt = event as BeforeAgentStartEvent;
    const messages = evt.messages;
    if (!Array.isArray(messages) || messages.length === 0) return;

    const text = lastUserText(messages);
    if (!text || !FIND_CODE_PATTERN.test(text)) return;

    // 注入 domain-first 提醒(作为 pre-agent message)
    return {
      message: {
        customType: "qey-find-code-reminder",
        content: [
          {
            type: "text",
            text: '💡 找代码?先 grep -rl "<关键词>" .qey/domain/ 拿英文符号(domain 是中文↔英文桥;答案常已在 domain/业务术语.md),再用英文符号查 codegraph——别直接 codegraph 搜中文(只索引英文,必 0 结果)。串行:domain 拿符号→codegraph 验证。',
          },
        ],
      },
    };
  });
}
