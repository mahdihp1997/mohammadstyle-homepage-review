import fs from "node:fs/promises";
import path from "node:path";
import { tmpdir } from "node:os";
import { spawn } from "node:child_process";
import { HttpException } from "@nestjs/common";
import sharp, { type Metadata } from "sharp";
import yauzl from "yauzl";
import type { Evidence } from "../admin/security.js";
import type { MvpRepository } from "./repository.js";
import { sha, type MediaStorage } from "./storage.js";
const maxFile = 32 * 1024 * 1024;
sharp.concurrency(1);
sharp.cache({ memory: 32, files: 0, items: 20 });
const fail = (code: string, status = 422): never => {
  throw new HttpException({ code }, status);
};
export interface Upload {
  fileName: string;
  base64: string;
  branchId: string | null;
}
export function decodeUpload(value: unknown): {
  name: string;
  bytes: Buffer;
  branchId: string | null;
} {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    Object.keys(value).sort().join(",") !== "base64,branchId,fileName"
  )
    return fail("INVALID_UPLOAD");
  const d = value as Upload;
  if (
    typeof d.fileName !== "string" ||
    !d.fileName.trim() ||
    d.fileName.length > 240 ||
    /[\\/\x00-\x1f]/.test(d.fileName) ||
    typeof d.base64 !== "string" ||
    d.base64.length > Math.ceil(maxFile / 3) * 4 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(d.base64) ||
    !(
      d.branchId === null ||
      (typeof d.branchId === "string" && /^[a-f0-9-]{36}$/.test(d.branchId))
    )
  )
    return fail("INVALID_UPLOAD");
  const bytes = Buffer.from(d.base64, "base64");
  if (
    !bytes.length ||
    bytes.length > maxFile ||
    bytes.toString("base64") !== d.base64
  )
    return fail("UPLOAD_SIZE", 413);
  return { name: d.fileName, bytes, branchId: d.branchId };
}
export async function zipEntries(
  bytes: Buffer,
): Promise<{ name: string; bytes: Buffer }[]> {
  return new Promise((resolve, reject) => {
    yauzl.fromBuffer(
      bytes,
      { lazyEntries: true, validateEntrySizes: true, strictFileNames: true },
      (error, zip) => {
        if (error || !zip) {
          reject(new HttpException({ code: "INVALID_ZIP" }, 422));
          return;
        }
        let total = 0,
          count = 0,
          visited = 0,
          finished = false;
        const entries: { name: string; bytes: Buffer }[] = [],
          seen = new Set<string>();
        const bad = () => {
          if (finished) return;
          finished = true;
          zip.close();
          reject(new HttpException({ code: "UNSAFE_ZIP" }, 422));
        };
        zip.on("error", bad);
        zip.on("end", () => {
          if (!finished) {
            finished = true;
            if (!entries.length)
              reject(new HttpException({ code: "EMPTY_ZIP" }, 422));
            else resolve(entries);
          }
        });
        zip.on("entry", (e: yauzl.Entry) => {
          if (++visited > 100) return bad();
          const name = e.fileName.normalize("NFC"),
            segments = name.split("/"),
            mode = (e.externalFileAttributes >>> 16) & 0xf000;
          if (
            name.length > 260 ||
            name.startsWith("/") ||
            /[\\:\x00-\x1f]/.test(name) ||
            segments.some((x) => x === "." || x === "..") ||
            seen.has(name.toLowerCase()) ||
            e.isEncrypted() ||
            mode === 0xa000
          )
            return bad();
          seen.add(name.toLowerCase());
          if (name.endsWith("/")) {
            zip.readEntry();
            return;
          }
          if (
            ++count > 20 ||
            !/^.+\.(?:jpe?g|png|webp|mp4|mov|webm)$/i.test(name) ||
            e.uncompressedSize < 1 ||
            e.uncompressedSize > maxFile ||
            (total += e.uncompressedSize) > 128 * 1024 * 1024 ||
            e.uncompressedSize > Math.max(1, e.compressedSize) * 100
          )
            return bad();
          zip.openReadStream(e, (err, stream) => {
            if (err || !stream) return bad();
            const chunks: Buffer[] = [];
            let actual = 0;
            stream.on("data", (chunk: Buffer) => {
              actual += chunk.length;
              if (actual > e.uncompressedSize || actual > maxFile) {
                stream.destroy();
                bad();
              } else chunks.push(chunk);
            });
            stream.on("error", bad);
            stream.on("end", () => {
              if (finished) return;
              if (actual !== e.uncompressedSize) return bad();
              entries.push({
                name: segments.at(-1)!,
                bytes: Buffer.concat(chunks),
              });
              zip.readEntry();
            });
          });
        });
        zip.readEntry();
      },
    );
  });
}
function run(
  executable: string,
  args: string[],
  timeout = 90000,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const p = spawn(executable, args, {
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
    });
    let out = "",
      err = "",
      done = false;
    const finish = (e?: Error) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      e ? reject(e) : resolve(out);
    };
    const timer = setTimeout(() => {
      p.kill();
      finish(Error("MEDIA_TIMEOUT"));
    }, timeout);
    p.on("error", () => finish(Error("MEDIA_PROCESSOR_UNAVAILABLE")));
    p.stdout.on("data", (b: Buffer) => {
      if (out.length + b.length > 1024 * 1024) {
        p.kill();
        finish(Error("MEDIA_METADATA_LIMIT"));
      } else out += b.toString();
    });
    p.stderr.on("data", (b: Buffer) => {
      if (err.length < 8192) err += b.toString();
    });
    p.on("close", (code) =>
      finish(code === 0 ? undefined : Error("MEDIA_UNSUPPORTED")),
    );
  });
}
type Variant = {
  name: "THUMB" | "DISPLAY" | "VIDEO";
  key: string;
  mime: "image/webp" | "video/mp4";
  bytes: number;
  sha256: string;
  width: number;
  height: number;
  durationMs: number | null;
};
function idFor(value: string) {
  const h = sha(value).slice(0, 32).split("");
  h[12] = "4";
  h[16] = ((parseInt(h[16]!, 16) & 3) | 8).toString(16);
  const s = h.join("");
  return [
    s.slice(0, 8),
    s.slice(8, 12),
    s.slice(12, 16),
    s.slice(16, 20),
    s.slice(20),
  ].join("-");
}
export class MediaService {
  private busy = false;
  constructor(
    private readonly repo: MvpRepository,
    private readonly storage: MediaStorage,
  ) {}
  async upload(e: Evidence, key: string, raw: unknown) {
    if (this.busy) return fail("MEDIA_PROCESSOR_BUSY", 429);
    const file = decodeUpload(raw);
    // Acquire synchronously, before any await: two authorized requests must never
    // both pass an idle check while authorization/receipt lookup is pending.
    this.busy = true;
    let scratch: string | undefined;
    const deadline = Date.now() + 120000;
    const budget = (limit: number) => {
      const remaining = deadline - Date.now();
      if (remaining <= 0) return fail("MEDIA_BATCH_TIMEOUT", 422);
      return Math.min(limit, remaining);
    };
    try {
      // Authorization still precedes ZIP/image parsing and native video tools.
      await this.repo.mediaAuthorize(e.hash, e.csrf, file.branchId);
      const digest = sha(
        Buffer.concat([
          Buffer.from(
            JSON.stringify({ name: file.name, branch: file.branchId }),
          ),
          file.bytes,
        ]),
      );
      const prior = await this.repo.portalRead(
        e.hash,
        "upload-receipt",
        file.branchId,
        null,
        0,
        { key, hash: digest },
      );
      if (prior) return prior;
      await this.storage.prepare?.();
      scratch = await fs.mkdtemp(path.join(tmpdir(), "ms-mvp-media-"));
      const zipped = /\.zip$/i.test(file.name);
      if (!zipped && file.bytes.subarray(0, 2).toString() === "PK")
        return fail("ZIP_EXTENSION_REQUIRED");
      const files = zipped
          ? await zipEntries(file.bytes)
          : [{ name: file.name, bytes: file.bytes }],
        assets = [];
      for (const [index, f] of files.entries()) {
        budget(1);
        const id = idFor(
            e.actor.businessId + ":" + e.actor.userId + ":" + key + ":" + index,
          ),
          sourceHash = sha(f.bytes),
          prefix = e.actor.businessId + "/" + id + "/" + sourceHash;
        const variants: Variant[] = [],
          save = async (
            name: Variant["name"],
            data: Buffer,
            mime: Variant["mime"],
            width: number,
            height: number,
            durationMs: number | null = null,
          ) => {
            if (data.length > 64 * 1024 * 1024)
              return fail("OPTIMIZED_MEDIA_SIZE");
            const key =
              prefix +
              "/" +
              (name === "VIDEO" ? "video.mp4" : name.toLowerCase() + ".webp");
            await this.storage.put(key, data, mime);
            variants.push({
              name,
              key,
              mime,
              bytes: data.length,
              sha256: sha(data),
              width,
              height,
              durationMs,
            });
          };
        let kind: "IMAGE" | "VIDEO";
        let metadata: Metadata | undefined;
        try {
          metadata = await sharp(f.bytes, {
            limitInputPixels: 40_000_000,
            failOn: "warning",
          }).metadata();
        } catch {
          metadata = undefined;
        }
        if (
          metadata &&
          ["jpeg", "png", "webp"].includes(metadata.format ?? "")
        ) {
          if (
            (metadata.pages ?? 1) !== 1 ||
            !metadata.width ||
            !metadata.height
          )
            return fail("ANIMATED_IMAGE_UNSUPPORTED");
          kind = "IMAGE";
          for (const [name, size] of [
            ["THUMB", 480],
            ["DISPLAY", 1920],
          ] as const) {
            const { data, info } = await sharp(f.bytes, {
              limitInputPixels: 40_000_000,
              failOn: "warning",
            })
              .rotate()
              .resize({
                width: size,
                height: size,
                fit: "inside",
                withoutEnlargement: true,
              })
              .webp({ quality: name === "THUMB" ? 76 : 84 })
              .timeout({
                seconds: Math.max(1, Math.floor(budget(20000) / 1000)),
              })
              .toBuffer({ resolveWithObject: true });
            await save(name, data, "image/webp", info.width, info.height);
          }
        } else {
          if (!/\.(mp4|mov|webm)$/i.test(f.name))
            return fail("UNSUPPORTED_MEDIA");
          kind = "VIDEO";
          const input = path.join(
              scratch,
              "source-" + index + path.extname(f.name).toLowerCase(),
            ),
            output = path.join(scratch, "video-" + index + ".mp4"),
            poster = path.join(scratch, "poster-" + index + ".webp");
          await fs.writeFile(input, f.bytes, { flag: "wx" });
          const probe = JSON.parse(
            await run(
              process.env.FFPROBE_BIN ?? "ffprobe",
              [
                "-v",
                "error",
                "-protocol_whitelist",
                "file,pipe",
                "-format_whitelist",
                "mov,matroska,webm",
                "-show_format",
                "-show_streams",
                "-of",
                "json",
                input,
              ],
              budget(20000),
            ),
          ) as {
            streams: { codec_type: string; width?: number; height?: number }[];
            format: { duration: string };
          };
          const v = probe.streams.find((s) => s.codec_type === "video"),
            duration = Number(probe.format.duration);
          if (
            !v?.width ||
            !v.height ||
            v.width * v.height > 33_177_600 ||
            probe.streams.length > 8 ||
            !Number.isFinite(duration) ||
            duration < 0.1 ||
            duration > 120
          )
            return fail("VIDEO_LIMIT");
          const common = [
            "-v",
            "error",
            "-nostdin",
            "-protocol_whitelist",
            "file,pipe",
            "-format_whitelist",
            "mov,matroska,webm",
            "-i",
            input,
            "-map_metadata",
            "-1",
            "-map_chapters",
            "-1",
          ];
          await run(
            process.env.FFMPEG_BIN ?? "ffmpeg",
            [
              ...common,
              "-map",
              "0:v:0",
              "-map",
              "0:a:0?",
              "-vf",
              "scale=w='min(1280,iw)':h='min(720,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",
              "-c:v",
              "libx264",
              "-preset",
              "fast",
              "-crf",
              "25",
              "-pix_fmt",
              "yuv420p",
              "-r",
              "30",
              "-threads",
              "2",
              "-c:a",
              "aac",
              "-b:a",
              "96k",
              "-movflags",
              "+faststart",
              "-t",
              "120",
              "-f",
              "mp4",
              "-y",
              output,
            ],
            budget(90000),
          );
          await run(
            process.env.FFMPEG_BIN ?? "ffmpeg",
            [
              ...common,
              "-map",
              "0:v:0",
              "-frames:v",
              "1",
              "-vf",
              "scale=w='min(1280,iw)':h='min(720,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",
              "-threads",
              "2",
              "-y",
              poster,
            ],
            budget(30000),
          );
          const display = await sharp(poster)
            .webp({ quality: 84 })
            .toBuffer({ resolveWithObject: true });
          await save(
            "DISPLAY",
            display.data,
            "image/webp",
            display.info.width,
            display.info.height,
          );
          const thumb = await sharp(display.data)
            .resize({
              width: 480,
              height: 480,
              fit: "inside",
              withoutEnlargement: true,
            })
            .webp({ quality: 76 })
            .toBuffer({ resolveWithObject: true });
          await save(
            "THUMB",
            thumb.data,
            "image/webp",
            thumb.info.width,
            thumb.info.height,
          );
          await save(
            "VIDEO",
            await fs.readFile(output),
            "video/mp4",
            display.info.width,
            display.info.height,
            Math.min(120000, Math.round(duration * 1000)),
          );
        }
        const originalKey = prefix + "/original.bin";
        await this.storage.put(
          originalKey,
          f.bytes,
          "application/octet-stream",
        );
        assets.push({
          id,
          kind,
          originalName: f.name,
          originalKey,
          sourceHash,
          sourceBytes: f.bytes.length,
          variants,
        });
      }
      budget(1);
      return await this.repo.ingest(
        e.hash,
        e.csrf,
        file.branchId,
        key,
        digest,
        e.requestId,
        assets,
      );
    } catch (error) {
      if (error instanceof HttpException) throw error;
      const code = (error as { code?: string }).code;
      if (code && /^(?:MS[0-9]{3}|[0-9A-Z]{5})$/.test(code)) throw error;
      return fail("MEDIA_PROCESSING_FAILED", 422);
    } finally {
      this.busy = false;
      if (scratch) {
        const resolved = path.resolve(scratch),
          base = await fs.realpath(tmpdir());
        if (
          path.dirname(resolved) === path.resolve(base) &&
          path.basename(resolved).startsWith("ms-mvp-media-")
        )
          await fs.rm(resolved, { recursive: true, force: true });
      }
    }
  }
}
