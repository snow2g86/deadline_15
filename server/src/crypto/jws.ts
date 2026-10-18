// Apple 이 서명한 JWS (StoreKit 2 signedTransaction · App Store Server Notifications V2 signedPayload) 확인
//  머리의 x5c 사슬 [잎, 중간, 루트] 을 Apple Root CA - G3 (SHA-256 고정값) 까지 확인하고, 잎의 키로 ES256 서명을 확인.
//  Apple 확장 OID: 잎 1.2.840.113635.100.6.11.1 · 중간 1.2.840.113635.100.6.2.1
//  (참고: Apple app-store-server-library 의 SignedDataVerifier 와 같은 확인 — 온라인 OCSP 확인은 하지 않음)
import { b64decode, b64urlDecode, hex, utf8 } from "./enc";
import { parseCert, publicKey, signedBy, type Cert } from "./x509";

export const OID_APPLE_LEAF = "1.2.840.113635.100.6.11.1";
export const OID_APPLE_INTERMEDIATE = "1.2.840.113635.100.6.2.1";

export class JwsError extends Error {}

export interface JwsOptions {
  /** Apple Root CA - G3 의 SHA-256 (16진수, 콜론 없이) */
  rootSha256: string;
  /** 인증서 유효 기간을 볼 시각 (ms) — 없으면 페이로드 signedDate, 그것도 없으면 now */
  now: number;
}

export async function verifyAppleJws(jws: string, opt: JwsOptions): Promise<Record<string, unknown>> {
  if (typeof jws !== "string" || jws.length > 16384) throw new JwsError("bad jws");
  const parts = jws.split(".");
  if (parts.length !== 3) throw new JwsError("bad jws");
  const [h, p, s] = parts as [string, string, string];
  let header: { alg?: unknown; x5c?: unknown };
  let payload: Record<string, unknown>;
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlDecode(h)));
    payload = JSON.parse(new TextDecoder().decode(b64urlDecode(p)));
  } catch {
    throw new JwsError("bad jws json");
  }
  if (header.alg !== "ES256") throw new JwsError("alg must be ES256");
  if (!Array.isArray(header.x5c) || header.x5c.length !== 3 || !header.x5c.every((x) => typeof x === "string")) throw new JwsError("x5c must have 3 certificates");
  let chain: Cert[];
  try {
    chain = (header.x5c as string[]).map((x) => parseCert(b64decode(x)));
  } catch {
    throw new JwsError("bad certificate");
  }
  const [leaf, mid, root] = chain as [Cert, Cert, Cert];
  const rootSha = hex(await crypto.subtle.digest("SHA-256", root.der));
  if (rootSha !== opt.rootSha256.toLowerCase().replace(/[^0-9a-f]/g, "")) throw new JwsError("root is not Apple Root CA - G3");
  if (!mid.extensions.has(OID_APPLE_INTERMEDIATE) || !mid.isCA) throw new JwsError("intermediate is not Apple WWDR");
  if (!leaf.extensions.has(OID_APPLE_LEAF)) throw new JwsError("leaf is not an App Store signing certificate");
  const at = typeof payload.signedDate === "number" ? payload.signedDate : opt.now;
  for (const c of chain) if (at < c.notBefore || at > c.notAfter) throw new JwsError("certificate not valid at signedDate");
  if (!(await signedBy(mid, root)) || !(await signedBy(leaf, mid))) throw new JwsError("certificate chain signature failed");
  let sig: Uint8Array;
  try {
    sig = b64urlDecode(s);
  } catch {
    throw new JwsError("bad signature");
  }
  if (sig.length !== 64) throw new JwsError("bad signature");
  const good = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, await publicKey(leaf), sig, utf8(`${h}.${p}`));
  if (!good) throw new JwsError("signature failed");
  return payload;
}
