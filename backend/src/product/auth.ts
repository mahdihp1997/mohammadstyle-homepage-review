import { Inject, Injectable, HttpException } from "@nestjs/common";
import { Pool } from "pg";
import { randomBytes, randomUUID } from "node:crypto";
import { productPoolOptions, type ProductConfig } from "./config.js";
import { base32, digest, keyed, matchingTotpCounter, normalizeMobile, otp, passwordHash, passwordMatches, seal, token, unseal } from "./crypto.js";

export const PRODUCT_CONFIG = Symbol("validated product configuration");
export interface AuthContext { binding: Buffer; peer: Buffer; device: string }
type Reply = Record<string, unknown>;
function reject(code: string, status = 422): never { throw new HttpException({ code }, status); }
export function fields(value: unknown, names: readonly string[]): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).sort().join(",") !== [...names].sort().join(",")) reject("INVALID_FIELDS");
  return value as Record<string, unknown>;
}
const text = (v: unknown, max: number) => { if (typeof v !== "string" || v.length > max) return reject("INVALID_FIELDS"); return v; };
const uuid = (v: unknown) => { const s = text(v, 36); if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(s)) reject("INVALID_FIELDS"); return s; };
function normalizeCode(v: unknown) { const s = text(v, 10).replace(/[۰-۹]/g, c => String(c.charCodeAt(0) - 1776)).replace(/[٠-٩]/g, c => String(c.charCodeAt(0) - 1632)); if (!/^\d{6}$/.test(s)) reject("INVALID_OTP", 401); return s; }
const functions = new Set(["product_auth_request", "product_auth_context", "product_auth_verify", "product_admin_lookup", "product_admin_grant", "product_admin_finish", "product_admin_activate", "product_recover", "product_sessions"]);

