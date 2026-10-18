// 서버가 가게 API 를 부를 때 쓰는 JWT 서명 (WebCrypto)
//  Google: 서비스 계정 RS256 → OAuth 2.0 토큰 · Apple: App Store Server API ES256 (.p8)
import { b64urlEncode, pemToDer, utf8 } from "./enc";

async function sign(alg: "RS256" | "ES256", key: CryptoKey, header: Record<string, unknown>, claims: Record<string, unknown>): Promise<string> {
  const input = `${b64urlEncode(JSON.stringify({ ...header, alg }))}.${b64urlEncode(JSON.stringify(claims))}`;
  const algo = alg === "RS256" ? { name: "RSASSA-PKCS1-v1_5" } : { name: "ECDSA", hash: "SHA-256" };
  const sig = new Uint8Array(await crypto.subtle.sign(algo, key, utf8(input)));
  return `${input}.${b64urlEncode(sig)}`;
}

export async function signRs256(pem: string, header: Record<string, unknown>, claims: Record<string, unknown>): Promise<string> {
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(pem), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  return sign("RS256", key, { typ: "JWT", ...header }, claims);
}

export async function signEs256(pem: string, header: Record<string, unknown>, claims: Record<string, unknown>): Promise<string> {
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(pem), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  return sign("ES256", key, { typ: "JWT", ...header }, claims);
}
