#!/usr/bin/env node
// qey-harness CLI 入口
// 直接 import cli.js（ESM 顶层代码会在 import 时自动执行路由）
// 用 import.meta.url 确保相对路径在任何安装方式下都能解析

import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ESM: import 会执行 cli.js 的顶层代码（switch 路由）
// 路径相对于本文件:bin/qey.js → ../src/cli.js
await import("../src/cli.js");
