// Re-run unchanged approved test bodies against disposable cloned profiles, never their original databases.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { root, docker, save } from "./local.mjs";
const dest = path.join(root, ".local/mvp/flat/b4"),
  project = "mohammadstyle-mvp-b4-baseline",
  hash = (b) => createHash("sha256").update(b).digest("hex");
if (!path.resolve(dest).startsWith(path.resolve(root, ".local/mvp") + path.sep))
  throw Error("Unsafe scratch");
fs.mkdirSync(dest, { recursive: true });
for (const name of ["scripts", "migrations", "dist", "test", "prisma"])
  fs.cpSync(path.join(root, name), path.join(dest, name), { recursive: true });
for (const name of fs
  .readdirSync(root)
  .filter(
    (n) =>
      /^compose\..*\.yaml$/.test(n) ||
      ["package.json", "prisma.config.ts", ".env.example"].includes(n),
  ))
  fs.copyFileSync(path.join(root, name), path.join(dest, name));
const schema = path.join(dest, "../docs/architecture/schema");
fs.mkdirSync(schema, { recursive: true });
for (const n of [
  "draft-postgresql.sql",
  "b1-draft-postgresql.sql",
  "quote-content.schema.json",
  "quote-hash-vectors.json",
])
  fs.copyFileSync(
    path.join(root, "../docs/architecture/schema", n),
    path.join(schema, n),
  );
if (!fs.existsSync(path.join(dest, "node_modules")))
  fs.symlinkSync(
    path.join(root, "node_modules"),
    path.join(dest, "node_modules"),
    process.platform === "win32" ? "junction" : "dir",
  );
if (
  fs.realpathSync(path.join(dest, "node_modules")) !==
  fs.realpathSync(path.join(root, "node_modules"))
)
  throw Error("Unsafe modules");
for (const name of ["local", "infra", "backup"]) {
  const f = path.join(dest, "scripts/b4", name + ".mjs");
  fs.writeFileSync(
    f,
    fs
      .readFileSync(f, "utf8")
      .replaceAll("55446", "55452")
      .replaceAll("mohammadstyle-b4", project),
  );
}
const repository = path.join(dest, "dist/booking/repository.js");
fs.writeFileSync(
  repository,
  fs
    .readFileSync(repository, "utf8")
    .replaceAll("55446", "55452")
    .replaceAll("mohammadstyle-b4-disposable-v1", project + "-disposable-v1"),
);
let yaml = fs
  .readFileSync(path.join(root, "compose.b4.yaml"), "utf8")
  .replaceAll("55446", "55452")
  .replaceAll("mohammadstyle-b4", project)
  .replace(
    '    volumes: ["b4_pgdata:/var/lib/postgresql"]',
    '    tmpfs: ["/var/lib/postgresql"]',
  );
yaml = yaml.slice(0, yaml.indexOf("\nvolumes:")) + "\n";
if (!yaml.includes("tmpfs:") || yaml.includes("55446"))
  throw Error("Unsafe Compose");
fs.writeFileSync(path.join(dest, "compose.b4.yaml"), yaml);
function run(args, cwd = dest) {
  const r = spawnSync(process.execPath, args, {
    cwd,
    env: { ...process.env, APP_ENV: "b4-local" },
    encoding: "utf8",
    timeout: 1200000,
    maxBuffer: 30 * 1024 * 1024,
  });
  process.stdout.write((r.stdout ?? "") + (r.stderr ?? ""));
  if (r.status !== 0) throw Error("Regression failed " + args[0]);
}
try {
  for (const args of [
    ["scripts/b4/infra.mjs", "env"],
    ["scripts/b4/infra.mjs", "up"],
    ["scripts/b4/test.mjs"],
    ["scripts/b4/extra.mjs"],
  ])
    run(args);
  for (const [file, result] of [
    ["test", "integration"],
    ["extra", "extra"],
  ]) {
    const source = fs.readFileSync(
      path.join(root, "scripts/b4", file + ".mjs"),
    );
    if (
      hash(source) !==
      hash(fs.readFileSync(path.join(dest, "scripts/b4", file + ".mjs")))
    )
      throw Error("Changed original test body");
    const r = JSON.parse(
      fs.readFileSync(path.join(dest, ".local/b4/results", result + ".json")),
    );
    if (r.summary.failed) throw Error("Regression result failure");
    save("b4-" + result + "-regression.json", {
      ...r,
      originalTestBodySha256: hash(source),
    });
  }
} finally {
  const r = spawnSync(
    docker,
    [
      "compose",
      "--project-name",
      project,
      "--file",
      path.join(dest, "compose.b4.yaml"),
      "--env-file",
      path.join(dest, ".env.b4.local"),
      "down",
      "--volumes",
    ],
    { stdio: "inherit" },
  );
  if (r.status !== 0) throw Error("Owned tmpfs cleanup failed");
}
run(["scripts/b4/b3-regression.mjs"], root);
for (const p of ["b3", "b2h", "b2b", "b2a", "b1b", "b1a", "b0"])
  save(
    p + "-regression.json",
    JSON.parse(
      fs.readFileSync(
        path.join(root, ".local/b4/results", p + "-regression.json"),
      ),
    ),
  );
console.log("PASS all approved B0–B4 test bodies rerun on disposable clones.");
