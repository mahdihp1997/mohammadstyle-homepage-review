import {
  BookingRepository,
  type BookingOptions,
} from "../booking/repository.js";
import type { PageQuery, ResourceKind, WriteDto } from "../admin/contracts.js";
export class MvpRepository extends BookingRepository {
  constructor(o: BookingOptions) {
    if (process.env.APP_ENV !== "mvp-local" || o.port !== 55450)
      throw Error("Explicit MVP isolation required");
    super(o);
  }
  override async onModuleInit() {
    await super.onModuleInit();
    const r = (
      await this.pool.query(
        "SELECT has_function_privilege(current_user,to_regprocedure('ms_b1_design.mvp_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb)'),'EXECUTE') ready",
      )
    ).rows[0];
    if (!r?.ready) throw Error("MVP migration required");
  }
  legacyRead(
    h: Buffer,
    k: ResourceKind | "business",
    b: string | null,
    p: PageQuery,
  ) {
    return this.transaction(
      async (c) =>
        (
          await c.query("SELECT ms_b1_design.b1b_read($1,$2,$3,$4,$5,$6) r", [
            h,
            k,
            b,
            p.limit,
            p.offset,
            p.sort,
          ])
        ).rows[0].r,
    );
  }
  legacyCommand(
    h: Buffer,
    c: Buffer,
    k: ResourceKind | "session",
    id: string | null,
    b: string | null,
    v: string | null,
    key: string,
    r: string,
    d: WriteDto | Record<string, never>,
  ) {
    return this.transaction(
      async (db) =>
        (
          await db.query(
            "SELECT ms_b1_design.b1b_command($1,$2,$3,$4,$5,$6,$7,$8,$9) r",
            [h, c, k, id, b, v, key, r, d],
          )
        ).rows[0].r,
    );
  }
  workforceRead(
    h: Buffer,
    k: string,
    b: string | null,
    s: string | null,
    from: string,
    to: string,
    offset: number,
    view: string = "current",
  ) {
    return this.transaction(
      async (c) =>
        (
          await c.query(
            view === "history"
              ? "SELECT ms_b1_design.b2b_read_history($1,$2,$3,$4,$5,$6,$7) r"
              : "SELECT ms_b1_design.b2b_read($1,$2,$3,$4,$5,$6,$7) r",
            [h, k, b, s, from, to, offset],
          )
        ).rows[0].r,
    );
  }
  workforceCommand(
    h: Buffer,
    c: Buffer,
    op: string,
    b: string | null,
    id: string | null,
    v: string,
    key: string,
    r: string,
    d: unknown,
  ) {
    return this.transaction(
      async (db) =>
        (
          await db.query(
            "SELECT ms_b1_design.b2b_command($1,$2,$3,$4,$5,$6,$7,$8,$9) r",
            [h, c, op, b, id, v, key, r, d],
          )
        ).rows[0].r,
    );
  }
  pricingRead(
    h: Buffer,
    k: string,
    b: string | null,
    id: string | null,
    history: boolean,
    offset: number,
  ) {
    return this.transaction(
      async (c) =>
        (
          await c.query("SELECT ms_b1_design.b3_read($1,$2,$3,$4,$5,$6) r", [
            h,
            k,
            b,
            id,
            history,
            offset,
          ])
        ).rows[0].r,
    );
  }
  pricingCommand(
    h: Buffer,
    c: Buffer,
    op: string,
    b: string | null,
    id: string | null,
    v: string,
    key: string,
    r: string,
    d: unknown,
  ) {
    return this.transaction(
      async (db) =>
        (
          await db.query(
            "SELECT ms_b1_design.b3_command($1,$2,$3,$4,$5,$6,$7,$8,$9) r",
            [h, c, op, b, id, v, key, r, d],
          )
        ).rows[0].r,
    );
  }
  portalRead(
    h: Buffer,
    k: string,
    b: string | null,
    id: string | null,
    offset: number,
    d: unknown = {},
  ) {
    return this.transaction(
      async (c) =>
        (
          await c.query("SELECT ms_b1_design.mvp_read($1,$2,$3,$4,$5,$6) r", [
            h,
            k,
            b,
            id,
            offset,
            d,
          ])
        ).rows[0].r,
    );
  }
  mediaAuthorize(h: Buffer, c: Buffer, b: string | null) {
    return this.transaction(
      async (db) =>
        (
          await db.query(
            "SELECT ms_b1_design.mvp_media_authorize($1,$2,$3) r",
            [h, c, b],
          )
        ).rows[0].r,
    );
  }
  portalCommand(
    h: Buffer,
    c: Buffer,
    op: string,
    b: string | null,
    id: string | null,
    v: string,
    key: string,
    r: string,
    d: unknown,
  ) {
    return this.transaction(
      async (db) =>
        (
          await db.query(
            "SELECT ms_b1_design.mvp_command($1,$2,$3,$4,$5,$6,$7,$8,$9) r",
            [h, c, op, b, id, v, key, r, d],
          )
        ).rows[0].r,
    );
  }
  ingest(
    h: Buffer,
    c: Buffer,
    b: string | null,
    key: string,
    digest: string,
    r: string,
    assets: unknown,
  ) {
    return this.transaction(
      async (db) =>
        (
          await db.query(
            "SELECT ms_b1_design.mvp_media_ingest($1,$2,$3,$4,$5,$6,$7) r",
            [h, c, b, key, digest, r, JSON.stringify(assets)],
          )
        ).rows[0].r,
    );
  }
  async delivery(
    h: Buffer | null,
    b: string | null,
    id: string,
    v: string,
    pub: boolean,
  ): Promise<{ key: string; mime: string; bytes: string; sha256: string }> {
    // One authoritative SQL statement already has a consistent statement snapshot.
    // READ COMMITTED allows parallel session keep-alives for image requests without
    // serializable read/write conflicts. Booking admission keeps its original isolation.
    return (
      await this.pool.query(
        "SELECT ms_b1_design.mvp_media_delivery($1,$2,$3,$4,$5) r",
        [h, b, id, v, pub],
      )
    ).rows[0].r;
  }
  gallery(b: string | null, category: string | null, offset: number) {
    return this.transaction(
      async (db) =>
        (
          await db.query("SELECT ms_b1_design.mvp_public_gallery($1,$2,$3) r", [
            b,
            category,
            offset,
          ])
        ).rows[0].r,
    );
  }
  workspace(
    h: Buffer,
    view: string,
    requested: string | null,
    from: string,
    to: string,
    history: boolean,
    offset: number,
  ) {
    return this.transaction(async (c) => {
      const get = async (sql: string, args: unknown[]) =>
        (await c.query(sql, args)).rows[0].r;
      const actor = (await get("SELECT ms_b1_design.b1b_session($1) r", [
        h,
      ])) as import("../admin/contracts.js").SessionView;
      const can = (p: string, b: string | null = null) =>
        actor.assignments.some(
          (x) =>
            x.permission === p &&
            (x.branchId === null || (b !== null && x.branchId === b)),
        );
      if (
        !actor.assignments.some((x) =>
          [
            "branch.read",
            "catalog.read",
            "staff.read",
            "schedule.read",
            "policy.read",
            "media.manage",
            "booking.read",
          ].includes(x.permission),
        )
      )
        throw Object.assign(Error("FORBIDDEN"), { code: "MS403" });
      const empty = { items: [] };
      const legacy = (kind: string, b: string | null = null) =>
        get("SELECT ms_b1_design.b1b_read($1,$2,$3,$4,$5,$6) r", [
          h,
          kind,
          b,
          100,
          0,
          "asc",
        ]);
      const branches = actor.assignments.some(
        (x) => x.permission === "branch.read",
      )
        ? await legacy("branch")
        : empty;
      const branch = requested ?? branches.items[0]?.id ?? null;
      const base = {
        actor,
        business: can("business.read") ? await legacy("business") : empty,
        branches,
        services: can("catalog.read") ? await legacy("service") : empty,
        selectedBranchId: branch,
      };
      const data: Record<string, unknown> = {};
      const portal = (kind: string, id: string | null = null) =>
        get("SELECT ms_b1_design.mvp_read($1,$2,$3,$4,$5,$6) r", [
          h,
          kind,
          branch,
          id,
          ["media", "reservations"].includes(kind) ? offset : 0,
          {},
        ]);
      const wf = (kind: string, b: string | null = branch) =>
        get(
          history && ["calendar", "exceptions"].includes(kind)
            ? "SELECT ms_b1_design.b2b_read_history($1,$2,$3,$4,$5,$6,$7) r"
            : "SELECT ms_b1_design.b2b_read($1,$2,$3,$4,$5,$6,$7) r",
          [h, kind, b, null, from, to, 0],
        );
      if (
        ["overview", "reservations"].includes(view) &&
        branch &&
        can("booking.read", branch)
      )
        data.reservations = await portal("reservations");
      if (["overview", "media"].includes(view) && can("media.manage", branch)) {
        data.media = await portal("media");
        data.categories = await portal("categories");
      }
      if (
        ["prices", "staff", "schedule", "policies"].includes(view) &&
        can("staff.read", branch)
      )
        data.staff = await wf("staff", can("staff.read") ? null : branch);
      if (
        ["prices", "staff", "schedule"].includes(view) &&
        branch &&
        can("offering.read", branch)
      )
        data.offerings = await legacy("offering", branch);
      if (
        ["staff", "schedule"].includes(view) &&
        branch &&
        can("staff.read", branch)
      )
        for (const kind of ["assignments", "qualifications", "eligibilities"])
          data[kind] = await wf(kind);
      if (["staff", "schedule"].includes(view) && can("schedule.read", branch))
        data.context = await wf("context");
      if (view === "staff" && can("staff.link"))
        data.identities = await portal("identities");
      if (view === "policies" && can("policy.read", branch)) {
        for (const kind of ["context", "policies", "assignments"])
          data["pricing" + kind[0]!.toUpperCase() + kind.slice(1)] = await get(
            "SELECT ms_b1_design.b3_read($1,$2,$3,$4,$5,$6) r",
            [
              h,
              kind,
              branch,
              null,
              kind !== "context" && can("policy.history.read", branch),
              0,
            ],
          );
        data.policyHeaders = await portal("policy-headers");
      }
      if (
        ["prices", "schedule"].includes(view) &&
        branch &&
        can("resource.manage", branch)
      )
        data.resources = await wf("resources");
      if (view === "schedule" && branch && can("schedule.read", branch))
        for (const kind of [
          "rules",
          "hours",
          "calendar",
          "exceptions",
          "configuration",
        ])
          data[kind] = await wf(kind);
      return { ...base, data };
    });
  }
}
