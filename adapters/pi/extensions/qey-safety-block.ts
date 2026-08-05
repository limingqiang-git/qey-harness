// qey-safety-block.ts
// omp 独有(超越 Claude):tool_call hook 能 block + 弹 confirm 对话框
// 补 Claude settings.local.json 不覆盖的 Write/Edit 级别危险
//
// Claude 的 settings 只能管 Bash,Write/Edit 无权限闸;
// omp 的 tool_call hook 能拦截任意工具 + 弹对话框,这是 omp 相对 Claude 的纯增量。

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// 受保护文件路径规则(用户决策补充清单)
// 命中 → 有 UI 弹 confirm / 无 UI(headless/subagent)直接 block
const PROTECTED_WRITE_PATHS: readonly RegExp[] = [
  // ── 密钥/凭证文件 ──
  /\.env(\.|$)/i,                              // .env / .env.local / .env.production
  /(?:^|\/)\.env$/i,                           // 纯 .env
  /(?:^|\/)\.envrc$/i,                         // direnv
  /(?:^|\/)credentials?(?:\.(?:json|yml|yaml|ini|toml|txt))?$/i,  // credentials / credentials.json
  /\.(?:pem|key|p12|pfx|crt|cer|csr)$/i,       // 证书/私钥
  /(?:^|\/)id_(?:rsa|dsa|ecdsa|ed25519)$/i,    // SSH 私钥(id_rsa 等)
  /(?:^|\/)id_(?:rsa|dsa|ecdsa|ed25519)\.pub$/i, // SSH 公钥(也保护,防误改)
  /\.(?:keystore|jks|keychain)$/i,             // Java/macOS keystore
  /(?:^|\/)\.netrc$/i,                         // .netrc(含 API 凭证)
  /(?:^|\/)\.npmrc$/i,                         // .npmrc(可能含 token)
  /(?:^|\/)\.pypirc$/i,                        // .pypirc(含 PyPI token)
  /(?:^|\/)\.aws\/credentials$/i,             // AWS credentials
  /(?:^|\/)\.aws\/config$/i,                   // AWS config(可能含 key)
  /(?:^|\/)\.docker\/config\.json$/i,          // Docker(含 registry 凭证)
  /(?:^|\/)\.git-credentials$/i,               // git credential store
  /(?:^|\/)\.htpasswd$/i,                      // htpasswd
  /(?:^|\/)config\/secrets\.yml$/i,            // Rails secrets
  /(?:^|\/)config\/secrets\.yaml$/i,           // Rails secrets
  /(?:^|\/)wp-config\.php$/i,                  // WordPress(含 DB 凭证)
  /(?:^|\/)config\/master\.key$/i,             // Rails master key
  /(?:^|\/)token(?:s)?(?:\.json|\.txt)?$/i,    // token / tokens 文件

  // ── lock 文件(误改导致依赖漂移)──
  /(?:^|\/)(?:composer|package|pnpm-package)\.lock$/i,
  /(?:^|\/)pnpm-lock\.yaml$/i,
  /(?:^|\/)(?:yarn|bun)\.lock$/i,
  /(?:^|\/)(?:Cargo|Gemfile|Podfile)\.lock$/i,
  /(?:^|\/)(?:poetry|mamba|conda)\.lock$/i,
  /(?:^|\/)go\.sum$/i,                         // go.sum(checksum,误改导致校验失败)
  /(?:^|\/)flake\.lock$/i,                     // Nix flake lock

  // ── 数据库/数据文件(防误改数据)──
  /\.sqlite[0-9]*$/i,                          // SQLite DB
  /\.db$/i,                                    // 通用 .db
  /\.db3$/i,                                   // SQLite3
  /(?:^|\/)dump\.sql$/i,                       // SQL dump

  // ── 生成文件(误改会被覆盖,浪费时间)──
  /(?:^|\/)package-lock\.json$/i,              // npm lock(npm ci 会覆盖)
];

// 提取 write/edit 工具的 path 参数
interface WriteEditInput {
  path?: string;
  filePath?: string;
  file?: string;
}

function extractPath(input: unknown): string {
  if (!input || typeof input !== "object") return "";
  const i = input as WriteEditInput;
  return i.path ?? i.filePath ?? i.file ?? "";
}

// 找命中的规则(返回 RegExp 便于在 reason 里说明)
function matchedRule(path: string): RegExp | null {
  for (const re of PROTECTED_WRITE_PATHS) {
    if (re.test(path)) return re;
  }
  return null;
}

interface HookContext {
  hasUI?: boolean;
  ui?: {
    confirm?: (title: string, message: string) => Promise<boolean>;
  };
}

const WRITE_EDIT_TOOLS = new Set(["write", "edit"]);

export default function (pi: ExtensionAPI): void {
  pi.on("tool_call", async (event: unknown, ctx: unknown) => {
    if (!event || typeof event !== "object") return;
    const e = event as { toolName?: string; input?: unknown };
    if (!e.toolName || !WRITE_EDIT_TOOLS.has(e.toolName)) return;

    const path = extractPath(e.input);
    if (!path) return;

    const hit = matchedRule(path);
    if (!hit) return;

    const c = ctx as HookContext;
    // 有 UI:弹 confirm;无 UI(headless/subagent):直接 block
    if (!c?.hasUI || !c.ui?.confirm) {
      return {
        block: true,
        reason: `受保护文件(匹配规则 ${hit}),headless 模式禁止改:${path}`,
      };
    }

    const allow = await c.ui.confirm(
      "受保护文件",
      `即将修改受保护文件:\n${path}\n\n匹配规则:${hit}\n\n此文件通常含密钥/凭证/锁数据。确认修改?`
    );
    if (!allow) {
      return { block: true, reason: `用户取消修改受保护文件:${path}` };
    }
  });
}
