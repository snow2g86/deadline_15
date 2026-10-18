// 시험 도우미 — 요청 보내기 · 가짜 영수증 · 시험용 Apple 인증서 사슬 · Google 서비스 계정 · fetch 흉내
import { env as baseEnv } from "cloudflare:test";
import { handle } from "../src/app";
import type { Deps, Env } from "../src/env";
import { b64encode, b64urlDecode, b64urlEncode, hex, utf8 } from "../src/crypto/enc";
import { fakeSig } from "../src/stores/dev";

export const T0 = Date.UTC(2026, 9, 18, 0, 0, 0);
export const IID_A = "a".repeat(32);
export const IID_B = "b".repeat(32);
export const IID_C = "c".repeat(32);

export function mkEnv(over: Partial<Env> = {}): Env {
  return { ...(baseEnv as unknown as Env), ...over };
}

export interface Clock {
  t: number;
}

export type FetchFn = Deps["fetch"];

export interface CallOpts {
  iid?: string | null;
  body?: unknown;
  rawBody?: string;
  query?: Record<string, string>;
  host?: string;
  headers?: Record<string, string>;
  clock?: Clock;
  fetch?: FetchFn;
}

export async function call(env: Env, method: string, path: string, o: CallOpts = {}): Promise<{ status: number; body: any; headers: Headers }> {
  const q = o.query ? "?" + new URLSearchParams(o.query).toString() : "";
  const headers: Record<string, string> = { ...(o.headers ?? {}) };
  if (o.iid !== null) headers["X-D15-Install"] = o.iid ?? IID_A;
  let body: string | undefined;
  if (o.rawBody !== undefined) body = o.rawBody;
  else if (o.body !== undefined) body = JSON.stringify(o.body);
  if (body !== undefined && !Object.keys(headers).some((k) => k.toLowerCase() === "content-type")) headers["Content-Type"] = "application/json";
  const req = new Request(`http://${o.host ?? "127.0.0.1:8951"}${path}${q}`, { method, headers, body });
  const clock = o.clock;
  const deps: Deps = {
    fetch: o.fetch ?? (async () => {
      throw new Error("no network in tests");
    }),
    clock: clock ? () => clock.t : undefined,
  };
  const res = await handle(req, env, deps);
  const text = await res.text();
  let parsed: unknown = null;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = text;
  }
  return { status: res.status, body: parsed, headers: res.headers };
}

export async function resetDb(env: Env): Promise<void> {
  await env.DB.batch(["orders", "refunds", "cursors", "dev_ledger", "dev_meta", "purged_orders"].map((t) => env.DB.prepare(`DELETE FROM ${t}`)));
  await env.DB.prepare("DELETE FROM sqlite_sequence WHERE name = 'refunds'").run();
}

// ── 가짜 가게 (Godot backend_fake.gd 와 같은 영수증) ──

export interface LedgerOrder {
  pid: string;
  spid: string;
  acct?: string;
  state?: string;
  finished?: boolean;
  refunded?: boolean;
  refund_seq?: number;
  refunded_at?: number;
  at?: number;
}

export async function fakeReceipt(oid: string, spid: string, acct: string, signer = "dev-fake-store"): Promise<string> {
  return JSON.stringify({ oid, spid, acct, sig: await fakeSig(signer, oid, spid, acct) });
}

export async function putLedger(env: Env, orders: Record<string, LedgerOrder>): Promise<void> {
  const full: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(orders)) full[k] = { acct: "", state: "purchased", finished: false, at: T0 - 1000, ...v };
  const r = await call(env, "PUT", "/v1/dev/ledger", { iid: null, body: { orders: full } });
  if (r.status !== 200) throw new Error("ledger put failed " + JSON.stringify(r.body));
}

export async function devVerifyBody(oid: string, pid = "gold_1200", acct = "acct-a", over: Record<string, unknown> = {}): Promise<Record<string, unknown>> {
  return { store: "dev", product_id: pid, store_product_id: pid, order_id: oid, receipt: await fakeReceipt(oid, pid, acct), env: "dev", ...over };
}

// ── 시험용 DER 쓰개 (인증서 만들기) ──

function len(n: number): number[] {
  if (n < 0x80) return [n];
  const b: number[] = [];
  while (n > 0) {
    b.unshift(n & 0xff);
    n >>= 8;
  }
  return [0x80 | b.length, ...b];
}

export function tlv(tag: number, ...parts: (Uint8Array | number[])[]): Uint8Array {
  const body = concat(...parts.map((p) => (p instanceof Uint8Array ? p : new Uint8Array(p))));
  return concat(new Uint8Array([tag, ...len(body.length)]), body);
}

export function concat(...a: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(a.reduce((n, x) => n + x.length, 0));
  let o = 0;
  for (const x of a) {
    out.set(x, o);
    o += x.length;
  }
  return out;
}

export function oidDer(s: string): Uint8Array {
  const p = s.split(".").map(Number);
  const out: number[] = [p[0]! * 40 + p[1]!];
  for (const n of p.slice(2)) {
    const b: number[] = [n & 0x7f];
    let x = Math.floor(n / 128);
    while (x > 0) {
      b.unshift((x & 0x7f) | 0x80);
      x = Math.floor(x / 128);
    }
    out.push(...b);
  }
  return tlv(0x06, out);
}

