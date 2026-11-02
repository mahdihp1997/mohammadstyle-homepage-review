import fs from "node:fs";
import path from "node:path";
import type { PoolConfig } from "pg";

export type ProductEnvironment = "test" | "staging" | "production";
export interface ProductDatabaseOptions {
  profile: "product";
  environment: ProductEnvironment;
  marker: string;
  host: string;
  port: number;
  database: string;
  user: "ms_b1b_api";
  password: string;
  origin: string;
  ssl: PoolConfig["ssl"];
}
export interface ProductConfig {
  reviewOtpAutofill?: boolean;
  environment: ProductEnvironment;
  origin: string;
  listenHost: "127.0.0.1" | "0.0.0.0";
  port: number;
  businessId: string;
  bridgeKey: string;
  encryptionKey: string;
  identityKey: string;
  otpKey: string;
  sessionSeconds: number;
  idleSeconds: number;
  database: ProductDatabaseOptions;
  authDatabasePassword: string;
  workerDatabasePassword: string;
  sms: "none" | "mock" | "kavenegar";
  smsKey: string | null;
  smsOtpTemplate: string | null;
  smsSender: string | null;
  payment: "none" | "mock";
  mediaRoot: string;
  mockGatewayOrigin: string | null;
}
const keyPattern = /^[A-Za-z0-9_-]{43}$/;
export function secret(env: NodeJS.ProcessEnv, name: string, required = true): string | null {
  if (env[name] && env[name + "_FILE"]) throw Error("Duplicate secret source: " + name);
  const value = env[name + "_FILE"] ? fs.readFileSync(env[name + "_FILE"]!, "utf8").trim() : env[name];
  if (required && !value) throw Error("Missing secret: " + name);
  return value || null;
}
function integer(value: string | undefined, fallback: number, low: number, high: number) {
  const n = value === undefined ? fallback : Number(value);
  if (!Number.isSafeInteger(n) || n < low || n > high) throw Error("Invalid bounded runtime setting");
  return n;
}
export function isProductDatabase(o: unknown): o is ProductDatabaseOptions {
  return !!o && typeof o === "object" && "profile" in o && o.profile === "product";
}
export function assertProductDatabase(o: ProductDatabaseOptions) {
  if (!["test", "staging", "production"].includes(o.environment) || o.marker !== "mohammadstyle-product-" + o.environment + "-v1" ||
      o.user !== "ms_b1b_api" || !/^[A-Za-z0-9_]{3,63}$/.test(o.database))
    throw Error("Invalid product database identity");
  const origin = new URL(o.origin);
  if (origin.origin !== o.origin || origin.username || origin.password) throw Error("Invalid product origin");
  if (o.environment === "test") {
    if (process.env.APP_ENV !== "product-test" || process.env.NODE_ENV === "production" || o.host !== "127.0.0.1" ||
        ![55460,55461].includes(o.port) || !(["ms_product_test", "ms_product_restore", "ms_product_failure"].includes(o.database) || (o.database==="ms_product_owner_review" && o.port===55461 && o.origin==="http://127.0.0.1:3006")) ||
        !["127.0.0.1", "localhost"].includes(origin.hostname)) throw Error("Product test isolation required");
  } else if (process.env.APP_ENV !== o.environment || origin.protocol !== "https:" ||
      /(?:test|synthetic|_dev|restore|failure)/i.test(o.database) || !o.ssl || typeof o.ssl !== "object" ||
      o.ssl.rejectUnauthorized !== true || !o.ssl.ca || o.port < 1 || o.port > 65535 || o.host === "")
    throw Error("HTTPS, verified database TLS and the intended product environment are required");
}
export function productPoolOptions(o: ProductDatabaseOptions, role: string = o.user, password: string = o.password): PoolConfig {
  assertProductDatabase(o);
  if (!["ms_b1b_api", "ms_product_auth", "ms_product_worker"].includes(role) || !/^[a-f0-9]{64}$/.test(password))
    throw Error("Invalid product runtime role");
  return { host: o.host, port: o.port, database: o.database, user: role, password, ssl: o.ssl,
    max: 8, connectionTimeoutMillis: 5000, statement_timeout: 30000, idle_in_transaction_session_timeout: 15000,
    application_name: "mohammadstyle-" + role };
}
export function loadProductConfig(env: NodeJS.ProcessEnv = process.env, purpose: 'api'|'worker'|'migrate'|'bootstrap' = 'api'): ProductConfig {
  if(!['api','worker','migrate','bootstrap'].includes(purpose))throw Error('Explicit process purpose required');
  const environment: ProductEnvironment = env.APP_ENV === "product-test" ? "test" : env.APP_ENV === "staging" ? "staging" : "production";
  if (!["product-test", "staging", "production"].includes(env.APP_ENV ?? "")) throw Error("Explicit product environment required");
  const key = (name: string, required = true) => { const value = secret(env, name, required); if (!value) return ''; if (!keyPattern.test(value)) throw Error("Invalid key: " + name); return value; };
  const dbPassword = (name: string, required = true) => { const value = secret(env, name, required); if (!value) return ''; if (!/^[a-f0-9]{64}$/.test(value)) throw Error("Invalid database secret: " + name); return value; };
  const origin = env.PUBLIC_ORIGIN ?? "";
  const database: ProductDatabaseOptions = { profile: "product", environment, marker: "mohammadstyle-product-" + environment + "-v1",
    host: env.PGHOST ?? "", port: integer(env.PGPORT, 5432, 1, 65535), database: env.PGDATABASE ?? "",
    user: "ms_b1b_api", password: dbPassword("PRODUCT_API_PASSWORD",purpose==='api'), origin,
    ssl: env.PGSSL_CA_FILE ? { rejectUnauthorized: true, ca: fs.readFileSync(env.PGSSL_CA_FILE, "utf8") } : false };
  assertProductDatabase(database);
  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(env.PRODUCT_BUSINESS_ID ?? ""))
    throw Error("Configured business identity required");
  const sms = env.SMS_PROVIDER ?? "none", payment = env.PAYMENT_PROVIDER ?? "none";
  if (!["none", "mock", "kavenegar"].includes(sms) || !["none", "mock"].includes(payment)) throw Error("Unsupported/unapproved provider");
  if ((sms === "mock" || payment === "mock") && (environment !== "test" || env.NODE_ENV === "production"))
    throw Error("Mock providers are confined to the isolated test environment");
  if (environment === "test" && sms === "kavenegar") throw Error("Live SMS sending is forbidden in isolated testing");
  const smsKey = secret(env, "SMS_API_KEY", sms === "kavenegar" && purpose==='worker');
  if (sms === "kavenegar" && (!/^[A-Za-z0-9_-]{1,80}$/.test(env.SMS_OTP_TEMPLATE ?? "")))
    throw Error("Approved SMS verification template required");
  const mockGatewayOrigin = payment === "mock" || sms === "mock" ? env.MOCK_GATEWAY_ORIGIN ?? "http://127.0.0.1:3117" : null;
  const reviewOtpAutofill = env.PRODUCT_REVIEW_OTP_AUTOFILL === "1";
  if (env.PRODUCT_REVIEW_OTP_AUTOFILL && !["0", "1"].includes(env.PRODUCT_REVIEW_OTP_AUTOFILL)) throw Error("Invalid review OTP setting");
  if (reviewOtpAutofill && (environment !== "test" || env.NODE_ENV !== "development" || sms !== "mock" ||
      !((database.port===55460 && origin==="http://127.0.0.1:3006" && mockGatewayOrigin==="http://127.0.0.1:3117") ||
        (database.port===55461 && origin==="http://127.0.0.1:3007" && mockGatewayOrigin==="http://127.0.0.1:3120") ||
        (database.port===55461 && database.database==="ms_product_owner_review" && origin==="http://127.0.0.1:3006" && mockGatewayOrigin==="http://127.0.0.1:3117"))))
    throw Error("Review OTP autofill requires the explicitly isolated development profile");
  if (mockGatewayOrigin && !/^http:\/\/127\.0\.0\.1:\d{4,5}$/.test(mockGatewayOrigin)) throw Error("Loopback mock gateway required");
  const sessionSeconds = integer(env.SESSION_ABSOLUTE_SECONDS, 3600, 900, 86400);
  const idleSeconds = integer(env.SESSION_IDLE_SECONDS, 900, 300, 3600);
  if (idleSeconds > sessionSeconds) throw Error("Idle expiry exceeds absolute expiry");
  const mediaRoot = path.resolve(env.PRODUCT_MEDIA_ROOT ?? "");
  if (!env.PRODUCT_MEDIA_ROOT || mediaRoot.split(path.sep).includes("public")) throw Error("Private media storage root required");
  return { environment, origin, database, reviewOtpAutofill, businessId: env.PRODUCT_BUSINESS_ID!, bridgeKey: key("PRODUCT_BRIDGE_KEY",purpose==='api'||(purpose==='worker'&&environment==='test')),
    encryptionKey: key("PRODUCT_ENCRYPTION_KEY",purpose==='api'||purpose==='worker'), identityKey: key("PRODUCT_IDENTITY_KEY",purpose==='api'||purpose==='bootstrap'), otpKey: key("PRODUCT_OTP_KEY",purpose==='api'),
    authDatabasePassword: dbPassword("PRODUCT_AUTH_PASSWORD",purpose==='api'), workerDatabasePassword: dbPassword("PRODUCT_WORKER_PASSWORD",purpose==='worker'),
    sessionSeconds, idleSeconds, listenHost: environment === "test" ? "127.0.0.1" : "0.0.0.0",
    port: integer(env.PRODUCT_API_PORT, 3116, 1024, 65535), sms: sms as ProductConfig["sms"], smsKey,
    smsOtpTemplate: env.SMS_OTP_TEMPLATE ?? null, smsSender: env.SMS_SENDER ?? null,
    payment: payment as ProductConfig["payment"], mediaRoot, mockGatewayOrigin };
}
