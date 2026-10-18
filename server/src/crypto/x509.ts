// X.509 인증서 (ECDSA) — Apple JWS 의 x5c 사슬 확인용
import { children, ecdsaDerToRaw, oid, readTlv, time, type Tlv } from "./der";

export interface Cert {
  der: Uint8Array;
  tbs: Uint8Array;
  sigAlg: string;
  signature: Uint8Array;
  issuer: Uint8Array;
  subject: Uint8Array;
  notBefore: number;
  notAfter: number;
  spki: Uint8Array;
  curve: string;
  extensions: Set<string>;
  isCA: boolean;
}

const OID_EC_PUBLIC_KEY = "1.2.840.10045.2.1";
const CURVES: Record<string, { name: string; size: number }> = {
  "1.2.840.10045.3.1.7": { name: "P-256", size: 32 },
  "1.3.132.0.34": { name: "P-384", size: 48 },
};
const SIG_HASH: Record<string, string> = {
  "1.2.840.10045.4.3.2": "SHA-256",
  "1.2.840.10045.4.3.3": "SHA-384",
};
const OID_BASIC_CONSTRAINTS = "2.5.29.19";

export function parseCert(der: Uint8Array): Cert {
  const top = readTlv(der);
  if (top.tag !== 0x30 || top.end !== der.length) throw new Error("x509: not a certificate");
  const [tbsT, algT, sigT] = children(top);
  if (!tbsT || !algT || !sigT || sigT.tag !== 0x03) throw new Error("x509: bad certificate");
  const tbs = children(tbsT);
  let i = 0;
  if (tbs[0]?.tag === 0xa0) i++; // version
  i++; // serial
  i++; // signature alg (inside tbs)
  const issuer = tbs[i++]!;
  const validity = children(tbs[i++]!);
  const subject = tbs[i++]!;
  const spkiT = tbs[i++]!;
  const extensions = new Set<string>();
  let isCA = false;
  for (; i < tbs.length; i++) {
    const t = tbs[i]!;
    if (t.tag !== 0xa3) continue;
    for (const ext of children(children(t)[0]!)) {
      const parts = children(ext);
      const id = oid(parts[0]!);
      extensions.add(id);
      if (id === OID_BASIC_CONSTRAINTS) {
        const octet = parts[parts.length - 1]!;
        const bc = children(readTlv(octet.value));
        isCA = bc[0]?.tag === 0x01 && bc[0].value[0] !== 0;
      }
    }
  }
  const spkiParts = children(spkiT);
  const keyAlg = children(spkiParts[0]!);
  if (oid(keyAlg[0]!) !== OID_EC_PUBLIC_KEY) throw new Error("x509: not an EC key");
  const curve = oid(keyAlg[1]!);
  const sigBits = sigT.value;
  if (sigBits[0] !== 0) throw new Error("x509: bad signature bits");
  return {
    der,
    tbs: tbsT.raw,
    sigAlg: oid(children(algT)[0]!),
    signature: sigBits.subarray(1),
    issuer: issuer.raw,
    subject: subject.raw,
    notBefore: time(validity[0]!),
    notAfter: time(validity[1]!),
    spki: spkiT.raw,
    curve,
    extensions,
    isCA,
  };
}

export function curveOf(c: Cert): { name: string; size: number } {
  const cv = CURVES[c.curve];
  if (!cv) throw new Error("x509: unsupported curve");
  return cv;
}

export async function publicKey(c: Cert): Promise<CryptoKey> {
  return crypto.subtle.importKey("spki", c.spki, { name: "ECDSA", namedCurve: curveOf(c).name }, false, ["verify"]);
}

function sameBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

/** child 가 parent 의 키로 서명됐는가 (이름 사슬 · ECDSA 서명) */
export async function signedBy(child: Cert, parent: Cert): Promise<boolean> {
  if (!sameBytes(child.issuer, parent.subject)) return false;
  const hash = SIG_HASH[child.sigAlg];
  if (!hash) return false;
  const raw = ecdsaDerToRaw(child.signature, curveOf(parent).size);
  return crypto.subtle.verify({ name: "ECDSA", hash }, await publicKey(parent), raw, child.tbs);
}

export type { Tlv };
