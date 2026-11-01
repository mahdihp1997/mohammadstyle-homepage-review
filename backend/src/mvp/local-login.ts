import { Controller, HttpException, Inject, Injectable, Post, Req, Res } from "@nestjs/common";
import { createHash, randomBytes, randomUUID, scrypt, timingSafeEqual } from "node:crypto";
import { Pool } from "pg";
import type { Request, Response } from "../admin/security.js";
import { event } from "../observability.js";

export const LOCAL_LOGIN_OPTIONS = Symbol("offline-provisioned local review login");
export interface LocalLoginOptions {
  version: 1;
  username: string;
  salt: string;
  passwordHash: string;
  bridgeSecret: string;
  databasePassword: string;
  userId: string;
  businessId: string;
}
const hash = (s: string) => createHash("sha256").update(s).digest();
const deny = (code: string, status: number): never => { throw new HttpException({ code }, status); };
export function validateLocalLoginOptions(o: LocalLoginOptions) {
  if (process.env.APP_ENV !== "mvp-local" || process.env.NODE_ENV === "production" ||
      o.version !== 1 || !/^[a-z][a-z0-9_-]{2,31}$/.test(o.username) ||
      !/^[a-f0-9]{64}$/.test(o.salt) || !/^[a-f0-9]{128}$/.test(o.passwordHash) ||
      !/^[a-f0-9]{64}$/.test(o.databasePassword) || !/^[A-Za-z0-9_-]{43}$/.test(o.bridgeSecret) ||
      !/^[a-f0-9-]{36}$/.test(o.userId) || !/^[a-f0-9-]{36}$/.test(o.businessId))
    throw Error("Invalid isolated local login configuration");
}
export const passwordKey = (password: string, salt: string): Promise<Buffer> =>
  new Promise((resolve, reject) => scrypt(password, Buffer.from(salt, "hex"), 64,
    { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 },
    (e, key) => e ? reject(e) : resolve(key)));

@Injectable()
export class LocalLoginService {
  private pool?: Pool;
  private inFlight = 0;
  private window = { start: 0, attempts: 0, failures: 0 };
  constructor(@Inject(LOCAL_LOGIN_OPTIONS) private readonly options: LocalLoginOptions | null) {
    if (options) {
      validateLocalLoginOptions(options);
      this.pool = new Pool({ host: "127.0.0.1", port: 55450, database: "ms_mvp_dev",
        user: "ms_mvp_local_login", password: options.databasePassword, max: 2,
        connectionTimeoutMillis: 3000, statement_timeout: 8000,
        application_name: "mohammadstyle-local-review-login" });
      this.pool.on("error", () => {});
    }
  }
  async onModuleInit() {
    if (!this.pool) return;
    const r = (await this.pool.query(`SELECT current_database() db,current_user role,
      shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') marker,
      has_function_privilege(current_user,'ms_b1_design.mvp_local_issue_session(uuid,uuid,bytea,bytea,uuid)','EXECUTE') ready`)).rows[0];
    if (r.db !== "ms_mvp_dev" || r.role !== "ms_mvp_local_login" ||
        r.marker !== "mohammadstyle-mvp-disposable-v1" || !r.ready)
      throw Error("Local review login database identity mismatch");
  }
  async onModuleDestroy() { await this.pool?.end(); }
  async login(req: Request & { body?: unknown }) {
    const o = this.options;
    if (!o || !this.pool || process.env.APP_ENV !== "mvp-local" || process.env.NODE_ENV === "production")
      return deny("LOCAL_LOGIN_DISABLED", 404);
    if (req.headers.host !== "127.0.0.1:3112" || req.headers.origin !== "http://127.0.0.1:3112" ||
        req.headers["sec-fetch-site"] !== "same-origin" ||
        !["127.0.0.1", "::1", "::ffff:127.0.0.1"].includes(req.socket.remoteAddress ?? "") ||
        typeof req.headers["x-local-login-bridge"] !== "string" ||
        !timingSafeEqual(hash(req.headers["x-local-login-bridge"]), hash(o.bridgeSecret)))
      return deny("FORBIDDEN", 403);
    if (Date.now() - this.window.start >= 60000) this.window = { start: Date.now(), attempts: 0, failures: 0 };
    if (++this.window.attempts > 20 || this.window.failures >= 8 || this.inFlight >= 2)
      return deny("RATE_LIMITED", 429);
    if (typeof req.headers["content-type"] !== "string" ||
        !/^application\/json(?:;\s*charset=utf-8)?$/i.test(req.headers["content-type"]))
      return deny("INVALID_REQUEST", 415);
    const b = req.body;
    if (!b || typeof b !== "object" || Array.isArray(b) ||
        Object.keys(b).sort().join(",") !== "password,username") return deny("INVALID_REQUEST", 422);
    const { username, password } = b as { username: unknown; password: unknown };
    if (typeof username !== "string" || typeof password !== "string" || username.length > 64 ||
        password.length < 1 || password.length > 128) return deny("INVALID_REQUEST", 422);
    this.inFlight++;
    try {
      // Always run the same KDF, including an unknown username.
      const key = await passwordKey(password, o.salt);
      const validPassword = timingSafeEqual(key, Buffer.from(o.passwordHash, "hex"));
      const validUsername = timingSafeEqual(hash(username), hash(o.username));
      key.fill(0);
      if (!validPassword || !validUsername) {
        this.window.failures++;
        event("local-review.login.denied", { requestId: req.requestId ?? randomUUID() });
        return deny("INVALID_CREDENTIALS", 401);
      }
      const token = randomBytes(32).toString("base64url"), csrf = randomBytes(32).toString("base64url");
      try {
        await this.pool.query("SELECT ms_b1_design.mvp_local_issue_session($1,$2,$3,$4,$5)",
          [o.userId, o.businessId, hash(token), hash(csrf), req.requestId ?? randomUUID()]);
      } catch (e) {
        if ((e as { code?: string }).code === "MS429") return deny("RATE_LIMITED", 429);
        throw e;
      }
      event("local-review.login.succeeded", { requestId: req.requestId ?? randomUUID() });
      return { token, csrf, maxAge: 3600 };
    } finally { this.inFlight--; }
  }
}

@Controller("api/v1/local-review")
export class LocalLoginController {
  constructor(private readonly loginService: LocalLoginService) {}
  @Post("login") async login(@Req() req: Request & { body?: unknown }, @Res({ passthrough: true }) res: Response) {
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("X-Content-Type-Options", "nosniff");
    return this.loginService.login(req);
  }
}
