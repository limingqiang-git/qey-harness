// qey CLI 2.0 调度层(零依赖手写路由)
// 命令集:init | update | doctor | change | version | help
// 哲学:Node 做调度(路由/模板定位/同步/hash单源),bash 做引擎(文件操作/git/确定性执行)。
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { getTemplateRoot, requireTemplateRoot, getProjectVersion, getTemplateVersion } from "./template.js";
import { runUpdate } from "./upgrade.js";
import { checkDrift } from "./hashcheck.js";
import { printStaleReport, checkDiffImpact } from "./freshness.js";

const G = (s) => `\x1b[32m${s}\x1b[0m`;
const Y = (s) => `\x1b[33m${s}\x1b[0m`;
const R = (s) => `\x1b[31m${s}\x1b[0m`;
const B = (s) => `\x1b[1m${s}\x1b[0m`;

function needProject() {
  if (!existsSync(".qey")) {
    console.log(R("✗ 当前目录无 .qey/(在项目根跑,或先 qey init)"));
    process.exit(1);
  }
}
function runBash(script, args = []) {
  return spawnSync("bash", [script, ...args], {
    stdio: "inherit",
    env: { ...process.env, QEY_TEMPLATE: getTemplateRoot() },
  });
}

function usage() {
  const root = getTemplateRoot() || "(未知)";
  const tv = getTemplateVersion(root) || "?";
  console.log(`${B("qey — 项目级 AI 协作工程 CLI")} ${Y("v" + tv)}
  ${B("模板")}:${root}
  ${B("当前")}:${process.cwd()}

${B("快速开始:")}
  qey init [--adapter claude|codex|pi|all]   接入新项目(复制骨架 + 提示跑 /qey:scan)

${B("日常:")}
  qey update [--dry-run]                      同步最新模板文件到项目
  qey doctor                                  体检:版本/漂移/adapter/依赖
  qey status                                  变更总览(从 change 聚合 feature_list)
  qey verify [--inferred-only]                记忆保鲜检测(知识过期/符号失效)
  qey change new <id> [域]                    建变更骨架
  qey change list                             列所有变更 + 状态
  qey change archive <id>                     归档(验 evidence + merge delta + 移 archive)

${B("其他:")}
  qey version                                 查版本
  qey help                                    本帮助

${B("AI 命令(在 Claude/Codex/omp 里):")}
  /qey:scan [deep|drill X]                    扫描填充
  /qey:commit                                 提交 + 归档 + MR
  /qey:log                                    机械日志
  /qey:distill                                知识提炼

> ${B("新装")}:npx qey-harness init(模板随 npm 包,无需 clone)
> ${B("想短")}:alias qey='npx qey-harness'`);
}

// ── init:一站式接入(原 attach + 提示 scan)──
function cmdInit(adapterArgs) {
  const root = requireTemplateRoot();
  const r = runBash(resolve(root, ".qey/attach.sh"), adapterArgs);
  if ((r.status ?? 0) === 0) {
    console.log("");
    console.log(B("▶ 下一步:在 AI IDE 里跑扫描填充"));
    console.log("  /qey:scan              # quick 全景(技术栈/目录/架构/术语)");
    console.log("  /qey:scan deep         # 全景 + 数据 + 流程");
    console.log("  /qey:scan drill <模块>  # 深挖特定模块");
  }
  process.exit(r.status ?? 0);
}

// ── doctor:体检 ──
function cmdDoctor() {
  const root = requireTemplateRoot();
  const proj = existsSync(".qey");
  console.log(B("▶ qey doctor(体检)"));
  console.log(`  ${B("模板")}:${root} (${G(getTemplateVersion(root) || "?")})`);
  console.log(`  ${B("项目")}:${proj ? getProjectVersion() || "?" : Y("(未接入,跑 qey init)")}`);
  console.log("");

  if (!proj) return;

  // 版本
  const pv = getProjectVersion();
  const tv = getTemplateVersion(root);
  if (pv && tv) {
    const behind = cmpVerSimple(pv, tv) < 0;
    console.log(
      behind
        ? `  ${Y("⚠ 版本落后")}:${pv} → ${tv}(跑 qey update)`
        : `  ${G("✓ 版本最新")}:${pv}`
    );
  }

  // 漂移
  const { drifted, missing } = checkDrift(root);
  console.log(
    drifted.length || missing.length
      ? `  ${Y("⚠ 文件漂移")}:${drifted.length} 漂移, ${missing.length} 缺失(跑 qey update)`
      : `  ${G("✓ 无漂移")}`
  );

  // adapter
  const adapters = [];
  if (existsSync(".claude")) adapters.push("claude");
  if (existsSync(".codex")) adapters.push("codex");
  if (existsSync(".omp")) adapters.push("pi");
  if (existsSync(".agents")) adapters.push("agents");
  console.log(`  ${B("adapter")}:${adapters.join(", ") || Y("(无)")}`);
  if (existsSync(".qey/parity-check.sh")) {
    const r = spawnSync("bash", [".qey/parity-check.sh"], { stdio: "pipe" });
    console.log(r.status === 0 ? `  ${G("✓ parity 通过")}` : `  ${Y("⚠ parity 有问题")}`);
  }

  // 依赖
  console.log(B("  依赖:"));
  console.log(`    node:${process.version} ${G("✓")}`);
  const git = spawnSync("git", ["--version"], { stdio: "pipe" });
  console.log(git.status === 0 ? `    git:${G("✓")}` : `    git:${R("✗")}`);
}

