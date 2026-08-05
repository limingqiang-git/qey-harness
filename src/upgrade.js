// 2.0 update:从 npm 包内模板同步 overwrite 文件到项目。
// 不再是 1.x 的链式 migration(那是老版本包袱,2.0 不管老项目)。
// 以后 2.x 若需数据迁移,在 .qey/migrations/ 加脚本,discoverMigrations 自动发现。
import { existsSync, readdirSync, readFileSync, copyFileSync, mkdirSync, statSync } from "node:fs";
import { resolve, join, dirname } from "node:path";
import { getProjectVersion, getTemplateVersion } from "./template.js";

function cmpVer(a, b) {
  const pa = a.split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => parseInt(n, 10) || 0);
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    if ((pa[i] || 0) < (pb[i] || 0)) return -1;
    if ((pa[i] || 0) > (pb[i] || 0)) return 1;
  }
  return 0;
}

// 读 manifest overwrite 清单
function loadOverwrite(root) {
  const f = resolve(root, ".qey/manifest.json");
  if (!existsSync(f)) return [];
  try {
    const m = JSON.parse(readFileSync(f, "utf8"));
    return (m.file_classes && m.file_classes.overwrite) || [];
  } catch {
    return [];
  }
}

// 递归复制(文件或目录)
function copyRecursive(src, dst) {
  if (!existsSync(src)) return;
  const st = statSync(src);
  if (st.isFile()) {
    mkdirSync(dirname(dst), { recursive: true });
    copyFileSync(src, dst);
    return;
  }
  for (const e of readdirSync(src)) {
    copyRecursive(join(src, e), join(dst, e));
  }
}

// 2.0 同步:从模板把 overwrite 文件同步到项目(覆盖),diff_only 不碰
export function syncTemplate(root, projectDir = process.cwd(), opts = {}) {
  const list = loadOverwrite(root);
  let synced = 0;
  const detail = [];
  for (const entry of list) {
    // 只同步 .qey/** 和 adapters/**(模板根直接有的)
    if (!entry.startsWith(".qey") && entry !== "adapters") continue;
    const src = resolve(root, entry);
    if (!existsSync(src)) continue;
    const dst = resolve(projectDir, entry);
    if (opts.dryRun) {
      detail.push(entry);
      continue;
    }
    copyRecursive(src, dst);
    synced++;
  }
  return { synced, detail };
}

// 主入口:检查版本 + 同步
export function runUpdate(root, opts = {}) {
  const projectVersion = getProjectVersion(process.cwd());
  const templateVersion = getTemplateVersion(root);
  if (!projectVersion) {
    return { ok: false, reason: "no-project" };
  }
  const behind = templateVersion && cmpVer(projectVersion, templateVersion) < 0;
  const { synced, detail } = syncTemplate(root, process.cwd(), opts);
  // 更新项目版本号
  if (!opts.dryRun && templateVersion && behind) {
    const vf = resolve(process.cwd(), ".qey/version");
    if (existsSync(vf)) {
      copyFileSync(resolve(root, ".qey/version"), vf);
    }
  }
  return { ok: true, synced, detail, behind, projectVersion, templateVersion };
}

// 预留:数据驱动 migration(2.x 若需要)
export function discoverMigrations(root) {
  const dir = resolve(root, ".qey/migrations");
  if (!existsSync(dir)) return [];
  const re = /^upgrade-(\d+\.\d+(?:\.\d+)?)\-to\-(\d+\.\d+(?:\.\d+)?)\.sh$/;
  return readdirSync(dir)
    .filter((f) => re.test(f))
    .map((f) => {
      const m = f.match(re);
      return { from: m[1], to: m[2], file: join(dir, f) };
    })
    .sort((a, b) => cmpVer(a.from, b.from));
}
