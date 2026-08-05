// 模板根定位:env > 包根(src/ 的父目录)
// npm 包发布后,模板内容(.qey/ + adapters/)就在包根下。
// 兼容:git clone 用户也可设 QEY_TEMPLATE 指向 clone 目录。
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export function getTemplateRoot() {
  const env = process.env.QEY_TEMPLATE;
  if (env && existsSync(resolve(env, ".qey"))) return resolve(env);
  const pkgRoot = resolve(__dirname, "..");
  if (existsSync(resolve(pkgRoot, ".qey"))) return pkgRoot;
  return null;
}

export function requireTemplateRoot() {
  const root = getTemplateRoot();
  if (!root) {
    console.error(
      "\x1b[31m✗ 找不到模板根(.qey/)。\x1b[0m\n" +
        "  设环境变量:export QEY_TEMPLATE=/path/to/qey-harness\n" +
        "  或确认 npm 包完整(bin/ 的父目录下应有 .qey/)"
    );
    process.exit(2);
  }
  return root;
}

function readVersionFile(f) {
  if (!existsSync(f)) return null;
  try {
    const raw = readFileSync(f, "utf8");
    // 2.0+ 读 "version";兼容 1.x 的 "schema_version"
    const m = raw.match(/"version"\s*:\s*"([^"]*)"/) ||
              raw.match(/"schema_version"\s*:\s*"([^"]*)"/);
    return m ? m[1] : null;
  } catch {
    return null;
  }
}

export function getProjectVersion(cwd = process.cwd()) {
  return readVersionFile(resolve(cwd, ".qey/version"));
}

export function getTemplateVersion(root) {
  return readVersionFile(resolve(root, ".qey/version"));
}
