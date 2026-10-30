import fs from "node:fs/promises";
import { createReadStream } from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { Readable } from "node:stream";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  GetBucketPolicyCommand,
  GetBucketAclCommand,
} from "@aws-sdk/client-s3";
export interface ByteRange {
  start: number;
  end: number;
}
export interface MediaStorage {
  readonly kind: "LOCAL" | "S3";
  prepare?(): Promise<void>;
  close?(): void;
  put(key: string, bytes: Buffer, mime: string): Promise<void>;
  read(key: string, range?: ByteRange): Promise<Readable>;
}
const keyPattern =
  /^[a-f0-9-]{36}\/[a-f0-9-]{36}\/[a-f0-9]{64}\/(?:original\.(?:bin|mp4|mov|webm)|thumb\.webp|display\.webp|video\.mp4)$/;
export const sha = (data: Buffer | string) =>
  createHash("sha256").update(data).digest("hex");
export function validKey(key: string) {
  if (!keyPattern.test(key)) throw Error("Invalid immutable storage key");
  return key;
}
export class LocalMediaStorage implements MediaStorage {
  readonly kind = "LOCAL" as const;
  private readonly root: string;
  constructor(root: string) {
    this.root = path.resolve(root);
  }
  private async file(key: string, create = false) {
    validKey(key);
    await fs.mkdir(this.root, { recursive: true, mode: 0o700 });
    const root = await fs.realpath(this.root),
      full = path.resolve(root, ...key.split("/"));
    if (!full.startsWith(root + path.sep)) throw Error("Storage boundary");
    if (create)
      await fs.mkdir(path.dirname(full), { recursive: true, mode: 0o700 });
    const parent = await fs.realpath(path.dirname(full));
    if (!parent.startsWith(root + path.sep))
      throw Error("Storage symlink boundary");
    return full;
  }
  async put(key: string, bytes: Buffer, _mime: string) {
    const full = await this.file(key, true);
    try {
      await fs.writeFile(full, bytes, { flag: "wx", mode: 0o600 });
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code !== "EEXIST") throw e;
      const stat = await fs.lstat(full);
      if (
        stat.isSymbolicLink() ||
        !stat.isFile() ||
        stat.size !== bytes.length ||
        sha(await fs.readFile(full)) !== sha(bytes)
      )
        throw Error("Immutable object conflict");
    }
  }
  async read(key: string, range?: ByteRange) {
    const full = await this.file(key),
      stat = await fs.lstat(full);
    if (!stat.isFile() || stat.isSymbolicLink())
      throw Error("Invalid media object");
    return createReadStream(full, range);
  }
}
export interface S3Options {
  endpoint: string;
  bucket: string;
  region: string;
  accessKey: string;
  secretKey: string;
}
/** Official AWS SDK signing and path-style private objects. Dedicated owner-only bucket required. */
export class S3MediaStorage implements MediaStorage {
  readonly kind = "S3" as const;
  private readonly client: S3Client;
  close() {
    this.client.destroy();
  }
  constructor(private readonly options: S3Options) {
    const u = new URL(options.endpoint);
    if (
      u.username ||
      u.password ||
      u.pathname !== "/" ||
      u.search ||
      u.hash ||
      !(
        u.protocol === "https:" ||
        (u.protocol === "http:" &&
          ["127.0.0.1", "localhost"].includes(u.hostname))
      ) ||
      !/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(options.bucket) ||
      !options.region ||
      !options.accessKey ||
      !options.secretKey
    )
      throw Error("Explicit private S3 configuration required");
    this.client = new S3Client({
      endpoint: options.endpoint,
      region: options.region,
      credentials: {
        accessKeyId: options.accessKey,
        secretAccessKey: options.secretKey,
      },
      forcePathStyle: true,
      maxAttempts: 1,
      followRegionRedirects: false,
      requestChecksumCalculation: "WHEN_REQUIRED",
      responseChecksumValidation: "WHEN_REQUIRED",
    });
  }
  async prepare() {
    try {
      const policy = await this.client.send(
        new GetBucketPolicyCommand({ Bucket: this.options.bucket }),
        { abortSignal: AbortSignal.timeout(30000) },
      );
      if (policy.Policy)
        throw Error("Dedicated bucket must not have a bucket policy");
    } catch (e) {
      if ((e as { name?: string }).name !== "NoSuchBucketPolicy") throw e;
    }
    const acl = await this.client.send(
      new GetBucketAclCommand({ Bucket: this.options.bucket }),
      { abortSignal: AbortSignal.timeout(30000) },
    );
    if (
      !acl.Owner?.ID ||
      !acl.Grants?.length ||
      acl.Grants.some(
        (g) =>
          g.Grantee?.Type !== "CanonicalUser" || g.Grantee.ID !== acl.Owner!.ID,
      )
    )
      throw Error("Dedicated owner-only S3 bucket required");
  }
  async put(key: string, bytes: Buffer, mime: string) {
    validKey(key);
    await this.prepare();
    try {
      await this.client.send(
        new PutObjectCommand({
          Bucket: this.options.bucket,
          Key: key,
          Body: bytes,
          ContentType: mime,
          IfNoneMatch: "*",
        }),
        { abortSignal: AbortSignal.timeout(30000) },
      );
    } catch (e) {
      if (
        ![409, 412].includes(
          (e as { $metadata?: { httpStatusCode?: number } }).$metadata
            ?.httpStatusCode ?? 0,
        )
      )
        throw e;
      const found = await this.client.send(
        new GetObjectCommand({ Bucket: this.options.bucket, Key: key }),
        { abortSignal: AbortSignal.timeout(30000) },
      );
      if (
        !found.Body ||
        found.ContentLength !== bytes.length ||
        sha(Buffer.from(await found.Body.transformToByteArray())) !== sha(bytes)
      )
        throw Error("Immutable S3 object conflict");
    }
  }
  async read(key: string, range?: ByteRange) {
    validKey(key);
    await this.prepare();
    const found = await this.client.send(
      new GetObjectCommand({
        Bucket: this.options.bucket,
        Key: key,
        ...(range ? { Range: `bytes=${range.start}-${range.end}` } : {}),
      }),
      { abortSignal: AbortSignal.timeout(30000) },
    );
    if (
      !found.Body ||
      (range &&
        (found.ContentLength !== range.end - range.start + 1 ||
          !found.ContentRange?.startsWith(
            `bytes ${range.start}-${range.end}/`,
          )))
    )
      throw Error("Private S3 range mismatch");
    return found.Body as Readable;
  }
}
export function byteRange(
  value: string | undefined,
  size: number,
): ByteRange | undefined {
  if (value === undefined) return;
  const m = /^bytes=(\d*)-(\d*)$/.exec(value);
  if (!m || (!m[1] && !m[2])) throw Error("RANGE");
  let start = m[1] ? Number(m[1]) : Math.max(0, size - Number(m[2])),
    end = m[1] ? (m[2] ? Number(m[2]) : size - 1) : size - 1;
  if (
    !Number.isSafeInteger(start) ||
    !Number.isSafeInteger(end) ||
    start < 0 ||
    start >= size ||
    end < start
  )
    throw Error("RANGE");
  end = Math.min(end, size - 1);
  return { start, end };
}
