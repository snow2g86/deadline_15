// DEADLINE 15 결제 확인 서버 — Cloudflare Workers (ES 모듈) + D1. 약속: docs/server/api.md
import type { Env } from "./env";
import { handle } from "./app";
import { runCron } from "./cron";

export default {
  async fetch(req, env): Promise<Response> {
    return handle(req, env, { fetch: (input, init) => fetch(input, init) });
  },
  async scheduled(_controller, env, ctx): Promise<void> {
    ctx.waitUntil(runCron(env, { fetch: (input, init) => fetch(input, init) }, Date.now()));
  },
} satisfies ExportedHandler<Env>;
