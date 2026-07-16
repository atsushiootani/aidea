#!/usr/bin/env node
// aidea-mcp: Aidea の Companion とファイルベース backchannel (inbox / rpc) で通信する
// stdio 型 MCP サーバ。Aidea の内部 API には触らず、ファイルの読み書きだけで完結する。
// docs/specs/backchannels/rpc.md / ADR 0040

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";

// ---- 引数 ----------------------------------------------------------------

function parseArgs(argv) {
  const i = argv.indexOf("--workspace");
  if (i === -1 || !argv[i + 1]) {
    console.error("usage: aidea-mcp --workspace <path-to-workspace-root>");
    process.exit(1);
  }
  return { workspace: path.resolve(argv[i + 1]) };
}

const { workspace } = parseArgs(process.argv.slice(2));
const AIDEA_DIR = path.join(workspace, ".aidea");
const INBOX_DIR = path.join(AIDEA_DIR, "backchannels", "inbox");
const RPC_DIR = path.join(AIDEA_DIR, "backchannels", "rpc");
const WORKSPACE_JSON = path.join(AIDEA_DIR, "workspace.json");

// ---- ヘルパ ----------------------------------------------------------------

function timestamp() {
  const d = new Date();
  const p = (n, w = 2) => String(n).padStart(w, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}T${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

// 書き込み途中を FSEvents に拾わせないよう、一時ファイルに書いてから rename する
async function atomicWriteJSON(destDir, filename, obj) {
  await fsp.mkdir(destDir, { recursive: true });
  const tmp = path.join(os.tmpdir(), `aidea-mcp-${crypto.randomUUID()}.json`);
  await fsp.writeFile(tmp, JSON.stringify(obj), "utf8");
  const dest = path.join(destDir, filename);
  try {
    await fsp.rename(tmp, dest);
  } catch (e) {
    // /tmp とワークスペースが別ボリュームだと rename できないため copy + rename にフォールバック
    if (e.code === "EXDEV") {
      const tmp2 = path.join(destDir, `.${filename}.tmp`);
      await fsp.copyFile(tmp, tmp2);
      await fsp.rename(tmp2, dest);
      await fsp.unlink(tmp);
    } else {
      throw e;
    }
  }
  return dest;
}

// Companion の Write は原子的とは限らないため、サイズが安定するまで待ってから読む
async function readWhenStable(file, { pollMs = 200, stableReads = 2 } = {}) {
  let lastSize = -1;
  let stable = 0;
  for (;;) {
    let size;
    try {
      size = (await fsp.stat(file)).size;
    } catch {
      size = -1;
    }
    if (size > 0 && size === lastSize) {
      stable += 1;
      if (stable >= stableReads) return fsp.readFile(file, "utf8");
    } else {
      stable = 0;
    }
    lastSize = size;
    await new Promise((r) => setTimeout(r, pollMs));
  }
}

// res-<id>.txt の出現を待つ (ポーリング。fs.watch は rename 検知が環境依存のため使わない)
async function waitForResponse(id, timeoutSeconds) {
  const file = path.join(RPC_DIR, `res-${id}.txt`);
  const deadline = Date.now() + timeoutSeconds * 1000;
  while (Date.now() < deadline) {
    if (fs.existsSync(file)) {
      return readWhenStable(file);
    }
    await new Promise((r) => setTimeout(r, 300));
  }
  return null;
}

function newRequestId() {
  return `${timestamp()}-${crypto.randomBytes(3).toString("hex")}`;
}

async function readCompanions() {
  const raw = await fsp.readFile(WORKSPACE_JSON, "utf8");
  const json = JSON.parse(raw);
  return (json.companions ?? []).map((c) => ({ index: c.index, name: c.name }));
}

const TIMEOUT_HINT =
  "返事が来ませんでした。Aidea アプリが起動しているか、宛先の Companion 名が正しいかを確認してください。" +
  "長い作業の場合は send_to_companion + get_reply を使ってください。";

// ---- MCP サーバ ------------------------------------------------------------

const server = new McpServer({ name: "aidea-mcp", version: "0.1.0" });

server.registerTool(
  "list_companions",
  {
    description: "Aidea ワークスペースの Companion 一覧 (index と名前) を返す",
    inputSchema: {},
  },
  async () => {
    const companions = await readCompanions();
    return { content: [{ type: "text", text: JSON.stringify(companions, null, 2) }] };
  },
);

server.registerTool(
  "send_to_companion",
  {
    description:
      "Companion にメッセージを投げっぱなしで送る (返事は受け取らない)。返事が必要なら ask_companion を使う",
    inputSchema: {
      to: z.union([z.number().int(), z.string()]).describe("宛先 Companion の index (0..8) または名前"),
      message: z.string().min(1).describe("Companion に送るプロンプト本文"),
    },
  },
  async ({ to, message }) => {
    const dest = await atomicWriteJSON(INBOX_DIR, `handoff-${timestamp()}.json`, { to, message });
    return { content: [{ type: "text", text: `送信しました: ${dest} (Aidea が起動していれば配送されます)` }] };
  },
);

server.registerTool(
  "ask_companion",
  {
    description:
      "Companion に質問して返事を待つ (同期)。デフォルトタイムアウト 20 秒。長い作業は send_to_companion か、この結果が未着だったとき get_reply で再取得する",
    inputSchema: {
      to: z.union([z.number().int(), z.string()]).describe("宛先 Companion の index (0..8) または名前"),
      message: z.string().min(1).describe("Companion に送るプロンプト本文"),
      timeout: z.number().positive().optional().describe("返事を待つ秒数 (デフォルト 20)"),
    },
  },
  async ({ to, message, timeout }) => {
    const id = newRequestId();
    await atomicWriteJSON(RPC_DIR, `req-${id}.json`, { to, message });
    const reply = await waitForResponse(id, timeout ?? 20);
    if (reply === null) {
      return {
        isError: true,
        content: [{ type: "text", text: `request_id=${id}: ${TIMEOUT_HINT} (get_reply("${id}") で後から取得できます)` }],
      };
    }
    return { content: [{ type: "text", text: reply }] };
  },
);

server.registerTool(
  "get_reply",
  {
    description: "ask_companion がタイムアウトしたリクエストの返事を後から取得する",
    inputSchema: {
      request_id: z.string().min(1).describe("ask_companion が返した request_id"),
    },
  },
  async ({ request_id }) => {
    const file = path.join(RPC_DIR, `res-${request_id}.txt`);
    if (!fs.existsSync(file)) {
      return {
        isError: true,
        content: [{ type: "text", text: `まだ返事がありません: ${request_id}` }],
      };
    }
    const reply = await readWhenStable(file);
    return { content: [{ type: "text", text: reply }] };
  },
);

// ---- 起動 ------------------------------------------------------------------

if (!fs.existsSync(AIDEA_DIR)) {
  console.error(`warning: ${AIDEA_DIR} が見つかりません。--workspace のパスを確認してください`);
}

await server.connect(new StdioServerTransport());
