// Creates synthetic test media only, never imports salon/client files.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import sharp from "sharp";
import { root } from "./local.mjs";
const folder = path.join(root, ".local/mvp/ui-fixtures");
fs.mkdirSync(folder, { recursive: true });
const image = await sharp({
  create: { width: 800, height: 600, channels: 3, background: "#b99c6f" },
})
  .png()
  .toBuffer();
fs.writeFileSync(path.join(folder, "synthetic-zip.png"), image);
const video = path.join(folder, "synthetic-zip.mp4"),
  r = spawnSync(
    process.env.FFMPEG_BIN ?? "ffmpeg",
    [
      "-v",
      "error",
      "-f",
      "lavfi",
      "-i",
      "testsrc2=size=640x360:rate=24",
      "-t",
      "2",
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-threads",
      "2",
      "-y",
      video,
    ],
    { windowsHide: true, timeout: 30000 },
  );
if (r.status !== 0) throw Error("Synthetic video fixture failed");
const script =
  "import sys,zipfile,os\np=sys.argv[1]\nwith zipfile.ZipFile(os.path.join(p,'synthetic-media.zip'),'w',zipfile.ZIP_DEFLATED) as z:\n for n in ['synthetic-zip.png','synthetic-zip.mp4']:z.write(os.path.join(p,n),'safe/'+n)";
const z = spawnSync(
  process.platform === "win32" ? "python" : "python3",
  ["-c", script, folder],
  { windowsHide: true, timeout: 10000 },
);
if (z.status !== 0) throw Error("Synthetic ZIP fixture failed");
console.log(
  "Generated synthetic geometric/video test files; no client media read.",
);
