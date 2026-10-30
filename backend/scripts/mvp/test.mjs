import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { randomUUID, randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";
import sharp from "sharp";
import { client, connection, root, save, identify } from "./local.mjs";
import { createFixture } from "./fixture.mjs";
import { hash, terms } from "../b4/fixtures.mjs";
import { createMvpApp } from "../../dist/mvp/app.js";
import { MvpRepository } from "../../dist/mvp/repository.js";
import {
  LocalMediaStorage,
  S3MediaStorage,
  byteRange,
  sha,
} from "../../dist/mvp/storage.js";
import { catalog, assertCatalog } from "./catalog.mjs";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("MVP test profile required");
const report = {
    kind: "ACTUAL_MVP_POSTGRES_NEST_STORAGE_INTEGRATION",
    startedAt: new Date().toISOString(),
    tests: [],
  },
  db = client("ms_mvp_dev"),
  // Shared profile object root; immutable business/asset UUID keys isolate test tenants
  // while keeping the complete profile database recoverable with one object manifest.
  folder = path.join(root, ".local/mvp/media");
let app, f, url, currentActor, mediaOwner, image, asset, category, booking;
const key = () => randomUUID();
async function test(name, fn) {
  try {
    await fn();
    report.tests.push({ name, status: "PASS" });
    console.log("PASS " + name);
  } catch (e) {
    report.tests.push({
      name,
      status: "FAIL",
      code: e.code ?? null,
      error: e.message,
    });
    console.log("FAIL " + name + ": " + e.message);
  }
}
async function request(
  route,
  {
    method = "GET",
    data,
    actor = currentActor ?? f.owner,
    idem = key(),
    version,
    headers = {},
    binary = false,
  } = {},
) {
  const r = await fetch(url + "/api/v1/" + route, {
    method,
    headers: {
      cookie: "ms_session=" + actor.token,
      origin: "http://127.0.0.1:3112",
      "sec-fetch-site": "same-origin",
      "content-type": "application/json",
      "x-csrf-token": actor.csrf,
      "idempotency-key": idem,
      ...(version ? { "if-match": '"' + version + '"' } : {}),
      ...headers,
    },
    body: data === undefined ? undefined : JSON.stringify(data),
  });
  return {
    status: r.status,
    headers: r.headers,
    body: binary
      ? Buffer.from(await r.arrayBuffer())
      : method === "HEAD"
        ? null
        : await r.json(),
  };
}
async function ok(route, options) {
  const r = await request(route, options);
  assert.ok(
    r.status >= 200 && r.status < 300,
    route + " " + r.status + " " + JSON.stringify(r.body),
  );
  return r.body;
}
async function denied(route, status, options) {
  const r = await request(route, options);
  assert.equal(r.status, status, route + " " + JSON.stringify(r.body));
  return r.body;
}
const portal = (op, id, version, data, opts = {}) =>
  ok("admin/portal/commands/" + op, {
    method: "POST",
    data: { branchId: f.branch.id, entityId: id, version, data },
    ...opts,
  });
const read = (kind, entity = null, branch = f.branch.id) =>
  ok(
    "admin/portal/read/" +
      kind +
      "?" +
      new URLSearchParams({
        ...(branch ? { branchId: branch } : {}),
        ...(entity ? { entityId: entity } : {}),
      }),
  );
const upload = (fileName, bytes, opts = {}) =>
  ok("admin/media/upload", {
    method: "POST",
    data: { fileName, base64: bytes.toString("base64"), branchId: f.branch.id },
    ...opts,
  });
const bookingCommand = (op, data, opts = {}) =>
  ok("booking/commands/" + op, {
    method: "POST",
    data,
    actor: f.customer,
    ...opts,
  });
function zip(files) {
  const script =
    "import sys,json,io,zipfile,base64\na=json.load(sys.stdin);b=io.BytesIO()\nwith zipfile.ZipFile(b,'w',zipfile.ZIP_DEFLATED) as z:\n for f in a:\n  i=zipfile.ZipInfo(f['name']);i.compress_type=zipfile.ZIP_DEFLATED;i.external_attr=f.get('attrs',0);z.writestr(i,base64.b64decode(f['data']))\nsys.stdout.buffer.write(b.getvalue())";
  const r = spawnSync(
    process.platform === "win32" ? "python" : "python3",
    ["-c", script],
    { input: JSON.stringify(files), maxBuffer: 40 * 1024 * 1024 },
  );
  if (r.status !== 0) throw Error("ZIP fixture generation failed");
  return r.stdout;
}
async function scopeData() {
  return {
    branchId: f.branch.id,
    offeringIds: f.offerings.map((o) => o.id),
    staffId: null,
    date: f.day,
    optionalDepositChosen: false,
    rescheduleBookingId: null,
    cursor: "0",
  };
}
try {
  await db.connect();
  await identify(db, "ms_mvp_dev");
  f = await createFixture(db);
  app = await createMvpApp(
    { ...connection("ms_mvp_dev", "api"), origin: "http://127.0.0.1:3112" },
    new LocalMediaStorage(folder),
    f.business.id,
  );
  await app.listen(0, "127.0.0.1");
  url = await app.getUrl();
  await test("all nine workspace views delegate to the approved scoped APIs in a consistent snapshot", async () => {
    for (const view of [
      "overview",
      "branches",
      "services",
      "prices",
      "staff",
      "schedule",
      "policies",
      "reservations",
      "media",
    ]) {
      const r = await ok(
        "admin/portal/workspace?" +
          new URLSearchParams({
            view,
            branchId: f.branch.id,
            from: f.day,
            to: new Date(f.start.getTime() + 7 * 86400000)
              .toISOString()
              .slice(0, 10),
          }),
      );
      assert.equal(r.actor.businessId, f.business.id);
      assert.equal(r.selectedBranchId, f.branch.id);
    }
  });
  await test("unconfigured public tenant returns an empty gallery, without private fallbacks", async () => {
    const r = await ok("portfolio");
    assert.deepEqual(r.items, []);
    assert.deepEqual(r.categories, []);
  });
  await test("session, Origin, CSRF, verified identity and customer-only admin access fail closed", async () => {
    await denied("session", 401, { headers: { cookie: "" } });
    await denied(
      "admin/portal/workspace?view=media&from=" +
        f.day +
        "&to=" +
        new Date(f.start.getTime() + 86400000).toISOString().slice(0, 10),
      403,
      { actor: f.customer },
    );
    for (const headers of [
      { origin: "https://invalid.example" },
      { "x-csrf-token": randomBytes(32).toString("base64url") },
    ])
      await denied("admin/portal/commands/category.save", 403, {
        method: "POST",
        data: {
          branchId: null,
          entityId: null,
          version: "0",
          data: { name: "Synthetic", slug: key(), active: true },
        },
        headers,
      });
  });
  await test("branches can be created after a calendar exists, without enabling booking", async () => {
    const r = await portal(
      "branch.save",
      null,
      "0",
      {
        code: "MVP_" + key(),
        displayName: "MVP SYNTHETIC new branch",
        address: null,
        timeZone: "Asia/Tehran",
        active: true,
      },
      {
        data: {
          branchId: null,
          entityId: null,
          version: "0",
          data: {
            code: "MVP_" + key(),
            displayName: "MVP SYNTHETIC new branch",
            address: null,
            timeZone: "Asia/Tehran",
            active: true,
          },
        },
      },
    );
    assert.equal(r.bookable, false);
    assert.equal(r.address, null);
  });
  await test("branch metadata updates preserve activation; timezone changes with schedules are rejected", async () => {
    let branch = (await ok("admin/branches?limit=100")).items.find(
      (b) => b.id === f.branch.id,
    );
    const before = branch.version;
    branch = await portal("branch.save", branch.id, branch.version, {
      code: branch.code,
      displayName: "MVP SYNTHETIC renamed",
      address: null,
      timeZone: branch.timeZone,
      active: true,
    });
    assert.equal(branch.bookable, true);
    await denied("admin/portal/commands/branch.save", 412, {
      method: "POST",
      data: {
        branchId: branch.id,
        entityId: branch.id,
        version: before,
        data: {
          code: branch.code,
          displayName: "stale",
          address: null,
          timeZone: branch.timeZone,
          active: true,
        },
      },
    });
    await denied("admin/portal/commands/branch.save", 409, {
      method: "POST",
      data: {
        branchId: branch.id,
        entityId: branch.id,
        version: branch.version,
        data: {
          code: branch.code,
          displayName: branch.displayName,
          address: null,
          timeZone: "UTC",
          active: true,
        },
      },
    });
  });
  let newService, newOffering;
  await test("service creation and inactive branch offering reuse the existing command boundary", async () => {
    newService = await portal(
      "service.save",
      null,
      "0",
      {
        code: "MVP_" + key(),
        displayName: "MVP SYNTHETIC service",
        description: null,
        active: true,
      },
      {
        data: {
          branchId: null,
          entityId: null,
          version: "0",
          data: {
            code: "MVP_" + key(),
            displayName: "MVP SYNTHETIC service",
            description: null,
            active: true,
          },
        },
      },
    );
    newOffering = await portal("offering.create", null, "0", {
      serviceId: newService.id,
    });
    assert.equal(newOffering.active, false);
    assert.equal(newOffering.price, null);
    assert.equal(newOffering.resourcesConfirmed, false);
  });
  await test("real offering price/duration and confirmed physical requirements persist with row CAS", async () => {
    newOffering = await portal(
      "offering.configure",
      newOffering.id,
      newOffering.version,
      {
        priceRial: "123450",
        durationMinutes: 40,
        bufferBeforeMinutes: 5,
        bufferAfterMinutes: 10,
      },
    );
    assert.equal(newOffering.price.amountRial, "123450");
    newOffering = await portal(
      "offering.requirements",
      newOffering.id,
      newOffering.version,
      { kind: "CHAIR", quantity: 1, confirmed: true },
    );
    assert.equal(newOffering.resourcesConfirmed, true);
    assert.deepEqual(newOffering.resourceRequirements, [
      { kind: "CHAIR", quantity: 1 },
    ]);
  });
  await test("forged price fields, missing confirmation and cross-tenant offering references are rejected", async () => {
    await denied("admin/portal/commands/offering.configure", 422, {
      method: "POST",
      data: {
        branchId: f.branch.id,
        entityId: newOffering.id,
        version: newOffering.version,
        data: {
          priceRial: "1",
          durationMinutes: 40,
          bufferBeforeMinutes: 5,
          bufferAfterMinutes: 10,
        },
      },
    });
    await denied("admin/portal/commands/offering.requirements", 422, {
      method: "POST",
      data: {
        branchId: f.branch.id,
        entityId: newOffering.id,
        version: newOffering.version,
        data: { kind: "CHAIR", quantity: 1, confirmed: false },
      },
    });
    await denied("admin/portal/commands/offering.configure", 404, {
      method: "POST",
      data: {
        branchId: f.branch.id,
        entityId: key(),
        version: "1",
        data: {
          priceRial: "1000",
          durationMinutes: 30,
          bufferBeforeMinutes: 0,
          bufferAfterMinutes: 0,
        },
      },
    });
  });
  await test("concurrent admin price updates have one CAS winner and one stale rejection", async () => {
    const data = {
      branchId: f.branch.id,
      entityId: newOffering.id,
      version: newOffering.version,
      data: {
        priceRial: "130000",
        durationMinutes: 40,
        bufferBeforeMinutes: 5,
        bufferAfterMinutes: 10,
      },
    };
    const r = await Promise.all([
      request("admin/portal/commands/offering.configure", {
        method: "POST",
        data,
      }),
      request("admin/portal/commands/offering.configure", {
        method: "POST",
        data: { ...data, data: { ...data.data, priceRial: "140000" } },
      }),
    ]);
    assert.deepEqual(r.map((x) => x.status).sort(), [201, 412]);
  });
  await test("current branch-local instant conversion uses the original IANA resolver", async () => {
    const r = await ok(
      "admin/portal/read/instant?" +
        new URLSearchParams({ branchId: f.branch.id, local: f.day + "T10:00" }),
    );
    assert.equal(r.timeZone, "Asia/Tehran");
    assert.equal(r.instant, f.day + "T06:30:00.000Z");
  });
  await test("staff creation and future membership use the unchanged workforce API and version", async () => {
    const ctx = await ok(
        "admin/workforce/context?from=" +
          f.day +
          "&to=" +
          new Date(f.start.getTime() + 86400000).toISOString().slice(0, 10),
      ),
      s = await ok("admin/staff", {
        method: "POST",
        version: ctx.version,
        data: { displayName: "MVP SYNTHETIC newly entered staff" },
      });
    await ok("admin/branches/" + f.secondBranch.id + "/branch-assignments", {
      method: "POST",
      version: s.version,
      data: { staffId: s.id, validFrom: f.day, validTo: null },
    });
  });
  await test("published shifts remain readable through the hardened calendar projection", async () => {
    const r = await ok(
      "admin/branches/" +
        f.branch.id +
        "/calendar?from=" +
        f.day +
        "&to=" +
        new Date(f.start.getTime() + 86400000).toISOString().slice(0, 10),
    );
    assert.equal(r.items.length, 2);
    assert.ok(r.items.every((x) => x.evidenceState === "PUBLISHED"));
  });
  await test("existing policy create/publish APIs freeze a version and reject silent edits", async () => {
    let ctx = await ok("admin/pricing/context?branchId=" + f.branch.id),
      p = await ok("admin/pricing/commands/policy.create", {
        method: "POST",
        version: ctx.version,
        data: {
          branchId: f.branch.id,
          entityId: null,
          data: { code: "MVP_" + key(), name: "MVP SYNTHETIC UI policy" },
        },
      }),
      v = await ok("admin/pricing/commands/version.create", {
        method: "POST",
        version: p.version,
        data: {
          branchId: f.branch.id,
          entityId: p.id,
          data: { terms: terms() },
        },
      });
    v = await ok("admin/pricing/commands/version.publish", {
      method: "POST",
      version: v.version,
      data: { branchId: f.branch.id, entityId: v.id, data: {} },
    });
    await denied("admin/pricing/commands/version.replace", 422, {
      method: "POST",
      version: v.version,
      data: {
        branchId: f.branch.id,
        entityId: v.id,
        data: { terms: terms({ termsText: "tampering" }) },
      },
    });
  });
  await test("the unchanged booking flow creates a real non-payment confirmation in integration", async () => {
    const av = await bookingCommand("availability", await scopeData());
    assert.ok(av.slots.length);
    const q = await bookingCommand("quote", { planId: av.slots[0].id }),
      d = await bookingCommand("draft", { branchId: f.branch.id }),
      held = await bookingCommand("hold", {
        bookingId: d.id,
        version: d.version,
        quoteId: q.id,
        contentHash: q.contentHash,
        snapshotHash: q.content.policy.snapshotHash,
        accepted: true,
      });
    booking = await bookingCommand("confirm", {
      bookingId: held.id,
      version: held.version,
    });
    assert.equal(booking.status, "CONFIRMED");
    assert.equal(booking.moneyExecuted, false);
  });
  await test("admin price edits leave accepted booking terms and prices byte-identical", async () => {
    const original = JSON.stringify(booking.quote),
      o = (await ok("admin/branches/" + f.branch.id + "/offerings")).items.find(
        (o) => o.id === f.offerings[0].id,
      );
    await portal("offering.configure", o.id, o.version, {
      priceRial: "110000",
      durationMinutes: o.durationMinutes,
      bufferBeforeMinutes: o.bufferBeforeMinutes,
      bufferAfterMinutes: o.bufferAfterMinutes,
    });
    const current = await read("reservation", booking.id);
    assert.equal(JSON.stringify(current.quote), original);
  });
  await test("capacity edits with an active reservation fail closed", async () => {
    const o = (
      await ok("admin/branches/" + f.branch.id + "/offerings")
    ).items.find((o) => o.id === f.offerings[0].id);
    await denied("admin/portal/commands/offering.configure", 409, {
      method: "POST",
      data: {
        branchId: f.branch.id,
        entityId: o.id,
        version: o.version,
        data: {
          priceRial: "110000",
          durationMinutes: 99,
          bufferBeforeMinutes: o.bufferBeforeMinutes,
          bufferAfterMinutes: o.bufferAfterMinutes,
        },
      },
    });
  });
  await test("admin cancellation requires scope, CAS, explicit confirmation and records a reason", async () => {
    const detail = await read("reservation", booking.id);
    assert.equal(detail.customerName, "B4 SYNTHETIC customer");
    await denied("admin/portal/commands/booking.cancel", 403, {
      method: "POST",
      actor: f.customer,
      data: {
        branchId: f.branch.id,
        entityId: booking.id,
        version: booking.version,
        data: { reason: "MVP SYNTHETIC cancellation", confirmed: true },
      },
    });
    const cancelled = await portal(
      "booking.cancel",
      booking.id,
      booking.version,
      { reason: "MVP SYNTHETIC cancellation", confirmed: true },
    );
    assert.equal(cancelled.status, "CANCELLED");
    const after = await read("reservation", booking.id);
    assert.equal(after.events.at(-1).reason, "MVP SYNTHETIC cancellation");
    assert.equal(
      (
        await db.query(
          "SELECT count(*)::int n FROM ms_b1_design.resource_allocation WHERE business_id=$1 AND released_at IS NULL",
          [f.business.id],
        )
      ).rows[0].n,
      0,
    );
  });
  await test("branch-scoped readers cannot inspect another branch or global media", async () => {
    await denied(
      "admin/portal/read/reservations?branchId=" + f.secondBranch.id,
      403,
      { actor: f.accounts.scoped },
    );
    await denied("admin/portal/read/media", 403, { actor: f.accounts.scoped });
  });
  mediaOwner = await f.actor("MVP media integration owner");
  await f.grant(mediaOwner, [
    "media.manage",
    "media.publish",
    "media.rights.manage",
    "branch.read",
  ]);
  currentActor = mediaOwner;
  image = await sharp({
    create: { width: 640, height: 480, channels: 3, background: "#c9a76b" },
  })
    .png()
    .toBuffer();
  await test("manual upload produces actual private optimized variants, without publication rights", async () => {
    const result = await upload("MVP-synthetic-tools.png", image);
    asset = result.items[0];
    assert.equal(asset.state, "READY");
    assert.equal(asset.rightsConfirmed, false);
    assert.deepEqual(asset.variants.map((v) => v.name).sort(), [
      "DISPLAY",
      "THUMB",
    ]);
    const gallery = await ok("portfolio");
    assert.equal(gallery.items.length, 0);
    await denied("portfolio/" + asset.id + "/DISPLAY", 404, { binary: true });
  });
  await test("two uploads racing during real authorization admit exactly one processor and release the gate", async () => {
    const repo = app.get(MvpRepository),
      original = repo.mediaAuthorize.bind(repo);
    let release,
      entered,
      calls = 0;
    const gate = new Promise((resolve) => (release = resolve)),
      arrived = new Promise((resolve) => (entered = resolve));
    repo.mediaAuthorize = async (...args) => {
      const result = await original(...args);
      if (++calls === 1) {
        entered();
        await gate;
      }
      return result;
    };
    let first;
    try {
      first = request("admin/media/upload", {
        method: "POST",
        data: {
          fileName: "race-first.png",
          base64: image.toString("base64"),
          branchId: f.branch.id,
        },
      });
      await Promise.race([
        arrived,
        new Promise((_, reject) => {
          const t = setTimeout(
            () => reject(Error("authorization barrier timeout")),
            5000,
          );
          t.unref();
        }),
      ]);
      const second = await request("admin/media/upload", {
        method: "POST",
        data: {
          fileName: "race-second.png",
          base64: image.toString("base64"),
          branchId: f.branch.id,
        },
      });
      assert.equal(second.status, 429);
      assert.equal(second.body.code, "MEDIA_PROCESSOR_BUSY");
      assert.equal(calls, 1);
    } finally {
      release();
      if (first) assert.equal((await first).status, 201);
      repo.mediaAuthorize = original;
    }
    assert.ok((await upload("race-after-release.png", image)).items.length);
  });
  await test("parallel authenticated thumbnail delivery preserves session security without serialization failures", async () => {
    const responses = await Promise.all(
      Array.from({ length: 16 }, () =>
        request("admin/media/view/" + asset.id + "/THUMB", { binary: true }),
      ),
    );
    assert.ok(
      responses.every((r) => r.status === 200),
      JSON.stringify(responses.map((r) => r.status)),
    );
    for (const r of responses)
      assert.equal((await sharp(r.body).metadata()).format, "webp");
  });
  await test("upload retries retain one asset identity and never overwrite immutable objects", async () => {
    const id = key(),
      one = await upload("MVP-retry.png", image, { idem: id }),
      two = await upload("MVP-retry.png", image, { idem: id });
    assert.deepEqual(one, two);
    await denied("admin/media/upload", 409, {
      method: "POST",
      idem: id,
      data: {
        fileName: "MVP-retry.png",
        base64: (
          await sharp({
            create: {
              width: 640,
              height: 480,
              channels: 3,
              background: "#000000",
            },
          })
            .png()
            .toBuffer()
        ).toString("base64"),
        branchId: f.branch.id,
      },
    });
  });
  await test("wrong CSRF is rejected before native processing and does not create media records", async () => {
    const before = (
      await db.query(
        "SELECT count(*)::int n FROM ms_b1_design.media_asset WHERE business_id=$1",
        [f.business.id],
      )
    ).rows[0].n;
    await denied("admin/media/upload", 403, {
      method: "POST",
      headers: { "x-csrf-token": randomBytes(32).toString("base64url") },
      data: {
        fileName: "MVP-denied.png",
        base64: image.toString("base64"),
        branchId: f.branch.id,
      },
    });
    assert.equal(
      (
        await db.query(
          "SELECT count(*)::int n FROM ms_b1_design.media_asset WHERE business_id=$1",
          [f.business.id],
        )
      ).rows[0].n,
      before,
    );
  });
  await test("publication without an active rights attestation is denied", async () => {
    await denied("admin/portal/commands/media.publish", 409, {
      method: "POST",
      data: {
        branchId: f.branch.id,
        entityId: asset.id,
        version: asset.version,
        data: {},
      },
    });
  });
  await test("category and accessible public metadata persist with actual server validation", async () => {
    category = await portal(
      "category.save",
      null,
      "0",
      { name: "MVP SYNTHETIC category", slug: "mvp-" + key(), active: true },
      {
        data: {
          branchId: null,
          entityId: null,
          version: "0",
          data: {
            name: "MVP SYNTHETIC category",
            slug: "mvp-" + key(),
            active: true,
          },
        },
      },
    );
    asset = await portal("media.edit", asset.id, asset.version, {
      title: "MVP SYNTHETIC — fixture only",
      altText: "Synthetic plain color fixture, not a salon client",
      categoryIds: [category.id],
    });
    assert.equal(asset.categories[0].id, category.id);
  });
  await test("a media editor cannot assert rights or publish without the separate permissions", async () => {
    await denied("admin/portal/commands/media.rights", 403, {
      method: "POST",
      actor: f.accounts.editor,
      data: {
        branchId: f.branch.id,
        entityId: asset.id,
        version: asset.version,
        data: {
          action: "GRANT",
          scope: "PUBLIC_WEBSITE",
          confirmed: true,
          evidenceReference: "synthetic",
          validUntil: null,
        },
      },
    });
  });
  await test("rights require affirmative confirmation and a private evidence reference", async () => {
    await denied("admin/portal/commands/media.rights", 422, {
      method: "POST",
      data: {
        branchId: f.branch.id,
        entityId: asset.id,
        version: asset.version,
        data: {
          action: "GRANT",
          scope: "PUBLIC_WEBSITE",
          confirmed: false,
          evidenceReference: "synthetic",
          validUntil: null,
        },
      },
    });
    asset = await portal("media.rights", asset.id, asset.version, {
      action: "GRANT",
      scope: "PUBLIC_WEBSITE",
      confirmed: true,
      evidenceReference: "MVP synthetic fixture rights — no client images",
      validUntil: null,
    });
    assert.equal(asset.rightsConfirmed, true);
  });
  await test("only explicitly published approved media appears, with no private fields", async () => {
    asset = await portal("media.publish", asset.id, asset.version, {});
    const g = await ok("portfolio");
    assert.equal(g.items.length, 1);
    assert.equal(g.items[0].id, asset.id);
    for (const word of [
      "originalName",
      "originalKey",
      "sourceHash",
      "evidenceReference",
      "createdBy",
      "token",
      "csrf",
    ])
      assert.ok(!JSON.stringify(g).includes(word));
    const filtered = await ok("portfolio?category=" + category.slug);
    assert.equal(filtered.items.length, 1);
    assert.equal((await ok("portfolio?category=unknown")).items.length, 0);
  });
  await test("real WebP delivery strips source metadata and supports Range and HEAD safely", async () => {
    const r = await request("portfolio/" + asset.id + "/DISPLAY", {
      binary: true,
    });
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("content-type"), "image/webp");
    assert.equal(r.headers.get("cache-control"), "no-store");
    const meta = await sharp(r.body).metadata();
    assert.equal(meta.width, 640);
    assert.equal(meta.exif, undefined);
    const part = await request("portfolio/" + asset.id + "/DISPLAY", {
      binary: true,
      headers: { range: "bytes=0-15" },
    });
    assert.equal(part.status, 206);
    assert.equal(part.body.length, 16);
    assert.deepEqual(part.body, r.body.subarray(0, 16));
    const head = await request("portfolio/" + asset.id + "/DISPLAY", {
      method: "HEAD",
    });
    assert.equal(head.status, 200);
    assert.equal(Number(head.headers.get("content-length")), r.body.length);
    await denied("portfolio/" + asset.id + "/DISPLAY", 416, {
      binary: true,
      headers: { range: "bytes=999999999-" },
    });
    await denied("portfolio/" + asset.id + "/original", 404, { binary: true });
  });
  await test("metadata edits and renewed rights each require a separate new publication", async () => {
    asset = await portal("media.edit", asset.id, asset.version, {
      title: "MVP SYNTHETIC edited",
      altText: "Synthetic fixture only",
      categoryIds: [category.id],
    });
    assert.equal(asset.state, "READY");
    assert.equal((await ok("portfolio")).items.length, 0);
    asset = await portal("media.publish", asset.id, asset.version, {});
    asset = await portal("media.rights", asset.id, asset.version, {
      action: "GRANT",
      scope: "PUBLIC_WEBSITE",
      confirmed: true,
      evidenceReference: "MVP SYNTHETIC renewal evidence",
      validUntil: null,
    });
    assert.equal(asset.state, "READY");
    await denied("portfolio/" + asset.id + "/DISPLAY", 404, { binary: true });
    asset = await portal("media.publish", asset.id, asset.version, {});
  });
  await test("invalid category edits roll back metadata, version and publication atomically", async () => {
    await denied("admin/portal/commands/media.edit", 422, {
      method: "POST",
      data: {
        branchId: f.branch.id,
        entityId: asset.id,
        version: asset.version,
        data: {
          title: "should roll back",
          altText: "synthetic",
          categoryIds: [key()],
        },
      },
    });
    const after = (await read("media")).items.find((x) => x.id === asset.id);
    assert.equal(after.version, asset.version);
    assert.equal(after.title, asset.title);
    assert.equal(after.state, "PUBLISHED");
  });
  await test("media original identity and source object references cannot be rewritten", async () => {
    await assert.rejects(
      db.query(
        "UPDATE ms_b1_design.media_asset SET original_name=$1 WHERE id=$2",
        ["tampered", asset.id],
      ),
      (e) => e.code === "MS409",
    );
    await assert.rejects(
      db.query("DELETE FROM ms_b1_design.media_asset WHERE id=$1", [asset.id]),
      (e) => e.code === "MS409",
    );
  });
  await test("revoke immediately removes gallery membership and stops new derivative requests", async () => {
    asset = await portal("media.rights", asset.id, asset.version, {
      action: "REVOKE",
      scope: "PUBLIC_WEBSITE",
      confirmed: true,
      evidenceReference: "MVP SYNTHETIC revocation",
      validUntil: null,
    });
    assert.equal(asset.state, "READY");
    assert.equal((await ok("portfolio")).items.length, 0);
    await denied("portfolio/" + asset.id + "/THUMB", 404, { binary: true });
    assert.equal(asset.rightsEvents.length, 3);
  });
  await test("rights and derivative evidence are immutable even for trusted SQL edits", async () => {
    await assert.rejects(
      db.query(
        "UPDATE ms_b1_design.media_rights_event SET evidence_reference=$1 WHERE asset_id=$2",
        ["tamper", asset.id],
      ),
      (e) => e.code === "MS409",
    );
    await assert.rejects(
      db.query("DELETE FROM ms_b1_design.media_variant WHERE asset_id=$1", [
        asset.id,
      ]),
      (e) => e.code === "MS409",
    );
  });
  await test("ZIP import accepts nested safe media, atomically private and without rights", async () => {
    const archive = zip([
        { name: "nested/a.png", data: image.toString("base64") },
        { name: "b.png", data: image.toString("base64") },
      ]),
      r = await upload("MVP-import.zip", archive);
    assert.equal(r.items.length, 2);
    assert.ok(r.items.every((m) => m.state === "READY" && !m.rightsConfirmed));
  });
  await test("ZIP traversal, symlinks, duplicate names, non-media, excessive count and bombs fail atomically", async () => {
    const before = (
      await db.query(
        "SELECT count(*)::int n FROM ms_b1_design.media_asset WHERE business_id=$1",
        [f.business.id],
      )
    ).rows[0].n;
    const files = [{ name: "../outside.png", data: image.toString("base64") }];
    for (const entries of [
      files,
      [
        ...Array.from({ length: 101 }, (_, i) => ({
          name: "dir" + i + "/",
          data: "",
        })),
        { name: "safe.png", data: image.toString("base64") },
      ],
      [
        {
          name: "link.png",
          data: Buffer.from("/etc/passwd").toString("base64"),
          attrs: 0xa1ff0000,
        },
      ],
      [
        { name: "a.png", data: image.toString("base64") },
        { name: "A.png", data: image.toString("base64") },
      ],
      [{ name: "script.svg", data: Buffer.from("<svg/>").toString("base64") }],
      Array.from({ length: 21 }, (_, i) => ({
        name: i + ".png",
        data: image.toString("base64"),
      })),
      [
        {
          name: "bomb.png",
          data: Buffer.alloc(2 * 1024 * 1024).toString("base64"),
        },
      ],
    ])
      await denied("admin/media/upload", 422, {
        method: "POST",
        data: {
          fileName: "MVP-bad.zip",
          base64: zip(entries).toString("base64"),
          branchId: f.branch.id,
        },
      });
    assert.equal(
      (
        await db.query(
          "SELECT count(*)::int n FROM ms_b1_design.media_asset WHERE business_id=$1",
          [f.business.id],
        )
      ).rows[0].n,
      before,
    );
  });
  await test("a malformed file in an otherwise valid ZIP cannot leave partially registered media", async () => {
    const before = (
      await db.query(
        "SELECT count(*)::int n FROM ms_b1_design.media_asset WHERE business_id=$1",
        [f.business.id],
      )
    ).rows[0].n;
    await denied("admin/media/upload", 422, {
      method: "POST",
      data: {
        fileName: "MVP-mixed.zip",
        base64: zip([
          { name: "valid.png", data: image.toString("base64") },
          {
            name: "invalid.png",
            data: Buffer.from("not an image").toString("base64"),
          },
        ]).toString("base64"),
        branchId: f.branch.id,
      },
    });
    assert.equal(
      (
        await db.query(
          "SELECT count(*)::int n FROM ms_b1_design.media_asset WHERE business_id=$1",
          [f.business.id],
        )
      ).rows[0].n,
      before,
    );
  });
  await test("video is actually transcoded to faststart H264 with WebP thumbnail/poster and ranged delivery", async () => {
    const target = path.join(root, ".local/mvp/synthetic-video.mp4");
    const generated = spawnSync(
      process.env.FFMPEG_BIN ?? "ffmpeg",
      [
        "-v",
        "error",
        "-f",
        "lavfi",
        "-i",
        "color=c=0xb89560:s=640x480:r=15",
        "-t",
        "1.2",
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-y",
        target,
      ],
      { windowsHide: true },
    );
    assert.equal(generated.status, 0);
    const bytes = fs.readFileSync(target),
      r = await upload("MVP-synthetic-video.mp4", bytes),
      v = r.items[0];
    assert.equal(v.kind, "VIDEO");
    assert.equal(v.variants.length, 3);
    const preview = await request("admin/media/view/" + v.id + "/VIDEO", {
      binary: true,
    });
    assert.equal(preview.status, 200);
    assert.ok(
      preview.body.indexOf(Buffer.from("moov")) <
        preview.body.indexOf(Buffer.from("mdat")),
    );
    assert.ok(preview.body.includes(Buffer.from("avc1")));
    const ranged = await request("admin/media/view/" + v.id + "/VIDEO", {
      binary: true,
      headers: { range: "bytes=0-127" },
    });
    assert.equal(ranged.status, 206);
    assert.equal(ranged.body.length, 128);
    report.video = {
      actuallyTranscoded: true,
      faststart: true,
      codec: "H264",
      originalPrivate: true,
    };
  });
  await test("local storage rejects traversal and mutation, and byte ranges validate safe bounds", async () => {
    const storage = new LocalMediaStorage(folder),
      k = f.business.id + "/" + key() + "/" + sha(image) + "/original.bin";
    await storage.put(k, image, "image/png");
    await storage.put(k, image, "image/png");
    await assert.rejects(storage.put(k, Buffer.from("replace"), "image/png"));
    await assert.rejects(storage.put("../escape", image, "image/png"));
    assert.deepEqual(byteRange("bytes=-10", 100), { start: 90, end: 99 });
    assert.throws(() => byteRange("bytes=0-1,3-4", 100));
    assert.throws(() => byteRange("bytes=100-", 100));
  });
  await test("S3 adapter rejects insecure remote endpoints and absent private bucket settings", async () => {
    assert.throws(
      () =>
        new S3MediaStorage({
          endpoint: "http://example.invalid",
          bucket: "media",
          region: "test",
          accessKey: "test",
          secretKey: "test",
        }),
    );
    assert.throws(
      () =>
        new S3MediaStorage({
          endpoint: "https://example.invalid/path",
          bucket: "media",
          region: "test",
          accessKey: "test",
          secretKey: "test",
        }),
    );
  });
  await test("original native capacity constraints and table/function privilege boundary remain intact", async () => {
    const c = await catalog(db);
    assert.equal(c.tables.length, 55);
    assert.equal(c.constraints.filter((x) => x.type === "x").length, 4);
    assert.ok(!c.functionSecurity.some((x) => x.grantee === "PUBLIC"));
    assert.equal(c.apiMemberships.length, 0);
    const api = client("ms_mvp_dev", "api");
    try {
      await api.connect();
      await assert.rejects(
        api.query("SELECT * FROM ms_b1_design.media_asset"),
        (e) => e.code === "42501",
      );
      await assert.rejects(
        api.query("SELECT ms_b1_design.mvp_rights_current($1,$2)", [
          f.business.id,
          asset.id,
        ]),
        (e) => e.code === "42501",
      );
    } finally {
      await api.end();
    }
  });
} catch (e) {
  report.fatal = { code: e.code ?? null, error: e.message };
  console.log("FATAL " + e.message);
  process.exitCode = 1;
} finally {
  if (app) await app.close();
  await db.end();
  report.summary = {
    passed: report.tests.filter((t) => t.status === "PASS").length,
    failed: report.tests.filter((t) => t.status === "FAIL").length,
  };
  report.finishedAt = new Date().toISOString();
  save("integration.json", report);
  if (report.summary.failed || report.fatal) process.exitCode = 1;
  console.log(JSON.stringify(report.summary));
}
