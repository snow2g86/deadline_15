// 아주 작은 DER(ASN.1) 읽개 — X.509 인증서에서 필요한 부분만 꺼냄
export interface Tlv {
  tag: number;
  /** TLV 전체 (머리 포함) */
  raw: Uint8Array;
  /** 값 부분 */
  value: Uint8Array;
}

export function readTlv(buf: Uint8Array, off = 0): Tlv & { end: number } {
  if (off + 2 > buf.length) throw new Error("der: short");
  const tag = buf[off]!;
  if ((tag & 0x1f) === 0x1f) throw new Error("der: high tag");
  let len = buf[off + 1]!;
  let p = off + 2;
  if (len & 0x80) {
    const n = len & 0x7f;
    if (n === 0 || n > 4) throw new Error("der: bad length");
    len = 0;
    for (let i = 0; i < n; i++) len = len * 256 + buf[p + i]!;
    p += n;
  }
  const end = p + len;
  if (end > buf.length) throw new Error("der: overflow");
  return { tag, raw: buf.subarray(off, end), value: buf.subarray(p, end), end };
}

export function children(t: Tlv): Tlv[] {
  const out: Tlv[] = [];
  let o = 0;
  while (o < t.value.length) {
    const c = readTlv(t.value, o);
    out.push(c);
    o = c.end;
  }
  return out;
}

export function oid(t: Tlv): string {
  if (t.tag !== 0x06) throw new Error("der: not OID");
  const v = t.value;
  const parts: number[] = [];
  let n = 0;
  for (let i = 0; i < v.length; i++) {
    n = n * 128 + (v[i]! & 0x7f);
    if (!(v[i]! & 0x80)) {
      if (parts.length === 0) {
        const a = n < 80 ? Math.floor(n / 40) : 2;
        parts.push(a, n - a * 40);
      } else parts.push(n);
      n = 0;
    }
  }
  return parts.join(".");
}

export function time(t: Tlv): number {
  const s = new TextDecoder().decode(t.value);
  let m: RegExpMatchArray | null;
  if (t.tag === 0x17 && (m = s.match(/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/))) {
    const yy = Number(m[1]);
    return Date.UTC(yy >= 50 ? 1900 + yy : 2000 + yy, Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6]));
  }
  if (t.tag === 0x18 && (m = s.match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/))) {
    return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6]));
  }
  throw new Error("der: bad time");
}

/** DER ECDSA 서명 SEQ{r, s} → WebCrypto 의 r||s (각 size 바이트) */
export function ecdsaDerToRaw(sig: Uint8Array, size: number): Uint8Array {
  const seq = readTlv(sig);
  if (seq.tag !== 0x30) throw new Error("der: bad ecdsa sig");
  const [r, s] = children(seq);
  if (!r || !s || r.tag !== 0x02 || s.tag !== 0x02) throw new Error("der: bad ecdsa sig");
  const out = new Uint8Array(size * 2);
  const put = (v: Uint8Array, at: number) => {
    let x = v;
    while (x.length > size && x[0] === 0) x = x.subarray(1);
    if (x.length > size) throw new Error("der: ecdsa int too long");
    out.set(x, at + size - x.length);
  };
  put(r.value, 0);
  put(s.value, size);
  return out;
}