function cmpVerSimple(a, b) {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    if ((pa[i] || 0) < (pb[i] || 0)) return -1;
    if ((pa[i] || 0) > (pb[i] || 0)) return 1;
  }
  return 0;
}

// ── 主路由 ──
const [cmd, ...rest] = process.argv.slice(2);

switch (cmd) {
  case undefined:
  case "help":
  case "-h":
  case "--help":
    usage();
    break;

  case "version":
  case "-v":
  case "--version":
    console.log(getTemplateVersion(getTemplateRoot()) || "未知");
    break;

  case "init":
    cmdInit(rest);
    break;

  case "update": {
    needProject();
    const root = requireTemplateRoot();
    const dryRun = rest.includes("--dry-run");
    const r = runUpdate(root, { dryRun });
    if (!r.ok && r.reason === "no-project") {
      console.log(R("✗ 当前目录无 .qey/(在项目根跑,或先 qey init)"));
      process.exit(1);
    }
    if (dryRun) {
      console.log(B("▶ qey update --dry-run(预览)"));
      console.log(`  将同步 ${r.detail.length} 个模板条目:`);
      r.detail.forEach((d) => console.log(`    ${d}`));
    } else {
      console.log(B("▶ qey update(同步模板)"));
      console.log(`  ${G(`✓ 同步 ${r.synced} 个模板条目`)}`);
      if (r.behind) console.log(`  ${G(`✓ 版本 ${r.projectVersion} → ${r.templateVersion}`)}`);
    }
    break;
  }

  case "doctor":
    cmdDoctor();
    break;

  case "verify": {
    needProject();
    const inferredOnly = rest.includes("--inferred-only") || rest.includes("-i");
    process.exit(printStaleReport(process.cwd(), { confidence: inferredOnly ? "inferred_only" : "all" }));
  }

  case "change": {
    needProject();
    // 适配:change new → change create(兼容 bash 脚本的 create 子命令)
    const args = rest[0] === "new" ? ["create", ...rest.slice(1)] : rest;
    if (existsSync(".qey/change.sh")) runBash(".qey/change.sh", args);
    else console.log(Y("缺 .qey/change.sh(跑 qey update 同步)"));
    break;
  }

  case "status": {
    needProject();
    const { readFileSync } = await import("node:fs");
    console.log(B("▶ Feature List(从 change 聚合)"));
    // 扫描进行中的 change
    const changesDir = resolve(process.cwd(), ".qey/changes");
    const archiveDir = resolve(changesDir, "archive");
    const rows = [];
    // 进行中
    if (existsSync(changesDir)) {
      for (const e of readdirSync(changesDir)) {
        if (e === "archive" || e.startsWith("_") || e.startsWith(".")) continue;
        const cj = resolve(changesDir, e, "change.json");
        if (!existsSync(cj)) continue;
        try {
          const j = JSON.parse(readFileSync(cj, "utf8"));
          rows.push({
            id: j.id || e, status: j.status || "?",
            priority: j.priority || "-", domain: j.domain || "-",
            title: (j.title || "").slice(0, 30), where: "进行中",
          });
        } catch { /* skip */ }
      }
    }
    // 归档
    if (existsSync(archiveDir)) {
      for (const e of readdirSync(archiveDir)) {
        const cj = resolve(archiveDir, e, "change.json");
        if (!existsSync(cj)) continue;
        try {
          const j = JSON.parse(readFileSync(cj, "utf8"));
          rows.push({
            id: j.id || e, status: j.status || "archived",
            priority: j.priority || "-", domain: j.domain || "-",
            title: (j.title || "").slice(0, 30), where: "📦",
          });
        } catch { /* skip */ }
      }
    }
    if (rows.length === 0) {
      console.log(Y("  (无 change,跑 qey change new <id> [域] 新建)"));
    } else {
      // 表格输出
      console.log(`  ${"ID".padEnd(24)} ${"STATUS".padEnd(14)} ${"PRI".padEnd(4)} ${"DOMAIN".padEnd(8)} ${"WHERE".padEnd(6)} TITLE`);
      for (const r of rows) {
        const mark = r.status === "in_progress" ? Y("🔄") : r.status === "archived" ? G("📦") : "  ";
        console.log(`  ${mark} ${(r.id || "").padEnd(22).slice(0,22)} ${(r.status||"").padEnd(14).slice(0,14)} ${String(r.priority).padEnd(4)} ${(r.domain||"").padEnd(8).slice(0,8)} ${(r.where||"").padEnd(6)} ${r.title}`);
      }
      const active = rows.filter(r => r.where === "进行中").length;
      console.log(`\n  ${G(`✓ ${rows.length} change`)}(${active} 进行中, ${rows.length - active} 归档)`);
    }
    // 漂移摘要
    console.log("");
    console.log(B("▶ 漂移"));
    const root = getTemplateRoot();
    if (root) {
      const { drifted, missing } = checkDrift(root);
      console.log(drifted.length || missing.length
        ? `  ${Y(`⚠ ${drifted.length} 漂移, ${missing.length} 缺失`)}` : `  ${G("✓ 无漂移")}`);
    }
    break;
  }

  default:
    console.log(R(`未知命令:${cmd}`));
    console.log("");
    usage();
    process.exit(1);
}
