// 记忆保鲜检测引擎:检测 domain/specs/knowledge 里的知识是否过期。
// 核心原则:"过期的知识比没知识更危险"——必须能自动发现过期,不依赖人记得跑。
// 被 qey commit(硬闸)和 qey verify(独立检测)共用。
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { resolve, join, relative } from "node:path";
import { spawnSync } from "node:child_process";
// ── 从 markdown 提取锚点(知识引用的代码符号/路径)──

// 符号锚点:Class::method 或 ClassName(大驼峰,至少 2 段或带 ::)
const SYMBOL_RE = /\b([A-Z][a-zA-Z0-9_]+)(?:::([a-zA-Z_][a-zA-Z0-9_]*))?\b/g;

// 文件路径锚点:app/xxx/xxx.php 或 src/xxx/xxx.ts(常见代码路径)
const PATH_RE = /\b((?:app|src|lib|internal|cmd|pkg|api|Service|Controller|Domain|Repository)\/[a-zA-Z0-9_/.-]+\.\w{1,5})\b/g;

// 锚点标记行:以 锚点/anchor/签名/signature 开头的行
function extractAnchors(content) {
  const anchors = { symbols: new Set(), paths: new Set() };
  // 显式锚点行:**锚点**:`Class::method`  或 **签名**:`...`
  const explicitRe = /\*\*(?:锚点|anchor|签名|signature)\*\*[：:]\s*[`"]?([^`"\n]+)[`"]?/gi;
  let m;
  while ((m = explicitRe.exec(content))) {
    const val = m[1].trim();
    const sm = val.match(/([A-Z][a-zA-Z0-9_]+)(?:::([a-zA-Z_]\w*))?/);
    if (sm) anchors.symbols.add(sm[1] + (sm[2] ? "::" + sm[2] : ""));
  }
  // 隐式:正文里的 Class::method 和 app/path
  while ((m = SYMBOL_RE.exec(content))) {
    const sym = m[1] + (m[2] ? "::" + m[2] : "");
    // 过滤常见非符号(Markdown 语法/模板占位)
    if (!["TODO", "NOTE", "WARN", "FIXME", "YYYY", "MM", "DD"].includes(m[1])) {
      anchors.symbols.add(sym);
    }
  }
  while ((m = PATH_RE.exec(content))) {
    anchors.paths.add(m[1]);
  }
  return anchors;
}

// ── 验证锚点:符号/路径还在代码里吗?──

function symbolExists(symbol, projectDir) {
  // symbol 可能是 ClassName 或 ClassName::method
  const className = symbol.split("::")[0];
  // grep 类名是否出现在代码里(宽松:定义/引用/导入 都算"在")
  const r = spawnSync("grep", [
    "-rl",
    "--include=*.php", "--include=*.ts", "--include=*.js",
    "--include=*.go", "--include=*.py", "--include=*.java",
    "--include=*.rb", "--include=*.rs", "--include=*.kt",
    "-m1", className, projectDir,
  ], { stdio: "pipe", timeout: 5000 });
  return (r.stdout || "").toString().trim().length > 0;
}

function pathExists(filePath, projectDir) {
  return existsSync(resolve(projectDir, filePath));
}

// ── 主检测:扫某个知识目录,返回过期清单 ──

// 置信度判定:根据内容判断这条知识的可信度
function getConfidence(content, lineNum) {
  const lines = content.split("\n");
  const ctx = lines.slice(Math.max(0, lineNum - 3), lineNum + 2).join(" ");
  if (ctx.includes("⚠️待确认") || ctx.includes("inferred")) return "inferred";
  if (ctx.includes("❓待确认") || ctx.includes("unknown")) return "unknown";
  if (ctx.includes("observed")) return "observed";
  return "unknown";
}