@Injectable()
export class ProductAuthService {
  private readonly pool: Pool;
  private dummyVerifier = "";
  private expensive = 0;
  constructor(@Inject(PRODUCT_CONFIG) readonly config: ProductConfig) {
    this.pool = new Pool(productPoolOptions(config.database, "ms_product_auth", config.authDatabasePassword));
    this.pool.on("error", () => {});
  }
  async onModuleInit() {
    const row = (await this.pool.query("SELECT current_user role,ms_b1_design.product_runtime_view() runtime,shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') marker")).rows[0];
    if (row.role !== "ms_product_auth" || row.marker !== this.config.database.marker || row.runtime?.environment !== this.config.environment || row.runtime?.businessId !== this.config.businessId || row.runtime?.origin !== this.config.origin || (this.config.environment !== "test" && Number(row.runtime?.testIdentities) !== 0))
      throw Error("Product authentication realm mismatch");
    this.dummyVerifier = await passwordHash(token());
  }
  async onModuleDestroy() { await this.pool.end(); }
  private async call(name: string, args: unknown[]): Promise<Reply | null> {
    if (!functions.has(name)) throw Error("Authentication entry point allowlist");
    return (await this.pool.query(`SELECT ms_b1_design.${name}(${args.map((_, i) => "$" + (i + 1)).join(",")}) r`, args)).rows[0].r as Reply | null;
  }
  private checked(value: Reply | null): Reply {
    if (!value) reject("INVALID_CREDENTIALS", 401);
    if (typeof value.code === "string") reject(value.code, value.code === "RATE_LIMITED" ? 429 : value.code === "USE_ADMIN_LOGIN" ? 409 : 401);
    return value;
  }
  private session(value: Reply, sessionToken: string, csrf: string): Reply {
    return value.authenticated === true ? { ...value, session: { token: sessionToken, csrf, maxAge: this.config.sessionSeconds } } : value;
  }
  private async kdf<T>(fn: () => Promise<T>): Promise<T> {
    if (this.expensive >= 2) reject("RATE_LIMITED", 429);
    this.expensive++; try { return await fn(); } finally { this.expensive--; }
  }
  async request(kind: "MOBILE_LOGIN" | "ADMIN_ACTIVATION" | "ADMIN_RECOVERY", value: unknown, ctx: AuthContext) {
    if (this.config.sms === "none") reject("SMS_UNCONFIGURED", 503);
    const body = fields(value, kind === "ADMIN_ACTIVATION" ? ["mobile", "invitation"] : ["mobile"]);
    let mobile: string; try { mobile = normalizeMobile(body.mobile); } catch { return reject("INVALID_MOBILE"); }
    const id = randomUUID(), code = otp(), lookup = keyed(this.config.identityKey, "mobile", mobile);
    const invitation = kind === "ADMIN_ACTIVATION" ? text(body.invitation, 100) : null;
    if (invitation && !/^[A-Za-z0-9_-]{43}$/.test(invitation)) reject("INVALID_ACTIVATION");
    const reply = this.checked(await this.call("product_auth_request", [id, kind, lookup, seal(this.config.encryptionKey, { mobile }, "mobile:" + lookup.toString("hex")), mobile.slice(-4),
      keyed(this.config.otpKey, "otp", id, lookup.toString("hex"), code), seal(this.config.encryptionKey, { mobile, code }, "otp:" + id), ctx.binding, ctx.peer, invitation ? digest(invitation) : null]));
    // Only expose the newly issued, browser-bound customer challenge in the
    // explicit isolated review realm. Existing/rate-limited/admin challenges
    // never acquire a code through this path. SQL verification remains required.
    return this.config.reviewOtpAutofill && kind === "MOBILE_LOGIN" && reply.challengeId === id
      ? { ...reply, testOtp: code } : reply;
  }
  async verify(value: unknown, ctx: AuthContext) {
    const body = fields(value, ["challengeId", "code"]), id = uuid(body.challengeId), code = normalizeCode(body.code);
    const prior = await this.call("product_auth_context", [id, ctx.binding]);
    const sessionToken = token(), csrf = token();
    const result = this.checked(await this.call("product_auth_verify", [id, ctx.binding,
      keyed(this.config.otpKey, "otp", id, typeof prior?.lookup === "string" ? prior.lookup : "", code), digest(sessionToken), digest(csrf), ctx.device, randomUUID()]));
    return this.session(result, sessionToken, csrf);
  }
  async adminLogin(value: unknown, ctx: AuthContext, enrollMfa = false) {
    const body = fields(value, ["username", "password"]), username = text(body.username, 64).toLowerCase(), password = text(body.password, 128);
    return this.kdf(async () => {
      const record = await this.call("product_admin_lookup", [username, ctx.peer, keyed(this.config.identityKey, "username", username)]);
      if (record?.code === "RATE_LIMITED") reject("RATE_LIMITED", 429);
      const valid = await passwordMatches(password, typeof record?.verifier === "string" ? record.verifier : this.dummyVerifier);
      if (!record || !valid) reject("INVALID_CREDENTIALS", 401);
      const sessionToken = token(), csrf = token();
      const recovery=Array.from({length:10},()=>randomBytes(16).toString('hex'));
      const result = this.checked(await this.call("product_admin_grant", [record.userId, record.version, ctx.binding, ctx.peer, randomUUID(), digest(sessionToken), digest(csrf), ctx.device,enrollMfa,JSON.stringify(recovery.map(c=>keyed(this.config.otpKey,'recovery',c).toString('hex')))]));
      if (result.state === "MFA_ENROLLMENT_REQUIRED" && typeof result.totpCiphertext === "string") {
        const secret = unseal<{ secret: string }>(this.config.encryptionKey, result.totpCiphertext, "totp:" + username).secret;
        delete result.totpCiphertext; return { ...result, secret, issuer: "Mohammad Style", username };
      }
      delete result.totpCiphertext;
      const issued=result.recoveryCodesIssued===true;delete result.recoveryCodesIssued;
      return {...this.session(result, sessionToken, csrf),...(issued?{recoveryCodes:recovery}:{})};
    });
  }
  async mfa(value: unknown, ctx: AuthContext) {
    const body = fields(value, ["challengeId", "code"]), id = uuid(body.challengeId), code = normalizeCode(body.code);
    const prior = await this.call("product_auth_context", [id, ctx.binding]);
    let counter: bigint | null = null;
    if (typeof prior?.totpCiphertext === "string" && typeof prior.username === "string") {
      const secret = unseal<{ secret: string }>(this.config.encryptionKey, prior.totpCiphertext, "totp:" + prior.username).secret;
      counter = matchingTotpCounter(secret, code);
    }
    const recovery = prior?.kind === "MFA_ENROLLMENT" ? Array.from({ length: 10 }, () => randomBytes(16).toString("hex")) : [];
    const sessionToken = token(), csrf = token();
    const result = this.checked(await this.call("product_admin_finish", [id, ctx.binding, counter?.toString() ?? null, digest(sessionToken), digest(csrf), ctx.device,
      JSON.stringify(recovery.map(c => keyed(this.config.otpKey, "recovery", c).toString("hex")))]));
    return { ...this.session(result, sessionToken, csrf), ...(recovery.length ? { recoveryCodes: recovery } : {}) };
  }
  async activate(value: unknown, ctx: AuthContext) {
    const body = fields(value, ["challengeId", "username", "password"]), id = uuid(body.challengeId), username = text(body.username, 64).toLowerCase();
    if (!/^[a-z][a-z0-9_.-]{2,63}$/.test(username)) reject("INVALID_USERNAME");
    return this.kdf(async () => {
      let verifier: string; try { verifier = await passwordHash(text(body.password, 128)); } catch { return reject("PASSWORD_REQUIREMENTS"); }
      const secret = base32(randomBytes(20));
      const result = this.checked(await this.call("product_admin_activate", [id, ctx.binding, username, verifier, seal(this.config.encryptionKey, { secret }, "totp:" + username), randomUUID()]));
      return { ...result, secret, issuer: "Mohammad Style", username };
    });
  }
  async recover(value: unknown, ctx: AuthContext) {
    const body = fields(value, ["challengeId", "recoveryCode", "password"]), id = uuid(body.challengeId), recovery = text(body.recoveryCode, 64).replace(/\s/g, "").toLowerCase();
    const prior = await this.call("product_auth_context", [id, ctx.binding]);
    if (typeof prior?.username !== "string") reject("INVALID_RECOVERY", 401);
    return this.kdf(async () => {
      let verifier: string; try { verifier = await passwordHash(text(body.password, 128)); } catch { return reject("PASSWORD_REQUIREMENTS"); }
      const secret = base32(randomBytes(20));
      const result = this.checked(await this.call("product_recover", [id, ctx.binding, keyed(this.config.otpKey, "recovery", recovery), verifier,
        seal(this.config.encryptionKey, { secret }, "totp:" + prior.username), randomUUID()]));
      return { ...result, secret, issuer: "Mohammad Style", username: prior.username };
    });
  }
  async sessions(hash: Buffer, csrf: Buffer, action: "list" | "revoke" | "revoke_all" | "revoke_others", id: string | null = null) {
    return this.checked(await this.call("product_sessions", [hash, csrf, action, id]));
  }
}
