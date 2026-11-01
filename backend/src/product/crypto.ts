import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes, randomInt, scrypt, timingSafeEqual } from "node:crypto";

export const token = () => randomBytes(32).toString("base64url");
export const digest = (s: string) => createHash("sha256").update(s, "utf8").digest();
export function keyed(key: string, ...parts: string[]) { return createHmac("sha256", Buffer.from(key, "base64url")).update(JSON.stringify(parts)).digest(); }
export function normalizeMobile(input: unknown): string {
  if (typeof input !== "string" || input.length > 40) throw Error("INVALID_MOBILE");
  let s = input.replace(/[۰-۹]/g, c => String(c.charCodeAt(0) - 1776)).replace(/[٠-٩]/g, c => String(c.charCodeAt(0) - 1632)).replace(/[\s()-]/g, "");
  if (/^00989\d{9}$/.test(s)) s = "+" + s.slice(2);
  if (/^989\d{9}$/.test(s)) s = "+" + s;
  if (/^09\d{9}$/.test(s)) s = "+98" + s.slice(1);
  if (!/^\+989\d{9}$/.test(s)) throw Error("INVALID_MOBILE");
  return s;
}
export function seal(key: string, value: unknown, purpose: string): string {
  const iv = randomBytes(12), cipher = createCipheriv("aes-256-gcm", Buffer.from(key, "base64url"), iv);
  cipher.setAAD(Buffer.from(purpose));
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(value), "utf8"), cipher.final()]);
  return "v1." + [iv, cipher.getAuthTag(), encrypted].map(b => b.toString("base64url")).join(".");
}
export function unseal<T>(key: string, value: string, purpose: string): T {
  if (typeof value !== "string" || value.length > 100000) throw Error("INVALID_ENCRYPTED_VALUE");
  const [version, iv, tag, body, extra] = value.split(".");
  if (version !== "v1" || !iv || !tag || !body || extra) throw Error("INVALID_ENCRYPTED_VALUE");
  const decipher = createDecipheriv("aes-256-gcm", Buffer.from(key, "base64url"), Buffer.from(iv, "base64url"));
  decipher.setAAD(Buffer.from(purpose)); decipher.setAuthTag(Buffer.from(tag, "base64url"));
  return JSON.parse(Buffer.concat([decipher.update(Buffer.from(body, "base64url")), decipher.final()]).toString("utf8")) as T;
}
export const otp = () => String(randomInt(0, 1000000)).padStart(6, "0");
export async function passwordHash(password: string, salt = randomBytes(32).toString("hex")): Promise<string> {
  if (typeof password !== "string" || password.length < 12 || password.length > 128) throw Error("PASSWORD_REQUIREMENTS");
  const key = await new Promise<Buffer>((resolve, reject) => scrypt(password, Buffer.from(salt, "hex"), 64,
    { N: 65536, r: 8, p: 1, maxmem: 128 * 1024 * 1024 }, (e, k) => e ? reject(e) : resolve(k)));
  return "scrypt-v1$" + salt + "$" + key.toString("hex");
}
export async function passwordMatches(password: string, encoded: string): Promise<boolean> {
  const [version, salt, expected] = encoded.split("$");
  if (version !== "scrypt-v1" || !/^[a-f0-9]{64}$/.test(salt ?? "") || !/^[a-f0-9]{128}$/.test(expected ?? "") ||
      typeof password !== "string" || password.length > 128) return false;
  const padded = password.length < 12 ? password.padEnd(12, "\0") : password;
  const actual = (await passwordHash(padded, salt)).split("$")[2]!;
  return timingSafeEqual(Buffer.from(actual, "hex"), Buffer.from(expected!, "hex")) && password.length >= 12;
}
const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
export function base32(bytes: Buffer): string { let bits = 0, value = 0, out = ""; for (const byte of bytes) { value = (value << 8) | byte; bits += 8; while (bits >= 5) { out += alphabet[(value >>> (bits - 5)) & 31]; bits -= 5; } } if (bits) out += alphabet[(value << (5 - bits)) & 31]; return out; }
function decode32(s: string): Buffer { let bits = 0, value = 0; const out: number[] = []; for (const c of s) { const n = alphabet.indexOf(c); if (n < 0) throw Error("INVALID_TOTP_SECRET"); value = (value << 5) | n; bits += 5; if (bits >= 8) { out.push((value >>> (bits - 8)) & 255); bits -= 8; } } return Buffer.from(out); }
export function totp(secret: string, counter: bigint): string { const bytes = Buffer.alloc(8); bytes.writeBigUInt64BE(counter); const h = createHmac("sha1", decode32(secret)).update(bytes).digest(); const offset = h[19]! & 15; return String((h.readUInt32BE(offset) & 0x7fffffff) % 1000000).padStart(6, "0"); }
export function matchingTotpCounter(secret: string, code: string, now = Date.now()): bigint | null {
  if (!/^\d{6}$/.test(code)) return null;
  const current = BigInt(Math.floor(now / 30000));
  for (const offset of [0n, -1n, 1n]) { const c = current + offset; if (c >= 0n && timingSafeEqual(Buffer.from(totp(secret, c)), Buffer.from(code))) return c; }
  return null;
}
