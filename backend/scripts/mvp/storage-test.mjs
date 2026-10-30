// Real official AWS SDK against a bounded local S3 protocol fixture; no cloud credentials.
import http from "node:http";
import assert from "node:assert/strict";
import { createHmac, randomUUID } from "node:crypto";
import { S3MediaStorage, sha } from "../../dist/mvp/storage.js";
import { save } from "./local.mjs";
const access = "SYNTHETIC_ACCESS",
  secret = "synthetic-test-only-secret",
  region = "test-region",
  bucket = "mvp-private-test",
  objects = new Map(),
  tests = [];
let unsafeAcl = false,
  policy = false,
  badRange = false,
  requests = 0;
const mac = (key, s) => createHmac("sha256", key).update(s).digest(),
  escape = (s) =>
    encodeURIComponent(s).replace(
      /[!'()*]/g,
      (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase(),
    );
function authenticate(req, bytes) {
  const auth = req.headers.authorization ?? "",
    m =
      /^AWS4-HMAC-SHA256 Credential=([^/]+)\/([^,]+), SignedHeaders=([^,]+), Signature=([a-f0-9]+)$/.exec(
        auth,
      );
  assert.ok(m, "SDK must sign every request");
  assert.equal(m[1], access);
  const scope = m[2].split("/");
  assert.equal(scope[1], region);
  assert.equal(scope[2], "s3");
  assert.equal(scope[3], "aws4_request");
  const u = new URL(req.url, "http://localhost"),
    query = [...u.searchParams]
      .map(([k, v]) => [escape(k), escape(v)])
      .sort(
        (a, b) =>
          a[0].localeCompare(b[0], "en") || a[1].localeCompare(b[1], "en"),
      )
      .map((x) => x.join("="))
      .join("&");
  const headers = m[3]
    .split(";")
    .map(
      (k) =>
        k + ":" + String(req.headers[k]).trim().replace(/\s+/g, " ") + "\n",
    )
    .join("");
  const payload = req.headers["x-amz-content-sha256"];
  assert.equal(payload, sha(bytes));
  const canonical = [
    req.method,
    u.pathname,
    query,
    headers,
    m[3],
    payload,
  ].join("\n");
  const string = [
    "AWS4-HMAC-SHA256",
    req.headers["x-amz-date"],
    m[2],
    sha(canonical),
  ].join("\n");
  let k = mac("AWS4" + secret, scope[0]);
  for (const s of scope.slice(1)) k = mac(k, s);
  assert.equal(mac(k, string).toString("hex"), m[4]);
}
const server = http.createServer(async (req, res) => {
  try {
    requests++;
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const bytes = Buffer.concat(chunks);
    authenticate(req, bytes);
    const u = new URL(req.url, "http://localhost");
    res.setHeader("x-amz-request-id", "SYNTHETIC");
    if (u.searchParams.has("policy")) {
      if (policy) {
        res.setHeader("Content-Type", "application/json");
        res.end(JSON.stringify({ Statement: [{ Principal: "*" }] }));
      } else {
        res.writeHead(404, { "Content-Type": "application/xml" });
        res.end(
          "<Error><Code>NoSuchBucketPolicy</Code><Message>Fixture has no policy</Message></Error>",
        );
      }
      return;
    }
    if (u.searchParams.has("acl")) {
      res.setHeader("Content-Type", "application/xml");
      res.end(
        '<AccessControlPolicy xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Owner><ID>owner-fixture</ID></Owner><AccessControlList><Grant><Grantee xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="' +
          (unsafeAcl ? "Group" : "CanonicalUser") +
          '">' +
          (unsafeAcl
            ? "<URI>http://acs.amazonaws.com/groups/global/AllUsers</URI>"
            : "<ID>owner-fixture</ID>") +
          "</Grantee><Permission>FULL_CONTROL</Permission></Grant></AccessControlList></AccessControlPolicy>",
      );
      return;
    }
    assert.ok(u.pathname.startsWith("/" + bucket + "/"));
    const key = u.pathname.slice(bucket.length + 2);
    if (req.method === "PUT") {
      assert.equal(req.headers["if-none-match"], "*");
      assert.equal(req.headers["x-amz-acl"], undefined);
      if (objects.has(key)) {
        res.writeHead(412, { "Content-Type": "application/xml" });
        res.end("<Error><Code>PreconditionFailed</Code></Error>");
        return;
      }
      objects.set(key, bytes);
      res.setHeader("ETag", '"' + sha(bytes) + '"');
      res.end();
      return;
    }
    if (req.method === "GET") {
      const data = objects.get(key);
      if (!data) {
        res.writeHead(404);
        res.end();
        return;
      }
      const range = /^bytes=(\d+)-(\d+)$/.exec(req.headers.range ?? "");
      let result = data;
      if (range) {
        const a = Number(range[1]),
          b = Number(range[2]);
        result = data.subarray(a, b + 1);
        res.statusCode = 206;
        res.setHeader(
          "Content-Range",
          `bytes ${badRange ? a + 1 : a}-${b}/${data.length}`,
        );
      }
      res.setHeader("Content-Length", result.length);
      res.end(result);
      return;
    }
    res.writeHead(405);
    res.end();
  } catch (e) {
    res.writeHead(400, { "Content-Type": "application/xml" });
    res.end("<Error><Code>SignatureDoesNotMatch</Code></Error>");
    tests.push({ name: "fixture verification: " + e.message, status: "FAIL" });
  }
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const storage = new S3MediaStorage({
    endpoint: "http://127.0.0.1:" + server.address().port,
    bucket,
    region,
    accessKey: access,
    secretKey: secret,
  }),
  key =
    randomUUID() + "/" + randomUUID() + "/" + sha("source") + "/display.webp",
  data = Buffer.from("SYNTHETIC PRIVATE MEDIA");
const collect = async (stream) => {
  const chunks = [];
  for await (const c of stream) chunks.push(c);
  return Buffer.concat(chunks);
};
async function test(name, fn) {
  try {
    await fn();
    tests.push({ name, status: "PASS" });
  } catch (e) {
    tests.push({ name, status: "FAIL", error: e.message });
  }
}
try {
  await test("official SDK signs private bucket policy and owner ACL checks", () =>
    storage.prepare());
  await test("conditional private PUT and streamed GET preserve actual bytes", async () => {
    await storage.put(key, data, "image/webp");
    assert.deepEqual(await collect(await storage.read(key)), data);
  });
  await test("same-byte retries are idempotent, changed bytes cannot overwrite", async () => {
    await storage.put(key, data, "image/webp");
    await assert.rejects(
      storage.put(key, Buffer.from("changed"), "image/webp"),
      /Immutable S3 object conflict/,
    );
    assert.deepEqual(objects.get(key), data);
  });
  await test("actual signed Range GET validates response bounds", async () => {
    assert.deepEqual(
      await collect(await storage.read(key, { start: 2, end: 7 })),
      data.subarray(2, 8),
    );
    badRange = true;
    await assert.rejects(
      storage.read(key, { start: 2, end: 7 }),
      /range mismatch/,
    );
    badRange = false;
  });
  await test("public ACL fails closed before any media delivery", async () => {
    unsafeAcl = true;
    await assert.rejects(storage.read(key), /owner-only/);
    unsafeAcl = false;
  });
  await test("any bucket policy fails closed before publication delivery", async () => {
    policy = true;
    await assert.rejects(storage.read(key), /bucket policy/);
    policy = false;
  });
  await test("traversal key is rejected without network access", async () => {
    const before = requests;
    await assert.rejects(storage.put("../escape", data, "image/webp"));
    assert.equal(requests, before);
  });
} finally {
  storage.close();
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
}
const result = {
  kind: "ACTUAL_OFFICIAL_SDK_LOCAL_S3_PROTOCOL_FIXTURE",
  liveCloudProviderTested: false,
  tests,
  summary: {
    passed: tests.filter((t) => t.status === "PASS").length,
    failed: tests.filter((t) => t.status === "FAIL").length,
  },
};
save("storage.json", result);
console.log(JSON.stringify(result));
if (result.summary.failed) process.exitCode = 1;