// 非符号噪声词(常见英文词被误判为 ClassName)
const NOISE_WORDS = new Set([
  "CLAUDE", "AGENTS", "README", "TODO", "NOTE", "WARN", "FIXME", "WIP",
  "YYYY", "MM", "DD", "HH", "ADR", "API", "JSON", "XML", "HTML", "CSS",
  "SQL", "URL", "URI", "UUID", "TDD", "SDD", "CI", "CD", "MR", "PR",
  "MCP", "LLM", "DAG", "HTTP", "HTTPS", "SSH", "GPL", "MIT",
  "Controller", "Service", "Model", "Repository", "Domain", "View",
  "Enum", "Level", "Layer", "Route", "Router", "Config", "Provider",
  "Factory", "Builder", "Adapter", "Wrapper", "Handler", "Listener",
  "Middleware", "Component", "Module", "Plugin", "Extension",
  "Spec", "Check", "Checklist", "Quality", "GREEN", "RED",
  "ADDED", "MODIFIED", "REMOVED", "Current", "Truth",
  "Business", "Evolution", "Stage", "Pitfall", "Ledger",
  "MySQL", "Postgres", "Redis", "Docker", "Kafka", "RabbitMQ", "Repo",
]);

function isRealSymbol(symbol) {
  const className = symbol.split("::")[0];
  if (NOISE_WORDS.has(className)) return false;
  if (className.length <= 3) return false;
  if (/^[A-Z]+$/.test(className) && className.length <= 4) return false;
  if (className.startsWith("Placeholder") || className.startsWith("XXX")) return false;
  return true;
}

// 扫 .qey/{domain,specs,knowledge} 下所有 md,提取锚点,验证
// opts.confidence: 'inferred_only'(默认,只查 ⚠️/❓)| 'all'(查全部)
export function scanStale(projectDir = process.cwd(), opts = {}) {
  const qeyDir = resolve(projectDir, ".qey");
  const scanDirs = ["domain", "specs", "knowledge"];
  const stale = [];
  const verified = [];
  const skipped = []; // 跳过的(置信度不够 or 噪声)
  const confidenceMode = opts.confidence || "all"; // 默认查全部,--inferred-only 只查待确认

  for (const sub of scanDirs) {
    const dir = resolve(qeyDir, sub);
    if (!existsSync(dir)) continue;
    const files = walkMd(dir);
    for (const f of files) {
      const rel = relative(qeyDir, f);
      const content = readFileSync(f, "utf8");
      const lines = content.split("\n");
      const { symbols, paths } = extractAnchors(content);

      for (const sym of symbols) {
        if (!isRealSymbol(sym)) { skipped.push({ anchor: sym, reason: "噪声/非符号" }); continue; }
        // 置信度过滤
        const ln = lines.findIndex((l) => l.includes(sym.split("::")[0])) + 1;
        const conf = getConfidence(content, ln);
        if (confidenceMode === "inferred_only" && conf === "observed") {
          skipped.push({ anchor: sym, reason: "observed,跳过" });
          continue;
        }
        if (symbolExists(sym, projectDir)) {
          verified.push({ file: rel, anchor: sym, type: "symbol", confidence: conf });
        } else {
          stale.push({
            file: rel, line: ln || 1, anchor: sym, type: "symbol",
            confidence: conf,
            reason: `符号 ${sym} 在代码中未找到(已删/改名?)`,
          });
        }
      }
      for (const p of paths) {
        if (pathExists(p, projectDir)) {
          verified.push({ file: rel, anchor: p, type: "path" });
        } else {
          const pln = lines.findIndex((l) => l.includes(p)) + 1;
          stale.push({
            file: rel, line: pln || 1, anchor: p, type: "path",
            reason: `路径 ${p} 不存在(已移动/删除?)`,
          });
        }
      }
    }
  }
  return { stale, verified, skipped, total: stale.length + verified.length };
}

// ── commit 场景:git diff 改了哪些文件,哪些知识引用了它们 ──

