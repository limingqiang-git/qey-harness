// hashcheck:Node 重写 SHA256 漂移检测。读 manifest.json 的 file_classes.overwrite 作为单一真相源。
// 消灭 hash-check.sh 里 hardcoded OVERWRITE[] 数组(三处副本之一)。
// 模板就在包内,hash 现算(Node crypto),不预生成 JSON(按需计算,不预生成清单)。
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { resolve, join, relative } from "node:path";

// 读 manifest.json 的 overwrite 清单
function loadOverwriteList(root) {
  const f = resolve(root, ".qey/manifest.json");
  if (!existsSync(f)) return [];
  try {
    const m = JSON.parse(readFileSync(f, "utf8"));
    return (m.file_classes && m.file_classes.overwrite) || [];
  } catch {
    return [];
  }
}

function sha256(f) {
  return createHash("sha256").update(readFileSync(f)).digest("hex");
}

// 遍历路径(文件或目录)产出所有叶子文件相对路径
function walk(base, rel = "") {
  const full = rel ? join(base, rel) : base;
  if (!existsSync(full)) return [];
  const st = statSync(full);
  if (st.isFile()) return [rel || "."];
  return readdirSync(full).flatMap((e) => walk(base, rel ? `${rel}/${e}` : e));
}

// 主检测:返回 { drifted:[], missing:[], clean:N }
export function checkDrift(root, projectDir = process.cwd()) {
  const list = loadOverwriteList(root);
  // manifest 的 overwrite 里有 .claude/commands 等(adapter 副本路径),这些模板里在 adapters/ 下。
  // 但对 hashcheck 而言,我们只比"项目里实际存在的 overwrite 文件"vs"模板对应文件"。
  // 模板源路径映射:manifest 写的是项目内路径;模板源 = root + 路径(对 .qey/* 和 adapters/* 直接用);
  // .claude/.codex/ 等 adapter 副本,模板源在 adapters/ 下,跳过(由 parity-check 管)。
  const drift = [];
  const missing = [];
  let clean = 0;

  for (const entry of list) {
    // 只处理 .qey/** 和 adapters/**(模板根直接有的)
    if (!entry.startsWith(".qey")) continue;
    const srcBase = resolve(root, entry);
    if (!existsSync(srcBase)) continue;
    const files = walk(srcBase);
    for (const rel of files) {
      const srcFile = resolve(srcBase, rel === "." ? "" : rel);
      const dstRel = entry.endsWith("/") || existsSync(resolve(root, entry))
        ? `${entry}/${rel}`.replace(/\/\.$/, "")
        : entry;
      const dstFile = resolve(projectDir, dstRel);
      if (!existsSync(dstFile)) {
        missing.push(dstRel);
        continue;
      }
      try {
        if (sha256(srcFile) === sha256(dstFile)) clean++;
        else drift.push(dstRel);
      } catch {
        drift.push(dstRel);
      }
    }
  }
  return { drifted: drift, missing, clean };
}

// 打印结果,返回退出码(0=干净,1=有漂移)
export function printDriftReport(root, projectDir = process.cwd()) {
  const { drifted, missing, clean } = checkDrift(root, projectDir);
  const g = (s) => `\x1b[32m${s}\x1b[0m`;
  const y = (s) => `\x1b[33m${s}\x1b[0m`;
  console.log(`\x1b[1m▶ hash-check(项目 vs 模板,SHA256)\x1b[0m`);
  for (const f of drifted) console.log(`  ${y("≠ 漂移")} ${f}`);
  for (const f of missing) console.log(`  ${y("+ 缺失")} ${f}`);
  console.log(`  ${g(`✓ ${clean} 文件一致`)}`);
  if (drifted.length || missing.length) {
    console.log(
      `  ${y(`共 ${drifted.length} 漂移, ${missing.length} 缺失`)} → qey update 同步`
    );
    return 1;
  }
  console.log(`  ${g("✓ 无漂移")}`);
  return 0;
}