const seq = (...p: Uint8Array[]) => tlv(0x30, ...p);
const gtime = (ms: number) => {
  const d = new Date(ms);
  const z = (n: number, w = 2) => String(n).padStart(w, "0");
  return tlv(0x18, [...utf8(`${z(d.getUTCFullYear(), 4)}${z(d.getUTCMonth() + 1)}${z(d.getUTCDate())}${z(d.getUTCHours())}${z(d.getUTCMinutes())}${z(d.getUTCSeconds())}Z`)]);
};
const name = (cn: string) => seq(tlv(0x31, seq(oidDer("2.5.4.3"), tlv(0x0c, [...utf8(cn)]))));

function rawToDerSig(raw: Uint8Array): Uint8Array {
  const half = raw.length / 2;
  const int = (b: Uint8Array) => {
    let x = b;
    while (x.length > 1 && x[0] === 0) x = x.subarray(1);
    if (x[0]! & 0x80) x = concat(new Uint8Array([0]), x);
    return tlv(0x02, x);
  };
  return seq(int(raw.subarray(0, half)), int(raw.subarray(half)));
}

export interface TestCa {
  key: CryptoKeyPair;
  der: Uint8Array;
  cn: string;
  curve: "P-256" | "P-384";
}

export async function mkCert(o: { cn: string; issuer?: TestCa; curve?: "P-256" | "P-384"; ca?: boolean; exts?: string[]; notBefore?: number; notAfter?: number }): Promise<TestCa> {
  const curve = o.curve ?? "P-256";
  const key = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: curve }, true, ["sign", "verify"])) as CryptoKeyPair;
  const spki = new Uint8Array((await crypto.subtle.exportKey("spki", key.publicKey)) as ArrayBuffer);
  const signer = o.issuer ?? { key, cn: o.cn, curve, der: new Uint8Array() };
  const hash = signer.curve === "P-384" ? "SHA-384" : "SHA-256";
  const sigOid = hash === "SHA-384" ? "1.2.840.10045.4.3.3" : "1.2.840.10045.4.3.2";
  const exts: Uint8Array[] = [];
  if (o.ca) exts.push(seq(oidDer("2.5.29.19"), tlv(0x01, [0xff]), tlv(0x04, seq(tlv(0x01, [0xff])))));
  for (const e of o.exts ?? []) exts.push(seq(oidDer(e), tlv(0x04, [0x05, 0x00])));
  const tbs = seq(
    tlv(0xa0, tlv(0x02, [2])),
    tlv(0x02, [1, 2, 3]),
    seq(oidDer(sigOid)),
    name(signer.cn),
    seq(gtime(o.notBefore ?? T0 - 365 * 86400000), gtime(o.notAfter ?? T0 + 3650 * 86400000)),
    name(o.cn),
    spki,
    ...(exts.length ? [tlv(0xa3, seq(...exts))] : []),
  );
  const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash }, signer.key.privateKey, tbs));
  const der = seq(tbs, seq(oidDer(sigOid)), tlv(0x03, concat(new Uint8Array([0]), rawToDerSig(raw))));
  return { key, der, cn: o.cn, curve };
}

export interface AppleChain {
  root: TestCa;
  mid: TestCa;
  leaf: TestCa;
  rootSha: string;
}

export async function mkAppleChain(o: { leafExt?: boolean; midExt?: boolean; root?: TestCa } = {}): Promise<AppleChain> {
  const root = o.root ?? (await mkCert({ cn: "Test Apple Root CA - G3", curve: "P-384", ca: true }));
  const mid = await mkCert({ cn: "Test Apple WWDR G6", issuer: root, curve: "P-384", ca: true, exts: o.midExt === false ? [] : ["1.2.840.113635.100.6.2.1"] });
  const leaf = await mkCert({ cn: "Test Prod ECC Mac App Store", issuer: mid, curve: "P-256", exts: o.leafExt === false ? [] : ["1.2.840.113635.100.6.11.1"] });
  return { root, mid, leaf, rootSha: hex(await crypto.subtle.digest("SHA-256", root.der)) };
}

export async function signJws(chain: AppleChain, payload: Record<string, unknown>, signWith?: CryptoKey): Promise<string> {
  const h = b64urlEncode(JSON.stringify({ alg: "ES256", x5c: [chain.leaf.der, chain.mid.der, chain.root.der].map((d) => b64encode(d)) }));
  const p = b64urlEncode(JSON.stringify(payload));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, signWith ?? chain.leaf.key.privateKey, utf8(`${h}.${p}`)));
  return `${h}.${p}.${b64urlEncode(sig)}`;
}

export async function pemPkcs8(key: CryptoKey): Promise<string> {
  const der = new Uint8Array((await crypto.subtle.exportKey("pkcs8", key)) as ArrayBuffer);
  return `-----BEGIN PRIVATE KEY-----\n${b64encode(der).replace(/(.{64})/g, "$1\n")}\n-----END PRIVATE KEY-----\n`;
}

export function decodeJwt(jwt: string): { header: any; payload: any; input: string; sig: Uint8Array } {
  const [h, p, s] = jwt.split(".") as [string, string, string];
  return { header: JSON.parse(new TextDecoder().decode(b64urlDecode(h))), payload: JSON.parse(new TextDecoder().decode(b64urlDecode(p))), input: `${h}.${p}`, sig: b64urlDecode(s) };
}

/** 바깥 HTTP 흉내: (url, init) → Response. 부른 기록을 남김 */
export function mockFetch(route: (url: URL, init: RequestInit | undefined) => Response | Promise<Response>): FetchFn & { calls: { url: string; init?: RequestInit }[] } {
  const calls: { url: string; init?: RequestInit }[] = [];
  const f = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const u = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
    calls.push({ url: u.href, init });
    return route(u, init);
  }) as FetchFn & { calls: typeof calls };
  f.calls = calls;
  return f;
}

export const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