export function checkDiffImpact(projectDir = process.cwd()) {
  // 拿 git diff --name-only(工作区 vs HEAD)
  const r = spawnSync("git", ["diff", "--name-only", "HEAD"], {
    cwd: projectDir, stdio: "pipe", timeout: 5000,
  });
  const changed = (r.stdout || "").toString().trim().split("\n").filter(Boolean);
  if (!changed.length) return { impacted: [], changed };

  // 也查 staged
  const r2 = spawnSync("git", ["diff", "--cached", "--name-only"], {
    cwd: projectDir, stdio: "pipe", timeout: 5000,
  });
  const staged = (r2.stdout || "").toString().trim().split("\n").filter(Boolean);
  const allChanged = [...new Set([...changed, ...staged])];

  const qeyDir = resolve(projectDir, ".qey");
  const scanDirs = ["domain", "specs", "knowledge"];
  const impacted = [];

  for (const sub of scanDirs) {
    const dir = resolve(qeyDir, sub);
    if (!existsSync(dir)) continue;
    for (const f of walkMd(dir)) {
      const content = readFileSync(f, "utf8");
      const lines = content.split("\n");
      for (const changedFile of allChanged) {
        // 知识文件引用了改动的文件?
        const ln = lines.findIndex((l) => l.includes(changedFile)) + 1;
        if (ln > 0) {
          impacted.push({
            knowledgeFile: relative(qeyDir, f),
            line: ln,
            changedFile,
            reason: `引用了本次改动的文件 ${changedFile},核实是否过期`,
          });
        }
        // 改动的文件名(不含路径)也在知识里?
        const basename = changedFile.split("/").pop().replace(/\.\w+$/, "");
        if (basename.length > 3) {
          const symLn = lines.findIndex((l) =>
            l.includes(basename) && !l.includes(changedFile)
          ) + 1;
          if (symLn > 0) {
            impacted.push({
              knowledgeFile: relative(qeyDir, f),
              line: symLn,
              changedFile: basename,
              reason: `引用了 ${basename}(本次改动的文件名),核实符号是否还在`,
            });
          }
        }
      }
    }
  }
  return { impacted, changed: allChanged };
}

// ── 辅助 ──
function walkMd(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = join(dir, e.name);
    if (e.isDirectory()) return walkMd(p);
    // 排除模板/README(示例内容不是项目真实知识)
    if (e.name.endsWith(".md") && !e.name.startsWith("_") && e.name !== "README.md") return [p];
    return [];
  });
}

// ── 打印报告(verify 命令用)──
// opts.confidence: 'all'(默认)| 'inferred_only'(只查 ⚠️/❓)
export function printStaleReport(projectDir = process.cwd(), opts = {}) {
  const { stale, verified, skipped, total } = scanStale(projectDir, opts);
  const G = (s) => `\x1b[32m${s}\x1b[0m`;
  const Y = (s) => `\x1b[33m${s}\x1b[0m`;
  const B = (s) => `\x1b[1m${s}\x1b[0m`;
  const confLabel = opts.confidence === "inferred_only" ? "[只查待确认] " : "";

  console.log(B(`▶ qey verify ${confLabel}(记忆保鲜检测)`));
  console.log(`  ${B("扫描")}:domain/ + specs/ + knowledge/`);
  if (skipped.length) console.log(`  ${G(`✓ ${skipped.length} 条跳过(噪声/observed)`)}`);
  console.log("");

  if (stale.length === 0) {
    console.log(`  ${G("✓ 无过期知识")}(${verified.length} 锚点已验证)`);
    return 0;
  }

  console.log(`  ${Y(`⚠ ${stale.length} 条疑似过期`)}:`);
  for (const s of stale) {
    const conf = s.confidence ? ` [${s.confidence}]` : "";
    console.log(`    ${Y(s.type === "symbol" ? "符号" : "路径")} ${s.file}:${s.line}${conf}`);
    console.log(`      ${s.reason}`);
  }
  console.log("");
  console.log(`  ${G(`✓ ${verified.length} 锚点正常`)}`);
  console.log(`  → 用 /qey:distill 处理过期项(MODIFY/REMOVE)`);
  return 1;
}
