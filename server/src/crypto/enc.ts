// 글 ↔ 바이트 바꾸기 · 해시 (WebCrypto)
const te = new TextEncoder();

export function utf8(s: string): Uint8Array {
  return te.encode(s);
}

export function hex(b: ArrayBuffer | Uint8Array): string {
  const u = b instanceof Uint8Array ? b : new Uint8Array(b);
  let s = "";
  for (const x of u) s += x.toString(16).padStart(2, "0");
  return s;
}

export function b64decode(s: string): Uint8Array {
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function b64encode(b: Uint8Array): string {
  let s = "";
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s);
}

export function b64urlEncode(b: Uint8Array | string): string {
  const u = typeof b === "string" ? utf8(b) : b;
  return b64encode(u).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function b64urlDecode(s: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]*$/.test(s)) throw new Error("bad base64url");
  const p = s.replace(/-/g, "+").replace(/_/g, "/");
  return b64decode(p + "=".repeat((4 - (p.length % 4)) % 4));
}

export async function sha256Hex(data: string | Uint8Array): Promise<string> {
  const u = typeof data === "string" ? utf8(data) : data;
  return hex(await crypto.subtle.digest("SHA-256", u));
}

export async function hmacSha256Hex(key: string, msg: string): Promise<string> {
  const k = await crypto.subtle.importKey("raw", utf8(key), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", k, utf8(msg)));
}

/** 같은 길이의 글을 시간 차 없이 비교 */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

/** PEM → DER */
export function pemToDer(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN [^-]+-----/g, "").replace(/-----END [^-]+-----/g, "").replace(/\\n/g, "").replace(/\s+/g, "");
  return b64decode(body);
}
